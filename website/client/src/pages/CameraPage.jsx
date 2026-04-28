import { useEffect, useRef, useState } from 'react';
import { Camera, Radio, Shield, ShieldOff, CheckCircle, XCircle, User, WifiOff } from 'lucide-react';
import { useRealtime } from '../context/RealtimeContext';
import { supabase, getPublicUrl } from '../services/supabase';
import { formatDistanceToNow } from 'date-fns';
import DetectionHoverPreview from '../components/Surveillance/DetectionHoverPreview';

const HOVER_DELAY_MS = 250;
const STREAM_URL = import.meta.env.VITE_CAMERA_STREAM_URL || '';

const CameraPage = () => {
    const { subscribe } = useRealtime();
    const [events, setEvents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [feedMode, setFeedMode] = useState('snapshot');
    const [streamError, setStreamError] = useState(false);

    const [hoverState, setHoverState] = useState(null); // { event, rect, url }
    const hoverTimerRef = useRef(null);

    useEffect(() => {
        const fetchEvents = async () => {
            try {
                const { data } = await supabase
                    .from('camera_events')
                    .select('*, events(*), event_faces(*, residents(name, label))')
                    .order('created_at', { ascending: false })
                    .limit(20);
                setEvents(data || []);
            } catch (err) { console.error(err); }
            finally { setLoading(false); }
        };
        fetchEvents();
    }, []);

    useEffect(() => {
        const unsub = subscribe('camera_event', (row) => {
            setEvents(prev => [row, ...prev].slice(0, 20));
        });
        return unsub;
    }, [subscribe]);

    useEffect(() => () => {
        if (hoverTimerRef.current) clearTimeout(hoverTimerRef.current);
    }, []);

    const latestSnapshotUrl = events[0]?.snapshot_path
        ? getPublicUrl('event-snapshots', events[0].snapshot_path) : null;

    const handleRowEnter = (e, ev) => {
        const rect = e.currentTarget.getBoundingClientRect();
        if (hoverTimerRef.current) clearTimeout(hoverTimerRef.current);
        hoverTimerRef.current = setTimeout(() => {
            setHoverState({
                event: ev,
                rect,
                url: ev.snapshot_path ? getPublicUrl('event-snapshots', ev.snapshot_path) : null,
            });
        }, HOVER_DELAY_MS);
    };
    const handleRowLeave = () => {
        if (hoverTimerRef.current) {
            clearTimeout(hoverTimerRef.current);
            hoverTimerRef.current = null;
        }
        setHoverState(null);
    };

    return (
        <div>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Surveillance</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>AI face recognition · Event log</p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', background: events.length > 0 ? 'rgba(0,229,160,0.08)' : 'rgba(255,59,92,0.08)', border: `1px solid ${events.length > 0 ? 'rgba(0,229,160,0.18)' : 'rgba(255,59,92,0.18)'}`, borderRadius: 'var(--r-full)', padding: '7px 16px', fontSize: 'var(--size-xs)', color: events.length > 0 ? 'var(--jade-core)' : 'var(--crimson-core)', fontWeight: 700, letterSpacing: '0.08em' }}>
                    {events.length > 0 ? `${events.length} EVENTS` : 'NO EVENTS'}
                </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 'var(--s6)', alignItems: 'stretch' }}>
                <div className="card" style={{ padding: 0, overflow: 'hidden', position: 'relative', display: 'flex', flexDirection: 'column' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: 'var(--s3) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', fontSize: 'var(--size-xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                            <Camera size={14} /> {feedMode === 'live' ? 'Live Camera' : 'Latest Snapshot'}
                        </div>
                        <FeedModeSwitch value={feedMode} onChange={(m) => { setFeedMode(m); setStreamError(false); }} />
                    </div>
                    <div style={{ position: 'relative', width: '100%', aspectRatio: '16 / 9', background: 'var(--bg-base)', overflow: 'hidden' }}>
                        {feedMode === 'live' ? (
                            STREAM_URL && !streamError ? (
                                <>
                                    <img
                                        src={STREAM_URL}
                                        alt="Live camera feed"
                                        onError={() => setStreamError(true)}
                                        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                                    />
                                    <div style={{ position: 'absolute', top: 'var(--s3)', left: 'var(--s3)', display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', background: 'rgba(0,0,0,0.55)', border: '1px solid rgba(255,59,92,0.5)', borderRadius: 'var(--r-full)', backdropFilter: 'blur(6px)', color: '#ff3b5c', fontSize: 10, fontWeight: 700, letterSpacing: '0.06em' }}>
                                        <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#ff3b5c', boxShadow: '0 0 8px #ff3b5c', animation: 'alertBreath 2s infinite' }} />
                                        LIVE
                                    </div>
                                </>
                            ) : (
                                <FeedEmptyState
                                    icon={<WifiOff size={28} />}
                                    title={STREAM_URL ? 'Live feed unavailable' : 'No live stream configured'}
                                    desc={STREAM_URL
                                        ? 'The configured stream URL did not respond. Check the camera and network.'
                                        : 'Set VITE_CAMERA_STREAM_URL in the client .env to enable the live view.'}
                                />
                            )
                        ) : latestSnapshotUrl ? (
                            <img
                                src={latestSnapshotUrl}
                                alt="Latest capture"
                                style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                            />
                        ) : (
                            <FeedEmptyState
                                icon={<Camera size={28} />}
                                title="No Snapshots Yet"
                                desc="Snapshots will appear when motion is detected."
                            />
                        )}
                    </div>
                </div>

                <div className="card" style={{ padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', height: '100%', maxHeight: '100%', minHeight: 0 }}>
                    <div style={{ padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)', fontSize: 'var(--size-xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', flexShrink: 0 }}>
                        Recent Detections
                    </div>
                    <div style={{ flex: '1 1 0', minHeight: 0, overflowY: 'auto' }}>
                        {loading ? (
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: 200 }}><div className="spinner" /></div>
                        ) : events.length === 0 ? (
                            <div className="empty-state" style={{ padding: 'var(--s10) var(--s4)' }}>
                                <div className="empty-state-icon"><User size={36} /></div>
                                <h3>No events yet</h3>
                                <p>Face recognition events will appear here in real time.</p>
                            </div>
                        ) : (
                            events.map((ev, i) => {
                                const face = ev.event_faces?.[0];
                                const isKnown = face?.classification === 'resident';
                                const personName = face?.residents?.name || (isKnown ? 'Authorized Person' : 'Unknown Person');
                                return (
                                    <div
                                        key={ev.id || i}
                                        className="detection-row"
                                        onMouseEnter={(e) => handleRowEnter(e, ev)}
                                        onMouseLeave={handleRowLeave}
                                        style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: 'var(--s3) var(--s5)', borderBottom: '1px solid var(--border-dim)', cursor: 'pointer' }}
                                    >
                                        <div style={{ width: 36, height: 36, borderRadius: 'var(--r-md)', background: isKnown ? 'rgba(0,229,160,0.1)' : 'rgba(255,59,92,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: isKnown ? 'var(--jade-core)' : 'var(--crimson-core)', flexShrink: 0 }}>
                                            {isKnown ? <Shield size={16} /> : <ShieldOff size={16} />}
                                        </div>
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                            <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: isKnown ? 'var(--jade-core)' : 'var(--crimson-core)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                {isKnown ? personName : 'Unknown Person'}
                                            </div>
                                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>
                                                {ev.created_at ? formatDistanceToNow(new Date(ev.created_at), { addSuffix: true }) : 'Just now'}
                                            </div>
                                        </div>
                                        {isKnown ? <CheckCircle size={14} style={{ color: 'var(--jade-core)', flexShrink: 0 }} /> : <XCircle size={14} style={{ color: 'var(--crimson-core)', flexShrink: 0 }} />}
                                    </div>
                                );
                            })
                        )}
                    </div>
                </div>
            </div>

            {hoverState && (
                <DetectionHoverPreview
                    event={hoverState.event}
                    anchorRect={hoverState.rect}
                    snapshotUrl={hoverState.url}
                />
            )}

            <style>{`
                .detection-row { transition: background var(--t-fast) var(--ease-out); }
                .detection-row:hover { background: var(--border-dim); }
            `}</style>
        </div>
    );
};

const FeedModeSwitch = ({ value, onChange }) => {
    const isLive = value === 'live';
    return (
        <div
            role="tablist"
            aria-label="Feed source"
            style={{
                display: 'inline-flex',
                background: 'var(--bg-base)',
                border: '1px solid var(--border-soft)',
                borderRadius: 'var(--r-full)',
                overflow: 'hidden',
            }}
        >
            <FeedModeButton active={isLive} onClick={() => onChange('live')} icon={<Radio size={11} />} label="Live" />
            <span style={{ width: 1, alignSelf: 'stretch', background: 'var(--border-soft)' }} aria-hidden />
            <FeedModeButton active={!isLive} onClick={() => onChange('snapshot')} icon={<Camera size={11} />} label="Snapshot" />
        </div>
    );
};

const FeedModeButton = ({ active, onClick, icon, label }) => (
    <button
        type="button"
        role="tab"
        aria-selected={active}
        onClick={onClick}
        style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            padding: '6px 14px',
            border: 'none',
            background: active ? 'var(--ember-core)' : 'transparent',
            color: active ? 'white' : 'var(--text-muted)',
            fontSize: 11,
            fontWeight: 700,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            cursor: 'pointer',
            transition: 'background var(--t-fast) var(--ease-out), color var(--t-fast) var(--ease-out)',
        }}
    >
        {icon}
        {label}
    </button>
);

const FeedEmptyState = ({ icon, title, desc }) => (
    <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        textAlign: 'center', padding: 'var(--s6)', gap: 'var(--s3)',
    }}>
        <div style={{
            width: 64, height: 64,
            background: 'rgba(255,59,92,0.08)',
            border: '1px solid rgba(255,59,92,0.2)',
            borderRadius: 'var(--r-xl)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'var(--crimson-core)',
        }}>
            {icon}
        </div>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-lg)', fontWeight: 700, color: 'var(--text-secondary)' }}>{title}</div>
        <div style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', maxWidth: 320 }}>{desc}</div>
    </div>
);

export default CameraPage;
