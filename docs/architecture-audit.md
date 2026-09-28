# Auditoria Técnica do NEXUS ONE

**Data:** 2026-09-28

**Resultado:** **NO-GO para produção, dados reais ou alegação de conformidade.**

**Base de avaliação:** código, configurações e documentação presentes no workspace. As notas medem implementação verificável, não arquitetura pretendida.

## Parecer Executivo

O repositório é uma fundação de portfólio em estágio inicial, não a plataforma empresarial descrita no objetivo. Há um dashboard estático Next.js, um serviço NestJS que expõe somente health, um schema PostgreSQL inicial, infraestrutura local e documentos de design. A lista de serviços e vários controles existem apenas como arquivos README/planos. O único controller da API é o [health controller](../services/auth/src/health.controller.ts#L5); o estado de cada domínio está resumido em [Serviços e responsabilidades](services.md).

Há boas decisões iniciais: TypeScript estrito, CORS explícito, Helmet, DTO pipe preparado, rate limit local, chaves estrangeiras compostas por tenant, RLS forçado no schema, ambiente Docker preso a loopback e política de rede Kubernetes deny-all. Nenhuma delas, isoladamente, constitui autorização funcional, isolamento validado em produção ou readiness operacional.

**A meta de 95/100 não é atingível adicionando mais tecnologias ao estado atual.** O caminho é provar um fluxo de produto pequeno, implementar autorização e dados de ponta a ponta, e só então adicionar os sistemas cuja necessidade seja demonstrada por carga, requisitos de clientes ou risco regulatório.

## Achados Prioritários

### A1. Bloqueador: não há produto funcional nem autorização

**Severidade: crítica para qualquer implantação de produto.** O backend possui somente `GET /health`; não encontrei rotas de login, usuários, projetos, tarefas ou finanças, nem guard JWT, políticas RBAC/ABAC ou autorização de objeto. O app aplica rate limit global, Helmet, CORS e validação global, mas isso não substitui autenticação/autorização. A dashboard exibe zeros e seus botões/links não executam casos de uso; a verificação Playwright cobre apenas a apresentação inicial.

**Risco:** não existe uma boundary de segurança para proteger os dados que o sistema pretende armazenar. Um ambiente real não pode ser considerado SaaS multi-tenant.

**Ação:** manter o deploy bloqueado. Definir primeiro identidade, membership, política de autorização de objeto e testes negativos tenant-to-tenant; ligar UI, API e banco em um fluxo completo.

Referências: [bootstrap do Auth](../services/auth/src/app.module.ts#L18), [controller existente](../services/auth/src/health.controller.ts#L5), [dashboard](../apps/web/src/app/page.tsx#L98), [teste de UI](../apps/web/e2e/dashboard.spec.ts#L3).

### A2. Alto: RLS está no schema, mas não no caminho de request

**Severidade: crítica antes de persistir dados de clientes.** As policies dependem de `app.current_tenant_id()` lendo um GUC de conexão; o serviço não configura transação, tenant autenticado ou papel SQL de runtime. A documentação confirma essa lacuna. O teste prepara o contexto manualmente, portanto prova a policy isolada, não a integração API→transação.

GUCs de sessão são contexto confiável apenas enquanto o serviço que possui a conexão estiver íntegro. Um usuário SQL com essa conexão pode definir outro `app.tenant_id`; RLS baseado somente nesse valor protege principalmente contra queries acidentalmente sem filtro, não contra comprometimento do runtime ou SQL injection com liberdade suficiente. Superusers e papéis `BYPASSRLS` também ignoram RLS. O usuário inicial do Compose é o usuário de bootstrap do PostgreSQL e não deve virar credencial da aplicação.

**Ação:** autenticar membership antes da query, obter tenant de claims verificadas, estabelecer `SET LOCAL` dentro de cada transação, usar role runtime não proprietária e sem `BYPASSRLS`, restringir grants e testar pool reuse/rollback. Tratar RLS como defesa em profundidade; não como única autorização.

Referências: [função de contexto](../infra/docker/postgres/init/001_core.sql#L6), [ativação de RLS](../infra/docker/postgres/init/001_core.sql#L373), [guia do banco](database.md#L12).

### A3. Alto: o modelo de autenticação e os segredos ainda não são seguros para uso

Não há JWT, refresh token rotativo, MFA, OAuth, recuperação de conta, hash de senha, bloqueio de brute force ou sessão funcional. `users.mfa_secret` aparece como texto simples no schema. A função de auditoria remove campos com nomes conhecidos, mas snapshots continuam podendo copiar email, nome, identificadores fiscais, valores financeiros ou futuras colunas secretas. `actor_id`, IP e dispositivo vêm de GUCs que ainda não são preenchidos por middleware confiável.

**Ação:** não armazenar segredo MFA sem envelope encryption/Key Vault e rotação; definir algoritmo e custo de password hashing; armazenar apenas hashes de tokens; proteger cookies contra CSRF caso sejam usados; limitar e redigir auditoria por classificação de dados. Definir retenção, exportação WORM e processo auditado de eliminação/anonymização. “Nunca excluir” não pode impedir obrigações de privacidade e retenção legal.

Referências: [campo MFA](../infra/docker/postgres/init/001_core.sql#L82), [redação de snapshots](../infra/docker/postgres/init/001_core.sql#L10), [auditoria de segurança](security.md).

### A4. Alto: schema inicial não é uma migration operacional

O SQL está montado em `docker-entrypoint-initdb.d`, que roda somente na inicialização de um volume novo. Não há migration runner, sequência/checksum de versões, grants de runtime, rollback planejado ou compatibilidade expand/contract. Editar esse arquivo não atualiza bancos já inicializados. Além disso, as policies e triggers são geradas por bloco dinâmico que ainda não foi executado contra PostgreSQL neste ambiente.

**Ação:** executar a migration em PostgreSQL/Testcontainers, adotar ferramenta de migração versionada, definir ownership/grants separados para migrator/runtime e tornar backup/restore de schema e dados um gate. Não promover a migration por edição manual em ambiente persistente.

Referências: [migration atual](../infra/docker/postgres/init/001_core.sql), [limite documentado do init script](database.md#L5), [teste Testcontainers](../services/auth/test/tenant-isolation.integration.spec.ts#L15).

### A5. Alto: builds não são reproduzíveis nem há entrega de aplicação

Não existe `pnpm-lock.yaml`; a CI usa `pnpm install --no-frozen-lockfile` em todos os jobs. Dependências com ranges podem resolver versões diferentes entre execuções. Terraform também não possui lockfile de providers. A pipeline audita dependências e executa verificações, mas não constrói/publica imagem, não faz deploy e não define promoção/rollback. Não há Dockerfile de app.

**Ação:** gerar e revisar lockfiles, exigir `--frozen-lockfile`, fixar hashes/versões de actions e providers, habilitar branch protection, SBOM e scan de imagens. Criar ambientes dev/staging/prod e aprovação por ambiente antes de qualquer deploy.

Referências: [instalação CI](../.github/workflows/ci.yml#L28), [tarefas de qualidade](../.github/workflows/ci.yml#L30), [ausência de rollout documentada](deployment.md).

### A6. Alto: a infraestrutura declarada não pode hospedar o produto

Compose é apenas ambiente de desenvolvimento. Usa credenciais locais previsíveis, Elasticsearch sem auth e Qdrant sem autenticação; as portas estão em loopback, o que reduz exposição na máquina, mas não torna essas configurações apropriadas a um ambiente compartilhado. Kubernetes contém namespace/quota/deny-all, mas não Deployment, Service, ingress, secrets ou regras de rede para workloads. Terraform cria somente Resource Group e ACR Standard; não cria rede privada, banco, cluster, Key Vault ou observabilidade Azure.

**Ação:** manter os perfis locais explicitamente isolados; jamais reutilizar credenciais dev. Desenhar identidade de workload, private endpoints, banco gerenciado, secret store, política de saída e estratégia de backup antes de escolher AKS. Proibir `apply` de `production` até que módulos e guardrails existam.

Referências: [credencial local do PostgreSQL](../infra/docker/compose.yaml#L9), [Elasticsearch sem autenticação](../infra/docker/compose.yaml#L60), [baseline Kubernetes](../infra/kubernetes/base/default-deny.yaml#L1), [recursos Terraform](../infra/terraform/main.tf#L9).

### A7. Médio: estratégia de microserviços conflita com ownership de dados descrito

O documento diz que cada serviço será dono dos próprios dados e não lerá tabelas alheias; o schema, porém, compartilha tabelas e relações como projects→companies, boards→projects e invoices→companies. Esse desenho é adequado a um monólito modular, mas cria acoplamento e deploy coordenado se os módulos forem chamados de microserviços independentes.

**Ação:** escolher explicitamente um dos modelos. Para o MVP, recomendar monólito modular NestJS, um PostgreSQL e limites de módulo/schema; FKs são aceitáveis dentro do mesmo sistema. Só separar serviços quando ownership por time, disponibilidade, ciclo de release ou escala justificar, migrando então os dados para ownership real e substituindo FKs cross-service por contratos/eventos.

Referências: [regra de ownership](architecture.md#L31), [FK de projeto para empresa](../infra/docker/postgres/init/001_core.sql#L155), [FK de board para projeto](../infra/docker/postgres/init/001_core.sql#L169), [FK de fatura para empresa](../infra/docker/postgres/init/001_core.sql#L231).

### A8. Médio: observabilidade é infraestrutura sem instrumentação da aplicação

Jaeger recebe OTLP, mas não há SDK/agent OpenTelemetry no frontend nem nos serviços; Prometheus coleta apenas ele próprio e Jaeger. Não há métricas de negócio, logs estruturados/redigidos, correlation IDs, alertas, dashboards Grafana, SLOs ou runbooks. `/health` comprova apenas que o processo respondeu, não que banco/filas estão prontos.

**Ação:** padronizar logs estruturados com redaction; trace IDs W3C frontend→API→DB/consumidores; endpoints separados de liveness/readiness; histogramas p50/p95/p99, error rate e saturação; alertas por burn rate e runbooks. Evitar cardinalidade ilimitada por `tenantId` em métricas.

Referências: [scrapes atuais](../infra/observability/prometheus.yml#L1), [health do processo](../services/auth/src/health.controller.ts#L5), [lacuna documentada](deployment.md).

## Aderência Arquitetural

| Padrão | Situação observada | Parecer |
| --- | --- | --- |
| SOLID / Clean Architecture | Não há camadas de domínio, casos de uso ou portas/adapters no Auth; há somente bootstrap/controller. | Ainda não demonstrado |
| DDD | Bounded contexts aparecem nos documentos, mas não há agregados, invariantes ou eventos implementados. | Intenção, não aderência |
| CQRS | Nenhuma query/command handler ou projeção separada. | Não implementado; não exigir no MVP |
| Event Driven / Domain Events | RabbitMQ no Compose, sem publisher, consumer, outbox, schema registry ou tópico aplicado. | Não implementado |
| Repository / Unit of Work | Nenhum adapter de persistência ou transação da aplicação. | Não implementado |
| Dependency Injection | Nest DI é usada para controller/guard/configuração. | Presente no bootstrap |
| API Versioning | Prefixo estático `/api/v1`. | Adequado como baseline; contrato OpenAPI é só para health |
| Multi-tenant | Colunas, FKs e RLS existem no SQL; contexto da aplicação não existe. | Parcial e não operacional |

**Sobreengenharia:** sete serviços, três apps, cinco sistemas de dados adicionais, mensageria, vetores, marketplace e agentes autônomos antes de validar um fluxo central é complexidade de alto custo. Não adote CQRS, microserviços, event sourcing ou plugin sandbox por checklist. Use abstrações somente diante de uma necessidade mensurável.

## MVP: Adequação e Recorte Recomendado

**O MVP atual não valida o produto nem demonstra o fluxo full-stack prometido.** Login, gestão real de usuário/tenant, projeto, board, CRUD/movimentação de tarefa, dashboard conectada, settings e auditoria end-to-end estão ausentes. A dashboard estática não deve ser apresentada como funcionalidade entregue.

**Manter no MVP:**

- Um tipo de cliente e problema operacional bem definido; uma jornada principal demonstrável.
- Identidade e membership de tenant seguras; para um SaaS de demonstração, usar provedor OIDC gerenciado reduz risco de construir IAM prematuramente.
- Um monólito modular NestJS com projetos, boards, tarefas, filtros e transições com versão concorrente.
- Dashboard derivada dos dados reais; configurações mínimas de tenant; audit log de alterações relevantes.
- DTOs/runtime validation, OpenAPI, migrations, testes de autorização cross-tenant e E2E da jornada completa.

**Adiar:** mobile/admin separados, OAuth multi-provedor próprio, finance/ERP, analytics estilo Power BI, IA/RAG/agentes, Qdrant, Elasticsearch, marketplace, domínios white-label, RabbitMQ e Kubernetes. Começar com PostgreSQL; usar full-text search/JSONB quando adequado. Adicionar cache, broker e busca dedicada somente após medir o gargalo ou identificar requisito de negócio.

## Revisão por Domínio

### Frontend e UX

- Estrutura App Router é enxuta e usa Server Component para a página estática, mas só há uma rota. Query client/state Zustand estão instalados sem uso; não são exigidos para essa UI e devem permanecer fora do caminho até existir fluxo de cliente que justifique cache/state.
- Navegação leva a âncoras da mesma página; botões de criar, buscar, notificações, workspace e perfil não têm handlers. Não há loading/error/empty conectado a API, autenticação, preferências persistidas ou switch de tema explícito. Dark mode depende apenas da preferência do sistema.
- Há foco visível, redução de movimento e breakpoint mobile. Textos auxiliares de 9–11px e cinzas claros são pequenos e têm risco de contraste WCAG; não há auditoria automatizada/manual de leitores de tela, teclado ou alto contraste.
- CSS customizado e Tailwind coexistem; o pacote UI fornece apenas Button. Definir tokens documentados, primitives acessíveis e contrato de navegação; testar zoom 200%, teclado e WCAG 2.2 AA. SEO não é prioridade para workspace autenticado; requer política específica para páginas públicas.

### Backend e API

- Auth valida variáveis com Joi, aplica Helmet/CORS/ValidationPipe e rate limit global: boas proteções de bootstrap. O limite `120/min` usa armazenamento padrão local e não é quota distribuída entre réplicas; o endpoint health também fica sob o guard.
- Prefixo de rota não é versionamento de schema. Não há DTOs, casos de uso, autorização, OpenAPI de domínio, persistência, logs de domínio, idempotência ou tratamento de erro contratual.
- Separar `/live` de `/ready`, excluir liveness de limitação e adicionar shutdown graceful antes de escalar. Não criar sete APIs vazias para representar uma arquitetura.

### Banco de Dados

**Pontos bons:** IDs UUID, FKs compostas tenant-scoped, algumas constraints, checks monetários e cinco índices iniciais; RLS é habilitado e forçado para tabelas tenant-scoped.

**Lacunas e propostas:**

- Índices existentes cobrem tarefas por board/status, faturas por vencimento, auditoria por tenant/data, notificações por recipient e sessões ativas. Avaliar, com `EXPLAIN (ANALYZE, BUFFERS)` e workload real, índices nos lados filhos das FKs, como tarefas por `(tenant_id, board_id, position)`, atribuições por `(tenant_id, assignee_id)`, workflow por tarefa, arquivos por owner e embeddings por arquivo. O PostgreSQL não cria automaticamente índice no lado referencing de toda FK; não criar índices cegamente.
- `updated_at` tem defaults, não trigger de atualização; precisa de comportamento garantido no adapter/use case ou trigger testado. Email é `UNIQUE` case-sensitive por tenant; normalizar conforme política de identidade. `char(3)` não valida moeda ISO. Posição decimal do Kanban ainda precisa de estratégia para colisão/rebalanceamento e concorrência.
- Auditoria armazena snapshots JSON completos. Planejar partição por tempo/retention/archival, diffs seguros e redaction por classificação. Join rows sem coluna `id` produzem `entity_id` nulo; adotar `entity_key` JSON/PK composta no log.
- Entidades adicionais dependem do escopo e incluem memberships/teams/departments, project membership, workflow transitions/version history, audit de acesso, notifications delivery attempts, outbox/inbox e idempotency keys. IA precisa de `messages/tool_calls` e provenance/ACL de chunks; finanças precisa de linhas, pagamentos/ledger, moeda/conciliação; isso não deve ser todo introduzido no MVP.

### Segurança — OWASP Top 10

| Área | Estado real e ação principal |
| --- | --- |
| A01 Broken Access Control | **Bloqueador:** sem login/autorização de objetos/tenant no app. Implementar guards + policy checks + testes IDOR/cross-tenant. |
| A02 Cryptographic Failures | Sem gestão de chaves/criptografia de campo; `mfa_secret` no schema é texto. Classificar PII, usar TLS/KMS/envelope encryption e hashing de senha escolhido por benchmark. |
| A03 Injection | Não há API de domínio para auditar. ValidationPipe e queries parametrizadas devem ser padrão; nunca concatenar SQL. Testcontainers não prova segurança de queries ainda inexistentes. |
| A04 Insecure Design | Superfície extensa (marketplace/agentes/RAG) sem threat model, abuso, quotas ou aprovação humana. Reduzir escopo e fazer threat modeling por fluxo. |
| A05 Security Misconfiguration | Credenciais/serviços sem auth são aceitáveis apenas no Compose local preso a loopback. Não promover defaults, `--loose` ou Elasticsearch sem security. |
| A06 Vulnerable/Outdated Components | Sem lockfile/SBOM/scan de imagem; `pnpm audit` sozinho não substitui análise de supply chain. Fixar lock e política de atualização. |
| A07 Identification and Authentication | JWT, refresh rotation, MFA, recovery, OAuth, brute-force e sessão não implementados. Não permitir usuário/dados reais. |
| A08 Software and Data Integrity | Actions usam tags móveis; não há assinatura, provenance, SBOM ou deploy imutável. Fixar SHA/digests e proteger branch/releases. |
| A09 Logging and Monitoring Failures | Sem logs estruturados/redigidos, alertas ou trace da aplicação. Não registrar segredo, prompt/documento completo ou payload financeiro. |
| A10 SSRF | Ainda não há fetcher/integração de domínio; AI, URLs importadas e plugins ampliarão esse risco. Usar egress allowlist, bloqueio de metadata endpoints e isolamento. |

CSRF é obrigatório se autenticação futura usar cookies; CORS não substitui CSRF. React escaping não resolve XSS em conteúdo rico importado. OWASP API Security acrescenta BOLA, consumo irrestrito e propriedade de objeto como foco central para workflow e AI.

### IA, Multi-tenant, White Label e Marketplace

- **IA:** dependências/provedor, chat, tools, ingestão, embeddings e retrieval não existem. `ai_conversations` e `ai_sessions` guardam apenas cabeçalhos/estado, sem mensagens. Antes de implementar: filtros tenant+ACL antes e depois do retrieval, isolamento de documentos, scanning/limits, prompt-injection tests, logging redacted, quotas/token cost, avaliação de groundedness e human approval para ações. NL→SQL deve usar views allowlisted, role read-only, AST restrita, timeout/row limit e não confiar em tenant definido pelo modelo.
- **Multi-tenant:** FKs compostas e RLS reduzem erros acidentais. Falta onboarding/provisionamento, fonte confiável de membership, session context middleware, grants/roles, quotas, export/deletion e teste pelo fluxo HTTP. O GUC sozinho não impede que um runtime comprometido escolha outro tenant.
- **White label:** `tenants.branding` é somente JSON. Faltam schema validado de cores/logo, armazenamento/CDN, domínios verificados, certificados, cookies/CORS/CSP por domínio, cache key tenant-aware e fallback seguro de tema.
- **Marketplace:** não há entidade ou execução de plugin. Nunca executar código/upload de tenant no processo do API. Exigir assinatura/revisão, manifest de capacidades, consentimento por tenant, isolamento real, quotas, versão/compatibilidade, revogação e sandbox atualizável; preferir integrações por API/webhooks no MVP.

### DevOps, Observabilidade e Performance

- Só há ambiente local. DEV/HOMOLOG/PROD, backups/PITR/restore drill, DR, rollback, blue-green/canary, autoscaling, políticas de branch e secret store não foram configurados.
- Compose não tem serviço da aplicação nem health check para todos os serviços. Elasticsearch sem security, Qdrant sem chave e PostgreSQL bootstrap user exigem isolamento estrito local; não são defaults de staging.
- Terraform não oferece backend remoto/locking nem módulos para workload. AKS não é requisito inicial; Azure Container Apps + Postgres gerenciado pode reduzir a carga de operação até haver necessidade comprovada de Kubernetes.
- Gargalos futuros: queries sem paginação/limites, fan-out por tenant, contenção de board position, snapshots de auditoria, índices insuficientes, pool exaurido, filas sem DLQ, cache sem invalidação tenant-aware e consultas BI no OLTP. Ainda não há tráfego/benchmark para quantificá-los.
- Métricas a adicionar: latency/error/saturation por rota; pool wait/query/locks; cache hit/evictions; queue depth/lag/retries/DLQ; search/vector latency e frescor; autenticação/denials; uploads; tokens/custo/429/groundedness IA. Para frontend: Web Vitals, JS exceptions e falhas por release. Não etiquetar métricas com tenant ID de alta cardinalidade.

### Testes e Documentação

- Existem testes de health, alguns invariantes RLS/auditoria em Testcontainers, dois asserts de dashboard e um cenário K6 de health com 5 VUs (30 s sustentados; 55 s incluindo ramp-up/down). Isso é uma boa semente, não cobertura de domínio. O workspace atual não tem dependências instaladas; os diagnósticos reportam ausência de tipos Node/Jest e módulos `pg`/Testcontainers, então nenhum teste/build foi executado nesta auditoria.
- Não há `coverageThreshold`, contract tests, teste de auth, autorização, CRUD/drag-and-drop, outbox, upload, stress/soak ou teste de restore. Recomendo 80–90% de cobertura de linhas nos casos de uso críticos como indicador, mas 100% das decisões críticas de autorização/transição via testes de comportamento; porcentagem global não é gate de segurança.
- Há README, architecture, database, security, deployment, services, contributing e ADR. `API.md` e `ROADMAP.md` não existem. Swagger é opcional e descreve somente health.

## Roadmap de Elevação

1. **Reprodutibilidade:** Node/pnpm fixos, lockfile versionado, instalação frozen, formatos/checks estáveis; executar migration e Testcontainers em CI com evidência.
2. **Produto vertical:** escolher persona/jornada; fazer identity+tenant, membership, projetos, board/tarefas e audit trail integrado num modular monolith; entregar happy path e permission denials via Playwright/API.
3. **Segurança operacional:** threat model, authorization policy por objeto, contexto RLS transacional, papéis SQL mínimos, segredos gerenciados, logs redigidos, CSP/CSRF adequados ao modelo de sessão e testes independentes de tenant.
4. **Confiabilidade:** migrations versionadas, backup/restore comprovado, health/readiness, OpenTelemetry end-to-end, SLO/alertas, limites de recursos, runbooks e staging isolado.
5. **Escala medida:** adicionar outbox/consumer quando houver trabalho assíncrono; Redis para hot paths medidos; Elasticsearch se busca relacional/FTS insuficiente; Qdrant apenas com RAG ACL-safe; separar microserviços por ownership/carga comprovados.
6. **Expansão de produto:** finanças, analytics avançado, IA/agents, mobile, white-label domains e marketplace após entrevistas, unit economics, privacidade, modelo de ameaça e operação das etapas anteriores.

## Notas

Critério: implementação e evidência testada; planos e nomes de dependência recebem pouco crédito. Uma nota 95 exige comportamento, segurança, testes e operação comprovados em ambiente representativo.

| Critério | Nota | Justificativa curta |
| --- | ---: | --- |
| Arquitetura | 22/100 | Há direção documental; limites de dados e distribuição ainda se contradizem e padrões não estão no código. |
| Segurança | 10/100 | Alguns defaults defensivos; autenticação/autorização, segredos e isolamento de request ausentes. |
| Escalabilidade | 16/100 | Stack potencialmente escalável, sem cargas, isolamento operacional ou validação. |
| Manutenibilidade | 35/100 | Workspace e documentação úteis; sem lock, código de domínio ou contrato estável. |
| DevOps | 20/100 | CI/dev baseline e Terraform mínimo; sem artefatos, ambientes, backup ou deploy. |
| IA | 3/100 | Apenas intenção/documentação e tabelas de cabeçalho; nenhum modelo ou pipeline. |
| Banco de dados | 35/100 | Schema tenant-aware razoável como início, mas não migrado, integrado nem validado por carga. |
| Frontend | 28/100 | Dashboard visual responsiva; sem sessão, dados, navegação funcional ou estados reais. |
| Backend | 12/100 | Bootstrap Auth com health e proteções HTTP; sem endpoints/casos de uso. |
| **Geral** | **20/100** | Média arredondada, reduzida pelo bloqueio de produção em segurança, backend e operação. |

**Conclusão:** hoje é um esqueleto de portfólio bem documentado, não Enterprise Grade. A maior melhoria de nota virá de fechar uma jornada vertical e demonstrar controles com testes/runtime; expandir a stack sem esses fundamentos tende a baixar segurança e manutenibilidade, não elevá-las.