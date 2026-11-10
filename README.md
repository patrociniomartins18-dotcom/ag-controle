# AG Controle de Vendas

App de controle de vendas, estoque, caixa e entregas (PWA para celular e computador).

- **Hospedagem:** GitHub Pages (somente os arquivos do app, sem dados de clientes).
- **Dados e login:** Supabase (PostgreSQL + Auth). Os dados ficam no banco, protegidos por login e por regras de segurança (RLS).
- **Offline:** o app guarda uma cópia no aparelho e sincroniza quando a internet volta.

## Segurança

- O código é público de propósito; **os dados não estão no código**. Quem não tem login não lê nem grava nada.
- `config.js` tem a URL e a chave *anon* do Supabase. Elas são públicas por desenho: a proteção está nas regras do banco (`supabase/schema.sql`) e no login.
- **Nunca** coloque a chave `service_role` neste repositório.
- Não faça commit de backups (`ag-controle-vendas-backup-*.json`): eles têm dados de clientes. O `.gitignore` já bloqueia esse padrão.
- Para conferir de fora que o banco está fechado: `node supabase/verificar-seguranca.mjs <URL> <ANON_KEY>`.

## Perfis

- **Dono:** vê tudo, libera e bloqueia acessos, lança recebimentos no Caixa. O primeiro cadastro do sistema vira o dono.
- **Funcionário:** vendas, produtos e entregas. Não vê Painel, Caixa, Relatórios nem Configurações. O Caixa também é bloqueado no banco.

## Colocar no ar (resumo)

1. Supabase: criar projeto, rodar `supabase/schema.sql` no SQL Editor, desligar "Confirm email" (Authentication → Providers → Email) e definir a URL do site (Authentication → URL Configuration).
2. Preencher `config.js` com a *Project URL* e a chave *anon/publishable*.
3. GitHub: repositório público, Settings → Pages → Source: **GitHub Actions**. Cada push na branch `main` publica o app.
4. Abrir o endereço do app, tocar em "Criar meu acesso" (o primeiro cadastro é o dono) e importar o backup em Configurações.
