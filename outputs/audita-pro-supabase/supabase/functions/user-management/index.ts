import { createClient } from 'npm:@supabase/supabase-js@2.57.0';
import { uploadProfileDocument } from './profile-documents.ts';

const projectUrl = Deno.env.get('SUPABASE_URL') ?? '';
const secretKey = Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const admin = createClient(projectUrl, secretKey, { auth: { persistSession: false, autoRefreshToken: false } });
const allowedOrigins = new Set((Deno.env.get('AUDITA_PRO_ALLOWED_ORIGINS') ?? 'http://localhost:4173,http://127.0.0.1:4173,http://localhost:4174,http://127.0.0.1:4174,http://localhost:5181,http://127.0.0.1:5181')
  .split(',').map((value) => value.trim()).filter(Boolean));
// Current Audita PRO deployment; preserve any additional configured origins.
allowedOrigins.add('https://audita-pro-validacao.vinicius-eloisa2.chatgpt.site');
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const roles = new Set(['Administrador', 'Auditor Líder', 'Auditor', 'Participante / Auditado']);

function response(data: unknown, status = 200, origin = ''): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': allowedOrigins.has(origin) ? origin : '',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
    },
  });
}
function fail(message: string, status = 400, origin = ''): Response { return response({ error: message }, status, origin); }
function asText(value: unknown): string { return typeof value === 'string' ? value.trim() : ''; }
function asUuid(value: unknown): string { const result = asText(value); if (!uuid.test(result)) throw new Error('Identificador inválido.'); return result; }
function asEmail(value: unknown): string { const result = asText(value).toLowerCase(); if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result) || result.length > 254) throw new Error('E-mail inválido.'); return result; }
function asCpf(value: unknown): string | null { const result = asText(value).replace(/\D/g, ''); if (!result) return null; if (result.length !== 11) throw new Error('CPF deve conter 11 dígitos.'); return result; }

async function findAuthUser(email: string) {
  const { data: indexedProfile, error: lookupError } = await admin.from('user_profiles')
    .select('user_id').eq('email', email).maybeSingle();
  if (lookupError) throw lookupError;
  if (indexedProfile) {
    const { data, error } = await admin.auth.admin.getUserById(indexedProfile.user_id);
    if (error) throw error;
    if (data.user?.email?.toLowerCase() === email) return data.user;
  }
  for (let page = 1; page <= 100; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw error;
    const match = data.users.find((user) => user.email?.toLowerCase() === email);
    if (match) return match;
    if (data.users.length < 200) return null;
  }
  throw new Error('Limite de pesquisa de contas atingido.');
}

async function requireActor(request: Request) {
  const token = (request.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) throw new Error('Sessão ausente.');
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new Error('Sessão inválida.');
  const { data: profile, error: profileError } = await admin.from('user_profiles')
    .select('user_id,status,full_name,cpf').eq('user_id', data.user.id).single();
  if (profileError || !profile || profile.status !== 'active') throw new Error('Conta inativa ou indisponível.');
  return { user: data.user, profile };
}

function requireAdmin(actor: Awaited<ReturnType<typeof requireActor>>) {
  if (actor.user.app_metadata?.platform_role !== 'admin') throw new Error('Ação restrita ao Administrador.');
}

async function verifyAdminPassword(actor: Awaited<ReturnType<typeof requireActor>>, value: unknown) {
  const password = typeof value === 'string' ? value : '';
  if (!password) throw new Error('Confirme sua senha para alterar o papel global.');
  const publicKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? '';
  if (!publicKey) throw new Error('Verificação de identidade indisponível no servidor.');
  const verifier = createClient(projectUrl, publicKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: verified, error } = await verifier.auth.signInWithPassword({
    email: actor.user.email ?? '', password,
  });
  if (error || verified.user?.id !== actor.user.id) throw new Error('Senha de confirmação incorreta.');
}

