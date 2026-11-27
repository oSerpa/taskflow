-- Várias equipes independentes: cada equipe tem gerente, membros e código de convite
delete from auth.users where email like '%teste@exemplo.com';

create table public.equipes (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(nome) between 1 and 80),
  codigo text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  criado_em timestamptz not null default now()
);
alter table public.equipes enable row level security;

alter table public.perfis add column equipe_id uuid not null references public.equipes(id) on delete cascade;
create index perfis_equipe_idx on public.perfis(equipe_id);

create or replace function public.minha_equipe()
returns uuid language sql stable security definer set search_path = public as $$
  select equipe_id from public.perfis where id = auth.uid();
$$;
revoke execute on function public.minha_equipe() from public, anon;
grant execute on function public.minha_equipe() to authenticated;

alter table public.tarefas add column equipe_id uuid not null default public.minha_equipe() references public.equipes(id) on delete cascade;
create index tarefas_equipe_idx on public.tarefas(equipe_id);

create or replace function public.novo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_equipe uuid; v_papel text; v_codigo text; v_nome_eq text;
begin
  v_codigo := upper(trim(coalesce(new.raw_user_meta_data->>'codigo','')));
  v_nome_eq := trim(coalesce(new.raw_user_meta_data->>'equipe',''));
  if v_codigo <> '' then
    select id into v_equipe from public.equipes where codigo = v_codigo;
    if v_equipe is null then raise exception 'CODIGO_INVALIDO'; end if;
    v_papel := 'funcionario';
  else
    insert into public.equipes (nome) values (coalesce(nullif(v_nome_eq,''), 'Minha equipe')) returning id into v_equipe;
    v_papel := 'gerente';
  end if;
  insert into public.perfis (id, nome, email, papel, equipe_id)
  values (new.id, coalesce(nullif(new.raw_user_meta_data->>'nome',''), split_part(new.email,'@',1)), new.email, v_papel, v_equipe);
  return new;
end $$;
revoke execute on function public.novo_usuario() from public, anon, authenticated;

create or replace function public.antes_de_atualizar_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.papel is distinct from old.papel and not public.eh_gerente() then
    raise exception 'Somente o gerente pode alterar papéis';
  end if;
  new.email := old.email;
  new.equipe_id := old.equipe_id;
  return new;
end $$;

create or replace function public.antes_de_atualizar_tarefa()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.equipe_id := old.equipe_id;
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

create or replace function public.mesma_equipe(p_perfil uuid, p_equipe uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfis where id = p_perfil and equipe_id = p_equipe);
$$;
revoke execute on function public.mesma_equipe(uuid,uuid) from public, anon;
grant execute on function public.mesma_equipe(uuid,uuid) to authenticated;

drop policy "perfis: logados veem a equipe" on public.perfis;
drop policy "perfis: edita o proprio ou gerente edita todos" on public.perfis;
drop policy "tarefas: gerente ve tudo, funcionario ve as suas" on public.tarefas;
drop policy "tarefas: gerente cria" on public.tarefas;
drop policy "tarefas: gerente ou responsavel atualiza" on public.tarefas;
drop policy "tarefas: gerente exclui" on public.tarefas;

create policy "equipes: membros veem a sua" on public.equipes
  for select to authenticated using (id = (select public.minha_equipe()));
create policy "equipes: gerente renomeia" on public.equipes
  for update to authenticated using (id = (select public.minha_equipe()) and (select public.eh_gerente()))
  with check (id = (select public.minha_equipe()));

create policy "perfis: veem a propria equipe" on public.perfis
  for select to authenticated using (equipe_id = (select public.minha_equipe()));
create policy "perfis: edita o proprio ou gerente da equipe" on public.perfis
  for update to authenticated
  using (equipe_id = (select public.minha_equipe()) and (id = (select auth.uid()) or (select public.eh_gerente())))
  with check (equipe_id = (select public.minha_equipe()));

create policy "tarefas: ver" on public.tarefas
  for select to authenticated
  using (equipe_id = (select public.minha_equipe()) and ((select public.eh_gerente()) or responsavel_id = (select auth.uid())));
create policy "tarefas: gerente cria" on public.tarefas
  for insert to authenticated
  with check ((select public.eh_gerente()) and equipe_id = (select public.minha_equipe()) and public.mesma_equipe(responsavel_id, equipe_id));
create policy "tarefas: atualizar" on public.tarefas
  for update to authenticated
  using (equipe_id = (select public.minha_equipe()) and ((select public.eh_gerente()) or responsavel_id = (select auth.uid())))
  with check (equipe_id = (select public.minha_equipe()) and public.mesma_equipe(responsavel_id, equipe_id));
create policy "tarefas: gerente exclui" on public.tarefas
  for delete to authenticated
  using ((select public.eh_gerente()) and equipe_id = (select public.minha_equipe()));
