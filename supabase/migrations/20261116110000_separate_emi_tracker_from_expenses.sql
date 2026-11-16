-- Keep EMI Tracker payments independent from the Expenses module.
-- Remove only expense rows explicitly linked to EMI installments.
drop trigger if exists emi_installments_sync_expense on public.emi_installments;
drop trigger if exists emi_installments_delete_expense on public.emi_installments;

delete from public.expenses
where id in (
  select expense_id
  from public.emi_installments
  where expense_id is not null
);

update public.emi_installments
set expense_id = null
where expense_id is not null;

drop function if exists public.sync_emi_installment_expense();
