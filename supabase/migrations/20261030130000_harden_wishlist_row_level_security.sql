drop policy if exists "Users manage own wishlist items" on public.wishlist_items;
create policy "Users manage own wishlist items"
on public.wishlist_items for all to authenticated
using ((select auth.uid()) = owner_id)
with check (
  (select auth.uid()) = owner_id
  and exists (
    select 1 from public.profiles p
    where p.id = wishlist_items.profile_id
      and p.owner_id = (select auth.uid())
  )
);

drop policy if exists "Users manage own wishlist price history" on public.wishlist_price_history;
create policy "Users manage own wishlist price history"
on public.wishlist_price_history for all to authenticated
using ((select auth.uid()) = owner_id)
with check (
  (select auth.uid()) = owner_id
  and exists (
    select 1 from public.wishlist_items wi
    where wi.id = wishlist_price_history.wishlist_item_id
      and wi.owner_id = (select auth.uid())
  )
);

revoke all on public.wishlist_items from anon;
revoke all on public.wishlist_price_history from anon;
grant select, insert, update, delete on public.wishlist_items to authenticated;
grant select, insert, update, delete on public.wishlist_price_history to authenticated;
