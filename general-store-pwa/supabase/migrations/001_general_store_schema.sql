-- General Store Expense Manager: isolated schema objects for a dedicated Supabase project.
-- Apply ONLY to a new/dedicated Supabase project, never to the existing Couple Expense Manager project.
create extension if not exists pgcrypto;
create schema if not exists private;

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table public.shop_memberships (
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','family','employee')),
  created_at timestamptz not null default now(),
  primary key (shop_id,user_id)
);
create table public.shop_invites (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  email text not null,
  role text not null check (role in ('family','employee')),
  invited_by uuid not null references auth.users(id),
  token uuid not null default gen_random_uuid() unique,
  status text not null default 'pending' check (status in ('pending','claimed','revoked')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  unique(shop_id,email)
);
create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  phone text,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique(shop_id,name)
);
create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  bill_ref text,
  purchase_date date not null default current_date,
  vendor_id uuid references public.vendors(id) on delete set null,
  vendor_name text not null,
  item_name text not null check (length(trim(item_name)) between 1 and 160),
  quantity numeric(12,3) not null check (quantity > 0),
  unit text not null default 'pcs',
  unit_rate numeric(12,2) not null check (unit_rate >= 0),
  total_amount numeric(12,2) generated always as (round(quantity * unit_rate, 2)) stored,
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0 and paid_amount <= round(quantity * unit_rate,2)),
  payment_method text not null default 'Credit' check (payment_method in ('Cash','UPI','Bank transfer','Credit','Other')),
  notes text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  submitted_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  expense_date date not null default current_date,
  category text not null,
  description text not null check (length(trim(description)) between 1 and 240),
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null default 'Cash' check (payment_method in ('Cash','UPI','Bank transfer','Credit','Other')),
  notes text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  submitted_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.audit_log (
  id bigint generated always as identity primary key,
  shop_id uuid not null references public.shops(id) on delete cascade,
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function private.has_shop_role(target_shop uuid, allowed_roles text[])
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shop_memberships m
    where m.shop_id = target_shop
      and m.user_id = (select auth.uid())
      and m.role = any(allowed_roles)
  );
$$;
revoke all on function private.has_shop_role(uuid,text[]) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.has_shop_role(uuid,text[]) to authenticated;

create or replace function public.claim_shop_invites()
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare claimed_count integer := 0; user_email text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select lower(email) into user_email from auth.users where id = auth.uid();
  if user_email is null then raise exception 'Authenticated email not found'; end if;
  insert into public.shop_memberships(shop_id,user_id,role)
  select i.shop_id, auth.uid(), i.role
  from public.shop_invites i
  where lower(i.email) = user_email and i.status = 'pending' and i.expires_at > now()
  on conflict (shop_id,user_id) do nothing;
  get diagnostics claimed_count = row_count;
  update public.shop_invites set status='claimed'
  where lower(email)=user_email and status='pending' and expires_at > now();
  return claimed_count;
end;
$$;
revoke all on function public.claim_shop_invites() from public, anon;
grant execute on function public.claim_shop_invites() to authenticated;

alter table public.shops enable row level security;
alter table public.shop_memberships enable row level security;
alter table public.shop_invites enable row level security;
alter table public.vendors enable row level security;
alter table public.purchases enable row level security;
alter table public.expenses enable row level security;
alter table public.audit_log enable row level security;

create policy shops_read_members on public.shops for select to authenticated
using (created_by = (select auth.uid()) or private.has_shop_role(id,array['owner','family','employee']));
create policy shops_create_owner on public.shops for insert to authenticated
with check (created_by = (select auth.uid()));
create policy shops_update_owner on public.shops for update to authenticated
using (private.has_shop_role(id,array['owner']))
with check (private.has_shop_role(id,array['owner']) and created_by = (select auth.uid()));

create policy memberships_read_team on public.shop_memberships for select to authenticated
using (user_id = (select auth.uid()) or private.has_shop_role(shop_id,array['owner','family']));
create policy memberships_add_owner_self on public.shop_memberships for insert to authenticated
with check (user_id = (select auth.uid()) and role='owner' and exists(select 1 from public.shops s where s.id=shop_id and s.created_by=(select auth.uid())));
create policy memberships_manage_owner on public.shop_memberships for all to authenticated
using (private.has_shop_role(shop_id,array['owner']))
with check (private.has_shop_role(shop_id,array['owner']));

create policy invites_read_owner_family on public.shop_invites for select to authenticated
using (private.has_shop_role(shop_id,array['owner','family']));
create policy invites_create_owner_family on public.shop_invites for insert to authenticated
with check (private.has_shop_role(shop_id,array['owner','family']) and invited_by=(select auth.uid()));
create policy invites_manage_owner on public.shop_invites for update to authenticated
using (private.has_shop_role(shop_id,array['owner']))
with check (private.has_shop_role(shop_id,array['owner']));

create policy vendors_read_team on public.vendors for select to authenticated
using (private.has_shop_role(shop_id,array['owner','family','employee']));
create policy vendors_write_family on public.vendors for all to authenticated
using (private.has_shop_role(shop_id,array['owner','family']))
with check (private.has_shop_role(shop_id,array['owner','family']));

create policy purchases_read_managers_and_own on public.purchases for select to authenticated
using (private.has_shop_role(shop_id,array['owner','family']) or (private.has_shop_role(shop_id,array['employee']) and submitted_by=(select auth.uid())));
create policy purchases_insert_owner_family on public.purchases for insert to authenticated
with check (private.has_shop_role(shop_id,array['owner','family']) and submitted_by=(select auth.uid()));
create policy purchases_insert_employee_pending on public.purchases for insert to authenticated
with check (private.has_shop_role(shop_id,array['employee']) and status='pending' and submitted_by=(select auth.uid()));
create policy purchases_update_owner_family on public.purchases for update to authenticated
using (private.has_shop_role(shop_id,array['owner','family']))
with check (private.has_shop_role(shop_id,array['owner','family']));
create policy purchases_delete_owner on public.purchases for delete to authenticated
using (private.has_shop_role(shop_id,array['owner']));

create policy expenses_read_managers_and_own on public.expenses for select to authenticated
using (private.has_shop_role(shop_id,array['owner','family']) or (private.has_shop_role(shop_id,array['employee']) and submitted_by=(select auth.uid())));
create policy expenses_insert_owner_family on public.expenses for insert to authenticated
with check (private.has_shop_role(shop_id,array['owner','family']) and submitted_by=(select auth.uid()));
create policy expenses_insert_employee_pending on public.expenses for insert to authenticated
with check (private.has_shop_role(shop_id,array['employee']) and status='pending' and submitted_by=(select auth.uid()));
create policy expenses_update_owner_family on public.expenses for update to authenticated
using (private.has_shop_role(shop_id,array['owner','family']))
with check (private.has_shop_role(shop_id,array['owner','family']));
create policy expenses_delete_owner on public.expenses for delete to authenticated
using (private.has_shop_role(shop_id,array['owner']));

create policy audit_read_owner_family on public.audit_log for select to authenticated
using (private.has_shop_role(shop_id,array['owner','family']));
create policy audit_insert_member on public.audit_log for insert to authenticated
with check (private.has_shop_role(shop_id,array['owner','family','employee']) and actor_id=(select auth.uid()));

grant select,insert,update,delete on public.shops, public.shop_memberships, public.shop_invites,
  public.vendors, public.purchases, public.expenses, public.audit_log to authenticated;
grant usage,select on sequence public.audit_log_id_seq to authenticated;
