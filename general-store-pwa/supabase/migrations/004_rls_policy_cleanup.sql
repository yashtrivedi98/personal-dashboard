-- Consolidate overlapping row-level security policies without changing role permissions.
drop policy if exists purchases_insert_owner_family on public.purchases;
drop policy if exists purchases_insert_employee_pending on public.purchases;
create policy purchases_insert_by_role on public.purchases for insert to authenticated
with check (
  submitted_by = (select auth.uid())
  and (
    private.has_shop_role(shop_id, array['owner','family'])
    or (status = 'pending' and private.has_shop_role(shop_id, array['employee']))
  )
);

drop policy if exists expenses_insert_owner_family on public.expenses;
drop policy if exists expenses_insert_employee_pending on public.expenses;
create policy expenses_insert_by_role on public.expenses for insert to authenticated
with check (
  submitted_by = (select auth.uid())
  and (
    private.has_shop_role(shop_id, array['owner','family'])
    or (status = 'pending' and private.has_shop_role(shop_id, array['employee']))
  )
);

drop policy if exists memberships_manage_owner on public.shop_memberships;
create policy memberships_update_owner on public.shop_memberships for update to authenticated
using (private.has_shop_role(shop_id, array['owner']))
with check (private.has_shop_role(shop_id, array['owner']));
create policy memberships_delete_owner on public.shop_memberships for delete to authenticated
using (private.has_shop_role(shop_id, array['owner']));

drop policy if exists vendors_write_family on public.vendors;
create policy vendors_insert_manager on public.vendors for insert to authenticated
with check (private.has_shop_role(shop_id, array['owner','family']));
create policy vendors_update_manager on public.vendors for update to authenticated
using (private.has_shop_role(shop_id, array['owner','family']))
with check (private.has_shop_role(shop_id, array['owner','family']));
create policy vendors_delete_manager on public.vendors for delete to authenticated
using (private.has_shop_role(shop_id, array['owner','family']));
