import { useState, useEffect } from 'react';
import { Camera, Clock, Shield, ShieldOff, CheckCircle, XCircle, User } from 'lucide-react';
import { useRealtime } from '../context/RealtimeContext';
import { supabase, getPublicUrl } from '../services/supabase';
import { formatDistanceToNow } from 'date-fns';

const CameraPage = () => {
    const { subscribe } = useRealtime();
    const [events, setEvents] = useState([]);
    const [loading, setLoading] = useState(true);

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

    const latestSnapshotUrl = events[0]?.snapshot_path
        ? getPublicUrl('event-snapshots', events[0].snapshot_path) : null;
    if (events[0]?.snapshot_path && !latestSnapshotUrl) {
        console.warn('[Camera] snapshot_path exists but public URL is null:', events[0].snapshot_path);
    }

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

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 'var(--s6)' }}>
                <div className="card" style={{ padding: 0, overflow: 'hidden', position: 'relative', minHeight: 380 }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', fontSize: 'var(--size-xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                            <Camera size={14} /> Latest Snapshot
                        </div>
                    </div>
                    <div style={{ position: 'relative', background: 'var(--bg-raised)', height: 380, display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
                        {latestSnapshotUrl ? (
                            <img src={latestSnapshotUrl} alt="Latest capture" style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
                        ) : (
                            <div style={{ textAlign: 'center', position: 'relative', zIndex: 2 }}>
                                <div style={{ width: 64, height: 64, background: 'rgba(255,59,92,0.08)', border: '1px solid rgba(255,59,92,0.2)', borderRadius: 'var(--r-xl)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto var(--s4)', color: 'var(--crimson-core)' }}>
                                    <Camera size={28} />
                                </div>
                                <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-lg)', fontWeight: 700, color: 'var(--text-secondary)' }}>No Snapshots Yet</div>
                                <div style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>Snapshots will appear when motion is detected</div>
                            </div>
                        )}
                    </div>
                </div>

                <div className="card" style={{ padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
                    <div style={{ padding: 'var(--s4) var(--s5)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)', fontSize: 'var(--size-xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                        Recent Detections
                    </div>
                    <div style={{ flex: 1, overflowY: 'auto' }}>
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
                                    <div key={ev.id || i} style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: 'var(--s3) var(--s5)', borderBottom: '1px solid var(--border-dim)', transition: 'background var(--t-fast)' }}
                                        onMouseEnter={e => e.currentTarget.style.background = 'var(--border-dim)'}
                                        onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                                        <div style={{ width: 36, height: 36, borderRadius: 'var(--r-md)', background: isKnown ? 'rgba(0,229,160,0.1)' : 'rgba(255,59,92,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: isKnown ? 'var(--jade-core)' : 'var(--crimson-core)', flexShrink: 0 }}>
                                            {isKnown ? <Shield size={16} /> : <ShieldOff size={16} />}
                                        </div>
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                            <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: isKnown ? 'var(--jade-core)' : 'var(--crimson-core)' }}>
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
        </div>
    );
};

export default CameraPage;
