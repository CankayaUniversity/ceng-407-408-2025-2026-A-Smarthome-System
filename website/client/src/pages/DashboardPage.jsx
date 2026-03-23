import { useState, useEffect, useCallback } from 'react';
import { useSocket } from '../context/SocketContext';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import {
    Thermometer, Droplets, Flame, Waves, Activity,
    Eye, AlertTriangle, ShieldCheck, ShieldAlert,
    Camera, Wifi, CheckCircle2, Wind,
    DoorOpen, Sofa, UtensilsCrossed, BedDouble, Lock, ShowerHead, Flower2
} from 'lucide-react';

/* ── Sensor type config ─────────────────────────────────────── */
const SENSOR_CONFIG = {
    temperature: { icon: Thermometer, color: '#ff6b35', label: 'Temperature', unit: '°C' },
    humidity: { icon: Droplets, color: '#00d4ff', label: 'Humidity', unit: '%' },
    smoke: { icon: Flame, color: '#ff3b5c', label: 'Smoke', unit: 'ppm' },
    water: { icon: Waves, color: '#3b9eff', label: 'Water', unit: '' },
    motion: { icon: Eye, color: '#9b59ff', label: 'Motion', unit: '' },
    door: { icon: DoorOpen, color: '#00e5a0', label: 'Door', unit: '' },
    co2: { icon: Wind, color: '#a0f080', label: 'CO₂', unit: 'ppm' },
};
function getSC(type) { return SENSOR_CONFIG[type?.toLowerCase()] || { icon: Activity, color: '#8892a4', label: type, unit: '' }; }

const ROOM_TABS = [
    { id: 'all', label: 'All', icon: Activity },
    { id: 'living', label: 'Living', icon: Sofa, keys: ['living', 'Main RPi'] },
    { id: 'kitchen', label: 'Kitchen', icon: UtensilsCrossed, keys: ['Kitchen'] },
    { id: 'bedroom', label: 'Bedroom', icon: BedDouble, keys: ['Bedroom'] },
    { id: 'entrance', label: 'Entrance', icon: Lock, keys: ['Door', 'Front', 'Entrance'] },
    { id: 'bathroom', label: 'Bathroom', icon: ShowerHead, keys: ['Bathroom'] },
    { id: 'garden', label: 'Garden', icon: Flower2, keys: ['Garden'] },
];

function matchesRoom(sensor, tabId) {
    if (tabId === 'all') return true;
    const tab = ROOM_TABS.find(t => t.id === tabId);
    if (!tab?.keys) return false;
    const name = (sensor.deviceName || '').toLowerCase();
    return tab.keys.some(k => name.toLowerCase().includes(k.toLowerCase()));
}

/* ── Mini Sensor Card for Grid ───────────────────────────────── */
function MiniSensorCard({ sensor }) {
    const cfg = getSC(sensor.type);
    const Icon = cfg.icon;
    const val = sensor.value;
    const isBoolean = sensor.type === 'motion' || sensor.type === 'door' || sensor.type === 'water';
    const displayVal = val === null || val === undefined ? '—'
        : isBoolean ? (parseFloat(val) === 1 ? 'Active' : 'Clear')
            : parseFloat(val).toFixed(1);
    const isAlert = (sensor.type === 'smoke' && parseFloat(val) > 30)
        || (sensor.type === 'water' && parseFloat(val) > 0);

    return (
        <div style={{
            background: 'var(--bg-surface)', border: `1px solid ${isAlert ? '#ff3b5c55' : 'var(--border-soft)'}`,
            borderRadius: 'var(--r-lg)', padding: 'var(--s3)', display: 'flex', flexDirection: 'column',
            gap: 'var(--s2)', position: 'relative', overflow: 'hidden',
            boxShadow: isAlert ? '0 0 16px rgba(255,59,92,0.1)' : 'none'
        }}>
            {isAlert && <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 2, background: '#ff3b5c' }} />}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div style={{
                    width: 28, height: 28, borderRadius: 'var(--r-md)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    background: `${cfg.color}15`, color: isAlert ? '#ff3b5c' : cfg.color
                }}>
                    <Icon size={14} />
                </div>
                <div style={{ textAlign: 'right' }}>
                    <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 'var(--size-lg)', color: isAlert ? '#ff3b5c' : cfg.color, lineHeight: 1 }}>
                        {displayVal}
                    </div>
                    {cfg.unit && <div style={{ fontSize: 9, color: 'var(--text-muted)' }}>{cfg.unit}</div>}
                </div>
            </div>
            <div style={{ marginTop: 'auto' }}>
                <div style={{ fontSize: 'var(--size-xs)', fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{sensor.label}</div>
                <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{sensor.deviceName}</div>
            </div>
        </div>
    );
}

