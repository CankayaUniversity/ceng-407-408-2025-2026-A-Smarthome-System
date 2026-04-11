import { useState, useEffect, useCallback } from 'react';
import { useRealtime } from '../context/RealtimeContext';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../services/supabase';
import { getPublicUrl } from '../services/supabase';
import {
    Thermometer, Droplets, Flame, Waves, Activity,
    Eye, AlertTriangle, ShieldCheck, ShieldAlert,
    Camera, Wifi, Wind,
    DoorOpen, Sofa, UtensilsCrossed, BedDouble, Lock, ShowerHead, Flower2
} from 'lucide-react';

const SENSOR_CONFIG = {
    temperature: { icon: Thermometer, color: '#ff6b35', label: 'Temperature', unit: '°C' },
    humidity: { icon: Droplets, color: '#00d4ff', label: 'Humidity', unit: '%' },
    smoke: { icon: Flame, color: '#ff3b5c', label: 'Smoke', unit: '' },
    water: { icon: Waves, color: '#3b9eff', label: 'Water', unit: '' },
    motion: { icon: Eye, color: '#9b59ff', label: 'Motion', unit: '' },
    door: { icon: DoorOpen, color: '#00e5a0', label: 'Door', unit: '' },
    co2: { icon: Wind, color: '#a0f080', label: 'CO2', unit: 'ppm' },
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

function MiniSensorCard({ sensor }) {
    const cfg = getSC(sensor.sensor_type);
    const Icon = cfg.icon;
    const val = sensor.numeric_value;
    const isBoolean = sensor.sensor_type === 'motion' || sensor.sensor_type === 'door' || sensor.sensor_type === 'water';
    const displayVal = val === null || val === undefined ? '\u2014'
        : isBoolean ? (parseFloat(val) === 1 ? 'Active' : 'Clear')
            : parseFloat(val).toFixed(1);
    const isAlert = (sensor.sensor_type === 'smoke' && parseFloat(val) > 0)
        || (sensor.sensor_type === 'water' && parseFloat(val) > 0);

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
                <div style={{ fontSize: 'var(--size-xs)', fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{cfg.label}</div>
                <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{sensor.sensor_type}</div>
            </div>
        </div>
    );
}

const DashboardPage = () => {
    const navigate = useNavigate();
    const { subscribe } = useRealtime();
    const [sensors, setSensors] = useState([]);
    const [alerts, setAlerts] = useState([]);
    const [lastCameraEvent, setLastCameraEvent] = useState(null);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('all');

    const fetchData = useCallback(async () => {
        try {
            const { data: readings } = await supabase
                .from('sensor_readings')
                .select('*')
                .order('recorded_at', { ascending: false })
                .limit(50);

            const latestByType = {};
            (readings || []).forEach(r => {
                const key = `${r.device_id}_${r.sensor_type}`;
                if (!latestByType[key]) latestByType[key] = r;
            });
            setSensors(Object.values(latestByType));

            const { data: evts } = await supabase
                .from('events')
                .select('*')
                .is('acknowledged_at', null)
                .order('created_at', { ascending: false })
                .limit(3);
            setAlerts(evts || []);

            const { data: camEvts } = await supabase
                .from('camera_events')
                .select('*, event_faces(*, residents(name))')
                .order('created_at', { ascending: false })
                .limit(1);
            if (camEvts?.length > 0) setLastCameraEvent(camEvts[0]);
        } catch (err) { console.error(err); }
        finally { setLoading(false); }
    }, []);

    useEffect(() => { fetchData(); }, [fetchData]);

    useEffect(() => {
        const unsub1 = subscribe('sensor_reading', (row) => {
            setSensors(prev => {
                const key = `${row.device_id}_${row.sensor_type}`;
                const exists = prev.findIndex(s => `${s.device_id}_${s.sensor_type}` === key);
                if (exists >= 0) {
                    const next = [...prev];
                    next[exists] = row;
                    return next;
                }
                return [row, ...prev];
            });
        });
        const unsub2 = subscribe('event', (row) => {
            setAlerts(prev => [row, ...prev].slice(0, 3));
        });
        const unsub3 = subscribe('camera_event', (row) => {
            setLastCameraEvent(row);
        });
        return () => { unsub1(); unsub2(); unsub3(); };
    }, [subscribe]);

    const tempSensors = sensors.filter(s => s.sensor_type === 'temperature');
    const humSensors = sensors.filter(s => s.sensor_type === 'humidity');
    const avgTemp = tempSensors.reduce((a, s) => a + (s.numeric_value || 0), 0) / (tempSensors.length || 1);
    const avgHum = humSensors.reduce((a, s) => a + (s.numeric_value || 0), 0) / (humSensors.length || 1);
    const activeMotions = sensors.filter(s => s.sensor_type === 'motion' && s.numeric_value === 1).length;
    const securityStatus = alerts.some(a => a.priority === 'critical') ? 'warning' : 'secure';

    const filtered = sensors.filter(s => matchesRoom(s, activeTab));

    if (loading) return (
        <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading Overview</div></div>
    );

    const snapshotUrl = lastCameraEvent?.snapshot_path
        ? getPublicUrl('event-snapshots', lastCameraEvent.snapshot_path)
        : null;

    const lastFace = lastCameraEvent?.event_faces?.[0];
    const lastResult = lastFace?.classification || 'unknown';

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s6)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Dashboard</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>
                        <Wifi size={12} style={{ color: 'var(--jade-core)', display: 'inline', marginRight: 4 }} />
                        System Online · {sensors.length} sensors active
                    </p>
                </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--s5)' }}>
                <div className="card" onClick={() => navigate('/camera')}
                    style={{ gridColumn: '1 / -1', padding: 0, overflow: 'hidden', position: 'relative', cursor: 'pointer', minHeight: 240, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', backgroundImage: snapshotUrl ? `url(${snapshotUrl})` : 'none', backgroundColor: '#111318', backgroundSize: 'cover', backgroundPosition: 'center' }}>
                    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0.2) 60%, transparent 100%)' }} />
                    <div style={{ position: 'absolute', top: 'var(--s4)', left: 'var(--s4)', display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(0,0,0,0.5)', padding: '4px 10px', borderRadius: 'var(--r-full)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.1)' }}>
                        <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#ff3b5c', boxShadow: '0 0 8px #ff3b5c', animation: 'alertBreath 2s infinite' }} />
                        <span style={{ fontSize: 10, fontWeight: 700, color: 'white', letterSpacing: '0.05em' }}>LIVE CAMERA</span>
                    </div>
                    <div style={{ position: 'relative', padding: 'var(--s6)', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
                        <div>
                            <h2 style={{ color: 'white', fontSize: 'var(--size-xl)', fontWeight: 700, marginBottom: 'var(--s1)' }}>Front Door Surveillance</h2>
                            <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 'var(--size-sm)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                <Camera size={14} /> AI Face Recognition Active
                            </p>
                        </div>
                        {lastCameraEvent && (
                            <div style={{ background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.1)', padding: 'var(--s3)', borderRadius: 'var(--r-lg)', textAlign: 'center' }}>
                                <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', textTransform: 'uppercase', marginBottom: 4 }}>Last Event</div>
                                <div style={{ color: lastResult === 'resident' ? '#00e5a0' : '#ff3b5c', fontWeight: 700, fontSize: 'var(--size-sm)' }}>
                                    {lastResult === 'resident' ? 'Resident' : 'Unknown Person'}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                <div className="card" style={{ display: 'flex', flexDirection: 'column', background: securityStatus === 'secure' ? 'var(--bg-surface)' : 'rgba(255,59,92,0.05)', borderColor: securityStatus === 'secure' ? 'var(--border-soft)' : 'rgba(255,59,92,0.2)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s4)' }}>
                        {securityStatus === 'secure' ? <ShieldCheck style={{ color: 'var(--jade-core)' }} /> : <ShieldAlert style={{ color: '#ff3b5c' }} />}
                        <h3 style={{ fontSize: 'var(--size-base)', fontWeight: 600 }}>Security</h3>
                    </div>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--s3)', marginTop: 'auto' }}>
                        <div style={{ background: 'var(--bg-base)', padding: 'var(--s3)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ color: 'var(--text-muted)', fontSize: 11, textTransform: 'uppercase', marginBottom: 2 }}>Motion</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: activeMotions > 0 ? '#9b59ff' : 'var(--text-primary)' }}>{activeMotions} <span style={{ fontSize: 12, fontWeight: 400 }}>zones</span></div>
                        </div>
                        <div style={{ background: 'var(--bg-base)', padding: 'var(--s3)', borderRadius: 'var(--r-md)' }}>
                            <div style={{ color: 'var(--text-muted)', fontSize: 11, textTransform: 'uppercase', marginBottom: 2 }}>Alerts</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: alerts.length > 0 ? '#ffb020' : 'var(--text-primary)' }}>{alerts.length}</div>
                        </div>
                    </div>
                </div>

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

            {alerts.length > 0 && (
                <div>
                    <h3 style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 'var(--s3)' }}>Recent Alerts</h3>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s2)' }}>
                        {alerts.map(a => (
                            <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: 'var(--s3)', background: a.priority === 'critical' ? 'rgba(255,59,92,0.1)' : 'rgba(255,176,32,0.1)', borderRadius: 'var(--r-md)', border: `1px solid ${a.priority === 'critical' ? 'rgba(255,59,92,0.2)' : 'rgba(255,176,32,0.2)'}` }}>
                                <AlertTriangle size={16} style={{ color: a.priority === 'critical' ? '#ff3b5c' : '#ffb020' }} />
                                <div style={{ flex: 1, fontSize: 'var(--size-sm)' }}>
                                    <strong style={{ color: a.priority === 'critical' ? '#ff3b5c' : '#ffb020', marginRight: 8, textTransform: 'capitalize' }}>{a.event_type}</strong>
                                    {a.message}
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            <div style={{ marginTop: 'var(--s4)' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--s4)' }}>
                    <h2 style={{ fontSize: 'var(--size-lg)', fontWeight: 600 }}>Environmental Sensors</h2>
                    <div style={{ display: 'flex', gap: 'var(--s2)', overflowX: 'auto', scrollbarWidth: 'none' }}>
                        {ROOM_TABS.map(tab => {
                            const active = activeTab === tab.id;
                            return (
                                <button key={tab.id} onClick={() => setActiveTab(tab.id)}
                                    style={{ padding: '4px 12px', borderRadius: 'var(--r-full)', background: active ? 'var(--text-primary)' : 'transparent', color: active ? 'var(--bg-base)' : 'var(--text-muted)', border: `1px solid ${active ? 'transparent' : 'var(--border-dim)'}`, cursor: 'pointer', whiteSpace: 'nowrap', fontSize: 12, fontWeight: 600, transition: 'all 0.2s ease' }}>
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
