# Supabase Edge Function Deployment Guide

Follow these steps to set up the Supabase CLI and deploy your `sync-ical` function.

## 1. Install Supabase CLI

### Option A: Using Homebrew (Recommended for Mac)
Open your terminal and run:
```bash
brew install supabase/tap/supabase
```

### Option B: Using NPM (Node.js)
If you have Node.js installed:
```bash
npm install -g supabase
```

## 2. Login to Supabase
Run this command and follow the browser instructions to authorize:
```bash
supabase login
```

## 3. Link Your Project
You need your Supabase **Project ID** (found in Dashboard URL: `app.supabase.com/project/PROJECT_ID`).
Run:
```bash
# Replace PROJECT_ID with your actual ID
supabase link --project-ref PROJECT_ID
```
*(It will ask for your database password. If you don't know it, you can reset it in Dashboard settings).*

## 4. Deploy the Function
Now deploy the function we created:
```bash
supabase functions deploy sync-ical --no-verify-jwt
```
*Note: `--no-verify-jwt` allows us to call it from the app without a logged-in user if needed, or you can omit it and ensure the App sends the user's token (which it does automatically).*

## 5. (Important) Run the Database Migration First!
Before the function works, you **MUST** run the SQL script I provided (`supabase/migrations/20260123_fix_schema_reset.sql`) in the Supabase Dashboard SQL Editor. 
This script allows "External Bookings" to be saved without a User ID.


## 6. Test It
Restart your Flutter app and click the **Sync Icon** in the Analytics Dashboard.

## 7. How to Automate (Cron Job)
To make the sync happen automatically (e.g., every 30 minutes), you can set up a Cron Job in your Supabase Database.

1.  Open **Supabase Dashboard** > **SQL Editor**.
2.  Enable the extension if needed:
    ```sql
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    CREATE EXTENSION IF NOT EXISTS pg_net;
    ```
3.  Schedule the job (Replace `YOUR_PROJECT_REF` and `YOUR_SERVICE_KEY`):
    ```sql
    SELECT cron.schedule(
      'sync-ical-30min', -- Job name
      '*/30 * * * *',    -- Every 30 minutes
      $$
      SELECT net.http_post(
          url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/sync-ical',
          headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_KEY"}'::jsonb
      ) as request_id;
      $$
    );
    ```
    *Note: You can find your Project Ref and Service Key in Project Settings > API.*
