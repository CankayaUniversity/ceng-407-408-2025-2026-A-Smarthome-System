-- Pürüz B fix: keep public.users mirrored from auth.users.
--
-- Problem (15 May 2026 debugging):
--   `devices.user_id` foreign key referenced `public.users(id)`, while
--   `user_devices.user_id` referenced `auth.users(id)`. The OCI push function
--   resolves the recipient via `devices` → `user_id` → `user_devices`, so the
--   two id spaces had to match. They did not (auth.users had Deniz / Enis /
--   Ayberk; public.users only had the legacy admin@smarthome.local row).
--   Result: assigning a device to any real Auth user failed with
--   FK violation 23503, and the push pipeline silently returned no_fcm_tokens.
--
-- Approach (non-destructive):
--   * Keep `public.users` as-is — other parts of the project (RPi gateway,
--     dashboards) may still read it directly.
--   * Treat `auth.users` as the single source of truth.
--   * Backfill `public.users` from `auth.users` and install a trigger that
--     mirrors future INSERTs and email UPDATEs.
--
-- Reverting:
--   drop trigger if exists trg_sync_auth_user_to_public_users on auth.users;
--   drop function if exists public.sync_auth_user_to_public_users();
--   -- Backfilled rows remain in place; remove them manually if desired.

-- 1) Backfill — copy every auth.users row that is not yet in public.users.
insert into public.users (id, email, full_name, password_hash, created_at)
select
  u.id,
  u.email,
  coalesce(p.name, u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1)),
  'managed-by-auth',
  coalesce(u.created_at, now())
from auth.users u
left join public.profiles p on p.id = u.id
on conflict (id) do nothing;

-- 2) Sync function — auth.users INSERT/UPDATE → public.users upsert.
create or replace function public.sync_auth_user_to_public_users()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.users (id, email, full_name, password_hash, created_at)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    'managed-by-auth',
    coalesce(new.created_at, now())
  )
  on conflict (id) do update
    set email     = excluded.email,
        full_name = coalesce(excluded.full_name, public.users.full_name);
  return new;
end;
$$;

comment on function public.sync_auth_user_to_public_users() is
  'Mirrors auth.users rows into public.users so legacy FKs (devices.user_id) stay valid.';

-- 3) Trigger — fire on new signups and on email changes.
drop trigger if exists trg_sync_auth_user_to_public_users on auth.users;
create trigger trg_sync_auth_user_to_public_users
  after insert or update of email on auth.users
  for each row
  execute function public.sync_auth_user_to_public_users();
