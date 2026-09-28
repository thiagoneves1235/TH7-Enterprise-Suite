# Auth Service

**Estado: bootstrap técnico; não autentica usuários.** Expõe apenas `GET /api/v1/health`, valida configuração, aplica Helmet/rate limit e disponibiliza OpenAPI somente fora de produção quando explicitamente habilitado. Cadastro, senha, JWT, refresh token, MFA, OAuth, sessões, recuperação, audit middleware e persistência ainda não existem.

Antes de qualquer rota de credencial: threat model, desenho de rotação/revogação de sessão, hash moderno calibrado, segredo no vault, limites distribuídos, controles de enumeration/abuso, CSRF se houver cookie, auditoria sem segredo e testes de takeover/tenant. Não reutilize o endpoint de health como readiness de dependências.