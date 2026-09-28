# ADR 0001: isolamento por tenant no PostgreSQL

- Estado: aceito como baseline; operação ainda não implementada.
- Data: 2026-09-28.

## Contexto

TH7 Enterprise Suite compartilha uma instalação PostgreSQL entre empresas. Filtro aplicado somente na camada HTTP permite vazamento por query esquecida e relações cruzadas.

## Decisão

Linhas pertencentes a tenant carregam `tenant_id`; chaves e FKs compostas restringem relações ao mesmo tenant. RLS `ENABLE` e `FORCE` valida `tenant_id = app.current_tenant_id()`. Runtime recebe grants mínimos e define contextos com `SET LOCAL` dentro da mesma transação. Membership é autorizada antes de configurar o contexto. Tokens e headers não são acesso por si só.

## Consequências

- Pools de conexão exigem transações explícitas e testes para contexto nulo, rollback, reuse e acesso cruzado.
- Migrações, tarefas control-plane e provisionamento de tenants usam papéis separados e auditados.
- RLS não bloqueia papéis superuser/`BYPASSRLS`; ownership/grants precisam ser validados em ambiente real.
- Auditoria local não protege contra administrador privilegiado; saída WORM independente é requisito antes de dados regulados.
- Estratégia de sharding/isolamento físico poderá ser revista para tenants regulados ou com grande volume.

## Alternativas consideradas

- Banco por tenant: isolamento forte, mas custo/operabilidade altos sem requisito de residência ou ruído de vizinho comprovado.
- Filtro apenas na aplicação: rejeitado por não fornecer defesa em profundidade contra query omitida.
- Schema PostgreSQL por tenant: rejeitado como default por proliferação de migrations/conexões; avaliar para requisito futuro.