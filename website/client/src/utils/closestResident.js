/**
 * Label for Identity review queue: who the match score is relative to.
 */
export function getClosestResidentName(face, residentNameById) {
    if (!face) return null;
    const embedded = face.best_match?.name;
    if (embedded) return embedded;
    const id = face.best_match_resident_id;
    if (id && residentNameById?.get) {
        return residentNameById.get(id) || null;
    }
    return null;
}