async function invite(body: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  requireAdmin(actor);
  const email = asEmail(body.email);
  const fullName = asText(body.full_name);
  const profileName = asText(body.profile_name);
  if (fullName.length < 2 || fullName.length > 200) throw new Error('Informe o nome completo.');
  if (!roles.has(profileName)) throw new Error('Selecione um perfil válido.');
  if (profileName === 'Administrador') await verifyAdminPassword(actor, body.confirmation_password);
  const cpf = asCpf(body.cpf);
  const phone = asText(body.phone).slice(0, 32) || null;
  const orgId = profileName === 'Administrador' ? null : asUuid(body.organization_id);
  const unitId = body.unit_id ? asUuid(body.unit_id) : null;
  const positionId = profileName === 'Administrador' ? null : asUuid(body.position_id);
  let accessProfileId: string | null = null;
  if (orgId) {
    const { data: org, error: orgError } = await admin.from('organizations').select('id,status').eq('id', orgId).single();
    if (orgError || org?.status !== 'active') throw new Error('Organização não encontrada ou inativa.');
    const { data: position, error: positionError } = await admin.from('positions')
      .select('id,status').eq('id', positionId).single();
    if (positionError || position?.status !== 'active') throw new Error('Cargo não encontrado ou inativo.');
    if (unitId) {
      const { data: unit, error: unitError } = await admin.from('organization_units')
        .select('id,status').eq('id', unitId).eq('organization_id', orgId).single();
      if (unitError || unit?.status !== 'active') throw new Error('Unidade inválida para esta organização.');
    }
    const { data: accessProfile, error: accessError } = await admin.from('access_profiles')
      .select('id,status').eq('name', profileName).single();
    if (accessError || accessProfile?.status !== 'active') throw new Error('Perfil de acesso indisponível.');
    accessProfileId = accessProfile.id;
  }

  let account = await findAuthUser(email);
  const existing = Boolean(account);
  if (!account) {
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, { data: { full_name: fullName } });
    if (error || !data.user) {
      await admin.from('user_invites').insert({ email, organization_id: orgId, status: 'failed',
        attempt_count: 1, last_error: String(error?.message ?? 'Convite não enviado').slice(0, 500),
        invite_payload: { full_name: fullName, email, profile_name: profileName,
          organization_id: orgId, position_id: positionId, unit_id: unitId, phone },
        created_by: actor.user.id });
      throw new Error('Não foi possível enviar o convite. Confira a configuração de e-mail do Supabase.');
    }
    account = data.user;
  }
  if (!account) throw new Error('Não foi possível localizar a conta.');

  const { data: oldProfile } = await admin.from('user_profiles')
    .select('full_name,email,cpf,phone').eq('user_id', account.id).maybeSingle();
  if (oldProfile?.cpf && cpf && oldProfile.cpf !== cpf)
    throw new Error('O CPF informado diverge do cadastro existente. Solicite uma revisão antes de criar o vínculo.');
  const { error: profileError } = await admin.from('user_profiles').upsert({
    user_id: account.id, full_name: oldProfile?.full_name || fullName,
    email, cpf: oldProfile?.cpf || cpf,
    phone: oldProfile?.phone || phone,
  }, { onConflict: 'user_id' });
  if (profileError) throw new Error(`Conta localizada, mas o cadastro não foi concluído: ${profileError.message}`);

  if (profileName === 'Administrador') {
    const metadata = { ...(account.app_metadata ?? {}), platform_role: 'admin' };
    const { error } = await admin.auth.admin.updateUserById(account.id, { app_metadata: metadata });
    if (error) throw new Error('A conta foi localizada, mas o papel de Administrador não foi atribuído.');
    if (account.app_metadata?.platform_role !== 'admin') await admin.from('audit_events').insert({
      actor_user_id: actor.user.id, event_type: 'administrator_granted',
      entity_type: 'auth_user_role', entity_id: account.id,
      metadata: { before: account.app_metadata?.platform_role ?? null, after: 'admin' },
    });
  } else {
    const { data: membership, error: memberReadError } = await admin.from('organization_memberships')
      .select('id').eq('organization_id', orgId).eq('user_id', account.id).maybeSingle();
    if (memberReadError) throw memberReadError;
    if (membership) throw new Error('Esta pessoa já possui vínculo com a organização. Abra seu cadastro para gerenciá-lo.');
    const { error: memberError } = await admin.from('organization_memberships').insert({
      organization_id: orgId, unit_id: unitId, user_id: account.id, position_id: positionId,
      access_profile_id: accessProfileId, status: 'active', created_by: actor.user.id,
    });
    if (memberError) throw new Error(`Conta localizada, mas o vínculo não foi criado: ${memberError.message}`);
  }
  await admin.from('user_invites').insert({ user_id: account.id, organization_id: orgId,
    email, status: existing ? 'existing_account' : 'sent', attempt_count: existing ? 0 : 1,
    sent_at: existing ? null : new Date().toISOString(), created_by: actor.user.id });
  return { user_id: account.id, email, existing_account: existing,
    message: existing ? 'Conta existente vinculada. A senha foi preservada.' : 'Convite enviado. Aguarde o titular completar o cadastro.' };
}

