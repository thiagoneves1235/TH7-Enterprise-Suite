# Serviços e responsabilidades

O estado “planejado” significa que o serviço não tem endpoints de domínio, persistência, eventos, testes de contrato nem SLO implementados.

| Serviço | Responsabilidade | Estado |
| --- | --- | --- |
| Auth | Identidade, sessão, MFA, OAuth e tokens | Bootstrap HTTP/health somente |
| Users | Membership, organização, RBAC e políticas ABAC | Planejado |
| Workflow | Projetos, boards, tarefas, transições e sprints | Planejado |
| Finance | Receitas, despesas, orçamento e contratos | Planejado |
| Analytics | Métricas, consultas e relatórios | Planejado |
| Notifications | Outbox, preferências e entrega multicanal | Planejado |
| AI | Conversas, ingestão, RAG e agentes com ferramentas limitadas | Planejado |

## Contratos de eventos planejados

Nomes devem ser versionados no schema e conter `eventId`, `tenantId`, `occurredAt`, `actorId` quando disponível, `correlationId` e `schemaVersion`. Payloads não devem conter segredos nem dados pessoais sem necessidade.

- `identity.user.created.v1`
- `workflow.instance.approved.v1` e `workflow.instance.rejected.v1`
- `finance.invoice.overdue.v1`
- `platform.security.critical-error.v1`
- `notifications.delivery.requested.v1` e `notifications.delivery.completed.v1`

Nenhum desses tópicos ou eventos existe no broker local atualmente. Cada produtor/consumidor futuro precisa de idempotência, retry com backoff, fila de dead-letter e política de retenção.