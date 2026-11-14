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
    if old.expense_id is not null then
      update public.emi_installments set expense_id = null where id = new.id;
      delete from public.expenses
      where id = old.expense_id
        and owner_id = old.owner_id
        and profile_id = old.profile_id;
    end if;
    return new;
  end if;

  select loan_name into v_loan_name
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
           payment_method = 'Other',
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
      'Other', 'need', false
    )
    returning id into v_expense_id;
  end if;

  if new.expense_id is distinct from v_expense_id then
    update public.emi_installments set expense_id = v_expense_id where id = new.id;
  end if;

  return new;
end;
$$;