async function updateUser(body: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  requireAdmin(actor);
  const userId = asUuid(body.user_id);
  const { data: current, error: currentError } = await admin.auth.admin.getUserById(userId);
  if (currentError || !current.user) throw new Error('Usuário não encontrado.');
  const fullName = asText(body.full_name);
  if (fullName.length < 2 || fullName.length > 200) throw new Error('Informe o nome completo.');
  const email = body.email ? asEmail(body.email) : current.user.email;
  if (email !== current.user.email) {
    const { error } = await admin.auth.admin.updateUserById(userId, { email });
    if (error) throw new Error(`Não foi possível alterar o e-mail: ${error.message}`);
  }
  const { error } = await admin.from('user_profiles').update({ full_name: fullName,
    email, cpf: asCpf(body.cpf), phone: asText(body.phone).slice(0, 32) || null,
  }).eq('user_id', userId);
  if (error) throw new Error(`Não foi possível salvar os dados pessoais: ${error.message}`);
  return { user_id: userId, message: 'Dados pessoais atualizados.' };
}

async function setAccountStatus(body: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  requireAdmin(actor);
  const userId = asUuid(body.user_id);
  const status = asText(body.status);
  if (!['active', 'inactive'].includes(status)) throw new Error('Status inválido.');
  if (userId === actor.user.id && status === 'inactive') throw new Error('Você não pode inativar sua própria conta.');
  const { error } = await admin.from('user_profiles').update({ status }).eq('user_id', userId);
  if (error) throw new Error(error.message);
  return { user_id: userId, status };
}

async function setGlobalRole(body: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  requireAdmin(actor);
  await verifyAdminPassword(actor, body.confirmation_password);
  const userId = asUuid(body.user_id);
  const grant = body.admin === true;
  if (userId === actor.user.id && !grant) throw new Error('Você não pode remover seu próprio papel de Administrador.');
  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data.user) throw new Error('Conta não encontrada.');
  if (!grant && data.user.app_metadata?.platform_role === 'admin') {
    let activeAdmins = 0;
    for (let page = 1; page <= 100; page++) {
      const { data: usersPage, error: pageError } = await admin.auth.admin.listUsers({ page, perPage: 200 });
      if (pageError) throw pageError;
      const admins = usersPage.users.filter((user) => user.app_metadata?.platform_role === 'admin');
      if (admins.length) {
        const { data: profiles, error: profilesError } = await admin.from('user_profiles')
          .select('user_id,status').in('user_id', admins.map((user) => user.id));
        if (profilesError) throw profilesError;
        activeAdmins += (profiles ?? []).filter((profile) => profile.status === 'active').length;
      }
      if (usersPage.users.length < 200) break;
    }
    if (activeAdmins <= 1) throw new Error('O último Administrador ativo não pode perder esse papel.');
  }
  const metadata = { ...(data.user.app_metadata ?? {}) };
  if (grant) metadata.platform_role = 'admin'; else delete metadata.platform_role;
  const { error: updateError } = await admin.auth.admin.updateUserById(userId, { app_metadata: metadata });
  if (updateError) throw new Error('Não foi possível alterar o papel global.');
  await admin.from('audit_events').insert({ actor_user_id: actor.user.id,
    event_type: grant ? 'administrator_granted' : 'administrator_revoked',
    entity_type: 'auth_user_role', entity_id: userId,
    metadata: { before: data.user.app_metadata?.platform_role ?? null,
      after: grant ? 'admin' : null },
  });
  return { user_id: userId, administrator: grant, message: 'Papel atualizado. A sessão do titular deve ser renovada.' };
}