/* ── Main Dashboard ──────────────────────────────────────────── */
const DashboardPage = () => {
    const navigate = useNavigate();
    const { socket } = useSocket();
    const [sensors, setSensors] = useState([]);
    const [alerts, setAlerts] = useState([]);
    const [lastCameraEvent, setLastCameraEvent] = useState(null);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('all');

    const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001';

    const fetchData = useCallback(async () => {
        try {
            const [sRes, aRes, cRes] = await Promise.all([
                api.get('/sensors/latest'),
                api.get('/alerts?status=active&limit=3'),
                api.get('/camera/events?limit=1')
            ]);
            const raw = Array.isArray(sRes.data) ? sRes.data : (sRes.data.sensors || []);
            setSensors(raw.map(s => ({ ...s, id: s.sensorId || s.id })));
            
            setAlerts(Array.isArray(aRes.data) ? aRes.data : (aRes.data.alerts || []));
            
            const evts = Array.isArray(cRes.data) ? cRes.data : (cRes.data.events || []);
            if (evts.length > 0) setLastCameraEvent(evts[0]);
        } catch (err) { console.error(err); }
        finally { setLoading(false); }
    }, []);

    useEffect(() => { fetchData(); }, [fetchData]);

    useEffect(() => {
        if (!socket) return;
        const onUpdate = (data) => {
            setSensors(prev => prev.map(s => s.id === data.sensorId ? { ...s, value: data.value, lastUpdated: data.timestamp } : s));
        };
        const onAlert = (a) => setAlerts(prev => [a, ...prev].slice(0, 3));
        const onCamera = (ev) => setLastCameraEvent(ev);
        
        socket.on('sensor:update', onUpdate);
        socket.on('alert:new', onAlert);
        socket.on('camera:event', onCamera);
        return () => { socket.off('sensor:update', onUpdate); socket.off('alert:new', onAlert); socket.off('camera:event', onCamera); };
    }, [socket]);

    // Derived stats
    const avgTemp = sensors.filter(s => s.type === 'temperature').reduce((acc, s) => acc + parseFloat(s.value||0), 0) / (sensors.filter(s => s.type === 'temperature').length || 1);
    const avgHum = sensors.filter(s => s.type === 'humidity').reduce((acc, s) => acc + parseFloat(s.value||0), 0) / (sensors.filter(s => s.type === 'humidity').length || 1);
    const activeMotions = sensors.filter(s => s.type === 'motion' && parseFloat(s.value) === 1).length;
    const openDoors = sensors.filter(s => s.type === 'door' && parseFloat(s.value) === 1).length;
    
    const securityStatus = (alerts.some(a => a.severity === 'critical') || activeMotions > 2 || lastCameraEvent?.result === 'unauthorized') ? 'warning' : 'secure';

    // Filter sensors
    const filtered = sensors.filter(s => matchesRoom(s, activeTab));

    if (loading) return (
        <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading Overview</div></div>
    );

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s6)' }}>
            
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>
                        Dashboard
                    </h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>
                        <Wifi size={12} style={{ color: 'var(--jade-core)', display: 'inline', marginRight: 4 }} />
                        System Online · {sensors.length} sensors active
                    </p>
                </div>
            </div>

            {/* Top Grid: Camera & Overview Cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--s5)' }}>
                
                {/* 1. Camera Widget (Spans larger area) */}
                <div 
                    className="card" 
                    onClick={() => navigate('/camera')}
                    style={{ 
                        gridColumn: '1 / -1', 
                        // On large screens, span 2 columns out of 3, but auto-fit is tricky, so we use minmax. Assume it takes full width for now, but styled beautifully.
                        padding: 0, overflow: 'hidden', position: 'relative', cursor: 'pointer',
                        minHeight: 240, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
                        backgroundImage: lastCameraEvent?.imagePath ? `url(${API_URL}${lastCameraEvent.imagePath})` : 'none',
                        backgroundColor: '#111318', backgroundSize: 'cover', backgroundPosition: 'center',
                    }}
                >
                    {/* Dark gradient overlay for readability */}
                    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0.2) 60%, transparent 100%)' }} />
                    
                    {/* Live indicator pip */}
                    <div style={{ position: 'absolute', top: 'var(--s4)', left: 'var(--s4)', display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(0,0,0,0.5)', padding: '4px 10px', borderRadius: 'var(--r-full)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.1)' }}>
                        <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#ff3b5c', boxShadow: '0 0 8px #ff3b5c', animation: 'alertBreath 2s infinite' }} />
                        <span style={{ fontSize: 10, fontWeight: 700, color: 'white', letterSpacing: '0.05em' }}>LIVE CAMERA</span>
                    </div>

                    <div style={{ position: 'relative', padding: 'var(--s6)', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
                        <div>
                            <h2 style={{ color: 'white', fontSize: 'var(--size-xl)', fontWeight: 700, marginBottom: 'var(--s1)' }}>Front Door Survelliance</h2>
                            <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 'var(--size-sm)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                <Camera size={14} /> AI Face Recognition Active
                            </p>
                        </div>
                        {lastCameraEvent && (
                            <div style={{ background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.1)', padding: 'var(--s3)', borderRadius: 'var(--r-lg)', textAlign: 'center' }}>
                                <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', textTransform: 'uppercase', marginBottom: 4 }}>Last Event</div>
                                <div style={{ color: lastCameraEvent.result === 'authorized' ? '#00e5a0' : '#ff3b5c', fontWeight: 700, fontSize: 'var(--size-sm)' }}>
                                    {lastCameraEvent.result === 'authorized' ? lastCameraEvent.faceProfile?.name : 'Unknown Person'}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                {/* 2. Security Status */}
                <div className="card" style={{ display: 'flex', flexDirection: 'column', background: securityStatus === 'secure' ? 'var(--bg-surface)' : 'rgba(255,59,92,0.05)', borderColor: securityStatus === 'secure' ? 'var(--border-soft)' : 'rgba(255,59,92,0.2)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s4)' }}>
                        {securityStatus === 'secure' ? <ShieldCheck style={{ color: 'var(--jade-core)' }} /> : <ShieldAlert style={{ color: '#ff3b5c' }} />}
                        <h3 style={{ fontSize: 'var(--size-base)', fontWeight: 600 }}>Security</h3>
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--s3)', marginTop: 'auto' }}>
                        <div style={{ background: 'var(--bg-base)', padding: 'var(--s3)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ color: 'var(--text-muted)', fontSize: 11, textTransform: 'uppercase', marginBottom: 2 }}>Motion</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: activeMotions > 0 ? '#9b59ff' : 'var(--text-primary)' }}>{activeMotions} <span style={{fontSize:12, fontWeight:400}}>zones</span></div>
                        </div>
                        <div style={{ background: 'var(--bg-base)', padding: 'var(--s3)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ color: 'var(--text-muted)', fontSize: 11, textTransform: 'uppercase', marginBottom: 2 }}>Doors Open</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: openDoors > 0 ? '#ffb020' : 'var(--text-primary)' }}>{openDoors}</div>
                        </div>
                    </div>
                </div>

                {/* 3. Climate Average */}
                <div className="card" style={{ display: 'flex', flexDirection: 'column' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s4)' }}>
                        <Thermometer style={{ color: '#ff6b35' }} />
                        <h3 style={{ fontSize: 'var(--size-base)', fontWeight: 600 }}>Home Climate</h3>
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--s3)', marginTop: 'auto' }}>
                        <div style={{ background: 'var(--bg-base)', padding: 'var(--s3)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ color: 'var(--text-muted)', fontSize: 11, textTransform: 'uppercase', marginBottom: 2 }}>Avg Temp</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-xl)', color: '#ff6b35' }}>{avgTemp.toFixed(1)}°</div>
                        </div>
                        <div style={{ background: 'var(--bg-base)', padding: 'var(--s3)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ color: 'var(--text-muted)', fontSize: 11, textTransform: 'uppercase', marginBottom: 2 }}>Avg Hum</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-xl)', color: '#00d4ff' }}>{avgHum.toFixed(0)}%</div>
                        </div>
                    </div>
                </div>

            </div>

            {/* Alerts Section (Only show if there are alerts) */}
            {alerts.length > 0 && (
                <div>
                    <h3 style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 'var(--s3)' }}>Recent Alerts</h3>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s2)' }}>
                        {alerts.map(a => (
                            <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: 'var(--s3)', background: a.severity === 'critical' ? 'rgba(255,59,92,0.1)' : 'rgba(255,176,32,0.1)', borderRadius: 'var(--r-md)', border: `1px solid ${a.severity === 'critical' ? 'rgba(255,59,92,0.2)' : 'rgba(255,176,32,0.2)'}` }}>
                                <AlertTriangle size={16} style={{ color: a.severity === 'critical' ? '#ff3b5c' : '#ffb020' }} />
                                <div style={{ flex: 1, fontSize: 'var(--size-sm)' }}>
                                    <strong style={{ color: a.severity === 'critical' ? '#ff3b5c' : '#ffb020', marginRight: 8, textTransform: 'capitalize' }}>{a.type}</strong>
                                    {a.message}
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Detailed Sensors Grid */}
            <div style={{ marginTop: 'var(--s4)' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--s4)' }}>
                    <h2 style={{ fontSize: 'var(--size-lg)', fontWeight: 600 }}>Environmental Sensors</h2>
                    
                    {/* Room tabs */}
                    <div style={{ display: 'flex', gap: 'var(--s2)', overflowX: 'auto', scrollbarWidth: 'none' }}>
                        {ROOM_TABS.map(tab => {
                            const active = activeTab === tab.id;
                            return (
                                <button
                                    key={tab.id} onClick={() => setActiveTab(tab.id)}
                                    style={{
                                        padding: '4px 12px', borderRadius: 'var(--r-full)',
                                        background: active ? 'var(--text-primary)' : 'transparent',
                                        color: active ? 'var(--bg-base)' : 'var(--text-muted)',
                                        border: `1px solid ${active ? 'transparent' : 'var(--border-dim)'}`,
                                        cursor: 'pointer', whiteSpace: 'nowrap', fontSize: 12, fontWeight: 600,
                                        transition: 'all 0.2s ease'
                                    }}
                                >
                                    {tab.label}
                                </button>
                            );
                        })}
                    </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 'var(--s3)' }}>
                    {filtered.map(sensor => <MiniSensorCard key={sensor.id} sensor={sensor} />)}
                    {filtered.length === 0 && <div style={{ gridColumn: '1/-1', padding: 'var(--s8)', textAlign: 'center', color: 'var(--text-muted)' }}>No sensors match this filter.</div>}
                </div>
            </div>

        </div>
    );
};

export default DashboardPage;
