-- =====================================================================
-- COMPTA MULTI-SOCIÉTÉS — schéma initial
-- Base dédiée. Cloisonnement strict par société via RLS.
-- Rôles : admin (global) / secretaire / comptable (par société).
-- =====================================================================

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";

-- ---------- Utilisateurs applicatifs ----------
-- Miroir léger de auth.users : porte le flag admin global.
create table if not exists app_users (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text,
  is_admin   boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- Sociétés ----------
create table if not exists companies (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  siren            text,
  -- Régime TVA paramétrable PAR société (choix de David) :
  vat_regime       text not null default 'reel_mensuel'
                   check (vat_regime in ('reel_mensuel','reel_trimestriel','franchise')),
  default_vat_rate numeric(5,2) not null default 20.00,
  currency         text not null default 'EUR',
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);

-- ---------- Attribution des accès (cloisonnement) ----------
-- Un comptable/secrétaire est rattaché à une ou plusieurs sociétés.
create table if not exists company_access (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null check (role in ('secretaire','comptable')),
  created_at timestamptz not null default now(),
  unique (company_id, user_id)
);
create index if not exists idx_company_access_user on company_access(user_id);

-- ---------- Catégories de frais / produits ----------
-- company_id NULL = catégorie globale (modèle par défaut, visible partout).
create table if not exists categories (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid references companies(id) on delete cascade,
  name             text not null,
  flow             text not null default 'achat' check (flow in ('achat','vente','both')),
  vat_recoverable  boolean not null default true,   -- TVA récupérable ou non
  default_vat_rate numeric(5,2),
  created_at       timestamptz not null default now()
);
create index if not exists idx_categories_company on categories(company_id);

-- ---------- Relevés bancaires (fichiers importés) ----------
create table if not exists bank_statements (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references companies(id) on delete cascade,
  bank_name         text,
  period_month      date,           -- 1er du mois concerné
  original_filename text,
  storage_path      text,           -- fichier source dans le bucket
  uploaded_by       uuid references auth.users(id),
  created_at        timestamptz not null default now()
);
create index if not exists idx_statements_company on bank_statements(company_id);

-- ---------- Lignes du relevé (transactions) ----------
-- amount signé : négatif = débit/sortie, positif = crédit/entrée.
create table if not exists transactions (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references companies(id) on delete cascade,
  statement_id  uuid references bank_statements(id) on delete set null,
  op_date       date not null,
  label         text not null,
  amount        numeric(12,2) not null,
  category_id   uuid references categories(id) on delete set null,
  counterparty  text,               -- client / fournisseur détecté ou saisi
  vat_rate      numeric(5,2),
  vat_amount    numeric(12,2),
  status        text not null default 'a_classer'
                check (status in ('a_classer','classe')),
  note          text,
  created_by    uuid references auth.users(id),
  created_at    timestamptz not null default now()
);
create index if not exists idx_tx_company_date on transactions(company_id, op_date);
create index if not exists idx_tx_status on transactions(company_id, status);

-- ---------- Factures ----------
create table if not exists invoices (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references companies(id) on delete cascade,
  direction         text not null default 'achat' check (direction in ('achat','vente')),
  counterparty      text,           -- fournisseur (achat) ou client (vente)
  invoice_number    text,
  invoice_date      date,
  amount_ht         numeric(12,2),
  vat_amount        numeric(12,2),
  amount_ttc        numeric(12,2),
  vat_rate          numeric(5,2),
  storage_path      text,           -- PDF/photo dans le bucket
  original_filename text,
  -- Rapprochement : la facture pointe la ligne de relevé qu'elle justifie.
  transaction_id    uuid references transactions(id) on delete set null,
  status            text not null default 'a_rapprocher'
                    check (status in ('a_rapprocher','rapproche')),
  uploaded_by       uuid references auth.users(id),
  created_at        timestamptz not null default now()
);
create index if not exists idx_invoices_company on invoices(company_id);
create index if not exists idx_invoices_tx on invoices(transaction_id);

-- =====================================================================
-- HELPERS de sécurité
-- =====================================================================
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from app_users where user_id = auth.uid()), false);
$$;

