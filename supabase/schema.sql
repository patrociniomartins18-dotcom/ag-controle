-- =====================================================================
-- AG Controle de Vendas — banco de dados (Supabase / PostgreSQL)
-- Cole este arquivo inteiro em: Supabase > SQL Editor > New query > Run
-- Pode rodar mais de uma vez sem duplicar nada.
-- =====================================================================

-- ---------- 1) Quem tem acesso ----------
create table if not exists public.membros (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  email     text,
  papel     text not null default 'funcionario' check (papel in ('dono', 'funcionario')),
  ativo     boolean not null default false,
  criado_em timestamptz not null default now()
);

alter table public.membros enable row level security;

-- ---------- 2) Funções auxiliares (SECURITY DEFINER evita recursão nas regras) ----------
create or replace function public.eh_membro()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.membros m where m.user_id = auth.uid() and m.ativo);
$$;

create or replace function public.eh_dono()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.membros m where m.user_id = auth.uid() and m.ativo and m.papel = 'dono');
$$;

-- ---------- 3) Todo novo login vira "membro": o PRIMEIRO é o dono (já ativo); os demais ficam aguardando liberação ----------
create or replace function public.novo_usuario()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not exists (select 1 from public.membros where papel = 'dono') then
    insert into public.membros (user_id, email, papel, ativo) values (new.id, new.email, 'dono', true);
  else
    insert into public.membros (user_id, email, papel, ativo) values (new.id, new.email, 'funcionario', false);
  end if;
  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.novo_usuario();

-- ---------- 4) Regras da tabela de membros ----------
drop policy if exists membros_ver_proprio  on public.membros;
drop policy if exists membros_dono_ve      on public.membros;
drop policy if exists membros_dono_altera  on public.membros;
drop policy if exists membros_dono_remove  on public.membros;

-- cada pessoa enxerga a própria linha (para saber se já foi liberada)
create policy membros_ver_proprio on public.membros
  for select to authenticated using (user_id = auth.uid());

-- o dono enxerga todos
create policy membros_dono_ve on public.membros
  for select to authenticated using (public.eh_dono());

-- o dono libera/bloqueia e muda papel (não pode mexer na própria linha)
create policy membros_dono_altera on public.membros
  for update to authenticated
  using (public.eh_dono() and user_id <> auth.uid())
  with check (public.eh_dono() and user_id <> auth.uid());

-- o dono remove outros acessos (a conta de login some junto da lista de membros)
create policy membros_dono_remove on public.membros
  for delete to authenticated using (public.eh_dono() and user_id <> auth.uid());

-- ---------- 5) Dados do negócio ----------
-- Uma linha por registro. colecao: produtos | pedidos | caixa | kits | estoque_dia | meta_vendas | meta
create table if not exists public.registros (
  colecao       text        not null,
  id            text        not null,
  dados         jsonb       not null,
  removido      boolean     not null default false,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid       default auth.uid(),
  primary key (colecao, id)
);

create index if not exists registros_atualizado_idx on public.registros (atualizado_em);

alter table public.registros enable row level security;

create or replace function public.carimbar_registro()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := auth.uid();
  return new;
end;
$$;

drop trigger if exists registros_carimbo on public.registros;
create trigger registros_carimbo
  before insert or update on public.registros
  for each row execute function public.carimbar_registro();

drop policy if exists registros_ver     on public.registros;
drop policy if exists registros_inserir on public.registros;
drop policy if exists registros_mudar   on public.registros;

-- Membros ativos veem tudo, exceto o Caixa, que é só do dono.
create policy registros_ver on public.registros
  for select to authenticated
  using (public.eh_membro() and (colecao <> 'caixa' or public.eh_dono()));

create policy registros_inserir on public.registros
  for insert to authenticated
  with check (public.eh_membro() and (colecao <> 'caixa' or public.eh_dono()));

create policy registros_mudar on public.registros
  for update to authenticated
  using (public.eh_membro() and (colecao <> 'caixa' or public.eh_dono()))
  with check (public.eh_membro() and (colecao <> 'caixa' or public.eh_dono()));

-- Sem política de DELETE: ninguém apaga de verdade pelo app (exclusões viram "removido = true").

-- ---------- 6) Atualização em tempo real entre aparelhos ----------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'registros'
  ) then
    alter publication supabase_realtime add table public.registros;
  end if;
end $$;

-- ---------- 7) Permissões básicas ----------
revoke all on public.membros   from anon;
revoke all on public.registros from anon;
grant select, update, delete on public.membros to authenticated;
grant select, insert, update on public.registros to authenticated;
