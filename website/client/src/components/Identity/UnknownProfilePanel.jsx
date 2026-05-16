import { useState } from 'react';
import {
    Clock, Pencil, GitMerge, Archive, UserPlus, ArrowRightLeft, Unlink, X, CheckCircle,
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { supabase, getPublicUrl } from '../../services/supabase';
import { getProfileDisplayName } from '../../utils/faceDisplay';

export default function UnknownProfilePanel({
    profile,
    labelMap,
    otherProfiles,
    sightings,
    residents,
    isAdmin,
    onRefresh,
    onAssignSighting,
    showToast,
}) {
    const [renameOpen, setRenameOpen] = useState(false);
    const [renameValue, setRenameValue] = useState('');
    const [renameSaving, setRenameSaving] = useState(false);
    const [mergeOpen, setMergeOpen] = useState(false);
    const [mergeTargetId, setMergeTargetId] = useState('');
    const [mergeSaving, setMergeSaving] = useState(false);
    const [moveOpen, setMoveOpen] = useState(null);
    const [moveTargetId, setMoveTargetId] = useState('');
    const [moveSaving, setMoveSaving] = useState(false);
    const [actionSaving, setActionSaving] = useState(false);

    const displayName = getProfileDisplayName(profile, labelMap);
    const mergeCandidates = otherProfiles.filter(p => p.id !== profile.id);

    const handleRename = async (e) => {
        e.preventDefault();
        setRenameSaving(true);
        const { data, error } = await supabase.rpc('rename_unknown_face_profile', {
            p_profile_id: profile.id,
            p_display_label: renameValue.trim(),
        });
        setRenameSaving(false);
        if (error) { showToast(error.message, 'error'); return; }
        if (data?.success === false) { showToast(data.error, 'error'); return; }
        showToast('Visitor nickname updated.');
        setRenameOpen(false);
        await onRefresh();
    };

    const handleMerge = async (e) => {
        e.preventDefault();
        if (!mergeTargetId) return;
        setMergeSaving(true);
        const { data, error } = await supabase.rpc('merge_unknown_face_profiles', {
            p_source_profile_id: profile.id,
            p_target_profile_id: mergeTargetId,
        });
        setMergeSaving(false);
        if (error) { showToast(error.message, 'error'); return; }
        if (data?.success === false) { showToast(data.error, 'error'); return; }
        showToast('Profiles merged.');
        setMergeOpen(false);
        await onRefresh(mergeTargetId);
    };

    const handleDismiss = async () => {
        if (!window.confirm(`Dismiss "${displayName}"? Sightings will be ungrouped.`)) return;
        setActionSaving(true);
        const { data, error } = await supabase.rpc('dismiss_unknown_face_profile', {
            p_profile_id: profile.id,
        });
        setActionSaving(false);
        if (error) { showToast(error.message, 'error'); return; }
        if (data?.success === false) { showToast(data.error, 'error'); return; }
        showToast('Profile dismissed.');
        await onRefresh(null);
    };

    const handleMove = async (e) => {
        e.preventDefault();
        if (!moveOpen?.eventFaceId || !moveTargetId) return;
        setMoveSaving(true);
        const { data, error } = await supabase.rpc('move_event_face_to_unknown_profile', {
            p_event_face_id: moveOpen.eventFaceId,
            p_target_profile_id: moveTargetId,
        });
        setMoveSaving(false);
        if (error) { showToast(error.message, 'error'); return; }
        if (data?.success === false) { showToast(data.error, 'error'); return; }
        showToast('Photo moved to selected visitor.');
        setMoveOpen(null);
        setMoveTargetId('');
        await onRefresh(profile.id);
    };

    const handleUngroup = async (eventFaceId) => {
        setActionSaving(true);
        const { data, error } = await supabase.rpc('ungroup_event_face', {
            p_event_face_id: eventFaceId,
        });
        setActionSaving(false);
        if (error) { showToast(error.message, 'error'); return; }
        if (data?.success === false) { showToast(data.error, 'error'); return; }
        showToast('Removed from this visitor group.');
        await onRefresh(profile.id);
    };

    return (
        <div className="card" style={{ padding: 'var(--s5)' }}>
            <div style={{ display: 'flex', gap: 'var(--s5)', flexWrap: 'wrap', alignItems: 'flex-start' }}>
                <div style={{
                    width: 140, height: 140, borderRadius: 'var(--r-xl)', overflow: 'hidden',
                    border: '2px solid rgba(155,89,255,0.3)', flexShrink: 0,
                }}>
                    {profile.representative_snapshot_path && (
                        <img
                            src={getPublicUrl('event-snapshots', profile.representative_snapshot_path)}
                            alt=""
                            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                        />
                    )}
                </div>
                <div style={{ flex: 1, minWidth: 200 }}>
                    <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-xl)', fontWeight: 700, marginBottom: 'var(--s2)' }}>
                        {displayName}
                    </h2>
                    {profile.display_label && profile.display_label !== displayName && (
                        <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', marginBottom: 'var(--s2)' }}>
                            Stored: {profile.display_label}
                        </div>
                    )}
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--s3)', fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginBottom: 'var(--s4)' }}>
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                            <Clock size={12} /> Last seen {profile.last_seen_at ? formatDistanceToNow(new Date(profile.last_seen_at), { addSuffix: true }) : '—'}
                        </span>
                        <span>{profile.sighting_count} sightings</span>
                    </div>
                    {isAdmin && (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--s2)' }}>
                            <button type="button" className="btn btn-ghost btn-sm" onClick={() => { setRenameValue(displayName); setRenameOpen(true); }}>
                                <Pencil size={13} /> Nickname
                            </button>
                            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setMergeOpen(true)} disabled={mergeCandidates.length === 0}>
                                <GitMerge size={13} /> Merge into…
                            </button>
                            <button type="button" className="btn btn-ghost btn-sm" onClick={handleDismiss} disabled={actionSaving} style={{ color: 'var(--text-muted)' }}>
                                <Archive size={13} /> Dismiss
                            </button>
                        </div>
                    )}
                </div>
            </div>

            {mergeCandidates.length > 0 && isAdmin && (
                <div style={{
                    marginTop: 'var(--s4)', padding: 'var(--s3) var(--s4)', borderRadius: 'var(--r-md)',
                    background: 'rgba(255,176,32,0.06)', border: '1px solid rgba(255,176,32,0.2)',
                    fontSize: 'var(--size-xs)', color: 'var(--text-secondary)', lineHeight: 1.5,
                }}>
                    Same person in multiple visitor groups? Use <strong>Merge into…</strong> to combine them, or move individual photos below.
                </div>
            )}

            <h3 style={{ fontSize: 'var(--size-sm)', fontWeight: 700, marginTop: 'var(--s5)', marginBottom: 'var(--s3)' }}>Sighting timeline</h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(108px, 1fr))', gap: 'var(--s3)' }}>
                {sightings.map(s => {
                    const path = s.camera_events?.snapshot_path;
                    const url = path ? getPublicUrl('event-snapshots', path) : null;
                    const eventFaceId = s.event_faces?.id;
                    return (
                        <div key={s.id} style={{ borderRadius: 'var(--r-md)', overflow: 'hidden', border: '1px solid var(--border-soft)', background: 'var(--bg-raised)' }}>
                            <div style={{ aspectRatio: '1', background: '#0a0c10' }}>
                                {url && <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                            </div>
                            <div style={{ padding: 6, display: 'flex', flexDirection: 'column', gap: 4 }}>
                                <div style={{ fontSize: 9, color: 'var(--text-muted)' }}>
                                    {s.created_at ? formatDistanceToNow(new Date(s.created_at), { addSuffix: true }) : '—'}
                                </div>
                                {isAdmin && eventFaceId && (
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
                                        <button
                                            type="button"
                                            className="btn btn-ghost btn-sm"
                                            style={{ fontSize: 9, padding: '2px 4px', color: 'var(--violet-core)' }}
                                            onClick={() => { setMoveOpen({ eventFaceId }); setMoveTargetId(''); }}
                                            disabled={actionSaving}
                                        >
                                            <ArrowRightLeft size={10} /> Move
                                        </button>
                                        <button
                                            type="button"
                                            className="btn btn-ghost btn-sm"
                                            style={{ fontSize: 9, padding: '2px 4px', color: 'var(--text-muted)' }}
                                            onClick={() => handleUngroup(eventFaceId)}
                                            disabled={actionSaving}
                                        >
                                            <Unlink size={10} /> Ungroup
                                        </button>
                                        {onAssignSighting && (
                                            <button
                                                type="button"
                                                className="btn btn-ghost btn-sm"
                                                style={{ fontSize: 9, padding: '2px 4px', color: 'var(--jade-core)' }}
                                                onClick={() => onAssignSighting(eventFaceId)}
                                            >
                                                <UserPlus size={10} /> Resident
                                            </button>
                                        )}
                                    </div>
                                )}
                            </div>
                        </div>
                    );
                })}
            </div>

            {renameOpen && (
                <Modal title="Rename visitor" onClose={() => setRenameOpen(false)}>
                    <form onSubmit={handleRename} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">Nickname</label>
                            <input className="form-input" value={renameValue} onChange={e => setRenameValue(e.target.value)} maxLength={80} required autoFocus />
                        </div>
                        <ModalActions onCancel={() => setRenameOpen(false)} saving={renameSaving} label="Save" />
                    </form>
                </Modal>
            )}

            {mergeOpen && (
                <Modal title="Merge into another visitor" onClose={() => setMergeOpen(false)}>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginBottom: 'var(--s4)', lineHeight: 1.55 }}>
                        All photos from <strong>{displayName}</strong> will join the selected profile. This profile will be closed.
                    </p>
                    <form onSubmit={handleMerge} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                        <select className="form-input" value={mergeTargetId} onChange={e => setMergeTargetId(e.target.value)} required>
                            <option value="">Select target visitor…</option>
                            {mergeCandidates.map(p => (
                                <option key={p.id} value={p.id}>{getProfileDisplayName(p, labelMap)}</option>
                            ))}
                        </select>
                        <ModalActions onCancel={() => setMergeOpen(false)} saving={mergeSaving} label="Merge" />
                    </form>
                </Modal>
            )}

            {moveOpen && (
                <Modal title="Move photo to another visitor" onClose={() => setMoveOpen(null)}>
                    <form onSubmit={handleMove} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                        <select className="form-input" value={moveTargetId} onChange={e => setMoveTargetId(e.target.value)} required>
                            <option value="">Select visitor…</option>
                            {otherProfiles.filter(p => p.id !== profile.id).map(p => (
                                <option key={p.id} value={p.id}>{getProfileDisplayName(p, labelMap)}</option>
                            ))}
                        </select>
                        <ModalActions onCancel={() => setMoveOpen(null)} saving={moveSaving} label="Move" />
                    </form>
                </Modal>
            )}
        </div>
    );
}

function Modal({ title, onClose, children }) {
    return (
        <div className="modal-overlay" onClick={onClose} style={{ zIndex: 3100 }}>
            <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 400 }}>
                <div className="modal-header">
                    <h2 style={{ fontSize: 'var(--size-lg)' }}>{title}</h2>
                    <button type="button" className="modal-close" onClick={onClose}><X size={20} /></button>
                </div>
                <div style={{ padding: '0 var(--s5) var(--s5)' }}>{children}</div>
            </div>
        </div>
    );
}

function ModalActions({ onCancel, saving, label }) {
    return (
        <div style={{ display: 'flex', gap: 'var(--s3)', justifyContent: 'flex-end' }}>
            <button type="button" className="btn btn-ghost" onClick={onCancel}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><CheckCircle size={15} /> {label}</>}
            </button>
        </div>
    );
}
