/**
 * Resolve snapshot storage path for a sighting row (unknown_face_sightings + embeds).
 * After 007 retention, camera_event_id on the sighting may be NULL while
 * event_faces.camera_events still holds the path.
 */
export function resolveSightingSnapshotPath(sighting) {
    if (!sighting) return null;
    if (sighting.camera_events?.snapshot_path) {
        return sighting.camera_events.snapshot_path;
    }
    const viaFace = sighting.event_faces?.camera_events?.snapshot_path;
    if (viaFace) return viaFace;
    if (sighting._snapshot_path) return sighting._snapshot_path;
    return null;
}
