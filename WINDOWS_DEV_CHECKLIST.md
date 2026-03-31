# Windows Dev Backend Checklist

Use este checklist quando quiser validar o backend Windows/Tailscale sem bloquear o E2E principal do iOS.

## SSH

- Confirmar que `ssh mav@100.86.55.27 -p 22` autentica normalmente.
- Evitar depender da `2222` enquanto ela continuar aceitando TCP sem completar banner SSH.
- Se usar alias, revisar `~/.ssh/config` para host, porta e usuário.

## Backend Vita

- Confirmar processo ouvindo `3110`.
- Se usar Docker, rodar `docker ps` e verificar containers do Vita.
- Testar respostas HTTP reais:
  - `/api/mockup/dashboard`
  - `/api/config/app`
  - `/api/progress`
  - `/api/activity/stats`
- Se houver timeout/reset, inspecionar logs do serviço e do reverse proxy.

## iOS Override

- Para apontar o app iOS ao Windows sem editar código:
  - `VITA_API_BASE_URL=http://100.86.55.27:3110/api`
  - `VITA_AUTH_BASE_URL=http://100.86.55.27:3110`
- O iOS mantém ATS liberado apenas para `localhost` e `100.86.55.27`.
- `x-forwarded-host: localhost` só é enviado quando o override usa HTTP explícito.

## Regra operacional

- `prod` é o baseline do E2E.
- `demo/e2e` é o fallback confiável para UI e navegação.
- `windows/dev` é ambiente opcional de integração e não deve bloquear smoke local.
