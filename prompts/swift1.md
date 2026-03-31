Voce eh SWIFT-1: AUTH e NETWORKING. Corrija TODOS os bugs abaixo no VitaAI iOS. Edite os arquivos diretamente.

1. BEARER para COOKIE (CRITICO): 4 locais enviam Bearer mas backend espera Cookie (Better Auth).
   - VitaChatClient.swift:25 - trocar Authorization Bearer por Cookie: better-auth.session_token=TOKEN
   - TranscricaoClient.swift:79 - mesmo fix
   - OsceSseClient.swift:36 - mesmo fix
   - OnboardingViewModel.swift:164 - mesmo fix
   - Referencia correta: HTTPClient.swift:40 ja usa Cookie.

2. TOKEN REFRESH (CRITICO): HTTPClient.swift:70-71 recebe 401 e so lanca erro. Implementar interceptor que ao receber 401 tenta refresh via /api/auth/session. Se falhar, AuthManager.logout() automatico.

3. RETRY LOGIC (CRITICO): Zero retry. HTTPClient: adicionar retry com exponential backoff (max 3) pra 5xx e timeout. SimuladoViewModel.swift:284 - NUNCA try? em resposta do aluno. OnboardingViewModel.swift:167 - dados nao podem ser perdidos.

4. URLSession.shared BYPASS: AuthManager.swift:114,119 e os 3 SSE clients usam URLSession.shared ignorando HTTPClient. Corrigir.

Apos cada fix, explique brevemente o que mudou.
