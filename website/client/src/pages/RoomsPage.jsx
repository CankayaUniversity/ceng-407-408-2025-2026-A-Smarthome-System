import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../services/supabase';
import {
    Thermometer, Droplets, Flame, Waves, Eye, Activity,
    X, BarChart3, ShieldAlert, CheckCircle2, Sofa,
    UtensilsCrossed, BedDouble, Lock, ShowerHead, Flower2
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const ROOMS = [
    { id: 'living', label: 'Living Room', Icon: Sofa, color: '#7c6fff', left: 2, top: 2, w: 36, h: 45 },
    { id: 'kitchen', label: 'Kitchen', Icon: UtensilsCrossed, color: '#ff6b35', left: 40, top: 2, w: 28, h: 45 },
    { id: 'garden', label: 'Garden', Icon: Flower2, color: '#52b788', left: 70, top: 2, w: 28, h: 45 },
    { id: 'bedroom', label: 'Master Bedroom', Icon: BedDouble, color: '#00d4ff', left: 2, top: 51, w: 36, h: 46 },
    { id: 'entrance', label: 'Entrance', Icon: Lock, color: '#00e5a0', left: 40, top: 51, w: 17, h: 46 },
    { id: 'bathroom', label: 'Bathroom', Icon: ShowerHead, color: '#3b9eff', left: 59, top: 51, w: 39, h: 46 },
];

const SIC = {
    temperature: { Icon: Thermometer, color: '#ff6b35' },
    humidity: { Icon: Droplets, color: '#00d4ff' },
    smoke: { Icon: Flame, color: '#ff3b5c' },
    water: { Icon: Waves, color: '#3b9eff' },
    motion: { Icon: Eye, color: '#9b59ff' },
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

function SensorPin({ sensor, pos, onClick }) {
    const sic = getSIC(sensor.sensor_type);
    const Icon = sic.Icon;
    const isAlert = (sensor.sensor_type === 'smoke' && sensor.numeric_value > 0);
    return (
        <div onClick={(e) => { e.stopPropagation(); onClick(); }}
            title={`${sensor.sensor_type}: ${sensor.numeric_value}`}
            style={{ position: 'absolute', left: `${pos.x}%`, top: `${pos.y}%`, transform: 'translate(-50%, -50%)', zIndex: 10, cursor: 'pointer' }}>
            <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(15, 17, 23, 0.85)', border: `1.5px solid ${isAlert ? '#ff3b5c' : sic.color + '55'}`, backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: isAlert ? '0 0 15px rgba(255,59,92,0.6)' : '0 4px 12px rgba(0,0,0,0.5)' }}>
                <Icon size={14} style={{ color: isAlert ? '#ff3b5c' : sic.color }} />
            </div>
        </div>
    );
}

function RoomDrawer({ room, sensors, onClose }) {
    const navigate = useNavigate();
    const { Icon, label, color } = room;
    const temp = sensors.find(s => s.sensor_type === 'temperature')?.numeric_value;
    const hum = sensors.find(s => s.sensor_type === 'humidity')?.numeric_value;

    return (
        <div style={{ position: 'fixed', inset: 0, zIndex: 200, display: 'flex', justifyContent: 'flex-end', pointerEvents: 'none' }}>
            <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(4px)', pointerEvents: 'auto', animation: 'fadeIn 0.2s ease-out' }} />
            <div style={{ width: 420, maxWidth: '100vw', background: 'rgba(15,18,25,0.95)', borderLeft: '1px solid rgba(255,255,255,0.05)', display: 'flex', flexDirection: 'column', pointerEvents: 'auto', boxShadow: '-20px 0 80px rgba(0,0,0,0.6)', backdropFilter: 'blur(20px)', animation: 'slideLeft 0.3s cubic-bezier(0.2, 0.8, 0.2, 1) both' }}>
                <div style={{ padding: 'var(--s6)', background: `linear-gradient(to bottom right, ${color}20, transparent)`, borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--s5)' }}>
                        <div style={{ width: 60, height: 60, borderRadius: 'var(--r-2xl)', background: `${color}15`, border: `1px solid ${color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
                            <Icon size={28} />
                        </div>
                        <button onClick={onClose} style={{ background: 'rgba(255,255,255,0.05)', border: 'none', borderRadius: '50%', width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', cursor: 'pointer' }}>
                            <X size={16} />
                        </button>
                    </div>
                    <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 800, marginBottom: 4 }}>{label}</h2>
                    <div style={{ display: 'flex', gap: 'var(--s4)', fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                        <span>{sensors.length} sensors</span>
                        {temp != null && <span>{parseFloat(temp).toFixed(1)}°C</span>}
                        {hum != null && <span>{parseFloat(hum).toFixed(0)}% Hum</span>}
                    </div>
                </div>
                <div style={{ flex: 1, overflowY: 'auto', padding: 'var(--s4)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 var(--s2) var(--s3)', borderBottom: '1px solid rgba(255,255,255,0.05)', marginBottom: 'var(--s3)' }}>
                        <span style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-muted)' }}>Live Telemetry</span>
                        <button className="btn btn-ghost btn-sm" onClick={() => navigate('/history')} style={{ fontSize: 11, padding: '4px 8px' }}><BarChart3 size={12} /> Analytics</button>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s2)' }}>
                        {sensors.map(s => {
                            const sic = getSIC(s.sensor_type);
                            const SIcon = sic.Icon;
                            const isBoolean = s.sensor_type === 'motion' || s.sensor_type === 'door';
                            const display = s.numeric_value === null ? '\u2014' : isBoolean ? (s.numeric_value === 1 ? 'Active' : 'Clear') : parseFloat(s.numeric_value).toFixed(1);
                            return (
                                <div key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)', padding: 'var(--s3) var(--s4)', borderRadius: 'var(--r-md)' }}>
                                    <div style={{ width: 40, height: 40, borderRadius: 'var(--r-md)', background: `${sic.color}15`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: sic.color, flexShrink: 0 }}>
                                        <SIcon size={18} />
                                    </div>
                                    <div style={{ flex: 1 }}>
                                        <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600, textTransform: 'capitalize' }}>{s.sensor_type}</div>
                                        <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>
                                            {s.recorded_at ? formatDistanceToNow(new Date(s.recorded_at), { addSuffix: true }) : 'Live'}
                                        </div>
                                    </div>
                                    <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 'var(--size-xl)', color: 'var(--text-primary)' }}>{display}</div>
                                </div>
                            );
                        })}
                    </div>
                </div>
            </div>
            <style>{`@keyframes slideLeft { from { transform: translateX(100%); } to { transform: translateX(0); } } @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }`}</style>
        </div>
    );
}

const RoomsPage = () => {
    const [sensors, setSensors] = useState([]);
    const [loading, setLoading] = useState(true);
    const [openRoom, setOpenRoom] = useState(null);

    useEffect(() => {
        const fetchSensors = async () => {
            const { data } = await supabase
                .from('sensor_readings')
                .select('*')
                .order('recorded_at', { ascending: false })
                .limit(100);
            const latestByType = {};
            (data || []).forEach(r => {
                const key = `${r.device_id}_${r.sensor_type}`;
                if (!latestByType[key]) latestByType[key] = r;
            });
            setSensors(Object.values(latestByType));
            setLoading(false);
        };
        fetchSensors();
        const t = setInterval(fetchSensors, 10000);
        return () => clearInterval(t);
    }, []);

    const byRoom = {};
    for (const s of sensors) {
        const rId = deviceToRoom('');
        if (!byRoom[rId]) byRoom[rId] = [];
        byRoom[rId].push(s);
    }

    const drawerRoom = ROOMS.find(r => r.id === openRoom);
    const drawerSensors = openRoom ? (byRoom[openRoom] || []) : [];

    if (loading) return <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading Blueprint</div></div>;

    return (
        <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
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

            <div style={{ position: 'relative', width: '100%', paddingBottom: '55%', minHeight: 400, background: '#0a0c10', backgroundImage: 'radial-gradient(rgba(255,255,255,0.08) 1px, transparent 1px)', backgroundSize: '24px 24px', borderRadius: 'var(--r-2xl)', border: '1px solid rgba(255,255,255,0.05)', overflow: 'hidden' }}>
                <div style={{ position: 'absolute', inset: '2%', border: '2px solid rgba(255,255,255,0.1)', borderRadius: 12, pointerEvents: 'none' }} />
                {ROOMS.map(room => {
                    const roomSensors = byRoom[room.id] || [];
                    const positions = pinGrid(Math.min(roomSensors.length, 6));
                    const { Icon } = room;
                    return (
                        <div key={room.id}
                            style={{ position: 'absolute', left: `${room.left}%`, top: `${room.top}%`, width: `${room.w}%`, height: `${room.h}%`, background: `${room.color}08`, border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, cursor: 'pointer', transition: 'all 0.3s' }}
                            onMouseEnter={e => { e.currentTarget.style.background = `${room.color}20`; e.currentTarget.style.borderColor = room.color; }}
                            onMouseLeave={e => { e.currentTarget.style.background = `${room.color}08`; e.currentTarget.style.borderColor = 'rgba(255,255,255,0.1)'; }}
                            onClick={() => setOpenRoom(room.id)}>
                            <div style={{ position: 'absolute', top: 12, left: 16, display: 'flex', alignItems: 'center', gap: 8, pointerEvents: 'none' }}>
                                <Icon size={16} style={{ color: room.color }} />
                                <span style={{ fontFamily: 'var(--font-display)', fontSize: 13, fontWeight: 700, letterSpacing: '0.05em', color: 'rgba(255,255,255,0.9)' }}>{room.label.toUpperCase()}</span>
                            </div>
                            <div style={{ position: 'absolute', bottom: 12, right: 16, fontSize: 10, color: 'rgba(255,255,255,0.5)', fontWeight: 600 }}>{roomSensors.length} Nodes</div>
                            {roomSensors.slice(0, 6).map((sensor, i) => (
                                <SensorPin key={sensor.id} sensor={sensor} pos={positions[i]} onClick={() => setOpenRoom(room.id)} />
                            ))}
                        </div>
                    );
                })}
            </div>

            {openRoom && drawerRoom && <RoomDrawer room={drawerRoom} sensors={drawerSensors} onClose={() => setOpenRoom(null)} />}
        </div>
    );
};

export default RoomsPage;
