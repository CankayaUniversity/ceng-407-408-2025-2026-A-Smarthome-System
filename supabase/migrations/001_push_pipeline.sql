-- Push pipeline: `user_devices` (Flutter FCM token) + mevcut `public.events` webhook.
-- Mevcut şema: `events` (device_id, user_id?, event_type, priority, status, message, …),
-- `devices` (id, user_id?, …) — export: current_supabase/*.sql
--
-- Webhook (Dashboard: Database → Webhooks):
--   Table: public.events
--   Event: INSERT
--   URL: OCI API Gateway POST …/v1/alarm
--   Header: X-Webhook-Secret: <same as OCI WEBHOOK_SECRET>
--
-- OCI Function `record.user_id` boşsa `device_id` ile `devices.user_id` okur.

-- ─── user_devices: one row per physical device token ─────────────────────
create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  fcm_token text not null,
  platform text not null default 'unknown',
  updated_at timestamptz not null default now(),
  constraint user_devices_fcm_token_key unique (fcm_token)
);

create index if not exists user_devices_user_id_idx on public.user_devices (user_id);

alter table public.user_devices enable row level security;

drop policy if exists "user_devices_select_own" on public.user_devices;
create policy "user_devices_select_own"
  on public.user_devices for select
  using (auth.uid() = user_id);

drop policy if exists "user_devices_insert_own" on public.user_devices;
create policy "user_devices_insert_own"
  on public.user_devices for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_devices_update_own" on public.user_devices;
create policy "user_devices_update_own"
  on public.user_devices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_devices_delete_own" on public.user_devices;
create policy "user_devices_delete_own"
  on public.user_devices for delete
  using (auth.uid() = user_id);

comment on table public.user_devices is 'FCM registration rows; Flutter upserts after sign-in.';
