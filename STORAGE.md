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

**Ungrouped unknown snapshots** (uploaded before clustering existed): on the Pi with updated gateway,
`curl -X POST "http://127.0.0.1:8000/api/v1/unknown/backfill-clustering?device_id=YOUR_DEVICE_UUID&limit=50"`
or use **Group photos** on Identity Review (needs `VITE_GATEWAY_URL` + `VITE_DEVICE_ID` in `website/client/.env`).
