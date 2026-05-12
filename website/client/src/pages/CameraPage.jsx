import { useEffect, useRef, useState, useCallback } from 'react';
import { Camera, Radio, Shield, ShieldOff, CheckCircle, XCircle, User, Loader } from 'lucide-react';
import { useRealtime } from '../context/RealtimeContext';
import { supabase, getPublicUrl } from '../services/supabase';
import { formatDistanceToNow } from 'date-fns';
import DetectionHoverPreview from '../components/Surveillance/DetectionHoverPreview';
import LiveCameraFeed from '../components/Surveillance/LiveCameraFeed';

const HOVER_DELAY_MS = 250;

const CameraPage = () => {
    const { subscribe } = useRealtime();
    const [events, setEvents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [feedMode, setFeedMode] = useState('snapshot');

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

    const refetchEvent = useCallback(async (eventId) => {
        try {
            const { data } = await supabase
                .from('camera_events')
                .select('*, events(*), event_faces(*, residents(name, label))')
                .eq('id', eventId)
                .single();
            if (data) {
                setEvents(prev => prev.map(ev => ev.id === eventId ? data : ev));
            }
        } catch (err) { console.error('Refetch event failed:', err); }
    }, []);

    useEffect(() => {
        const unsub = subscribe('camera_event', (row) => {
            const hasfaces = row.event_faces && row.event_faces.length > 0;
            const newEvent = { ...row, _scanning: !hasfaces };
            setEvents(prev => [newEvent, ...prev].slice(0, 20));
            if (!hasfaces && row.id) {
                setTimeout(() => refetchEvent(row.id), 1500);
            }
        });
        return unsub;
    }, [subscribe, refetchEvent]);

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
                        <FeedModeSwitch value={feedMode} onChange={setFeedMode} />
                    </div>
                    <div style={{ position: 'relative', width: '100%', aspectRatio: '16 / 9', background: 'var(--bg-base)', overflow: 'hidden' }}>
                        {feedMode === 'live' ? (
                            <LiveCameraFeed />
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
                                const isScanning = ev._scanning && !face;
                                const isKnown = face?.classification === 'resident';
                                const personName = isScanning
                                    ? 'Scanning...'
                                    : face?.residents?.name || (isKnown ? 'Authorized Person' : 'Unknown Person');
                                const rowColor = isScanning
                                    ? 'var(--amber-core, #f59e0b)'
                                    : isKnown ? 'var(--jade-core)' : 'var(--crimson-core)';
                                const rowBg = isScanning
                                    ? 'rgba(245,158,11,0.1)'
                                    : isKnown ? 'rgba(0,229,160,0.1)' : 'rgba(255,59,92,0.1)';
                                return (
                                    <div
                                        key={ev.id || i}
                                        className="detection-row"
                                        onMouseEnter={(e) => handleRowEnter(e, ev)}
                                        onMouseLeave={handleRowLeave}
                                        style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: 'var(--s3) var(--s5)', borderBottom: '1px solid var(--border-dim)', cursor: 'pointer' }}
                                    >
                                        <div style={{ width: 36, height: 36, borderRadius: 'var(--r-md)', background: rowBg, display: 'flex', alignItems: 'center', justifyContent: 'center', color: rowColor, flexShrink: 0 }}>
                                            {isScanning ? <Loader size={16} className="spin-icon" /> : isKnown ? <Shield size={16} /> : <ShieldOff size={16} />}
                                        </div>
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                            <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: rowColor, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                {personName}
                                            </div>
                                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>
                                                {ev.created_at ? formatDistanceToNow(new Date(ev.created_at), { addSuffix: true }) : 'Just now'}
                                            </div>
                                        </div>
                                        {isScanning ? <Loader size={14} className="spin-icon" style={{ color: rowColor, flexShrink: 0 }} /> : isKnown ? <CheckCircle size={14} style={{ color: 'var(--jade-core)', flexShrink: 0 }} /> : <XCircle size={14} style={{ color: 'var(--crimson-core)', flexShrink: 0 }} />}
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
                .spin-icon { animation: spin 1.2s linear infinite; }
                @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
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
