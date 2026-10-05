# TH7 Enterprise Suite

Fundação de uma plataforma SaaS empresarial multi-tenant para reunir projetos, pessoas, workflow, finanças, analytics, notificações e inteligência artificial em um único workspace.

> **Status atual: fundação de desenvolvimento.** Este repositório ainda não é um produto pronto para produção. Autenticação completa, autorização, casos de uso de domínio, integrações, operação e evidências de segurança precisam ser implementados e validados antes do uso com dados reais.

## Visão geral

O TH7 é organizado como um monorepo TypeScript. A aplicação web fornece a experiência do workspace; serviços independentes representam bounded contexts; pacotes compartilhados concentram tipos e componentes; e a pasta `infra` reúne os recursos para desenvolvimento local, observabilidade e futuros alvos de deploy.

### O que existe hoje

- Dashboard inicial em Next.js com estado vazio e navegação visual do workspace.
- Bootstrap HTTP do serviço de identidade em NestJS, com endpoint de health.
- Configuração de CORS, Helmet, prefixo de API, validação global e Swagger opcional no serviço de identidade.
- Esquema PostgreSQL inicial com entidades tenant-scoped, RLS, auditoria e soft delete.
- Biblioteca compartilhada de contexto de tenant e pacote de UI.
- Ambiente local Docker Compose para dados, mensageria, busca, vetores, armazenamento e observabilidade.
- Testes unitários, integração PostgreSQL com Testcontainers, E2E com Playwright e smoke load com k6.

### O que ainda não existe

Não há login utilizável, emissão ou verificação de JWT, MFA, RBAC/ABAC, autorização por objeto, fluxos de negócio, outbox, consumers, integrações reais com IA/RAG, métricas de domínio, SLAs ou deploy automatizado. O RLS está definido no banco, mas o serviço ainda não configura o tenant autenticado na transação. Consulte [Prontidão para produção](docs/production-readiness.md) antes de planejar um ambiente real.

## Stack e ferramentas

| Camada             | Tecnologias                                                    | Papel                                                              |
| ------------------ | -------------------------------------------------------------- | ------------------------------------------------------------------ |
| Runtime            | Node.js `22.14+`, TypeScript `5.9`                             | Execução e tipagem estática em todo o workspace                    |
| Workspace          | pnpm `10.15`, pnpm workspaces, Turborepo `2.5`                 | Dependências, workspaces e execução coordenada de tarefas          |
| Web                | Next.js `15`, React `19`, Tailwind CSS `4`                     | Aplicação web e composição visual                                  |
| UI                 | Lucide React, CVA, `clsx`, `tailwind-merge`                    | Ícones, variantes e composição de classes                          |
| Estado e dados web | Zustand, TanStack React Query                                  | Estado local e camada preparada para dados assíncronos             |
| APIs               | NestJS `11`, Express, RxJS                                     | Serviços HTTP modulares e APIs versionadas                         |
| Contrato de API    | Swagger / OpenAPI                                              | Documentação opcional da API de desenvolvimento                    |
| Persistência       | PostgreSQL `17`                                                | Fonte transacional, integridade referencial e RLS                  |
| Cache              | Redis `7.4`                                                    | Dependência local preparada para cache e coordenação               |
| Mensageria         | RabbitMQ `4.1`                                                 | Dependência local preparada para eventos e workers                 |
| Busca              | Elasticsearch `8.15`                                           | Dependência local para projeções de pesquisa e analytics           |
| Vetores            | Qdrant `1.13`                                                  | Dependência local para embeddings e RAG                            |
| Storage            | Azurite `3.33`                                                 | Emulador local de Blob, Queue e Table Storage do Azure             |
| Observabilidade    | OpenTelemetry, Jaeger `1.62`, Prometheus `3.2`, Grafana `11.5` | Base para traces, métricas e visualização                          |
| Testes             | Jest, Supertest, Testcontainers, Playwright, k6                | Unitários, integração, E2E e carga smoke                           |
| Qualidade          | ESLint `9`, Prettier `3`, TypeScript                           | Lint, formatação e verificação de tipos                            |
| Infraestrutura     | Docker Compose, Kubernetes/Kustomize, Terraform `1.9`, Azure   | Desenvolvimento local e alvos de implantação                       |
| CI                 | GitHub Actions                                                 | Lint, tipos, testes, build, auditoria, E2E, Terraform e smoke load |

As versões acima refletem os manifestos e arquivos de infraestrutura deste repositório. Dependências locais não significam que a integração de produção já esteja implementada.

## Fundamentos arquiteturais

### Multi-tenancy e isolamento

