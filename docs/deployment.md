# Infraestrutura e deploy

## Desenvolvimento

```powershell
Copy-Item .env.example .env
docker compose --env-file .env -f infra/docker/compose.yaml config
docker compose --env-file .env -f infra/docker/compose.yaml up -d
```

O Compose fornece dependências locais e dados persistentes nomeados. Redefinir o workspace Docker pode apagar dados. PostgreSQL, Redis, Elasticsearch e Grafana locais não usam configurações de produção. Prometheus atualmente coleta somente suas próprias métricas e as métricas do Jaeger; nenhuma aplicação publica métricas ainda.

## Kubernetes

`infra/kubernetes/base` aplica namespace restrito, quota, limites de recursos e negação de rede por padrão. Não há Deployment, Service, Ingress, External Secrets, políticas de saída específicas ou imagens publicadas. O namespace não está pronto para receber workloads até que exceções de rede, identidades de workload, secrets e observabilidade sejam revisadas.

## Terraform/Azure

O Terraform cria apenas Resource Group e Azure Container Registry com autenticação administrativa desativada. Configure `ARM_*` via identidade federada/CLI ou `TF_VAR_subscription_id`; use backend remoto com RBAC e locking antes de `apply`. Não há Postgres Azure, rede privada, Key Vault, private endpoints, monitoramento Azure ou cluster Kubernetes provisionados.

## CI

GitHub Actions executa instalação, lint, typecheck, Jest, Testcontainers, build, auditoria de dependências, Playwright, smoke K6 e validação Terraform. O primeiro install cria `pnpm-lock.yaml`; gere e revise esse arquivo localmente e altere a CI para `--frozen-lockfile` antes de exigir builds reproduzíveis. Não há build/push de imagens nem deploy automático: faltam imagens endurecidas, testes de contrato de domínio, ambiente com aprovação, credenciais federadas e política de rollback.

## Rollout esperado

Promova artefatos imutáveis por digest em dev/staging/prod, use migrações expand/contract compatíveis, secret store e workload identity, probes separadas de startup/readiness/liveness, limites de recursos, topology spread, PDB, NetworkPolicy testada, rollout canário e rollback automatizado. A configuração presente não implementa esse processo.