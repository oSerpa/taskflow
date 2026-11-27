-- Preferências de aparência
alter table public.perfis add column preferencias jsonb not null default '{}'::jsonb;

-- Finanças: clientes, revenda, investimentos; Estudos; Vagas (tudo privado por pessoa)
create table public.clientes (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 120), contato text, observacao text, criado_em timestamptz not null default now());
create table public.produtos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 120), custo numeric(12,2) not null default 0 check (custo >= 0), preco numeric(12,2) not null default 0 check (preco >= 0), estoque integer not null default 0, criado_em timestamptz not null default now());
create table public.investimentos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, nome text not null check (length(nome) between 1 and 120), tipo text not null default 'outros', aplicado numeric(14,2) not null default 0 check (aplicado >= 0), atual numeric(14,2) not null default 0 check (atual >= 0), data date not null default current_date, criado_em timestamptz not null default now());
alter table public.lancamentos add column cliente_id uuid references public.clientes(id) on delete set null;
alter table public.lancamentos add column produto_id uuid references public.produtos(id) on delete set null;
alter table public.lancamentos add column quantidade integer check (quantidade is null or quantidade > 0);
create table public.estudos (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, materia text not null default 'Geral' check (length(materia) between 1 and 80), titulo text not null default '' check (length(titulo) <= 200), conteudo text not null default '', criado_em timestamptz not null default now(), atualizado_em timestamptz not null default now());
create table public.vagas (id uuid primary key default gen_random_uuid(), dono_id uuid not null default auth.uid() references public.perfis(id) on delete cascade, titulo text not null check (length(titulo) between 1 and 250), empresa text, local text, fonte text, link text not null, resumo text, salario text, publicada_em date, encontrada_em timestamptz not null default now(), status text not null default 'nova' check (status in ('nova','salva','enviado','entrevista','recusado','descartada')), enviado_em date, notas text, unique (dono_id, link));

create or replace function public.manter_dono() returns trigger language plpgsql set search_path = public as $$
begin new.dono_id := old.dono_id; if tg_table_name = 'estudos' then new.atualizado_em := now(); end if; return new; end $$;
-- triggers manter_dono e políticas "so o dono" (dono_id = auth.uid()) em clientes, produtos, investimentos, estudos e vagas
