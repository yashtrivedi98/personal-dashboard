# Couple Expense Manager

A responsive shared finance dashboard using Supabase Auth and Postgres.

## Features
- Sign in / create account with Supabase Auth
- Switch between profiles associated with the same account
- Add, edit and delete expenses; needs/wants, category and payment method
- Monthly overview and category breakdown
- Monthly category budgets
- Savings goals
- Wishlist with price tracking, savings progress, priorities, and purchase-to-expense conversion
- CSV export

## Configure Supabase
1. Open `config.js`.
2. Replace `YOUR_SUPABASE_PROJECT_URL` with the Project URL from Supabase API settings.
3. Replace `YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY` with the publishable key (or legacy anon key).
4. Keep the service_role/secret key out of browser code.
5. Confirm the database tables and RLS policies are enabled. The app expects `profiles`, `expenses`, `budgets`, and `savings_goals` matching the schema already set up for this project.

## Deploy
The GitHub Actions workflow in `.github/workflows/deploy.yml` publishes the repository root to GitHub Pages on each push to `main`. In the repository settings, set Pages build/deployment source to **GitHub Actions** if it is not already selected.

## Privacy note
The two profiles are under one Supabase login. Anyone with that login can access both profiles. Profile switching is for organization, not a privacy boundary. Do not store sensitive data unless access rules have been reviewed for your needs.
