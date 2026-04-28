import { useState, useEffect, useMemo, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../services/supabase';
import {
    Thermometer, Droplets, Flame, Waves, Eye, Activity,
    X, BarChart3, CheckCircle2, Sofa, Cpu,
    UtensilsCrossed, BedDouble, Lock, ShowerHead, Flower2, MapPin
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

const ROOM_IDS = ROOMS.map(r => r.id);

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

function resolveRoom(device) {
    if (!device) return 'living';
    if (device.room && ROOM_IDS.includes(device.room)) return device.room;
    return deviceToRoom(device.name);
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
            <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'var(--blueprint-pin-bg)', border: `1.5px solid ${isAlert ? '#ff3b5c' : sic.color + '55'}`, backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: isAlert ? '0 0 15px rgba(255,59,92,0.6)' : 'var(--blueprint-pin-shadow)' }}>
                <Icon size={14} style={{ color: isAlert ? '#ff3b5c' : sic.color }} />
            </div>
        </div>
    );
}

function DeviceCard({ device, sensors, onAssign, pending, errMsg }) {
    const currentRoom = resolveRoom(device);
    const sortedSensors = [...sensors].sort((a, b) => (a.sensor_type || '').localeCompare(b.sensor_type || ''));

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)', padding: 'var(--s4)', borderRadius: 'var(--r-lg)', background: 'var(--bg-raised)', border: '1px solid var(--border-soft)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)' }}>
                <div style={{ width: 36, height: 36, borderRadius: 'var(--r-md)', background: 'var(--ember-trace)', border: '1px solid var(--ember-trace)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ember-core)', flexShrink: 0 }}>
                    <Cpu size={16} />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 'var(--size-sm)', fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {device?.name || `Device ${device?.id ?? '—'}`}
                    </div>
                    <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                        {sortedSensors.length} sensor{sortedSensors.length !== 1 ? 's' : ''}
                    </div>
                </div>
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--s2)' }}>
                {sortedSensors.map(s => {
                    const sic = getSIC(s.sensor_type);
                    const SIcon = sic.Icon;
                    const isBoolean = s.sensor_type === 'motion' || s.sensor_type === 'door';
                    const display = s.numeric_value === null || s.numeric_value === undefined
                        ? '\u2014'
                        : isBoolean
                            ? (parseFloat(s.numeric_value) === 1 ? 'Active' : 'Clear')
                            : parseFloat(s.numeric_value).toFixed(1);
                    return (
                        <div
                            key={s.id}
                            title={s.recorded_at ? formatDistanceToNow(new Date(s.recorded_at), { addSuffix: true }) : 'Live'}
                            style={{
                                display: 'inline-flex', alignItems: 'center', gap: 8,
                                padding: '6px 10px',
                                borderRadius: 'var(--r-md)',
                                background: 'var(--bg-base)',
                                border: '1px solid var(--border-dim)',
                                fontSize: 12,
                                minWidth: 90,
                            }}
                        >
                            <span style={{ width: 22, height: 22, borderRadius: 'var(--r-sm)', background: `${sic.color}15`, color: sic.color, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                                <SIcon size={12} />
                            </span>
                            <span style={{ color: 'var(--text-muted)', textTransform: 'capitalize', flex: 1 }}>{s.sensor_type}</span>
                            <span style={{ fontFamily: 'var(--font-display)', fontWeight: 700, color: 'var(--text-primary)' }}>{display}</span>
                        </div>
                    );
                })}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)' }}>
                <MapPin size={11} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                <span style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase' }}>Room</span>
                <select
                    className="form-input"
                    value={currentRoom}
                    disabled={pending || !device?.id}
                    onChange={e => onAssign(device.id, e.target.value)}
                    style={{ flex: 1, padding: '6px var(--s3)', fontSize: 12, background: 'var(--bg-surface)' }}
                >
                    {ROOMS.map(r => (
                        <option key={r.id} value={r.id}>{r.label}</option>
                    ))}
                </select>
                {pending && <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>Saving…</span>}
            </div>

            {errMsg && (
                <div style={{ fontSize: 11, color: 'var(--crimson-core)' }}>{errMsg}</div>
            )}
        </div>
    );
}

