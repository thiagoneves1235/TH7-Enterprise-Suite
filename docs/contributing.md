# Contribuição

## Fluxo

1. Abra issue/ADR para decisões de contrato, segurança, isolamento tenant ou custo de infraestrutura.
2. Mantenha bounded context e schema do serviço dono do dado; mudanças de eventos/API devem ser compatíveis e versionadas.
3. Escreva testes de permissão positiva e negativa entre tenants, não apenas testes do caminho feliz.
4. Execute `pnpm format:check`, `pnpm lint`, `pnpm check-types`, `pnpm test`, `pnpm build` e Terraform validate quando aplicável.
5. Documente migrations, configuração, rollback e observabilidade junto da funcionalidade.

## Convenções

- Código de aplicação e nomes de contrato em inglês; documentação de produto e operação em português.
- Nunca registre tokens, prompts/documentos completos, senhas, segredos MFA ou dados financeiros em logs.
- Não use mocks para declarar integração/segurança concluída; registre o limite e adicione contract tests para provedores reais/emulados.
- A branch principal deve exigir revisões e checks. Configure proteção da branch, CODEOWNERS, Dependabot e permissões mínimas no GitHub antes de aceitar contribuições externas.

## Estado do toolchain

A raiz fixa Node.js 22.14 e pnpm 10.15. O lockfile ainda precisa ser gerado e revisado; `pnpm install --no-frozen-lockfile` no workflow existe apenas para inicialização desta fundação.