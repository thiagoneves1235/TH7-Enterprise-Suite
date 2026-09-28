# AI Service

**Estado: planejado; nenhum provedor/embedding/documento disponível.** RAG futuro exige tenant ACL antes de busca vetorial, isolamento de collection, proteção contra prompt injection, allowlist de tools, quotas, revisão de retenção e avaliação de groundedness. Arquivos precisam de antivírus, limits, content sniffing e extração isolada.

Natural-language-to-SQL deve operar sobre views/read models allowlisted, AST permitido, parâmetros tipados, timeout e role SQL read-only sujeita a RLS. Rejeitar DDL/DML e nunca permitir que a saída do modelo decida tenant ou privilégio. Documentos e queries podem conter dados empresariais confidenciais; não os envie a provedores sem consentimento e política de residência aprovados.