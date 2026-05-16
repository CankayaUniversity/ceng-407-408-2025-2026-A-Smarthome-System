# Supabase Storage — `event-snapshots`

## Active prefixes

| Prefix | Purpose |
|--------|---------|
| `resident_photos/` | Enrollment photos (web/mobile upload) |
| `resident_snapshots/` | Known resident at detection |
| `unknown_snapshots/` | Unknown face at detection |

Do not write to `strangers/` (legacy). Delete the empty `resident-faces` bucket in the dashboard.

See `supabase_setup_v5.sql` for unknown visitor DB tables.

After v5, run `supabase_setup_v6_identity_corrections.sql` for label-only assign (default), revert, and unlink RPCs used by **Identity Review**.
