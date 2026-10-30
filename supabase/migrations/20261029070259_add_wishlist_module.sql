create table if not exists public.wishlist_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null,
  item_name text not null check (length(trim(item_name)) > 0),
  description text,
  category text not null default 'Other',
  target_price numeric not null default 0 check (target_price >= 0),
  current_price numeric check (current_price is null or current_price >= 0),
  amount_saved numeric not null default 0 check (amount_saved >= 0),
  priority text not null default 'medium' check (priority in ('high','medium','low')),
  status text not null default 'want_to_buy' check (status in ('want_to_buy','saving','purchased','on_hold')),
  target_date date,
  purchased_date date,
  actual_price numeric check (actual_price is null or actual_price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wishlist_items_profile_owner_fkey
    foreign key (profile_id, owner_id) references public.profiles(id, owner_id) on delete cascade
);

create table if not exists public.wishlist_price_history (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  wishlist_item_id uuid not null references public.wishlist_items(id) on delete cascade,
  price numeric not null check (price >= 0),
  recorded_at timestamptz not null default now(),
  notes text
);

create index if not exists wishlist_items_owner_priority_idx
  on public.wishlist_items(owner_id, priority);
create index if not exists wishlist_items_owner_status_idx
  on public.wishlist_items(owner_id, status);
create index if not exists wishlist_price_history_item_date_idx
  on public.wishlist_price_history(wishlist_item_id, recorded_at desc);

alter table public.wishlist_items enable row level security;
alter table public.wishlist_price_history enable row level security;

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