function RoomDrawer({ room, deviceGroups, onClose, onAssignDevice }) {
    const navigate = useNavigate();
    const { Icon, label, color } = room;
    const [pendingByDevice, setPendingByDevice] = useState({});
    const [errorByDevice, setErrorByDevice] = useState({});

    const allSensors = deviceGroups.flatMap(g => g.sensors);
    const temp = allSensors.find(s => s.sensor_type === 'temperature')?.numeric_value;
    const hum = allSensors.find(s => s.sensor_type === 'humidity')?.numeric_value;

    const handleAssign = async (deviceId, nextRoom) => {
        if (!deviceId) return;
        setPendingByDevice(prev => ({ ...prev, [deviceId]: true }));
        setErrorByDevice(prev => ({ ...prev, [deviceId]: null }));
        const result = await onAssignDevice(deviceId, nextRoom);
        setPendingByDevice(prev => {
            const next = { ...prev };
            delete next[deviceId];
            return next;
        });
        if (!result.ok) {
            setErrorByDevice(prev => ({ ...prev, [deviceId]: result.error || 'Update failed' }));
            setTimeout(() => {
                setErrorByDevice(prev => {
                    const next = { ...prev };
                    delete next[deviceId];
                    return next;
                });
            }, 3500);
        }
    };

    return (
        <div style={{ position: 'fixed', inset: 0, zIndex: 200, display: 'flex', justifyContent: 'flex-end', pointerEvents: 'none' }}>
            <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(4px)', pointerEvents: 'auto', animation: 'fadeIn 0.2s ease-out' }} />
            <div style={{ width: 480, maxWidth: '100vw', background: 'var(--bg-surface)', borderLeft: '1px solid var(--border-soft)', display: 'flex', flexDirection: 'column', pointerEvents: 'auto', boxShadow: 'var(--shadow-modal)', animation: 'slideLeft 0.3s cubic-bezier(0.2, 0.8, 0.2, 1) both' }}>
                <div style={{ padding: 'var(--s6)', background: `linear-gradient(to bottom right, ${color}20, transparent)`, borderBottom: '1px solid var(--border-dim)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--s5)' }}>
                        <div style={{ width: 60, height: 60, borderRadius: 'var(--r-2xl)', background: `${color}15`, border: `1px solid ${color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
                            <Icon size={28} />
                        </div>
                        <button onClick={onClose} style={{ background: 'var(--border-dim)', border: 'none', borderRadius: '50%', width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', cursor: 'pointer' }}>
                            <X size={16} />
                        </button>
                    </div>
                    <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 800, marginBottom: 4 }}>{label}</h2>
                    <div style={{ display: 'flex', gap: 'var(--s4)', fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                        <span>{deviceGroups.length} device{deviceGroups.length !== 1 ? 's' : ''}</span>
                        <span>{allSensors.length} sensor{allSensors.length !== 1 ? 's' : ''}</span>
                        {temp != null && <span>{parseFloat(temp).toFixed(1)}°C</span>}
                        {hum != null && <span>{parseFloat(hum).toFixed(0)}% Hum</span>}
                    </div>
                </div>
                <div style={{ flex: 1, overflowY: 'auto', padding: 'var(--s4)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 var(--s2) var(--s3)', borderBottom: '1px solid var(--border-dim)', marginBottom: 'var(--s3)' }}>
                        <span style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: 'var(--text-muted)', letterSpacing: '0.06em' }}>Devices in this room</span>
                        <button className="btn btn-ghost btn-sm" onClick={() => navigate('/history')} style={{ fontSize: 11, padding: '4px 8px' }}><BarChart3 size={12} /> Analytics</button>
                    </div>
                    {deviceGroups.length === 0 ? (
                        <div className="empty-state" style={{ padding: 'var(--s8) var(--s4)' }}>
                            <h3>No devices here yet</h3>
                            <p>Move a device into this room from another room&apos;s panel.</p>
                        </div>
                    ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)' }}>
                            {deviceGroups.map(group => (
                                <DeviceCard
                                    key={group.deviceId ?? `dev-${group.device?.name || 'unknown'}`}
                                    device={group.device}
                                    sensors={group.sensors}
                                    onAssign={handleAssign}
                                    pending={!!pendingByDevice[group.deviceId]}
                                    errMsg={errorByDevice[group.deviceId]}
                                />
                            ))}
                        </div>
                    )}
                </div>
            </div>
            <style>{`@keyframes slideLeft { from { transform: translateX(100%); } to { transform: translateX(0); } } @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }`}</style>
        </div>
    );
}

const RoomsPage = () => {
    const [sensors, setSensors] = useState([]);
    const [devices, setDevices] = useState([]);
    const [loading, setLoading] = useState(true);
    const [openRoom, setOpenRoom] = useState(null);

    const fetchData = useCallback(async () => {
        const [sensorsRes, devicesRes] = await Promise.all([
            supabase
                .from('sensor_readings')
                .select('*')
                .order('recorded_at', { ascending: false })
                .limit(100),
            supabase
                .from('devices')
                .select('id, name, room'),
        ]);

        const data = sensorsRes.data || [];
        const latestByType = {};
        data.forEach(r => {
            const key = `${r.device_id}_${r.sensor_type}`;
            if (!latestByType[key]) latestByType[key] = r;
        });
        setSensors(Object.values(latestByType));
        setDevices(devicesRes.data || []);
        setLoading(false);
    }, []);

    useEffect(() => {
        fetchData();
        const t = setInterval(fetchData, 10000);
        return () => clearInterval(t);
    }, [fetchData]);

    const devicesById = useMemo(() => {
        const map = {};
        for (const d of devices) map[d.id] = d;
        return map;
    }, [devices]);

    // Group sensors by device, then bucket each device into its assigned room.
    const { sensorsByRoom, deviceGroupsByRoom } = useMemo(() => {
        const sensorsByDevice = {};
        for (const s of sensors) {
            const id = s.device_id ?? '__orphan__';
            if (!sensorsByDevice[id]) sensorsByDevice[id] = [];
            sensorsByDevice[id].push(s);
        }

        const sByRoom = {};
        const dByRoom = {};
        for (const [deviceId, deviceSensors] of Object.entries(sensorsByDevice)) {
            const device = devicesById[deviceId];
            const rId = resolveRoom(device);
            if (!sByRoom[rId]) sByRoom[rId] = [];
            sByRoom[rId].push(...deviceSensors);
            if (!dByRoom[rId]) dByRoom[rId] = [];
            dByRoom[rId].push({
                deviceId: device?.id ?? deviceId,
                device: device || { id: deviceId, name: `Device ${deviceId}` },
                sensors: deviceSensors,
            });
        }
        return { sensorsByRoom: sByRoom, deviceGroupsByRoom: dByRoom };
    }, [sensors, devicesById]);

    const assignDevice = useCallback(async (deviceId, nextRoom) => {
        if (!deviceId || !ROOM_IDS.includes(nextRoom)) {
            return { ok: false, error: 'Invalid room' };
        }
        const previous = devices;
        setDevices(prev => prev.map(d => (d.id === deviceId ? { ...d, room: nextRoom } : d)));
        const { error } = await supabase
            .from('devices')
            .update({ room: nextRoom })
            .eq('id', deviceId);
        if (error) {
            console.error('[Rooms] failed to update device room:', error);
            setDevices(previous);
            return { ok: false, error: error.message };
        }
        return { ok: true };
    }, [devices]);

    const drawerRoom = ROOMS.find(r => r.id === openRoom);
    const drawerGroups = openRoom ? (deviceGroupsByRoom[openRoom] || []) : [];

    if (loading) return <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading Blueprint</div></div>;

    return (
        <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s6)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Floor Plan</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>Interactive home blueprint · Live sensor telemetry · Reassign devices by room</p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--text-primary)', background: 'var(--bg-surface)', border: '1px solid var(--border-soft)', borderRadius: 'var(--r-full)', padding: '6px 14px', fontWeight: 600 }}>
                    <CheckCircle2 size={14} style={{ color: 'var(--jade-core)' }} />
                    {Object.keys(deviceGroupsByRoom).length} Zones Active
                </div>
            </div>

            <div
                className="floorplan-canvas"
                style={{
                    position: 'relative',
                    width: '100%',
                    paddingBottom: '55%',
                    minHeight: 400,
                    background: 'var(--blueprint-bg)',
                    backgroundImage: 'radial-gradient(var(--blueprint-grid) 1px, transparent 1px)',
                    backgroundSize: '24px 24px',
                    borderRadius: 'var(--r-2xl)',
                    border: '1px solid var(--border-soft)',
                    overflow: 'hidden',
                    transition: 'background-color var(--t-base) var(--ease-out), border-color var(--t-base) var(--ease-out)',
                }}>
                <div style={{ position: 'absolute', inset: '2%', border: '2px solid var(--blueprint-frame)', borderRadius: 12, pointerEvents: 'none' }} />
                {ROOMS.map(room => {
                    const roomSensors = sensorsByRoom[room.id] || [];
                    const positions = pinGrid(Math.min(roomSensors.length, 6));
                    const roomGroups = deviceGroupsByRoom[room.id] || [];
                    const { Icon } = room;
                    return (
                        <div
                            key={room.id}
                            className="floorplan-room"
                            style={{
                                position: 'absolute',
                                left: `${room.left}%`,
                                top: `${room.top}%`,
                                width: `${room.w}%`,
                                height: `${room.h}%`,
                                background: `${room.color}10`,
                                border: '1px solid var(--blueprint-room-border)',
                                borderRadius: 8,
                                cursor: 'pointer',
                                transition: 'all 0.3s',
                                ['--hover-bg']: `${room.color}25`,
                                ['--hover-border']: room.color,
                            }}
                            onClick={() => setOpenRoom(room.id)}
                        >
                            <div style={{ position: 'absolute', top: 12, left: 16, display: 'flex', alignItems: 'center', gap: 8, pointerEvents: 'none' }}>
                                <Icon size={16} style={{ color: room.color }} />
                                <span style={{ fontFamily: 'var(--font-display)', fontSize: 13, fontWeight: 700, letterSpacing: '0.05em', color: 'var(--blueprint-room-label)' }}>{room.label.toUpperCase()}</span>
                            </div>
                            <div style={{ position: 'absolute', bottom: 12, right: 16, fontSize: 10, color: 'var(--blueprint-room-meta)', fontWeight: 600 }}>
                                {roomGroups.length} dev · {roomSensors.length} sensors
                            </div>
                            {roomSensors.slice(0, 6).map((sensor, i) => (
                                <SensorPin key={sensor.id} sensor={sensor} pos={positions[i]} onClick={() => setOpenRoom(room.id)} />
                            ))}
                        </div>
                    );
                })}
            </div>

            {openRoom && drawerRoom && (
                <RoomDrawer
                    room={drawerRoom}
                    deviceGroups={drawerGroups}
                    onClose={() => setOpenRoom(null)}
                    onAssignDevice={assignDevice}
                />
            )}

            <style>{`
                .floorplan-room:hover {
                    background: var(--hover-bg) !important;
                    border-color: var(--hover-border) !important;
                }
            `}</style>
        </div>
    );
};

export default RoomsPage;
