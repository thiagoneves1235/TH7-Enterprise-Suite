# Prontidão para produção

**Decisão atual: NO-GO para produção, dados reais ou promessa de SLA.** Este repositório é uma fundação de desenvolvimento, não o produto empresarial solicitado pronto para operar. Uma tela dashboard contém dados vazios estáticos; ações nela não executam casos de uso.

## Bloqueadores

- Identidade: cadastro/login/logout, armazenamento/rotação/revogação de refresh token, recuperação segura, MFA, OAuth, sessões e brute-force controls não existem.
- Autorização: middleware JWT, membership, RBAC/ABAC, autorização por objeto e sincronização SQL/RLS não existem.
- Domínios: usuários, times, workflows, finanças, analytics, notificações, marketplace, white label e administração não possuem handlers/repositórios/casos de uso.
- Dados: executar e revisar a migração com PostgreSQL; criar roles runtime sem `BYPASSRLS`; ligar `SET LOCAL` por transação; migration framework, seeds controlados, backups, PITR e restore drill ainda faltam.
- Plataforma: transactional outbox, contratos de eventos, idempotência, consumers, retry/DLQ, cache, Elasticsearch e Qdrant não possuem integração.
- IA: não há upload/scan/extração/chunking/embeddings, filtros ACL no RAG, guardrails, redaction, tool permissions, quotas ou avaliação de respostas. SQL gerado deve ser read-only, allowlisted, paramétrico e executado sob RLS.
- Operação: não há OpenTelemetry na aplicação, métricas de domínio, dashboards provisionados, alertas, SLOs, tracing frontend/API/DB, runbooks nem plano de incidentes.
- Supply chain/testes: não há lockfile, imagens de aplicação, SBOM/assinatura/scans nem cobertura de domínio demonstrada de 90%. Jest cobre o bootstrap de processo; Testcontainers testa uma fatia PostgreSQL de RLS/auditoria; Playwright verifica o estado inicial da dashboard; K6 mede somente o endpoint de health. Não substituem testes de workflow, finanças, auth, autorização, contratos ou carga de negócio.
- Deploy: Terraform não provisiona rede privada, banco ou cluster; Kubernetes só tem policy baseline; CI não constrói/publica/deploya artefatos.
- Governança: threat model, DPA/retention, controle de acesso operador, revisão jurídica e pentest faltam.

## Critérios mínimos de saída

Cada domínio deve ter owner, ADR, contratos OpenAPI/eventos versionados, testes de autorização tenant-to-tenant, observabilidade com SLO, runbook e migrações revisadas. Segurança, banco, backups/restore, privacidade, DR, capacidade/carga e rollback precisam de aprovação demonstrável. A cobertura global de 90% só deve ser aplicada após definir exclusões legítimas e tornar unit, integração, contract, E2E e carga gates obrigatórios; porcentagem sozinha não prova segurança.