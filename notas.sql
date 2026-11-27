-- Anotações privadas de cada pessoa
create table public.notas (
  id uuid primary key default gen_random_uuid(),
  dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade,
  titulo text not null default '' check (length(titulo) <= 200),
  conteudo text not null default '',
  fixada boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index notas_dono_idx on public.notas(dono_id);
alter table public.notas enable row level security;

create or replace function public.antes_de_atualizar_nota()
returns trigger language plpgsql set search_path = public as $$
begin
  new.dono_id := old.dono_id;
  new.atualizado_em := now();
  return new;
end $$;
create trigger nota_update before update on public.notas
for each row execute function public.antes_de_atualizar_nota();

create policy "notas: so o dono" on public.notas
  for all to authenticated
  using (dono_id = (select auth.uid()))
  with check (dono_id = (select auth.uid()));
