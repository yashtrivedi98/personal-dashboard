alter table public.emi_installments
  add column if not exists expense_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.emi_installments'::regclass
      and conname = 'emi_installments_expense_id_key'
  ) then
    alter table public.emi_installments
      add constraint emi_installments_expense_id_key unique (expense_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.emi_installments'::regclass
      and conname = 'emi_installments_expense_id_fkey'
  ) then
    alter table public.emi_installments
      add constraint emi_installments_expense_id_fkey
      foreign key (expense_id) references public.expenses(id) on delete restrict;
  end if;
end $$;

create or replace function public.sync_emi_installment_expense()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_loan_name text;
  v_expense_id uuid;
begin
  if tg_op = 'DELETE' then
    if old.expense_id is not null then
      delete from public.expenses
      where id = old.expense_id
        and owner_id = old.owner_id
        and profile_id = old.profile_id;
    end if;
    return old;
  end if;

  if coalesce(new.paid_amount, 0) <= 0 then
    if new.expense_id is not null then
      delete from public.expenses
      where id = new.expense_id
        and owner_id = new.owner_id
        and profile_id = new.profile_id;
      new.expense_id := null;
    end if;
    return new;
  end if;

  select loan_name
    into v_loan_name
  from public.emi_loans
  where id = new.loan_id
    and owner_id = new.owner_id
    and profile_id = new.profile_id;

  if v_loan_name is null then
    raise exception 'Could not find the loan for this EMI installment.';
  end if;

  if new.expense_id is not null then
    update public.expenses
       set expense_date = coalesce(new.paid_date, current_date),
           amount = new.paid_amount,
           category = 'EMI',
           description = 'EMI - ' || v_loan_name || ' (Installment ' || new.installment_number || ')',
           payment_method = 'Auto-debit',
           expense_type = 'need',
           is_shared = false
     where id = new.expense_id
       and owner_id = new.owner_id
       and profile_id = new.profile_id
    returning id into v_expense_id;
  end if;

  if v_expense_id is null then
    insert into public.expenses (
      owner_id, profile_id, expense_date, amount, category,
      description, payment_method, expense_type, is_shared
    ) values (
      new.owner_id, new.profile_id, coalesce(new.paid_date, current_date),
      new.paid_amount, 'EMI',
      'EMI - ' || v_loan_name || ' (Installment ' || new.installment_number || ')',
      'Auto-debit', 'need', false
    )
    returning id into v_expense_id;

    new.expense_id := v_expense_id;
  end if;

  return new;
end;
$$;

drop trigger if exists emi_installments_sync_expense on public.emi_installments;
create trigger emi_installments_sync_expense
before insert or update of paid_amount, paid_date, amount, loan_id, profile_id, owner_id
on public.emi_installments
for each row
execute function public.sync_emi_installment_expense();

drop trigger if exists emi_installments_delete_expense on public.emi_installments;
create trigger emi_installments_delete_expense
before delete on public.emi_installments
for each row
execute function public.sync_emi_installment_expense();

create index if not exists emi_installments_expense_id_idx
  on public.emi_installments(expense_id)
  where expense_id is not null;
