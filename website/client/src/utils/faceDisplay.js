/**
 * Shared labels for camera / identity surveillance UI.
 * DB classification: 'resident' | 'unknown'
 */

export function getFaceFromEvent(event) {
    return event?.event_faces?.[0] ?? null;
}

export function isScanningEvent(event) {
    const face = getFaceFromEvent(event);
    return Boolean(event?._scanning && !face);
}

export function isResidentFace(face) {
    return face?.classification === 'resident';
}

export function getDetectionDisplayName(event) {
    if (isScanningEvent(event)) return 'Scanning...';

    const face = getFaceFromEvent(event);
    if (!face) return 'Unknown Person';

    if (isResidentFace(face)) {
        return face.residents?.name || 'Resident';
    }

    const profile = face.unknown_face_profiles;
    if (profile?.display_label) {
        const n = profile.sighting_count;
        if (n && n > 1) {
            return `${profile.display_label} · ${n}× seen`;
        }
        return profile.display_label;
    }

    return 'Unknown Person';
}

export function getDetectionTone(event) {
    if (isScanningEvent(event)) return 'scanning';
    const face = getFaceFromEvent(event);
    if (face && isResidentFace(face)) return 'resident';
    return 'unknown';
}
