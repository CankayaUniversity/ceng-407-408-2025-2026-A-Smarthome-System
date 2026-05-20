import { getPublicUrl } from '../services/supabase';

/** Public URL for an event-snapshots object path, or null. */
export function snapshotUrl(path) {
    return path ? getPublicUrl('event-snapshots', path) : null;
}