create or replace function public.has_company_access(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or exists (select 1 from company_access
                 where company_id = cid and user_id = auth.uid());
$$;

-- =====================================================================
-- RLS — chaque table cloisonnée par société
-- =====================================================================
alter table app_users      enable row level security;
alter table companies      enable row level security;
alter table company_access enable row level security;
alter table categories     enable row level security;
alter table bank_statements enable row level security;
alter table transactions   enable row level security;
alter table invoices       enable row level security;

-- app_users : chacun lit sa propre ligne ; admin lit tout.
drop policy if exists app_users_read on app_users;
create policy app_users_read on app_users for select
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists app_users_admin_write on app_users;
create policy app_users_admin_write on app_users for all
  using (public.is_admin()) with check (public.is_admin());

-- companies : visibles si on y a accès ; écriture admin uniquement.
drop policy if exists companies_read on companies;
create policy companies_read on companies for select
  using (public.has_company_access(id));
drop policy if exists companies_admin_write on companies;
create policy companies_admin_write on companies for all
  using (public.is_admin()) with check (public.is_admin());

-- company_access : l'utilisateur voit ses rattachements ; admin gère tout.
drop policy if exists ca_read on company_access;
create policy ca_read on company_access for select
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists ca_admin_write on company_access;
create policy ca_admin_write on company_access for all
  using (public.is_admin()) with check (public.is_admin());

-- Tables métier : lecture/écriture si accès à la société (catégories globales lisibles par tous).
drop policy if exists categories_rw on categories;
create policy categories_rw on categories for all
  using (company_id is null or public.has_company_access(company_id))
  with check (company_id is null and public.is_admin() or public.has_company_access(company_id));

drop policy if exists statements_rw on bank_statements;
create policy statements_rw on bank_statements for all
  using (public.has_company_access(company_id))
  with check (public.has_company_access(company_id));

drop policy if exists transactions_rw on transactions;
create policy transactions_rw on transactions for all
  using (public.has_company_access(company_id))
  with check (public.has_company_access(company_id));

drop policy if exists invoices_rw on invoices;
create policy invoices_rw on invoices for all
  using (public.has_company_access(company_id))
  with check (public.has_company_access(company_id));

-- =====================================================================
-- VUE : synthèse TVA mensuelle par société
--   collectée = TVA sur entrées (ventes) ; déductible = TVA sur sorties
--   (achats) dont la catégorie est récupérable.
-- =====================================================================
create or replace view tva_mensuelle
with (security_invoker = true) as
select
  t.company_id,
  date_trunc('month', t.op_date)::date as mois,
  sum(case when t.amount > 0 then coalesce(t.vat_amount,0) else 0 end)          as tva_collectee,
  sum(case when t.amount < 0 and coalesce(c.vat_recoverable, true)
           then coalesce(t.vat_amount,0) else 0 end)                            as tva_deductible,
  sum(case when t.amount > 0 then coalesce(t.vat_amount,0) else 0 end)
  - sum(case when t.amount < 0 and coalesce(c.vat_recoverable, true)
           then coalesce(t.vat_amount,0) else 0 end)                            as tva_nette
from transactions t
left join categories c on c.id = t.category_id
group by t.company_id, date_trunc('month', t.op_date);

-- =====================================================================
-- Catégories globales par défaut (modèles réutilisables)
-- =====================================================================
insert into categories (company_id, name, flow, vat_recoverable, default_vat_rate) values
  (null, 'Téléphonie / Internet',   'achat', true,  20.00),
  (null, 'Loyer',                    'achat', true,  20.00),
  (null, 'Fournitures',             'achat', true,  20.00),
  (null, 'Carburant',               'achat', true,  20.00),
  (null, 'Restauration',            'achat', true,  10.00),
  (null, 'Honoraires / Comptable',  'achat', true,  20.00),
  (null, 'Assurance',               'achat', false, 0.00),
  (null, 'Banque / Frais bancaires','achat', false, 0.00),
  (null, 'Salaires / URSSAF',       'achat', false, 0.00),
  (null, 'Ventes / Prestations',    'vente', true,  20.00)
on conflict do nothing;
