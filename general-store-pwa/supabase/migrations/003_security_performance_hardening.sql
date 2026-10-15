-- Security and query-performance hardening for General Store Manager.
drop policy if exists invites_create_owner_family on public.shop_invites;
create policy invites_create_owner_family
on public.shop_invites for insert to authenticated
with check (
  private.has_shop_role(shop_id, array['owner','family'])
  and invited_by = (select auth.uid())
  and (role <> 'owner' or private.has_shop_role(shop_id, array['owner']))
);
create index if not exists idx_audit_log_shop_id on public.audit_log(shop_id);
create index if not exists idx_audit_log_actor_id on public.audit_log(actor_id);
create index if not exists idx_expenses_shop_id on public.expenses(shop_id);
create index if not exists idx_expenses_submitted_by on public.expenses(submitted_by);
create index if not exists idx_expenses_reviewed_by on public.expenses(reviewed_by);
create index if not exists idx_expenses_shop_date on public.expenses(shop_id, expense_date desc);
create index if not exists idx_expenses_shop_status on public.expenses(shop_id, status);
create index if not exists idx_purchase_payments_shop_id on public.purchase_payments(shop_id);
create index if not exists idx_purchase_payments_purchase_id on public.purchase_payments(purchase_id);
create index if not exists idx_purchase_payments_submitted_by on public.purchase_payments(submitted_by);
create index if not exists idx_purchase_payments_reviewed_by on public.purchase_payments(reviewed_by);
create index if not exists idx_purchase_payments_shop_status_date on public.purchase_payments(shop_id, status, payment_date desc);
create index if not exists idx_purchases_shop_id on public.purchases(shop_id);
create index if not exists idx_purchases_vendor_id on public.purchases(vendor_id);
create index if not exists idx_purchases_submitted_by on public.purchases(submitted_by);
create index if not exists idx_purchases_reviewed_by on public.purchases(reviewed_by);
create index if not exists idx_purchases_shop_date on public.purchases(shop_id, purchase_date desc);
create index if not exists idx_purchases_shop_status on public.purchases(shop_id, status);
create index if not exists idx_shop_invites_invited_by on public.shop_invites(invited_by);
create index if not exists idx_shop_invites_pending_email on public.shop_invites(lower(email)) where status = 'pending';
create index if not exists idx_shop_memberships_user_id on public.shop_memberships(user_id);
create index if not exists idx_shops_created_by on public.shops(created_by);
create index if not exists idx_vendors_shop_id on public.vendors(shop_id);
create index if not exists idx_vendors_created_by on public.vendors(created_by);