O tenant é uma fronteira de segurança, não apenas um campo de filtro. Dados tenant-scoped usam chaves compostas e políticas de PostgreSQL Row-Level Security. O desenho exige que cada transação configure `app.tenant_id`, `app.actor_id`, `app.client_ip` e `app.device_info` com `SET LOCAL` antes de consultar dados protegidos. Um header enviado pelo cliente nunca é prova de autorização.

### Bounded contexts

Cada diretório em `services/` representa um contexto de negócio e deve ser dono de seus dados. Serviços não devem acessar diretamente tabelas de outros contextos. REST versionada é o contrato síncrono; eventos de domínio publicados após commit serão o contrato assíncrono quando broker, outbox e política de compatibilidade forem implementados.

### Fonte de verdade e projeções

PostgreSQL é a fonte transacional. Redis, Elasticsearch, Qdrant e Blob Storage são caches, índices, vetores ou referências reconstruíveis. CQRS só deve ser aplicado quando a assimetria entre leitura e escrita justificar projeções dedicadas.

### Segurança por camadas

O desenho combina validação de configuração, Helmet, CORS explícito, rate limit, validação de payload, autorização no serviço, RLS, auditoria e observabilidade. Esses controles formam uma base, mas não substituem threat modeling, gestão de segredos, CSP, CSRF, varreduras, pentest, backup/restore e resposta a incidentes.

### Observabilidade e operação

O ambiente local já inclui Jaeger, Prometheus e Grafana. A direção arquitetural é propagar IDs de correlação, traces e métricas sem registrar conteúdo sensível. A instrumentação de aplicação, métricas de domínio, dashboards acionáveis, alertas, SLOs e runbooks ainda precisam ser ligados aos serviços.

## Estrutura do monorepo

```text
apps/
	web/                    Next.js: dashboard e experiência do workspace
	admin/                  Superfície administrativa planejada
	mobile/                 Aplicação móvel planejada
services/
	auth/                   Bootstrap da API de identidade
	users/                  Bounded context de pessoas e usuários
	workflow/               Bounded context de processos e tarefas
	finance/                Bounded context financeiro
	analytics/              Bounded context de analytics
	notifications/          Bounded context de notificações
	ai/                     Bounded context de inteligência artificial
packages/
	shared/                 Código compartilhado, incluindo contexto de tenant
	types/                  Contratos e tipos compartilhados planejados
	ui/                     Componentes e utilitários de UI
infra/
	docker/                 Dependências locais e inicialização PostgreSQL
	kubernetes/             Baseline Kustomize de segurança
	terraform/              Recursos Azure iniciais
	observability/          Configuração Prometheus/Grafana
	load/                   Scripts k6
docs/
	architecture.md         Decisões e fluxo arquitetural
	database.md             Modelo, RLS e auditoria
	security.md              Controles e limites de segurança
	deployment.md            Docker, Kubernetes, Terraform e CI
	adr/                     Architecture Decision Records
```

## Pré-requisitos

- Node.js `22.14.0` ou superior.
- pnpm `10.15.0`, habilitado com Corepack.
- Docker Desktop com Docker Compose.
- PowerShell, Bash ou ambiente equivalente para os scripts de desenvolvimento.
- Credenciais Azure somente quando recursos de nuvem forem realmente provisionados.

## Começando

Na raiz do repositório:

```powershell
corepack enable
pnpm install
docker compose -f infra/docker/compose.yaml up -d
pnpm dev
```

Para conferir a configuração do Compose sem iniciar os containers:

```powershell
docker compose -f infra/docker/compose.yaml config
```

O Compose usa credenciais descartáveis e portas vinculadas a `127.0.0.1`. Troque-as antes de expor qualquer serviço fora da máquina local. Segredos de produção devem vir de um provedor de secrets e nunca ser commitados.

## Comandos principais

| Comando                                                | Finalidade                                         |
| ------------------------------------------------------ | -------------------------------------------------- |
| `pnpm dev`                                             | Inicia as tarefas de desenvolvimento via Turborepo |
| `pnpm --filter @th7/enterprise-suite-web dev`          | Inicia apenas o frontend web                       |
| `pnpm --filter @th7/enterprise-suite-auth-service dev` | Inicia apenas a API Auth em watch mode             |
| `pnpm lint`                                            | Executa ESLint nos pacotes configurados            |
| `pnpm check-types`                                     | Verifica os tipos TypeScript                       |
| `pnpm test`                                            | Executa os testes definidos nos workspaces         |
| `pnpm build`                                           | Compila os pacotes e aplicações                    |
| `pnpm format`                                          | Formata os arquivos com Prettier                   |
| `pnpm format:check`                                    | Verifica a formatação sem alterar arquivos         |
| `pnpm --filter @th7/enterprise-suite-web test:e2e`     | Executa os testes Playwright do frontend           |
| `pnpm audit --prod --audit-level high`                 | Audita dependências de produção                    |

