-- Kanban da equipe: esquema do banco (Supabase / Postgres)
-- Papéis: o primeiro usuário cadastrado vira gerente; os demais entram como funcionário.

create table public.perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null,
  email text not null,
  papel text not null default 'funcionario' check (papel in ('gerente','funcionario')),
  criado_em timestamptz not null default now()
);

create table public.tarefas (
  id uuid primary key default gen_random_uuid(),
  titulo text not null check (length(titulo) between 1 and 200),
  descricao text,
  prioridade text not null default 'media' check (prioridade in ('baixa','media','alta')),
  status text not null default 'a_fazer' check (status in ('a_fazer','em_andamento','pausado','concluido')),
  prazo date,
  responsavel_id uuid not null references public.perfis(id) on delete cascade,
  criado_por uuid references public.perfis(id) on delete set null default auth.uid(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  concluido_em timestamptz
);

create index tarefas_responsavel_idx on public.tarefas(responsavel_id);
create index tarefas_status_idx on public.tarefas(status);

-- Função auxiliar: o usuário logado é gerente?
create or replace function public.eh_gerente()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfis where id = auth.uid() and papel = 'gerente');
$$;

-- Cria o perfil ao cadastrar. Primeiro cadastro vira gerente.
create or replace function public.novo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfis (id, nome, email, papel)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome',''), split_part(new.email,'@',1)),
    new.email,
    case when exists (select 1 from public.perfis) then 'funcionario' else 'gerente' end
  );
  return new;
end $$;

create trigger ao_cadastrar after insert on auth.users
for each row execute function public.novo_usuario();

-- Funcionário só pode mudar o status das próprias tarefas. Datas automáticas.
create or replace function public.antes_de_atualizar_tarefa()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.eh_gerente() then
    if new.titulo is distinct from old.titulo
       or new.descricao is distinct from old.descricao
       or new.prioridade is distinct from old.prioridade
       or new.prazo is distinct from old.prazo
       or new.responsavel_id is distinct from old.responsavel_id
       or new.criado_por is distinct from old.criado_por then
      raise exception 'Somente o gerente pode editar os dados da tarefa';
    end if;
  end if;
  new.atualizado_em := now();
  if new.status = 'concluido' and old.status <> 'concluido' then
    new.concluido_em := now();
  elsif new.status <> 'concluido' then
    new.concluido_em := null;
  end if;
  return new;
end $$;

create trigger tarefa_update before update on public.tarefas
for each row execute function public.antes_de_atualizar_tarefa();

-- Só o gerente troca papéis; ninguém se promove sozinho.
create or replace function public.antes_de_atualizar_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.papel is distinct from old.papel and not public.eh_gerente() then
    raise exception 'Somente o gerente pode alterar papéis';
  end if;
  if new.email is distinct from old.email then
    new.email := old.email;
  end if;
  return new;
end $$;

create trigger perfil_update before update on public.perfis
for each row execute function public.antes_de_atualizar_perfil();

-- RLS
alter table public.perfis enable row level security;
alter table public.tarefas enable row level security;

create policy "perfis: logados veem a equipe" on public.perfis
  for select to authenticated using (true);
create policy "perfis: edita o proprio ou gerente edita todos" on public.perfis
  for update to authenticated using (id = auth.uid() or public.eh_gerente())
  with check (id = auth.uid() or public.eh_gerente());

create policy "tarefas: gerente ve tudo, funcionario ve as suas" on public.tarefas
  for select to authenticated using (public.eh_gerente() or responsavel_id = auth.uid());
create policy "tarefas: gerente cria" on public.tarefas
  for insert to authenticated with check (public.eh_gerente());
create policy "tarefas: gerente ou responsavel atualiza" on public.tarefas
  for update to authenticated using (public.eh_gerente() or responsavel_id = auth.uid())
  with check (public.eh_gerente() or responsavel_id = auth.uid());
create policy "tarefas: gerente exclui" on public.tarefas
  for delete to authenticated using (public.eh_gerente());

revoke execute on function public.novo_usuario() from public, anon, authenticated;
revoke execute on function public.antes_de_atualizar_tarefa() from public, anon, authenticated;
revoke execute on function public.antes_de_atualizar_perfil() from public, anon, authenticated;

-- Tempo real
alter publication supabase_realtime add table public.tarefas;
