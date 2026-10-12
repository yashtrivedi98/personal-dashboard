# Couple Expense Manager

A cloud-backed shared expense manager for two profiles, built to use Supabase Authentication and PostgreSQL.

## Current status

The application needs a Supabase project URL and publishable/anon key in `config.js` before it can connect to your existing Supabase project. Never put a Supabase `service_role` secret in browser code.

## Features planned

- Sign in with Supabase Auth
- Switch between two profiles attached to the shared account
- Track expenses and categorize needs/wants
- Monthly totals and CSV export
- Budgets, savings goals, and reports
- Period logs (sensitive data; use only after reviewing access controls)

## Run / deploy

Serve the files as a static website. Configure `config.js` with the Supabase project URL and browser-safe publishable key, then deploy through GitHub Pages or another static host. Enable RLS and verify the policies before entering real financial or health-related information.

## Security note

A shared login means anyone using that login can access both profiles. Profile switching is organizational, not a privacy boundary. Use separate accounts and profile-scoped policies if each person needs private records.