## Endpoints e portas locais

| Serviço       | Endereço                              | Observação                                     |
| ------------- | ------------------------------------- | ---------------------------------------------- |
| Web           | `http://localhost:3000`               | Dashboard Next.js                              |
| Auth health   | `http://localhost:3001/api/v1/health` | Verificação do processo HTTP                   |
| Grafana       | `http://localhost:3002`               | Dashboards locais                              |
| PostgreSQL    | `localhost:5432`                      | Banco transacional local                       |
| Redis         | `localhost:6379`                      | Cache local                                    |
| RabbitMQ      | `localhost:5672`                      | Broker; management em `http://localhost:15672` |
| Elasticsearch | `http://localhost:9200`               | Busca local sem autenticação no Compose        |
| Qdrant        | `http://localhost:6333`               | API vetorial; gRPC em `6334`                   |
| Azurite       | `localhost:10000-10002`               | Emulador de storage Azure                      |
| Jaeger        | `http://localhost:16686`              | Tracing local; OTLP em `4317`/`4318`           |
| Prometheus    | `http://localhost:9090`               | Métricas locais                                |

O serviço Auth ainda não oferece cadastro, login ou autenticação. Os valores padrão do Compose são somente para desenvolvimento local.

## Qualidade e CI

O workflow em `.github/workflows/ci.yml` é executado em pull requests e pushes para `main`. Ele cobre:

- instalação com Node.js e pnpm;
- lint, verificação de tipos, testes e build via Turborepo;
- auditoria de dependências de produção;
- `terraform fmt`, `terraform init -backend=false` e `terraform validate`;
- instalação do Chromium e testes E2E com Playwright;
- build e smoke load do endpoint de health com k6.

Os testes atuais validam a fundação e não substituem testes de autenticação, autorização, contratos de domínio, workflow, finanças, carga de negócio ou isolamento tenant-to-tenant.

## Infraestrutura e deploy

- **Docker Compose:** dependências locais com volumes nomeados para dados de desenvolvimento.
- **Kubernetes:** baseline com namespace restrito, quota, limites de recursos e negação de rede por padrão. Ainda faltam Deployments, Services, Ingress, secrets e exceções de rede revisadas.
- **Terraform/Azure:** base inicial para Resource Group e Azure Container Registry. Rede privada, banco gerenciado, Key Vault, cluster, monitoramento e backend remoto ainda não estão provisionados.
- **Produção:** exige artefatos imutáveis por digest, migrations expand/contract, workload identity, secret store, probes, limites, políticas de rede, rollout, rollback, backup e restore drill.

Detalhes operacionais estão em [Infraestrutura e deploy](docs/deployment.md).

## Segurança e dados

Não use dados pessoais, financeiros ou credenciais reais neste estado do projeto. Antes de qualquer uso real, ainda são necessários autenticação e autorização completas, gestão e rotação de segredos, criptografia, CSP/CSRF, proteção de uploads, filtros ACL no RAG, prevenção de prompt injection, threat model, varredura de supply chain, pentest, retenção/privacidade, backup/restore e plano de incidentes.

Leia [Segurança](docs/security.md), [Banco de dados](docs/database.md) e [Prontidão para produção](docs/production-readiness.md) antes de criar um ambiente compartilhado.

## Documentação técnica

- [Arquitetura](docs/architecture.md)
- [Serviços e estado de implementação](docs/services.md)
- [Banco de dados, RLS e auditoria](docs/database.md)
- [Segurança](docs/security.md)
- [Infraestrutura e deploy](docs/deployment.md)
- [Prontidão para produção](docs/production-readiness.md)
- [Auditoria técnica](docs/architecture-audit.md)
- [Contribuição](docs/contributing.md)
- [ADR 0001: isolamento de tenant](docs/adr/0001-tenant-isolation.md)

## Contribuição

Antes de abrir uma mudança, leia [Contribuição](docs/contributing.md), mantenha o escopo do bounded context, atualize a documentação quando o contrato mudar e execute pelo menos `pnpm lint`, `pnpm check-types`, `pnpm test` e `pnpm build`. Mudanças de segurança, banco ou infraestrutura também devem atualizar a documentação técnica e os ADRs relacionados.

## Licença

Este repositório não declara uma licença pública. Consulte os responsáveis pelo projeto antes de redistribuir o código.
