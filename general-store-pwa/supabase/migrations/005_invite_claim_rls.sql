-- Remove the SECURITY DEFINER invite-claim path. Invitation claiming now runs
-- as the signed-in user and is constrained by row-level security and column grants.
drop policy if exists invites_read_invitee on public.shop_invites;
create policy invites_read_invitee on public.shop_invites for select to authenticated
using (
  lower(email) = lower((select auth.jwt() ->> 'email'))
  and status = 'pending'
  and expires_at > now()
);

drop policy if exists invites_update_invitee on public.shop_invites;
create policy invites_update_invitee on public.shop_invites for update to authenticated
using (
  lower(email) = lower((select auth.jwt() ->> 'email'))
  and status = 'pending'
  and expires_at > now()
)
with check (
  lower(email) = lower((select auth.jwt() ->> 'email'))
  and status = 'claimed'
);

drop policy if exists memberships_claim_invite on public.shop_memberships;
create policy memberships_claim_invite on public.shop_memberships for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.shop_invites i
    where i.shop_id = shop_memberships.shop_id
      and lower(i.email) = lower((select auth.jwt() ->> 'email'))
      and i.role = shop_memberships.role
      and i.status = 'pending'
      and i.expires_at > now()
  )
);

-- A claimant can update only the invitation status, not its role, email or shop.
revoke update on public.shop_invites from authenticated;
grant update(status) on public.shop_invites to authenticated;

create or replace function public.claim_shop_invites()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  claimed_count integer := 0;
  user_email text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  user_email := lower(auth.jwt() ->> 'email');
  if user_email is null then
    raise exception 'Authenticated email not found';
  end if;

  insert into public.shop_memberships(shop_id, user_id, role)
  select i.shop_id, auth.uid(), i.role
  from public.shop_invites i
  where lower(i.email) = user_email
    and i.status = 'pending'
    and i.expires_at > now()
  on conflict (shop_id, user_id) do nothing;

  get diagnostics claimed_count = row_count;

  update public.shop_invites
  set status = 'claimed'
  where lower(email) = user_email
    and status = 'pending'
    and expires_at > now();

  return claimed_count;
end;
$$;
revoke all on function public.claim_shop_invites() from public, anon;
grant execute on function public.claim_shop_invites() to authenticated;
