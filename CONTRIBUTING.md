# Desenvolvimento do Audita PRO

O README original deste repositório foi preservado. Esta importação mantém a organização atual do aplicativo.

## Estrutura

- `outputs/`: frontend HTML/CSS/JavaScript, identidade visual, documentação e inicializador local.
- `outputs/audita-pro-supabase/supabase/migrations/`: histórico versionado de alterações do banco.
- `outputs/audita-pro-supabase/supabase/functions/`: código das Edge Functions.
- `outputs/audita-pro-supabase/README.md`: orientações do backend.

## Abrir localmente

Com Node.js disponível no PATH, execute no PowerShell:

```powershell
./outputs/iniciar-audita-pro.ps1
```

Acesse `http://127.0.0.1:5181/audita-pro-login.html`. A configuração pública do frontend aponta ao projeto Supabase existente. Clonar ou enviar este repositório não aplica migrations, publica funções nem altera dados do banco.

## Versionamento

Após cada alteração significativa, revisar o diff e sugerir um checkpoint com Conventional Commits: `feat:`, `fix:`, `refactor:`, `style:` ou `docs:`.

```sh
git status --short
git diff
git add caminho/dos/arquivos-revisados
git diff --cached --stat
git commit -m "feat: descreve a funcionalidade concluída"
git pull --ff-only
git push
```

Se houver divergência de histórico, revisar os commits antes de integrar; não usar push com force. Para desfazer um commit publicado, preferir um commit de reversão revisado. Não executar descarte geral do diretório de trabalho como rotina.

## Segredos

Não versionar arquivos `.env`, senhas, tokens de gerenciamento, chaves privadas, chaves `service_role`, logs sensíveis ou exportações do banco. O `.gitignore` evita arquivos comuns, mas não substitui revisão do conteúdo.

A URL e a chave Supabase `sb_publishable_` presentes no frontend são configuração pública do cliente; a autorização depende das funções e políticas do backend. Chaves secretas devem permanecer exclusivamente no ambiente seguro apropriado.

Arquivos temporários da CLI e a cópia gerada de deploy estão excluídos. Os scripts administrativos exigem credenciais disponíveis no ambiente autorizado e não devem ser executados automaticamente durante a instalação.
