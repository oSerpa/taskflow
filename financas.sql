-- Finanças pessoais (cada pessoa vê só as suas)
create table public.lancamentos (
  id uuid primary key default gen_random_uuid(),
  dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade,
  tipo text not null check (tipo in ('entrada','saida')),
  descricao text not null check (length(descricao) between 1 and 200),
  valor numeric(12,2) not null check (valor > 0),
  categoria text not null default 'outros',
  data date not null default current_date,
  pago boolean not null default true,
  criado_em timestamptz not null default now()
);
create index lancamentos_dono_data_idx on public.lancamentos(dono_id, data);
alter table public.lancamentos enable row level security;

create or replace function public.antes_de_atualizar_lancamento()
returns trigger language plpgsql set search_path = public as $$
begin
  new.dono_id := old.dono_id;
  return new;
end $$;
create trigger lancamento_update before update on public.lancamentos
for each row execute function public.antes_de_atualizar_lancamento();

create policy "lancamentos: so o dono" on public.lancamentos
  for all to authenticated
  using (dono_id = (select auth.uid()))
  with check (dono_id = (select auth.uid()));
