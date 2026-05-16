import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
    UserSearch, Users, RefreshCw, ChevronRight, AlertTriangle,
    CheckCircle, X, UserPlus, Camera, Clock, Hash, History,
    Undo2, Unlink, ImageIcon, Layers,
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { supabase, getPublicUrl } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';
import {
    buildProfileLabelMap,
    getProfileDisplayName,
    getDetectionTitle,
    getDetectionSubtitle,
} from '../utils/faceDisplay';
import UnknownProfilePanel from '../components/Identity/UnknownProfilePanel';

const EVENT_FACE_SELECT = `
  id, classification, match_score, resident_id, unknown_profile_id, camera_event_id,
  camera_events(id, snapshot_path, created_at, event_id),
  residents(name),
  unknown_face_profiles(id, display_label, sighting_count, first_seen_at, status)
`;

const ACTION_SELECT = `
  id, action, created_at, metadata, event_face_id, to_resident_id, from_unknown_profile_id,
  event_faces(
    id, classification, resident_id,
    camera_events(id, snapshot_path, created_at)
  )
`;

const IdentityPage = () => {
    const { isAdmin } = useAuth();
    const [profiles, setProfiles] = useState([]);
    const [recentUnknowns, setRecentUnknowns] = useState([]);
    const [residents, setResidents] = useState([]);
    const [recentActions, setRecentActions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [selectedProfileId, setSelectedProfileId] = useState(null);
    const [sightings, setSightings] = useState([]);
    const [assignTarget, setAssignTarget] = useState(null);
    const [assignResidentId, setAssignResidentId] = useState('');
    const [assignUseEnrollment, setAssignUseEnrollment] = useState(false);
    const [assignSaving, setAssignSaving] = useState(false);
    const [assignError, setAssignError] = useState(null);
    const [revertSavingId, setRevertSavingId] = useState(null);
    const [unlinkSavingId, setUnlinkSavingId] = useState(null);
    const [galleryResidentId, setGalleryResidentId] = useState('');
    const [residentDetections, setResidentDetections] = useState([]);
    const [galleryLoading, setGalleryLoading] = useState(false);
    const [clusterBackfillSaving, setClusterBackfillSaving] = useState(false);
    const [clusterStatus, setClusterStatus] = useState(null);
    const [toast, setToast] = useState(null);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 4500);
    };

    const residentNameById = useMemo(() => {
        const m = new Map();
        residents.forEach(r => m.set(r.id, r.name || 'Resident'));
        return m;
    }, [residents]);

    const profileLabelMap = useMemo(() => buildProfileLabelMap(profiles), [profiles]);

    const revertedActionIds = useMemo(() => {
        const ids = new Set();
        recentActions.forEach(a => {
            const src = a.metadata?.source_action_id;
            if (a.action === 'revert_assign' && src) ids.add(src);
        });
        return ids;
    }, [recentActions]);

    const loadRecentActions = useCallback(async () => {
        const { data } = await supabase
            .from('face_label_actions')
            .select(ACTION_SELECT)
            .in('action', ['assign_resident', 'revert_assign', 'unlink_from_resident', 'merge_profiles', 'rename_profile', 'move_sighting', 'dismiss_profile'])
            .order('created_at', { ascending: false })
            .limit(40);
        setRecentActions(data || []);
    }, []);

    const loadAll = useCallback(async () => {
        const [profRes, facesRes, resRes] = await Promise.all([
            supabase
                .from('unknown_face_profiles')
                .select('*')
                .eq('status', 'active')
                .order('last_seen_at', { ascending: false }),
            supabase
                .from('event_faces')
                .select(EVENT_FACE_SELECT)
                .eq('classification', 'unknown')
                .limit(40),
            supabase.from('residents').select('id, name, photo_path').order('name'),
        ]);

        setProfiles(profRes.data || []);
        const faces = (facesRes.data || []).sort((a, b) => {
            const ta = a.camera_events?.created_at || '';
            const tb = b.camera_events?.created_at || '';
            return tb.localeCompare(ta);
        });
        setRecentUnknowns(faces.slice(0, 30));
        setResidents(resRes.data || []);
        await loadRecentActions();
    }, [loadRecentActions]);

    const loadResidentDetections = useCallback(async (residentId) => {
        if (!residentId) {
            setResidentDetections([]);
            return;
        }
        setGalleryLoading(true);
        const { data } = await supabase
            .from('event_faces')
            .select(EVENT_FACE_SELECT)
            .eq('resident_id', residentId)
            .eq('classification', 'resident')
            .order('id', { ascending: false })
            .limit(60);
        const sorted = (data || []).sort((a, b) => {
            const ta = a.camera_events?.created_at || '';
            const tb = b.camera_events?.created_at || '';
            return tb.localeCompare(ta);
        });
        setResidentDetections(sorted);
        setGalleryLoading(false);
    }, []);

    useEffect(() => {
        (async () => {
            setLoading(true);
            await loadAll();
            setLoading(false);
        })();
    }, [loadAll]);

    useEffect(() => {
        loadResidentDetections(galleryResidentId);
    }, [galleryResidentId, loadResidentDetections]);

    const handleRefresh = async () => {
        setRefreshing(true);
        await loadAll();
        if (selectedProfileId) await loadSightings(selectedProfileId);
        if (galleryResidentId) await loadResidentDetections(galleryResidentId);
        setRefreshing(false);
    };

    const loadSightings = async (profileId) => {
        const { data } = await supabase
            .from('unknown_face_sightings')
            .select(`
              id, match_distance, created_at,
              camera_events(id, snapshot_path, created_at),
              event_faces(id, classification, match_score, camera_event_id)
            `)
            .eq('unknown_face_profile_id', profileId)
            .order('created_at', { ascending: false })
            .limit(50);
        setSightings(data || []);
    };

    useEffect(() => {
        if (selectedProfileId) loadSightings(selectedProfileId);
        else setSightings([]);
    }, [selectedProfileId]);

    const selectedProfile = useMemo(
        () => profiles.find(p => p.id === selectedProfileId) ?? null,
        [profiles, selectedProfileId],
    );

    const galleryResident = useMemo(
        () => residents.find(r => r.id === galleryResidentId) ?? null,
        [residents, galleryResidentId],
    );

    const reviewQueue = useMemo(() => {
        return recentUnknowns.filter(f => {
            const score = f.match_score;
            return score != null && score > 0.45 && score < 0.65;
        });
    }, [recentUnknowns]);

    const unclusteredCount = useMemo(
        () => recentUnknowns.filter(f => !f.unknown_profile_id).length,
        [recentUnknowns],
    );

    const canClusterViaGateway = Boolean(
        import.meta.env.VITE_GATEWAY_URL && import.meta.env.VITE_DEVICE_ID,
    );

    const triggerBackfillIfNeeded = async (useEnrollment) => {
        if (!useEnrollment) return;
        const gatewayUrl = import.meta.env.VITE_GATEWAY_URL;
        const deviceId = import.meta.env.VITE_DEVICE_ID;
        if (!gatewayUrl || !deviceId) return;
        try {
            await fetch(
                `${gatewayUrl.replace(/\/$/, '')}/api/v1/residents/backfill-embeddings?device_id=${deviceId}`,
                { method: 'POST' },
            );
        } catch {
            /* optional */
        }
    };

    const handleAssign = async (e) => {
        e.preventDefault();
        if (!assignTarget?.id || !assignResidentId) return;
        setAssignSaving(true);
        setAssignError(null);

        const { data, error } = await supabase.rpc('assign_event_face_to_resident', {
            p_event_face_id: assignTarget.id,
            p_resident_id: assignResidentId,
            p_use_snapshot_for_enrollment: assignUseEnrollment,
        });

        setAssignSaving(false);

        if (error) {
            setAssignError(error.message);
            return;
        }
        if (data?.success === false) {
            setAssignError(data.error || 'Assignment failed');
            return;
        }

        await triggerBackfillIfNeeded(assignUseEnrollment);

        setAssignTarget(null);
        setAssignResidentId('');
        setAssignUseEnrollment(false);
        const name = residentNameById.get(assignResidentId) || 'resident';
        showToast(
            assignUseEnrollment
                ? `Linked to ${name} and updated enrollment photo.`
                : `Linked to ${name}. Enrollment photo unchanged.`,
        );
        await loadAll();
        if (selectedProfileId) await loadSightings(selectedProfileId);
        if (galleryResidentId === assignResidentId) await loadResidentDetections(galleryResidentId);
    };

    const handleRevert = async (actionId) => {
        setRevertSavingId(actionId);
        const { data, error } = await supabase.rpc('revert_face_label_action', {
            p_action_id: actionId,
        });
        setRevertSavingId(null);

        if (error) {
            showToast(error.message, 'error');
            return;
        }
        if (data?.success === false) {
            showToast(data.error || 'Revert failed', 'error');
            return;
        }

        showToast('Assignment reverted. Detection is unknown again.');
        await loadAll();
        if (galleryResidentId) await loadResidentDetections(galleryResidentId);
    };

    const handleClusterBackfill = async () => {
        const gatewayUrl = import.meta.env.VITE_GATEWAY_URL;
        const deviceId = import.meta.env.VITE_DEVICE_ID;
        if (!gatewayUrl || !deviceId) {
            const msg = 'Add VITE_GATEWAY_URL and VITE_DEVICE_ID to website/client/.env, then restart npm run dev.';
            setClusterStatus({ type: 'error', msg });
            showToast(msg, 'error');
            return;
        }
        setClusterBackfillSaving(true);
        setClusterStatus({ type: 'loading', msg: `Calling gateway at ${gatewayUrl}…` });
        const url = `${gatewayUrl.replace(/\/$/, '')}/api/v1/unknown/backfill-clustering?device_id=${deviceId}&limit=50`;
        try {
            const res = await fetch(url, { method: 'POST' });
            const body = await res.json().catch(() => ({}));
            if (!res.ok) {
                const detail = typeof body.detail === 'string'
                    ? body.detail
                    : JSON.stringify(body.detail || body.error || body);
                const msg = res.status === 404
                    ? `Gateway endpoint not found (404). Pull latest code on the Pi and restart uvicorn. (${detail})`
                    : `Gateway error ${res.status}: ${detail}`;
                setClusterStatus({ type: 'error', msg });
                showToast(msg, 'error');
                return;
            }
            const ok = body.clustered_ok ?? 0;
            const created = body.profiles_created ?? 0;
            const candidates = body.candidates ?? 0;
            if (ok > 0) {
                const msg = `Grouped ${ok} of ${candidates} detection(s) (${created} new profile(s)). Refresh complete.`;
                setClusterStatus({ type: 'success', msg });
                showToast(msg);
            } else {
                const msg = candidates > 0
                    ? `Found ${candidates} photo(s) but could not cluster (face/embedding failed on Pi). Check uvicorn logs.`
                    : 'No ungrouped unknown detections left to cluster.';
                setClusterStatus({ type: 'error', msg });
                showToast(msg, 'error');
            }
            await loadAll();
        } catch (err) {
            const isLocalhost = /localhost|127\.0\.0\.1/.test(gatewayUrl);
            const hint = isLocalhost
                ? ' Site runs on your laptop but gateway is usually on the Pi — set VITE_GATEWAY_URL=http://PI_LAN_IP:8000'
                : ' Check Pi is on, uvicorn is running, and port 8000 is reachable from this PC.';
            const msg = `${err.message || 'Could not reach gateway'}.${hint}`;
            setClusterStatus({ type: 'error', msg });
            showToast(msg, 'error');
            console.error('Cluster backfill failed:', url, err);
        } finally {
            setClusterBackfillSaving(false);
        }
    };

    const handleUnlink = async (eventFaceId) => {
        if (!window.confirm('Mark this detection as unknown? The resident enrollment photo will not change.')) {
            return;
        }
        setUnlinkSavingId(eventFaceId);
        const { data, error } = await supabase.rpc('unlink_event_face_from_resident', {
            p_event_face_id: eventFaceId,
        });
        setUnlinkSavingId(null);

        if (error) {
            showToast(error.message, 'error');
            return;
        }
        if (data?.success === false) {
            showToast(data.error || 'Unlink failed', 'error');
            return;
        }

        showToast('Detection unlinked from resident.');
        await loadAll();
        if (galleryResidentId) await loadResidentDetections(galleryResidentId);
    };

    const handleProfileRefresh = async (selectProfileId) => {
        await loadAll();
        if (selectProfileId) {
            setSelectedProfileId(selectProfileId);
            await loadSightings(selectProfileId);
        } else {
            setSelectedProfileId(null);
            setSightings([]);
        }
    };

    const handleAssignFromEventFace = async (eventFaceId) => {
        const { data } = await supabase
            .from('event_faces')
            .select(EVENT_FACE_SELECT)
            .eq('id', eventFaceId)
            .single();
        if (data) setAssignTarget(data);
    };

    const actionLabel = (action) => {
        if (action.action === 'assign_resident') {
            const name = residentNameById.get(action.to_resident_id) || 'resident';
            return `Assigned → ${name}`;
        }
        if (action.action === 'revert_assign') return 'Reverted assign';
        if (action.action === 'unlink_from_resident') {
            const name = residentNameById.get(action.to_resident_id) || 'resident';
            return `Unlinked from ${name}`;
        }
        if (action.action === 'merge_profiles') return 'Merged visitor profiles';
        if (action.action === 'rename_profile') return 'Renamed visitor';
        if (action.action === 'move_sighting') return 'Moved / ungrouped photo';
        if (action.action === 'dismiss_profile') return 'Dismissed visitor profile';
        return action.action;
    };

    const actionSnapshotPath = (action) =>
        action.metadata?.snapshot_path
        || action.event_faces?.camera_events?.snapshot_path;

    if (loading) {
        return (
            <div className="loading-container">
                <div className="spinner" />
                <div className="loading-text">Loading identity data</div>
            </div>
        );
    }

    return (
        <div>
            {toast && (
                <div style={{
                    position: 'fixed', top: 24, right: 24, zIndex: 3000,
                    padding: 'var(--s4) var(--s5)', borderRadius: 'var(--r-lg)',
                    background: toast.type === 'success' ? 'rgba(0,229,160,0.12)' : 'rgba(255,59,92,0.12)',
                    border: `1px solid ${toast.type === 'success' ? 'rgba(0,229,160,0.35)' : 'rgba(255,59,92,0.35)'}`,
                    color: toast.type === 'success' ? 'var(--jade-core)' : 'var(--crimson-core)',
                    fontSize: 'var(--size-sm)', fontWeight: 600, maxWidth: 400,
                    boxShadow: 'var(--shadow-modal)',
                }}>
                    {toast.msg}
                </div>
            )}

            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s6)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1, display: 'flex', alignItems: 'center', gap: 10 }}>
                        <UserSearch size={28} style={{ color: 'var(--violet-core)' }} />
                        Identity Review
                    </h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)', maxWidth: 680, lineHeight: 1.55 }}>
                        Track recurring unknown visitors, correct mis-detections, and link faces to residents.
                        Assign keeps enrollment photos unless you opt in. Live feed on{' '}
                        <Link to="/camera" style={{ color: 'var(--ember-core)' }}>Surveillance</Link>.
                    </p>
                </div>
                <button type="button" className="btn btn-ghost" onClick={handleRefresh} disabled={refreshing}>
                    {refreshing ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><RefreshCw size={16} /> Refresh</>}
                </button>
            </div>

            {!isAdmin && (
                <div className="card" style={{ marginBottom: 'var(--s5)', padding: 'var(--s4)', borderColor: 'rgba(255,176,32,0.25)', background: 'rgba(255,176,32,0.06)' }}>
                    <div style={{ display: 'flex', gap: 'var(--s3)', alignItems: 'flex-start' }}>
                        <AlertTriangle size={18} style={{ color: 'var(--amber-core)', flexShrink: 0 }} />
                        <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', margin: 0, lineHeight: 1.5 }}>
                            View-only mode. Only administrators can assign, revert, or unlink faces.
                        </p>
                    </div>
                </div>
            )}

            {isAdmin && recentActions.length > 0 && (
                <div className="card" style={{ marginBottom: 'var(--s5)', padding: 0, overflow: 'hidden' }}>
                    <div style={{ padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)', display: 'flex', alignItems: 'center', gap: 8 }}>
                        <History size={16} style={{ color: 'var(--cyan-core)' }} />
                        <span style={{ fontWeight: 700, fontSize: 'var(--size-sm)' }}>Recent manual corrections</span>
                    </div>
                    <div style={{ maxHeight: 280, overflowY: 'auto' }}>
                        {recentActions.map(action => {
                            const snap = actionSnapshotPath(action);
                            const url = snap ? getPublicUrl('event-snapshots', snap) : null;
                            const canRevert = action.action === 'assign_resident' && !revertedActionIds.has(action.id);
                            const isReverted = action.action === 'assign_resident' && revertedActionIds.has(action.id);
                            return (
                                <div
                                    key={action.id}
                                    style={{
                                        display: 'flex', alignItems: 'center', gap: 'var(--s3)',
                                        padding: 'var(--s3) var(--s5)', borderBottom: '1px solid var(--border-dim)',
                                        opacity: isReverted ? 0.55 : 1,
                                    }}
                                >
                                    <div style={{ width: 40, height: 40, borderRadius: 'var(--r-md)', overflow: 'hidden', flexShrink: 0, background: 'var(--bg-base)' }}>
                                        {url && <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                                    </div>
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                        <div style={{ fontWeight: 600, fontSize: 'var(--size-sm)' }}>{actionLabel(action)}</div>
                                        <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>
                                            {action.created_at
                                                ? formatDistanceToNow(new Date(action.created_at), { addSuffix: true })
                                                : '—'}
                                            {action.metadata?.enrollment_updated && ' · enrollment photo updated'}
                                            {isReverted && ' · reverted'}
                                        </div>
                                    </div>
                                    {canRevert && (
                                        <button
                                            type="button"
                                            className="btn btn-ghost btn-sm"
                                            disabled={revertSavingId === action.id}
                                            onClick={() => handleRevert(action.id)}
                                            style={{ color: 'var(--amber-core)' }}
                                        >
                                            {revertSavingId === action.id
                                                ? <div className="spinner" style={{ width: 14, height: 14, borderWidth: 2 }} />
                                                : <><Undo2 size={13} /> Revert</>}
                                        </button>
                                    )}
                                    {action.event_face_id && (
                                        <Link to="/camera" className="btn btn-ghost btn-sm" style={{ fontSize: 11 }}>
                                            <Camera size={12} />
                                        </Link>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                </div>
            )}

            {isAdmin && (
                <div className="card" style={{ marginBottom: 'var(--s5)', padding: 'var(--s5)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s4)' }}>
                        <ImageIcon size={16} style={{ color: 'var(--jade-core)' }} />
                        <span style={{ fontWeight: 700, fontSize: 'var(--size-sm)' }}>Resident linked detections</span>
                    </div>
                    <p style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginBottom: 'var(--s4)', lineHeight: 1.5 }}>
                        Enrollment photo is separate from camera detections. Unlink if a snapshot was wrongly assigned to this person.
                    </p>
                    <div className="form-group" style={{ marginBottom: 'var(--s5)', maxWidth: 360 }}>
                        <label className="form-label">Resident</label>
                        <select
                            className="form-input"
                            value={galleryResidentId}
                            onChange={e => setGalleryResidentId(e.target.value)}
                        >
                            <option value="">Select resident…</option>
                            {residents.map(r => (
                                <option key={r.id} value={r.id}>{r.name || r.id}</option>
                            ))}
                        </select>
                    </div>

                    {galleryResident && (
                        <div style={{ display: 'flex', gap: 'var(--s5)', flexWrap: 'wrap', marginBottom: 'var(--s5)' }}>
                            <div>
                                <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                                    Enrollment photo
                                </div>
                                <div style={{
                                    width: 100, height: 100, borderRadius: 'var(--r-lg)', overflow: 'hidden',
                                    border: '2px solid rgba(0,229,160,0.25)', background: 'var(--bg-base)',
                                }}>
                                    {galleryResident.photo_path ? (
                                        <img
                                            src={getPublicUrl('event-snapshots', galleryResident.photo_path)}
                                            alt=""
                                            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                        />
                                    ) : (
                                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--text-muted)', fontSize: 11 }}>
                                            No photo
                                        </div>
                                    )}
                                </div>
                            </div>
                            <div style={{ flex: 1, minWidth: 200 }}>
                                <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--size-lg)' }}>{galleryResident.name}</div>
                                <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 4 }}>
                                    {galleryLoading ? 'Loading…' : `${residentDetections.length} linked detection${residentDetections.length !== 1 ? 's' : ''}`}
                                </div>
                            </div>
                        </div>
                    )}

                    {galleryResidentId && !galleryLoading && residentDetections.length === 0 && (
                        <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)' }}>No detections linked to this resident yet.</p>
                    )}

                    {residentDetections.length > 0 && (
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(110px, 1fr))', gap: 'var(--s3)' }}>
                            {residentDetections.map(face => {
                                const snap = face.camera_events?.snapshot_path;
                                const url = snap ? getPublicUrl('event-snapshots', snap) : null;
                                return (
                                    <div key={face.id} style={{ borderRadius: 'var(--r-md)', overflow: 'hidden', border: '1px solid var(--border-soft)' }}>
                                        <div style={{ aspectRatio: '1', background: '#0a0c10' }}>
                                            {url && <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                                        </div>
                                        <div style={{ padding: 6, display: 'flex', flexDirection: 'column', gap: 4 }}>
                                            <div style={{ fontSize: 9, color: 'var(--text-muted)' }}>
                                                {face.camera_events?.created_at
                                                    ? formatDistanceToNow(new Date(face.camera_events.created_at), { addSuffix: true })
                                                    : '—'}
                                            </div>
                                            <button
                                                type="button"
                                                className="btn btn-ghost btn-sm"
                                                style={{ fontSize: 10, padding: '2px 6px', color: 'var(--crimson-core)' }}
                                                disabled={unlinkSavingId === face.id}
                                                onClick={() => handleUnlink(face.id)}
                                            >
                                                {unlinkSavingId === face.id
                                                    ? <div className="spinner" style={{ width: 12, height: 12, borderWidth: 2 }} />
                                                    : <><Unlink size={11} /> Not this person</>}
                                            </button>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    )}
                </div>
            )}

            {reviewQueue.length > 0 && (
                <div className="card" style={{ marginBottom: 'var(--s5)', padding: 'var(--s5)', borderColor: 'rgba(255,176,32,0.2)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s4)' }}>
                        <AlertTriangle size={16} style={{ color: 'var(--amber-core)' }} />
                        <span style={{ fontWeight: 700, fontSize: 'var(--size-sm)' }}>Review queue</span>
                        <span className="badge badge-warning">{reviewQueue.length}</span>
                        <span style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>Borderline match scores — may be misclassified residents</span>
                    </div>
                    <div style={{ display: 'flex', gap: 'var(--s3)', overflowX: 'auto', paddingBottom: 4 }}>
                        {reviewQueue.map(face => {
                            const snap = face.camera_events?.snapshot_path;
                            const url = snap ? getPublicUrl('event-snapshots', snap) : null;
                            return (
                                <button
                                    key={face.id}
                                    type="button"
                                    onClick={() => isAdmin && setAssignTarget(face)}
                                    style={{
                                        flex: '0 0 120px', border: '1px solid var(--border-soft)', borderRadius: 'var(--r-lg)',
                                        overflow: 'hidden', background: 'var(--bg-raised)', cursor: isAdmin ? 'pointer' : 'default', padding: 0, textAlign: 'left',
                                    }}
                                >
                                    <div style={{ height: 90, background: '#0a0c10' }}>
                                        {url && <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                                    </div>
                                    <div style={{ padding: 'var(--s2)', fontSize: 10, color: 'var(--amber-core)' }}>
                                        score {face.match_score?.toFixed?.(2) ?? '—'}
                                    </div>
                                </button>
                            );
                        })}
                    </div>
                </div>
            )}

            <div style={{ display: 'grid', gridTemplateColumns: 'minmax(280px, 360px) 1fr', gap: 'var(--s5)', alignItems: 'start' }}>
                <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                    <div style={{ padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 'var(--s3)' }}>
                            <div>
                                <div style={{ fontWeight: 700, fontSize: 'var(--size-sm)' }}>Unknown visitors</div>
                                <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                                    {profiles.length} active profile{profiles.length !== 1 ? 's' : ''}
                                    {unclusteredCount > 0 && ` · ${unclusteredCount} ungrouped below`}
                                </div>
                            </div>
                            {isAdmin && (unclusteredCount > 0 || profiles.length === 0) && (
                                <button
                                    type="button"
                                    className="btn btn-ghost btn-sm"
                                    disabled={clusterBackfillSaving || !canClusterViaGateway}
                                    onClick={handleClusterBackfill}
                                    title={canClusterViaGateway ? 'Group recent unknown photos by face similarity' : 'Set VITE_GATEWAY_URL and VITE_DEVICE_ID'}
                                    style={{ fontSize: 10, whiteSpace: 'nowrap', color: 'var(--violet-core)' }}
                                >
                                    {clusterBackfillSaving
                                        ? <div className="spinner" style={{ width: 12, height: 12, borderWidth: 2 }} />
                                        : <><Layers size={12} /> Group photos</>}
                                </button>
                            )}
                        </div>
                        {clusterStatus && (
                            <p style={{
                                marginTop: 'var(--s3)',
                                fontSize: 'var(--size-xxs)',
                                lineHeight: 1.45,
                                color: clusterStatus.type === 'success'
                                    ? 'var(--jade-core)'
                                    : clusterStatus.type === 'loading'
                                        ? 'var(--cyan-core)'
                                        : 'var(--crimson-core)',
                            }}>
                                {clusterStatus.msg}
                            </p>
                        )}
                        {isAdmin && canClusterViaGateway && /localhost|127\.0\.0\.1/.test(import.meta.env.VITE_GATEWAY_URL || '') && (
                            <p style={{ marginTop: 6, fontSize: 10, color: 'var(--amber-core)', lineHeight: 1.4 }}>
                                Gateway URL is localhost — use the Pi IP in .env if the site runs on your laptop.
                            </p>
                        )}
                    </div>
                    <div style={{ maxHeight: 520, overflowY: 'auto' }}>
                        {profiles.length === 0 ? (
                            <div className="empty-state" style={{ padding: 'var(--s8)' }}>
                                <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', lineHeight: 1.55 }}>
                                    No clustered profiles yet. Detections below are ungrouped until the gateway clusters them
                                    (new uploads automatically, or use <strong>Group photos</strong>).
                                </p>
                            </div>
                        ) : profiles.map(p => {
                            const thumb = p.representative_snapshot_path
                                ? getPublicUrl('event-snapshots', p.representative_snapshot_path)
                                : null;
                            const active = p.id === selectedProfileId;
                            return (
                                <button
                                    key={p.id}
                                    type="button"
                                    onClick={() => setSelectedProfileId(p.id)}
                                    style={{
                                        display: 'flex', alignItems: 'center', gap: 'var(--s3)', width: '100%',
                                        padding: 'var(--s3) var(--s4)', border: 'none', borderBottom: '1px solid var(--border-dim)',
                                        background: active ? 'rgba(155,89,255,0.08)' : 'transparent',
                                        cursor: 'pointer', textAlign: 'left',
                                    }}
                                >
                                    <div style={{
                                        width: 48, height: 48, borderRadius: 'var(--r-md)', overflow: 'hidden', flexShrink: 0,
                                        background: 'var(--bg-base)', border: `1px solid ${active ? 'var(--violet-core)' : 'var(--border-soft)'}`,
                                    }}>
                                        {thumb ? <img src={thumb} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : <UserSearch size={20} style={{ margin: 14, color: 'var(--text-muted)' }} />}
                                    </div>
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                        <div style={{ fontWeight: 700, fontSize: 'var(--size-sm)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{getProfileDisplayName(p, profileLabelMap)}</div>
                                        <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', marginTop: 2 }}>
                                            <Hash size={10} style={{ display: 'inline', verticalAlign: -1 }} /> {p.sighting_count} sighting{p.sighting_count !== 1 ? 's' : ''}
                                        </div>
                                    </div>
                                    <ChevronRight size={14} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                                </button>
                            );
                        })}
                    </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s5)' }}>
                    {selectedProfile ? (
                        <UnknownProfilePanel
                            profile={selectedProfile}
                            labelMap={profileLabelMap}
                            otherProfiles={profiles}
                            sightings={sightings}
                            residents={residents}
                            isAdmin={isAdmin}
                            onRefresh={handleProfileRefresh}
                            onAssignSighting={isAdmin ? handleAssignFromEventFace : null}
                            showToast={showToast}
                        />
                    ) : (
                        <div className="card empty-state" style={{ padding: 'var(--s10)' }}>
                            <UserSearch size={40} style={{ color: 'var(--text-muted)', marginBottom: 'var(--s4)' }} />
                            <h3>Select an unknown profile</h3>
                            <p>View sighting history and patterns for recurring visitors.</p>
                        </div>
                    )}

                    <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                        <div style={{ padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <span style={{ fontWeight: 700, fontSize: 'var(--size-sm)' }}>Recent unknown detections</span>
                            <Link to="/camera" className="btn btn-ghost btn-sm" style={{ fontSize: 11 }}><Camera size={12} /> Surveillance</Link>
                        </div>
                        <div style={{ maxHeight: 360, overflowY: 'auto' }}>
                            {recentUnknowns.length === 0 ? (
                                <p style={{ padding: 'var(--s6)', fontSize: 'var(--size-sm)', color: 'var(--text-muted)', textAlign: 'center' }}>No recent unknown faces.</p>
                            ) : recentUnknowns.map(face => {
                                const ev = { event_faces: [face] };
                                const snap = face.camera_events?.snapshot_path;
                                const url = snap ? getPublicUrl('event-snapshots', snap) : null;
                                return (
                                    <div
                                        key={face.id}
                                        style={{
                                            display: 'flex', alignItems: 'center', gap: 'var(--s3)',
                                            padding: 'var(--s3) var(--s5)', borderBottom: '1px solid var(--border-dim)',
                                        }}
                                    >
                                        <div style={{ width: 44, height: 44, borderRadius: 'var(--r-md)', overflow: 'hidden', flexShrink: 0, background: 'var(--bg-base)' }}>
                                            {url && <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                                        </div>
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                            <div style={{ fontWeight: 600, fontSize: 'var(--size-sm)', color: face.unknown_profile_id ? 'var(--violet-core)' : 'var(--text-secondary)' }}>
                                                {getDetectionTitle(ev, profileLabelMap)}
                                            </div>
                                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>
                                                {getDetectionSubtitle(ev) && <span style={{ marginRight: 6 }}>{getDetectionSubtitle(ev)}</span>}
                                                {face.camera_events?.created_at
                                                    ? formatDistanceToNow(new Date(face.camera_events.created_at), { addSuffix: true })
                                                    : '—'}
                                            </div>
                                        </div>
                                        {isAdmin && (
                                            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setAssignTarget(face)} style={{ color: 'var(--violet-core)' }}>
                                                <Users size={13} /> Assign
                                            </button>
                                        )}
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </div>
            </div>

            {assignTarget && isAdmin && (
                <div className="modal-overlay" onClick={() => setAssignTarget(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
                        <div className="modal-header">
                            <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                <UserPlus size={18} style={{ color: 'var(--violet-core)' }} />
                                Assign to resident
                            </h2>
                            <button type="button" className="modal-close" onClick={() => setAssignTarget(null)}><X size={20} /></button>
                        </div>
                        <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginBottom: 'var(--s4)', lineHeight: 1.55 }}>
                            Links this detection to the resident. The snapshot stays in storage as audit evidence.
                            Enrollment photo on Residents is <strong>not</strong> changed unless you opt in below.
                        </p>
                        {assignError && <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{assignError}</div>}
                        <form onSubmit={handleAssign} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                            <div className="form-group" style={{ marginBottom: 0 }}>
                                <label className="form-label">Resident</label>
                                <select className="form-input" value={assignResidentId} onChange={e => setAssignResidentId(e.target.value)} required>
                                    <option value="">Select resident…</option>
                                    {residents.map(r => (
                                        <option key={r.id} value={r.id}>{r.name || r.id}</option>
                                    ))}
                                </select>
                            </div>
                            <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, cursor: 'pointer', fontSize: 'var(--size-sm)', color: 'var(--text-secondary)' }}>
                                <input
                                    type="checkbox"
                                    checked={assignUseEnrollment}
                                    onChange={e => setAssignUseEnrollment(e.target.checked)}
                                    style={{ marginTop: 3 }}
                                />
                                <span>
                                    Also replace enrollment photo with this snapshot
                                    <span style={{ display: 'block', fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 4 }}>
                                        Rare — only if this crop is better than the photo on Residents.
                                    </span>
                                </span>
                            </label>
                            <div style={{ display: 'flex', gap: 'var(--s3)', justifyContent: 'flex-end' }}>
                                <button type="button" className="btn btn-ghost" onClick={() => setAssignTarget(null)}>Cancel</button>
                                <button type="submit" className="btn btn-primary" disabled={assignSaving || !assignResidentId}>
                                    {assignSaving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><CheckCircle size={15} /> Confirm</>}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};

export default IdentityPage;
