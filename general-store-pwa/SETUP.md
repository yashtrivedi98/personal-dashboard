# General Store Manager PWA — setup

This folder is a separate app within the repository. It must use a **dedicated Supabase project**. Do not point it at the Couple Expense Manager project: that project contains private personal records.

## 1. Create a dedicated Supabase project
Create a new project in the Supabase organization you choose. Use the closest suitable region for your users (India region if available). Keep the database password private.

## 2. Apply the database schema
In the new project's SQL Editor, run both SQL files in order:
1. `supabase/migrations/001_general_store_schema.sql`
2. `supabase/migrations/002_vendor_payments.sql`

This creates shop/team, vendor, purchase, expense, invitation and audit tables, enables row-level security, and adds policies. Employees can create pending purchase/expense entries and only read their own submissions. Owner/family members can review records; only owners can manage roles and delete financial records.

After running the SQL, check the Supabase Security Advisor and resolve any warnings before entering real shop data.

## 3. Configure the browser client
Open `config.js` and set:
- `supabaseUrl`: Project URL from Supabase → Project Settings → API.
- `supabasePublishableKey`: publishable key from the same project.

Only use the publishable key in this file. Never put a `service_role` key or secret key in browser code.

## 4. Authentication and first owner
Enable Email authentication in Supabase Auth. For testing, configure email confirmation and SMTP settings to match your intended workflow.
1. Open the app and create an account with your email.
2. Confirm your email if requested, then sign in.
3. Create the shop. The account that creates the shop becomes the owner.
4. Under Team, create invitations for family and employees. This screen records the invitation; it does not send email. Invitees must create/sign in to Supabase Auth with the exact invited email to claim their membership. You must deliver the sign-up link to them separately.

## 5. Deploy
The repository currently uses GitHub Pages for the root app. Once this branch is reviewed and merged, the app folder should be available at:
`https://yashtrivedi98.github.io/personal-dashboard/general-store-pwa/`

Serve over HTTPS for installation and service-worker support. Open the URL in Chrome/Edge and choose **Install app** or **Add to Home Screen**.

## Offline behavior and limitations
The app shell is cached for offline launch. New purchase/expense entries created while offline are queued in IndexedDB and submitted when the device reconnects and the user is signed in. Queue entries remain local to that browser/device until sync; they are not visible on another device before synchronization. Keep the app open after reconnecting to allow the queue to sync, and verify pending counts before clearing browser data. This is an initial offline queue, not a full conflict-resolution engine.

## Before using for real accounting
- Test with dummy users for owner, family and employee roles.
- Confirm an employee cannot approve, edit, delete or see another employee's entries.
- Verify approvals, month totals, unpaid balances and CSV export against sample bills.
- Configure backups and authentication email delivery.
- Treat the app as an operational register, not a substitute for statutory accounting or tax records.
