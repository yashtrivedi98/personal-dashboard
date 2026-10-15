-- Vendor payments recorded after the original purchase bill.
create table public.purchase_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  payment_date date not null default current_date,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null check (payment_method in ('Cash','UPI','Bank transfer','Other')),
  notes text,
  status text not null default 'approved' check (status in ('pending','approved','rejected')),
  submitted_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.purchase_payments enable row level security;
create policy purchase_payments_read_managers on public.purchase_payments for select to authenticated
using (private.has_shop_role(shop_id,array['owner','family']));
create policy purchase_payments_insert_managers on public.purchase_payments for insert to authenticated
with check (private.has_shop_role(shop_id,array['owner','family']) and submitted_by=(select auth.uid()) and status='approved');
create policy purchase_payments_update_managers on public.purchase_payments for update to authenticated
using (private.has_shop_role(shop_id,array['owner','family']))
with check (private.has_shop_role(shop_id,array['owner','family']));
create policy purchase_payments_delete_owner on public.purchase_payments for delete to authenticated
using (private.has_shop_role(shop_id,array['owner']));
grant select,insert,update,delete on public.purchase_payments to authenticated;
