// Files stay private; database registration locks the draft against concurrent submission.
export async function uploadProfileDocument(admin: any, form: FormData, actorId: string) {
  const submissionId = String(form.get('submission_id') || '');
  const file = form.get('file');
  if (!(file instanceof File) || file.size === 0 || file.size > 10_000_000) throw new Error('Selecione PDF, JPEG ou PNG de até 10 MB.');
  const { data: submission, error } = await admin.from('profile_submissions').select('id,user_id,membership_id,state,required_types').eq('id', submissionId).single();
  if (error || submission?.user_id !== actorId || submission.state !== 'draft' || !submission.membership_id) throw new Error('Envio não autorizado ou cadastro já submetido.');
  const documentType = String(form.get('document_type') || '');
  if (!submission.required_types.includes(documentType)) throw new Error('Documento não exigido para este perfil.');
  const bytes = new Uint8Array(await file.arrayBuffer());
  const pdf = [37,80,68,70,45].every((v,i) => bytes[i] === v);
  const jpg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const png = [137,80,78,71,13,10,26,10].every((v,i) => bytes[i] === v);
  const kind = pdf ? ['pdf','application/pdf'] : jpg ? ['jpg','image/jpeg'] : png ? ['png','image/png'] : null;
  if (!kind || !/\.(pdf|jpe?g|png)$/i.test(file.name) || (file.type && file.type !== kind[1])) throw new Error('Conteúdo ou formato inválido. Envie PDF, JPEG ou PNG.');
  const path = `identity/${submission.membership_id}/${crypto.randomUUID()}.${kind[0]}`;
  const { error: uploadError } = await admin.storage.from('identity-documents').upload(path, bytes, { contentType: kind[1], upsert: false });
  if (uploadError) throw new Error('Não foi possível armazenar o arquivo. Tente novamente.');
  const { data, error: registrationError } = await admin.rpc('profile_register_document', {
    actor: actorId, submission: submission.id, info: {
      document_type: documentType, storage_path: path, filename: file.name, size_bytes: file.size,
      issued_on: String(form.get('issued_on') || ''), expires_on: String(form.get('expires_on') || ''),
      no_expiry: form.get('no_expiry') === 'true', issuer: String(form.get('issuer') || ''), document_number: String(form.get('document_number') || ''),
    },
  });
  if (registrationError) {
    await admin.storage.from('identity-documents').remove([path]);
    throw new Error(registrationError.message);
  }
  return { document_id: data, message: 'Documento salvo. Revise o cadastro e envie para validação.' };
}
