import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
    UserSearch, Users, RefreshCw, ChevronRight, AlertTriangle,
    CheckCircle, X, UserPlus, Camera, Clock, Hash,
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { supabase, getPublicUrl } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';
import { getDetectionDisplayName } from '../utils/faceDisplay';

const EVENT_FACE_SELECT = `
  id, classification, match_score, resident_id, unknown_profile_id, camera_event_id,
  camera_events(id, snapshot_path, created_at, event_id),
  residents(name)
`;

const IdentityPage = () => {
    const { isAdmin } = useAuth();
    const [profiles, setProfiles] = useState([]);
    const [recentUnknowns, setRecentUnknowns] = useState([]);
    const [residents, setResidents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [selectedProfileId, setSelectedProfileId] = useState(null);
    const [sightings, setSightings] = useState([]);
    const [assignTarget, setAssignTarget] = useState(null);
    const [assignResidentId, setAssignResidentId] = useState('');
    const [assignSaving, setAssignSaving] = useState(false);
    const [assignError, setAssignError] = useState(null);
    const [toast, setToast] = useState(null);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 4000);
    };

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
    }, []);

    useEffect(() => {
        (async () => {
            setLoading(true);
            await loadAll();
            setLoading(false);
        })();
    }, [loadAll]);

    const handleRefresh = async () => {
        setRefreshing(true);
        await loadAll();
        if (selectedProfileId) await loadSightings(selectedProfileId);
        setRefreshing(false);
    };

    const loadSightings = async (profileId) => {
        const { data } = await supabase
            .from('unknown_face_sightings')
            .select(`
              id, match_distance, created_at,
              camera_events(id, snapshot_path, created_at),
              event_faces(id, classification, match_score)
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

    const reviewQueue = useMemo(() => {
        return recentUnknowns.filter(f => {
            const score = f.match_score;
            return score != null && score > 0.45 && score < 0.65;
        });
    }, [recentUnknowns]);

    const handleAssign = async (e) => {
        e.preventDefault();
        if (!assignTarget?.id || !assignResidentId) return;
        setAssignSaving(true);
        setAssignError(null);

        const { data, error } = await supabase.rpc('assign_event_face_to_resident', {
            p_event_face_id: assignTarget.id,
            p_resident_id: assignResidentId,
            p_use_snapshot_for_enrollment: true,
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

        const gatewayUrl = import.meta.env.VITE_GATEWAY_URL;
        if (gatewayUrl) {
            try {
                const deviceId = import.meta.env.VITE_DEVICE_ID;
                if (deviceId) {
                    await fetch(
                        `${gatewayUrl.replace(/\/$/, '')}/api/v1/residents/backfill-embeddings?device_id=${deviceId}`,
                        { method: 'POST' },
                    );
                }
            } catch {
                /* optional */
            }
        }

        setAssignTarget(null);
        setAssignResidentId('');
        showToast('Face assigned to resident. Embedding will refresh on the gateway.');
        await loadAll();
        if (selectedProfileId) await loadSightings(selectedProfileId);
    };

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
                    fontSize: 'var(--size-sm)', fontWeight: 600, maxWidth: 360,
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
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)', maxWidth: 640, lineHeight: 1.55 }}>
                        Track recurring unknown visitors, correct mis-detections, and link faces to residents.
                        Live camera feed stays on <Link to="/camera" style={{ color: 'var(--ember-core)' }}>Surveillance</Link>.
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
                            View-only mode. Only administrators can assign faces to residents.
                        </p>
                    </div>
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
                {/* Unknown profiles */}
                <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                    <div style={{ padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)' }}>
                        <div style={{ fontWeight: 700, fontSize: 'var(--size-sm)' }}>Unknown visitors</div>
                        <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>{profiles.length} active profile{profiles.length !== 1 ? 's' : ''}</div>
                    </div>
                    <div style={{ maxHeight: 520, overflowY: 'auto' }}>
                        {profiles.length === 0 ? (
                            <div className="empty-state" style={{ padding: 'var(--s8)' }}>
                                <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)' }}>No clustered unknown profiles yet.</p>
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
                                        <div style={{ fontWeight: 700, fontSize: 'var(--size-sm)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.display_label}</div>
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

                {/* Detail + recent */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s5)' }}>
                    {selectedProfile ? (
                        <div className="card" style={{ padding: 'var(--s5)' }}>
                            <div style={{ display: 'flex', gap: 'var(--s5)', flexWrap: 'wrap' }}>
                                <div style={{
                                    width: 140, height: 140, borderRadius: 'var(--r-xl)', overflow: 'hidden',
                                    border: '2px solid rgba(155,89,255,0.3)', flexShrink: 0,
                                }}>
                                    {selectedProfile.representative_snapshot_path && (
                                        <img
                                            src={getPublicUrl('event-snapshots', selectedProfile.representative_snapshot_path)}
                                            alt=""
                                            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                        />
                                    )}
                                </div>
                                <div>
                                    <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-xl)', fontWeight: 700, marginBottom: 'var(--s2)' }}>{selectedProfile.display_label}</h2>
                                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--s3)', fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Clock size={12} /> Last seen {selectedProfile.last_seen_at ? formatDistanceToNow(new Date(selectedProfile.last_seen_at), { addSuffix: true }) : '—'}</span>
                                        <span>{selectedProfile.sighting_count} total sightings</span>
                                    </div>
                                </div>
                            </div>
                            <h3 style={{ fontSize: 'var(--size-sm)', fontWeight: 700, marginTop: 'var(--s5)', marginBottom: 'var(--s3)' }}>Sighting timeline</h3>
                            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(100px, 1fr))', gap: 'var(--s3)' }}>
                                {sightings.map(s => {
                                    const path = s.camera_events?.snapshot_path;
                                    const url = path ? getPublicUrl('event-snapshots', path) : null;
                                    return (
                                        <div key={s.id} style={{ borderRadius: 'var(--r-md)', overflow: 'hidden', border: '1px solid var(--border-soft)' }}>
                                            <div style={{ aspectRatio: '1', background: '#0a0c10' }}>
                                                {url && <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                                            </div>
                                            <div style={{ padding: 6, fontSize: 9, color: 'var(--text-muted)' }}>
                                                {s.created_at ? formatDistanceToNow(new Date(s.created_at), { addSuffix: true }) : '—'}
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
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
                                            <div style={{ fontWeight: 600, fontSize: 'var(--size-sm)', color: 'var(--crimson-core)' }}>{getDetectionDisplayName(ev)}</div>
                                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>
                                                {face.camera_events?.created_at
                                                    ? formatDistanceToNow(new Date(face.camera_events.created_at), { addSuffix: true })
                                                    : '—'}
                                                {face.match_score != null && ` · score ${Number(face.match_score).toFixed(2)}`}
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
                        <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginBottom: 'var(--s5)', lineHeight: 1.55 }}>
                            This detection will be marked as the selected resident. The snapshot can be used to refresh their enrollment photo and embedding on the gateway.
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