async function getUserAccess(body: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  requireAdmin(actor);
  const userId = asUuid(body.user_id);
  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data.user) throw new Error('Conta não encontrada.');
  return { user_id: userId, administrator: data.user.app_metadata?.platform_role === 'admin' };
}

async function resendInvite(body: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  requireAdmin(actor);
  const inviteId = asUuid(body.invite_id);
  const { data: invite, error } = await admin.from('user_invites').select('*').eq('id', inviteId).single();
  if (error || !invite) throw new Error('Convite não encontrado.');
  if (invite.attempt_count >= 5) throw new Error('Limite de reenvios atingido.');
  if (!invite.user_id && invite.status === 'failed') {
    if (!invite.invite_payload) throw new Error('Convite antigo sem dados de recuperação. Crie um novo cadastro.');
    let result: Awaited<ReturnType<typeof inviteUserFromPayload>>;
    try {
      result = await inviteUserFromPayload({ ...invite.invite_payload,
        confirmation_password: body.confirmation_password }, actor);
    } catch (retryError) {
      await admin.from('user_invites').update({ attempt_count: invite.attempt_count + 1 }).eq('id', inviteId);
      throw retryError;
    }
    const { error: updateError } = await admin.from('user_invites').update({ status: 'superseded',
      attempt_count: invite.attempt_count + 1 }).eq('id', inviteId);
    if (updateError) throw new Error('Convite processado, mas o histórico anterior não foi atualizado. Confira a conta antes de tentar novamente.');
    return { invite_id: inviteId, message: result.message };
  }
  const { error: sendError } = await admin.auth.resetPasswordForEmail(invite.email);
  const next = { attempt_count: invite.attempt_count + 1, status: sendError ? 'failed' : 'sent',
    sent_at: sendError ? invite.sent_at : new Date().toISOString(),
    last_error: sendError ? String(sendError.message).slice(0, 500) : null };
  const { error: updateError } = await admin.from('user_invites').update(next).eq('id', inviteId);
  if (updateError) throw updateError;
  if (sendError) throw new Error('Não foi possível reenviar o acesso. Confira a configuração de e-mail.');
  return { invite_id: inviteId, message: 'Instruções de acesso reenviadas.' };
}

async function inviteUserFromPayload(payload: Record<string, unknown>, actor: Awaited<ReturnType<typeof requireActor>>) {
  return invite(payload, actor);
}

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? '';
  if (request.method === 'OPTIONS') return response({}, 200, origin);
  if (request.method !== 'POST') return fail('Método não permitido.', 405, origin);
  if (!projectUrl || !secretKey) return fail('Configuração do servidor incompleta.', 503, origin);
  try {
    const actor = await requireActor(request);
    const contentType = request.headers.get('Content-Type') ?? '';
    if (contentType.includes('multipart/form-data')) {
      const form = await request.formData();
      if (form.get('action') !== 'upload_profile_document') throw new Error('Use a aba Meu Perfil para enviar documentos.');
      return response(await uploadProfileDocument(admin, form, actor.user.id), 200, origin);
    }
    const body = await request.json() as Record<string, unknown>;
    const action = asText(body.action);
    const result = action === 'invite' ? await invite(body, actor)
      : action === 'update_user' ? await updateUser(body, actor)
      : action === 'set_account_status' ? await setAccountStatus(body, actor)
      : action === 'set_global_role' ? await setGlobalRole(body, actor)
      : action === 'get_user_access' ? await getUserAccess(body, actor)
      : action === 'resend_invite' ? await resendInvite(body, actor)
      : action === 'complete_self_profile' ? (() => { throw new Error('Complete seus dados na aba Meu Perfil.'); })()
      : null;
    if (!result) return fail('Ação desconhecida.', 400, origin);
    return response(result, 200, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Falha ao processar a solicitação.';
    const status = /Sessão ausente|Sessão inválida/.test(message) ? 401
      : /restrita ao Administrador|não autorizado|Conta inativa/.test(message) ? 403 : 400;
    return fail(message, status, origin);
  }
});
