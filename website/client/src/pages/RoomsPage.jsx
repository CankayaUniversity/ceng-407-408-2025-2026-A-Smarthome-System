import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import {
    Thermometer, Droplets, Flame, Waves, Eye, Activity,
    Weight, Sprout, DoorOpen, Lightbulb, Wind, Volume2,
    X, BarChart3, ShieldAlert, CheckCircle2, Sofa,
    UtensilsCrossed, BedDouble, Lock, ShowerHead, Flower2
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

/* ─── Room colors + positions (percent-based) ─────────────────── */
const ROOMS = [
    { id: 'living', label: 'Living Room', Icon: Sofa, color: '#7c6fff', left: 2, top: 2, w: 36, h: 45 },
    { id: 'kitchen', label: 'Kitchen', Icon: UtensilsCrossed, color: '#ff6b35', left: 40, top: 2, w: 28, h: 45 },
    { id: 'garden', label: 'Garden', Icon: Flower2, color: '#52b788', left: 70, top: 2, w: 28, h: 45 },
    { id: 'bedroom', label: 'Master Bedroom', Icon: BedDouble, color: '#00d4ff', left: 2, top: 51, w: 36, h: 46 },
    { id: 'entrance', label: 'Entrance', Icon: Lock, color: '#00e5a0', left: 40, top: 51, w: 17, h: 46 },
    { id: 'bathroom', label: 'Bathroom', Icon: ShowerHead, color: '#3b9eff', left: 59, top: 51, w: 39, h: 46 },
];

/* ─── Sensor config ────────────────────────────────────────────── */
const SIC = {
    temperature: { Icon: Thermometer, color: '#ff6b35' },
    humidity: { Icon: Droplets, color: '#00d4ff' },
    smoke: { Icon: Flame, color: '#ff3b5c' },
    water: { Icon: Waves, color: '#3b9eff' },
    motion: { Icon: Eye, color: '#9b59ff' },
    weight: { Icon: Weight, color: '#00e5a0' },
    moisture: { Icon: Sprout, color: '#52b788' },
    light: { Icon: Lightbulb, color: '#ffb020' },
    door: { Icon: DoorOpen, color: '#00d4ff' },
    co2: { Icon: Wind, color: '#a0f080' },
    noise: { Icon: Volume2, color: '#ff9f40' },
};
function getSIC(type) { return SIC[type?.toLowerCase()] || { Icon: Activity, color: '#8892a4' }; }

function deviceToRoom(deviceName) {
    const n = (deviceName || '').toLowerCase();
    if (n.includes('kitchen')) return 'kitchen';
    if (n.includes('bedroom')) return 'bedroom';
    if (n.includes('door') || n.includes('front') || n.includes('entrance')) return 'entrance';
    if (n.includes('bath')) return 'bathroom';
    if (n.includes('garden')) return 'garden';
    return 'living';
}

function pinGrid(count) {
    const pad = 15;
    const cols = count <= 2 ? count : Math.ceil(Math.sqrt(count));
    const rows = Math.ceil(count / cols);
    return Array.from({ length: count }, (_, i) => ({
        x: pad + ((i % cols) / Math.max(cols - 1, 1)) * (100 - pad * 2),
        y: pad + (Math.floor(i / cols) / Math.max(rows - 1, 1)) * (60 - pad * 2) + 15,
    }));
}

/* ─── Sensor Pin ──────────────────────────────────────────────── */
function SensorPin({ sensor, pos, onClick, isSelected }) {
    const sic = getSIC(sensor.type);
    const Icon = sic.Icon;
    const valStr = String(sensor.value || '');
    const isAlert = (sensor.type === 'smoke' && parseFloat(valStr) > 30) || (sensor.type === 'water' && parseFloat(valStr) > 0);
    const isActive = (sensor.type === 'motion' || sensor.type === 'door') && parseFloat(valStr) === 1;

    let bg = 'rgba(15, 17, 23, 0.85)';
    let borderColor = `${sic.color}55`;
    let iconColor = sic.color;
    let shadow = '0 4px 12px rgba(0,0,0,0.5)';

    if (isAlert) {
        borderColor = '#ff3b5c'; iconColor = '#ff3b5c'; shadow = '0 0 15px rgba(255,59,92,0.6)';
    } else if (isActive) {
        borderColor = sic.color; bg = `${sic.color}15`; shadow = `0 0 12px ${sic.color}55`;
    }

    return (
        <div
            onClick={(e) => { e.stopPropagation(); onClick(sensor); }}
            title={`${sensor.label}: ${sensor.value}${sensor.unit || ''}`}
            style={{
                position: 'absolute', left: `${pos.x}%`, top: `${pos.y}%`,
                transform: `translate(-50%, -50%) scale(${isSelected ? 1.3 : 1})`,
                zIndex: isSelected ? 20 : 10, cursor: 'pointer',
                transition: 'all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1)',
            }}
        >
            <div style={{
                width: 32, height: 32, borderRadius: '50%', background: bg, border: `1.5px solid ${borderColor}`,
                backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: shadow,
            }}>
                <Icon size={14} style={{ color: iconColor }} />
            </div>
            {isAlert && <div style={{ position: 'absolute', inset: -4, borderRadius: '50%', border: '1px solid #ff3b5c', animation: 'statusPulse 1s infinite' }} />}
        </div>
    );
}

/* ─── Modern Room Drawer ──────────────────────────────────────── */
function RoomDrawer({ room, sensors, onClose }) {
    const navigate = useNavigate();
    const { Icon, label, color } = room;
    
    // Aggregate some stats for the drawer header
    const activeSensors = sensors.filter(s => ['motion', 'door'].includes(s.type) && parseFloat(s.value) === 1).length;
    const temp = sensors.find(s => s.type === 'temperature')?.value;
    const hum = sensors.find(s => s.type === 'humidity')?.value;

    return (
        <div style={{ position: 'fixed', inset: 0, zIndex: 200, display: 'flex', justifyContent: 'flex-end', pointerEvents: 'none' }}>
            {/* Backdrop */}
            <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(4px)', pointerEvents: 'auto', animation: 'fadeIn 0.2s ease-out' }} />
            
            {/* Drawer Panel */}
            <div style={{
                width: 420, maxWidth: '100vw', background: 'rgba(15,18,25,0.95)', borderLeft: '1px solid rgba(255,255,255,0.05)',
                display: 'flex', flexDirection: 'column', pointerEvents: 'auto',
                boxShadow: '-20px 0 80px rgba(0,0,0,0.6)', backdropFilter: 'blur(20px)',
                animation: 'slideLeft 0.3s cubic-bezier(0.2, 0.8, 0.2, 1) both',
            }}>
                {/* Header */}
                <div style={{ padding: 'var(--s6)', background: `linear-gradient(to bottom right, ${color}20, transparent)`, borderBottom: '1px solid rgba(255,255,255,0.05)', position: 'relative' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--s5)' }}>
                        <div style={{ width: 60, height: 60, borderRadius: 'var(--r-2xl)', background: `${color}15`, border: `1px solid ${color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', color, boxShadow: `0 0 30px ${color}15` }}>
                            <Icon size={28} />
                        </div>
                        <button onClick={onClose} style={{ background: 'rgba(255,255,255,0.05)', border: 'none', borderRadius: '50%', width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', cursor: 'pointer', transition: 'background 0.2s' }} onMouseEnter={e => e.currentTarget.style.background='rgba(255,255,255,0.1)'} onMouseLeave={e => e.currentTarget.style.background='rgba(255,255,255,0.05)'}>
                            <X size={16} />
                        </button>
                    </div>
                    <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 800, marginBottom: 4, letterSpacing: '-0.02em' }}>{label}</h2>
                    <div style={{ display: 'flex', gap: 'var(--s4)', fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                        <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}><Activity size={12}/> {sensors.length} sensors</span>
                        {activeSensors > 0 && <span style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#ffb020' }}><ShieldAlert size={12}/> {activeSensors} active</span>}
                        {temp && <span>{parseFloat(temp).toFixed(1)}°C</span>}
                        {hum && <span>{parseFloat(hum).toFixed(0)}% Hum</span>}
                    </div>
                </div>

                {/* List */}
                <div style={{ flex: 1, overflowY: 'auto', padding: 'var(--s4)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 var(--s2) var(--s3)', borderBottom: '1px solid rgba(255,255,255,0.05)', marginBottom: 'var(--s3)' }}>
                        <span style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-muted)', letterSpacing: '0.05em' }}>Live Telemetry</span>
                        <button className="btn btn-ghost btn-sm" onClick={() => navigate('/history')} style={{ fontSize: 11, padding: '4px 8px' }}>
                            <BarChart3 size={12}/> Analytics
                        </button>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s2)' }}>
                        {sensors.map(s => {
                            const sic = getSIC(s.type);
                            const SIcon = sic.Icon;
                            const isBoolean = s.type === 'motion' || s.type === 'door' || s.type === 'water';
                            const display = s.value === null ? '—' : isBoolean ? (parseFloat(s.value) === 1 ? 'Active' : 'Clear') : parseFloat(s.value).toFixed(1);
                            const active = isBoolean && parseFloat(s.value) === 1;

                            return (
                                <div key={s.id} style={{
                                    display: 'flex', alignItems: 'center', gap: 'var(--s4)',
                                    padding: 'var(--s3) var(--s4)', borderRadius: 'var(--r-md)',
                                    background: active ? `${sic.color}08` : 'transparent',
                                    border: `1px solid ${active ? sic.color+'20' : 'transparent'}`,
                                    transition: 'background 0.2s'
                                }}>
                                    <div style={{ width: 40, height: 40, borderRadius: 'var(--r-md)', background: `${sic.color}15`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: sic.color, flexShrink: 0 }}>
                                        <SIcon size={18} />
                                    </div>
                                    <div style={{ flex: 1 }}>
                                        <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600 }}>{s.label}</div>
                                        <div style={{ fontSize: 10, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginTop: 2 }}>
                                            {s.lastUpdated ? formatDistanceToNow(new Date(s.lastUpdated), {addSuffix:true}) : 'Live'}
                                        </div>
                                    </div>
                                    <div style={{ textAlign: 'right' }}>
                                        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 'var(--size-xl)', color: active ? sic.color : 'var(--text-primary)', lineHeight: 1 }}>{display}</div>
                                        {s.unit && <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 2 }}>{s.unit}</div>}
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>
            </div>
            <style>{`
                @keyframes slideLeft { from { transform: translateX(100%); } to { transform: translateX(0); } }
                @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
            `}</style>
        </div>
    );
}

/* ─── Main Page ───────────────────────────────────────────────── */
const RoomsPage = () => {
    const [sensors, setSensors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [openRoom, setOpenRoom] = useState(null);

    useEffect(() => {
        const fetch = async () => {
            try {
                const res = await api.get('/sensors/latest');
                const raw = Array.isArray(res.data) ? res.data : (res.data.sensors || []);
                setSensors(raw.map(s => ({ ...s, id: s.sensorId || s.id })));
            } catch (err) { console.error(err); }
            finally { setLoading(false); }
        };
        fetch();
        const t = setInterval(fetch, 10000); // 10s auto refresh for live-feel
        return () => clearInterval(t);
    }, []);

    const byRoom = {};
    for (const s of sensors) {
        const rId = deviceToRoom(s.deviceName);
        if (!byRoom[rId]) byRoom[rId] = [];
        byRoom[rId].push(s);
    }

    const drawerRoom = ROOMS.find(r => r.id === openRoom);
    const drawerSensors = openRoom ? (byRoom[openRoom] || []) : [];

    if (loading) return (
        <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading Blueprint</div></div>
    );

    return (
        <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s6)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Floor Plan</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>Interactive home blueprint · Live sensor telemetry</p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--text-primary)', background: 'var(--bg-surface)', border: '1px solid var(--border-soft)', borderRadius: 'var(--r-full)', padding: '6px 14px', fontWeight: 600 }}>
                    <CheckCircle2 size={14} style={{ color: 'var(--jade-core)' }} />
                    {Object.keys(byRoom).length} Zones Active
                </div>
            </div>

            {/* Premium Interactive Blueprint */}
            <div style={{
                position: 'relative', width: '100%', paddingBottom: '55%', minHeight: 400,
                background: '#0a0c10', // deep dark blueprint base
                backgroundImage: 'radial-gradient(rgba(255,255,255,0.08) 1px, transparent 1px)',
                backgroundSize: '24px 24px',
                borderRadius: 'var(--r-2xl)', border: '1px solid rgba(255,255,255,0.05)',
                overflow: 'hidden', boxShadow: 'inset 0 0 100px rgba(0,0,0,0.8), 0 20px 40px rgba(0,0,0,0.2)'
            }}>
                {/* Blueprint grid lines (accents) */}
                <div style={{ position: 'absolute', inset: 0, backgroundImage: 'linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px)', backgroundSize: '96px 96px', pointerEvents: 'none' }} />
                
                {/* Outer House Bounds */}
                <div style={{ position: 'absolute', inset: '2%', border: '2px solid rgba(255,255,255,0.1)', borderRadius: 12, pointerEvents: 'none' }} />

                {ROOMS.map(room => {
                    const roomSensors = byRoom[room.id] || [];
                    const hasAlert = roomSensors.some(s => (s.type === 'smoke' && parseFloat(s.value) > 30) || (s.type === 'water' && parseFloat(s.value) > 0));
                    const hasActive = roomSensors.some(s => ['motion', 'door'].includes(s.type) && parseFloat(s.value) === 1);
                    const positions = pinGrid(Math.min(roomSensors.length, 6));
                    const { Icon } = room;

                    let roomBg = `${room.color}08`;
                    let roomBorder = `rgba(255,255,255,0.1)`;
                    let glow = 'none';

                    if (hasAlert) {
                        roomBg = `rgba(255,59,92,0.1)`; roomBorder = '#ff3b5c'; glow = 'inset 0 0 40px rgba(255,59,92,0.2)';
                    } else if (hasActive) {
                        roomBg = `${room.color}15`; roomBorder = `${room.color}80`; glow = `inset 0 0 30px ${room.color}20`;
                    }

                    return (
                        <div
                            key={room.id}
                            style={{
                                position: 'absolute', left: `${room.left}%`, top: `${room.top}%`, width: `${room.w}%`, height: `${room.h}%`,
                                background: roomBg, border: `1px solid ${roomBorder}`, borderRadius: 8,
                                backdropFilter: 'blur(4px)', boxShadow: glow,
                                cursor: 'pointer', transition: 'all 0.3s cubic-bezier(0.2, 0.8, 0.2, 1)',
                            }}
                            onMouseEnter={e => {
                                e.currentTarget.style.background = `${room.color}20`;
                                e.currentTarget.style.borderColor = room.color;
                                e.currentTarget.style.boxShadow = `inset 0 0 40px ${room.color}30, 0 8px 32px rgba(0,0,0,0.4)`;
                            }}
                            onMouseLeave={e => {
                                e.currentTarget.style.background = roomBg;
                                e.currentTarget.style.borderColor = roomBorder;
                                e.currentTarget.style.boxShadow = glow;
                            }}
                            onClick={() => setOpenRoom(room.id)}
                        >
                            {/* Room Header Overlay */}
                            <div style={{ position: 'absolute', top: 12, left: 16, display: 'flex', alignItems: 'center', gap: 8, pointerEvents: 'none' }}>
                                <Icon size={16} style={{ color: room.color, filter: `drop-shadow(0 0 8px ${room.color})` }} />
                                <span style={{ fontFamily: 'var(--font-display)', fontSize: 13, fontWeight: 700, letterSpacing: '0.05em', color: 'rgba(255,255,255,0.9)', textShadow: '0 2px 4px rgba(0,0,0,0.5)' }}>
                                    {room.label.toUpperCase()}
                                </span>
                            </div>

                            {/* Alert Indicator */}
                            {hasAlert && (
                                <div style={{ position: 'absolute', top: 14, right: 14, width: 10, height: 10, borderRadius: '50%', background: '#ff3b5c', boxShadow: '0 0 12px #ff3b5c', animation: 'statusPulse 1s infinite' }} />
                            )}

                            {/* Sensor Count */}
                            <div style={{ position: 'absolute', bottom: 12, right: 16, fontSize: 10, color: 'rgba(255,255,255,0.5)', fontWeight: 600, letterSpacing: '0.05em', textTransform: 'uppercase' }}>
                                {roomSensors.length} Nodes
                            </div>

                            {/* Pins inside room */}
                            {roomSensors.slice(0, 6).map((sensor, i) => (
                                <SensorPin key={sensor.id} sensor={sensor} pos={positions[i]} onClick={() => setOpenRoom(room.id)} />
                            ))}
                        </div>
                    );
                })}
            </div>

            {openRoom && drawerRoom && (
                <RoomDrawer room={drawerRoom} sensors={drawerSensors} onClose={() => setOpenRoom(null)} />
            )}
        </div>
    );
};

export default RoomsPage;
