# Banco de dados

## Migração inicial

`infra/docker/postgres/init/001_core.sql` cria as entidades de tenant, empresa, usuários, autorização, sessões, projetos, workflow, finanças, notificações, arquivos, vetores, IA e auditoria. Chaves compostas `(tenant_id, id)` fazem FKs entre dados tenant-scoped rejeitarem referências cruzadas.

O arquivo sob `docker-entrypoint-initdb.d` executa somente na criação de um volume PostgreSQL vazio. Mudanças futuras precisam usar migrations versionadas e checksum (por exemplo, Flyway ou node-pg-migrate); editar esse SQL não atualiza ambientes já inicializados. Backup antes de qualquer migration destrutiva é obrigatório.

## Row-Level Security

RLS é habilitado e forçado em tabelas tenant-scoped. Cada transação precisa definir o tenant autenticado com `SELECT set_config('app.tenant_id', $1, true)` e manter a consulta na mesma transação/conexão. O terceiro parâmetro `true` é essencial: limita o valor à transação e evita vazamento por pooling. `NULL`/contexto ausente nega acesso por padrão.

O serviço precisa obter o tenant de uma membership validada, nunca confiar no cabeçalho do cliente. Usuários de runtime não devem ser superuser, proprietário das tabelas ou possuir `BYPASSRLS`. Migrations e provisionamento inicial de tenant exigem identidade control-plane separada e auditada. Esta aplicação ainda não configura sessão transacional, roles SQL nem provisionamento.

## Auditoria, soft delete e dados sensíveis

- Registros de negócio usam `deleted_at`; triggers rejeitam `DELETE` físico. Retenção/legal hold precisam ser implementados por processo privilegiado com trilha própria.
- Triggers registram ator, timestamps, IP e dispositivo quando o request configura `app.actor_id`, `app.client_ip` e `app.device_info`. Sem middleware de request, esses campos podem ficar nulos.
- A função de auditoria mascara hashes de senha, segredos MFA e tokens. Novas colunas sensíveis devem entrar explicitamente na lista de redação e em testes de regressão.
- `audit_logs` é imutável para `UPDATE`/`DELETE` no SQL inicial. Garantia regulatória contra administrador de banco requer exportação para armazenamento WORM/imutável, IAM segregado, backup e alertas, ainda inexistentes.
- Embeddings ficam em Qdrant; PostgreSQL guarda referência tenant-scoped. Filtros de tenant e controle de autorização são obrigatórios em toda busca vetorial.

Valores financeiros usam `numeric(19,4)` e moeda ISO 4217 de três caracteres; cálculos de câmbio e arredondamento precisam de política explícita por domínio.