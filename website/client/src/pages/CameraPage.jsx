import { useState, useEffect } from 'react';
import { Camera, Maximize2, Clock, User, Shield, ShieldOff, CheckCircle, XCircle } from 'lucide-react';
import { useSocket } from '../context/SocketContext';
import api from '../services/api';
import { formatDistanceToNow } from 'date-fns';

const CameraPage = () => {
    const { socket } = useSocket();
    const [events, setEvents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [streamAlive, setStreamAlive] = useState(false);

    const STREAM_URL = 'http://localhost:8090/stream.mjpg';

    useEffect(() => {
        const fetchEvents = async () => {
            try {
                const res = await api.get('/camera/events?limit=20');
                setEvents(res.data.events || []);
            } catch (err) { console.error(err); }
            finally { setLoading(false); }
        };
        fetchEvents();
    }, []);

    useEffect(() => {
        if (!socket) return;
        // Backend emits 'camera:event' (see socketHandler.js → emitCameraEvent)
        socket.on('camera:event', (event) => {
            setEvents(prev => [event, ...prev].slice(0, 20));
        });
        return () => socket.off('camera:event');
    }, [socket]);

    return (
        <div>
            {/* Header */}
            <div style={{
                display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between',
                marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)'
            }}>
                <div>
                    <h1 style={{
                        fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)',
                        fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1
                    }}>Surveillance</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>
                        Live feed · AI face recognition · Event log
                    </p>
                </div>
                <div style={{
                    display: 'flex', alignItems: 'center', gap: 'var(--s2)',
                    background: 'rgba(255,59,92,0.08)', border: '1px solid rgba(255,59,92,0.18)',
                    borderRadius: 'var(--r-full)', padding: '7px 16px',
                    fontSize: 'var(--size-xs)', color: 'var(--crimson-core)', fontWeight: 700, letterSpacing: '0.08em'
                }}>
                    ● CAMERA OFFLINE
                </div>
            </div>

            {/* Main grid */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 'var(--s6)' }}>
                {/* Live Feed */}
                <div className="card" style={{ padding: 0, overflow: 'hidden', position: 'relative', minHeight: 380 }}>
                    {/* Feed header */}
                    <div style={{
                        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                        padding: 'var(--s4) var(--s5)',
                        borderBottom: '1px solid var(--border-dim)',
                        background: 'var(--bg-raised)'
                    }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', fontSize: 'var(--size-xs)', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                            <Camera size={14} />
                            Live Feed
                        </div>
                        <button className="btn-ghost btn btn-sm" style={{ gap: 4 }}>
                            <Maximize2 size={13} />
                        </button>
                    </div>

                    {/* Stream or placeholder */}
                    <div style={{ position: 'relative', background: 'var(--bg-raised)', minHeight: 340, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        {/* Scanline overlay */}
                        <div style={{
                            position: 'absolute', inset: 0,
                            backgroundImage: 'repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.08) 2px, rgba(0,0,0,0.08) 4px)',
                            pointerEvents: 'none', zIndex: 1
                        }} />

                        {/* Camera offline state */}
                        <div style={{ textAlign: 'center', position: 'relative', zIndex: 2 }}>
                            <div style={{
                                width: 64, height: 64,
                                background: 'rgba(255,59,92,0.08)',
                                border: '1px solid rgba(255,59,92,0.2)',
                                borderRadius: 'var(--r-xl)',
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                margin: '0 auto var(--s4)',
                                color: 'var(--crimson-core)'
                            }}>
                                <Camera size={28} />
                            </div>
                            <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-lg)', fontWeight: 700, color: 'var(--text-secondary)' }}>No Stream Available</div>
                            <div style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>
                                Connect your Raspberry Pi camera module to begin streaming
                            </div>
                        </div>

                        {/* Corner brackets */}
                        {['top-left', 'top-right', 'bottom-left', 'bottom-right'].map(pos => {
                            const [v, h] = pos.split('-');
                            return (
                                <div key={pos} style={{
                                    position: 'absolute',
                                    [v]: 16, [h]: 16,
                                    width: 20, height: 20,
                                    borderTop: v === 'top' ? '2px solid var(--ember-core)' : 'none',
                                    borderBottom: v === 'bottom' ? '2px solid var(--ember-core)' : 'none',
                                    borderLeft: h === 'left' ? '2px solid var(--ember-core)' : 'none',
                                    borderRight: h === 'right' ? '2px solid var(--ember-core)' : 'none',
                                    opacity: 0.5
                                }} />
                            );
                        })}
                    </div>
                </div>

                {/* Recent Detections */}
                <div className="card" style={{ padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
                    <div style={{
                        padding: 'var(--s4) var(--s5)',
                        borderBottom: '1px solid var(--border-dim)',
                        background: 'var(--bg-raised)',
                        fontSize: 'var(--size-xs)', fontWeight: 700, letterSpacing: '0.08em',
                        textTransform: 'uppercase', color: 'var(--text-muted)'
                    }}>
                        Recent Detections
                    </div>

                    <div style={{ flex: 1, overflowY: 'auto' }}>
                        {loading ? (
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: 200 }}>
                                <div className="spinner" />
                            </div>
                        ) : events.length === 0 ? (
                            <div className="empty-state" style={{ padding: 'var(--s10) var(--s4)' }}>
                                <div className="empty-state-icon"><User size={36} /></div>
                                <h3>No events yet</h3>
                                <p>Face recognition events will appear here in real time.</p>
                            </div>
                        ) : (
                            events.map((ev, i) => {
                                const isKnown = ev.result === 'authorized';
                                const personName = ev.faceProfile?.name || (isKnown ? 'Authorized Person' : 'Unknown Person');
                                return (
                                    <div
                                        key={ev.id || i}
                                        style={{
                                            display: 'flex', alignItems: 'center', gap: 'var(--s3)',
                                            padding: 'var(--s3) var(--s5)',
                                            borderBottom: '1px solid var(--border-dim)',
                                            transition: 'background var(--t-fast)',
                                        }}
                                        onMouseEnter={e => e.currentTarget.style.background = 'var(--border-dim)'}
                                        onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                                    >
                                        <div style={{
                                            width: 36, height: 36, borderRadius: 'var(--r-md)',
                                            background: isKnown ? 'rgba(0,229,160,0.1)' : 'rgba(255,59,92,0.1)',
                                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                                            color: isKnown ? 'var(--jade-core)' : 'var(--crimson-core)',
                                            flexShrink: 0
                                        }}>
                                            {isKnown ? <Shield size={16} /> : <ShieldOff size={16} />}
                                        </div>
                                        <div style={{ flex: 1, minWidth: 0 }}>
                                            <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: isKnown ? 'var(--jade-core)' : 'var(--crimson-core)' }}>
                                                {isKnown ? (personName) : 'Unknown Person'}
                                            </div>
                                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>
                                                {ev.createdAt ? formatDistanceToNow(new Date(ev.createdAt), { addSuffix: true }) : 'Just now'}
                                            </div>
                                        </div>
                                        {isKnown
                                            ? <CheckCircle size={14} style={{ color: 'var(--jade-core)', flexShrink: 0 }} />
                                            : <XCircle size={14} style={{ color: 'var(--crimson-core)', flexShrink: 0 }} />
                                        }
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
