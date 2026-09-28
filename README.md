# NEXUS ONE

Fundação de uma plataforma SaaS multi-tenant. Este workspace ainda **não é uma plataforma pronta para produção**: os domínios funcionais, integrações externas, controles operacionais e evidências de segurança precisam ser implementados e validados antes de qualquer uso com dados reais.

## Arquitetura atual

- Monorepo TypeScript com pnpm workspaces e orquestração Turbo.
- `apps/web`: interface Next.js.
- `services/*`: limites de domínio para serviços NestJS independentes.
- `packages/*`: contratos e bibliotecas compartilhados, sem dependências de infraestrutura.
- PostgreSQL como fonte transacional; Redis, RabbitMQ, Elasticsearch, Qdrant e Azurite no ambiente local.
- Azure, Kubernetes e Terraform são alvos de implantação, não ambientes provisionados por este repositório.

## Estrutura

```text
apps/       web, admin e mobile
services/   auth, users, workflow, finance, analytics, notifications e ai
packages/   shared, types e ui
infra/      docker, kubernetes, terraform e observabilidade
docs/       arquitetura, segurança, dados, serviços, deploy e ADRs
```

## Pré-requisitos

- Node.js 22.14 ou superior e pnpm 10.15.
- Docker Desktop para dependências locais.
- Credenciais e recursos Azure apenas para implantação em nuvem.

## Comandos

```powershell
corepack enable
Copy-Item .env.example .env
pnpm install
pnpm dev
pnpm lint
pnpm check-types
pnpm test
pnpm build
docker compose --env-file .env -f infra/docker/compose.yaml up -d
```

Os serviços locais de dados usam credenciais descartáveis para desenvolvimento. Troque-as antes de abrir qualquer porta para outras interfaces de rede; os valores padrão não podem ser reutilizados fora da máquina local. Segredos de produção devem ser fornecidos pelo provedor de secrets, nunca commitados. `pnpm install` cria o primeiro lockfile; ele deve ser revisado e commitado antes de tratar os builds como reprodutíveis.

O frontend está disponível em `http://localhost:3000` após `pnpm --filter @nexus/web dev`. O bootstrap HTTP de identidade usa `http://localhost:3001/api/v1/health`; ainda não oferece cadastro nem autenticação. Grafana local usa a porta `3002`, Jaeger `16686`, Prometheus `9090` e RabbitMQ Management `15672`.

## Estado e limites

Esta versão contém a fundação do monorepo, a tela inicial, uma verificação HTTP de processo, o esquema inicial e infraestrutura de desenvolvimento. Não oferece ainda autenticação utilizável, autorização RBAC/ABAC, fluxos de negócio, IA/RAG, integrações de notificação, métricas de aplicação, SLAs ou implantação automatizada. O guard de RLS exige configuração explícita de tenant na conexão, que ainda não está ligada ao serviço. Não use dados pessoais ou financeiros reais. Leia [docs/production-readiness.md](docs/production-readiness.md) antes de planejar um deploy.

## Documentação

- [Arquitetura](docs/architecture.md)
- [Serviços e estado](docs/services.md)
- [Banco de dados e RLS](docs/database.md)
- [Segurança](docs/security.md)
- [Infraestrutura e deploy](docs/deployment.md)
- [Prontidão para produção](docs/production-readiness.md)
- [Auditoria técnica](docs/architecture-audit.md)
- [Contribuição](docs/contributing.md)
- [ADR 0001: isolamento tenant](docs/adr/0001-tenant-isolation.md)