# Segurança

## Controles presentes

- O bootstrap Auth aplica Helmet, CORS com origens de configuração, prefixo `/api/v1`, validação global futura de DTOs e rate limit global de 120 requests/minuto. Configuração é validada no startup.
- Swagger só pode ser ligado fora de produção por configuração; não há rota de autenticação exposta.
- O Compose vincula portas a `127.0.0.1`; as credenciais são exclusivamente de desenvolvimento e Elasticsearch está sem autenticação.
- O esquema PostgreSQL aplica RLS forçado, FKs tenant-scoped, bloqueio de hard delete e auditoria imutável de alterações.
- Não existem inputs de domínio nem credenciais de produção neste bootstrap.

## Limites conhecidos

Helmet não substitui sanitização contextual, política CSP validada com a UI, CSRF para cookies, escape de saída, autorização de objetos, rotação de chaves nem proteção de upload. RLS instalado sem transação tenant-aware não é isolamento funcional. A API inicial não emite nem verifica JWT e não oferece MFA, RBAC/ABAC ou autenticação.

Criptografia em trânsito/em repouso depende de configuração do serviço/infraestrutura. Ainda não existem gestão de chaves, Azure Key Vault, criptografia de campo AES-256, MFA, rate limits distribuídos, detecção de abuso, verificação de arquivos, SBOM ou resposta a incidentes. Bcrypt/Argon2 e parâmetros de hash devem ser escolhidos com benchmark e política de migração antes de criar usuários.

## Gates antes de dados reais

Threat model por fluxo; testes de tenant isolation/IDOR; revisão de SSRF e prompt injection no RAG; modelagem de retenção e privacidade; rotação e recuperação de segredos; varredura de dependências/containers; CSP e CSRF verificadas em browsers; pentest; backup restore; alertas acionáveis; logs de auditoria exportados para storage imutável. Não afirmar conformidade OWASP, SOC 2 ou ISO sem evidência revisada.