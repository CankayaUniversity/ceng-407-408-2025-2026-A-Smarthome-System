import { useState, useEffect, useCallback } from 'react';
import { useRealtime } from '../context/RealtimeContext';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../services/supabase';
import { getPublicUrl } from '../services/supabase';
import {
    Activity, Thermometer, Flame, Sprout,
    Eye, ShieldCheck, ShieldAlert,
    Camera, Wifi,
    ChevronRight,
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { DASHBOARD_ROOM_TABS, resolveRoom, matchesRoomTab, ROOM_LABELS } from '../utils/rooms';
import { getEventMeta, getEventToneStyle } from '../utils/eventLabels';
import {
    getSensorConfig,
    normalizeSensorType,
    formatSensorDisplayValue,
    isSensorAlert,
} from '../utils/sensorConfig';

function getSC(type) {
    return getSensorConfig(type);
}

function MiniSensorCard({ sensor }) {
    const sensorType = normalizeSensorType(sensor.sensor_type);
    const cfg = getSC(sensorType);
    const Icon = cfg.icon;
    const val = sensor.numeric_value;
    const displayVal = formatSensorDisplayValue(sensorType, val);
    const isAlert = isSensorAlert(sensorType, val);

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
                <div style={{ fontSize: 10, color: 'var(--text-secondary)' }}>
                    {sensor.deviceLabel || ROOM_LABELS[sensor.roomId] || 'Home'}
                </div>
            </div>
        </div>
    );
}

const STAT_CARD = {
    display: 'flex', flexDirection: 'column', gap: 'var(--s3)', padding: 'var(--s4) var(--s5)',
};
const STAT_HEAD = {
    display: 'flex', alignItems: 'center', gap: 8,
};
const STAT_TITLE = { fontSize: 'var(--size-sm)', fontWeight: 600 };
const STAT_GRID = { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--s2)', marginTop: 'auto' };
const STAT_TILE = (alert) => ({
    background: alert ? 'rgba(255,59,92,0.08)' : 'var(--bg-base)',
    border: alert ? '1px solid rgba(255,59,92,0.25)' : '1px solid transparent',
    padding: '8px 10px',
    borderRadius: 'var(--r-md)',
});
const STAT_LABEL = { color: 'var(--text-muted)', fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 2 };

function HazardCard({ icon: Icon, label, sensors, accent, alertText, kind = 'smoke' }) {
    const active = sensors.filter(s => isSensorAlert(normalizeSensorType(s.sensor_type), s.numeric_value)).length;
    const total = sensors.length;
    const max = sensors.reduce((m, s) => Math.max(m, parseFloat(s.numeric_value) || 0), 0);
    const isAlert = active > 0;

    let statusLabel = 'Status';
    let statusValue = 'No sensor';
    let detailLabel = 'Monitors';
    let detailValue = '\u2014';

    if (total > 0) {
        if (kind === 'soil_moisture') {
            statusValue = isAlert ? 'Soil dry' : 'Moisture OK';
            detailLabel = 'Probe';
            detailValue = total === 1 ? '1 sensor' : `${total} sensors`;
        } else {
            statusValue = isAlert ? 'Smoke detected' : 'Air clear';
            detailLabel = isAlert ? 'Peak level' : 'Reading';
            detailValue = isAlert ? max.toFixed(1) : (max > 0 ? max.toFixed(1) : 'Normal');
        }
    }

    return (
        <div className="card" style={{
            ...STAT_CARD,
            background: isAlert ? 'rgba(255,59,92,0.06)' : 'var(--bg-surface)',
            borderColor: isAlert ? 'rgba(255,59,92,0.25)' : 'var(--border-soft)',
        }}>
            <div style={STAT_HEAD}>
                <div style={{ width: 30, height: 30, borderRadius: 'var(--r-md)', background: `${accent}15`, color: isAlert ? '#ff3b5c' : accent, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon size={15} />
                </div>
                <h3 style={STAT_TITLE}>{label}</h3>
                {isAlert && <span className="badge badge-danger" style={{ marginLeft: 'auto' }}>{alertText}</span>}
                {!isAlert && total > 0 && <span className="badge badge-success" style={{ marginLeft: 'auto' }}>OK</span>}
            </div>
            <div style={STAT_GRID}>
                <div style={STAT_TILE(isAlert)}>
                    <div style={STAT_LABEL}>{statusLabel}</div>
                    <div style={{ fontWeight: 700, fontSize: 'var(--size-sm)', color: isAlert ? '#ff3b5c' : 'var(--text-primary)', lineHeight: 1.3 }}>
                        {statusValue}
                    </div>
                </div>
                <div style={STAT_TILE(false)}>
                    <div style={STAT_LABEL}>{detailLabel}</div>
                    <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: isAlert ? '#ff3b5c' : accent }}>
                        {detailValue}
                    </div>
                </div>
            </div>
        </div>
    );
}

function RecentAlertRow({ alert, onOpen }) {
    const meta = getEventMeta(alert.event_type);
    const tone = getEventToneStyle(meta.tone);
    const Icon = meta.icon;
    return (
        <button type="button" onClick={onOpen} style={{
            display: 'flex', alignItems: 'stretch', gap: 'var(--s3)', padding: 'var(--s3) var(--s4)',
            background: tone.bg, borderRadius: 'var(--r-lg)', border: `1px solid ${tone.border}`,
            cursor: 'pointer', textAlign: 'left', width: '100%',
        }}>
            <div style={{
                width: 40, height: 40, borderRadius: 'var(--r-md)', flexShrink: 0,
                background: 'var(--bg-surface)', border: `1px solid ${tone.border}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center', color: tone.color,
            }}>
                <Icon size={18} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4, flexWrap: 'wrap' }}>
                    <span style={{ fontWeight: 700, fontSize: 'var(--size-sm)', color: 'var(--text-primary)' }}>{meta.title}</span>
                    <span className={`badge ${alert.priority === 'critical' ? 'badge-danger' : 'badge-warning'}`} style={{ fontSize: 10 }}>
                        {alert.priority === 'critical' ? 'Critical' : 'Attention'}
                    </span>
                </div>
                <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', margin: 0, lineHeight: 1.45 }}>
                    {alert.message || meta.short}
                </p>
                {alert.created_at && (
                    <span style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 6, display: 'block' }}>
                        {formatDistanceToNow(new Date(alert.created_at), { addSuffix: true })}
                    </span>
                )}
            </div>
            <ChevronRight size={18} style={{ color: 'var(--text-muted)', alignSelf: 'center', flexShrink: 0 }} />
        </button>
    );
}

function enrichSensors(readings, deviceMap) {
    return readings.map(r => {
        const device = deviceMap[r.device_id];
        const roomId = resolveRoom(device);
        return { ...r, roomId, deviceLabel: device?.name || ROOM_LABELS[roomId] };
    });
}

const DashboardPage = () => {
    const navigate = useNavigate();
    const { subscribe } = useRealtime();
    const [sensors, setSensors] = useState([]);
    const [deviceMap, setDeviceMap] = useState({});
    const [alerts, setAlerts] = useState([]);
    const [lastCameraEvent, setLastCameraEvent] = useState(null);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('all');

    const fetchData = useCallback(async () => {
        try {
            const [{ data: readings }, { data: devices }] = await Promise.all([
                supabase.from('sensor_readings').select('*').order('recorded_at', { ascending: false }).limit(50),
                supabase.from('devices').select('id, name, room'),
            ]);

            const map = Object.fromEntries((devices || []).map(d => [d.id, d]));
            setDeviceMap(map);

            const latestByType = {};
            (readings || []).forEach(r => {
                const key = `${r.device_id}_${r.sensor_type}`;
                if (!latestByType[key]) latestByType[key] = r;
            });
            setSensors(enrichSensors(Object.values(latestByType), map));

            const { data: evts } = await supabase
                .from('events')
                .select('*')
                .is('acknowledged_at', null)
                .order('created_at', { ascending: false })
                .limit(3);
            setAlerts(evts || []);

            const { data: camEvts } = await supabase
                .from('camera_events')
                .select('*, event_faces(*, residents!resident_id(name, id))')
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
                const enriched = enrichSensors([row], deviceMap)[0];
                const exists = prev.findIndex(s => `${s.device_id}_${s.sensor_type}` === key);
                if (exists >= 0) {
                    const next = [...prev];
                    next[exists] = enriched;
                    return next;
                }
                return [enriched, ...prev];
            });
        });
        const unsub2 = subscribe('event', (row) => {
            setAlerts(prev => [row, ...prev].slice(0, 3));
        });
        const unsub3 = subscribe('camera_event', (row) => {
            const hasfaces = row.event_faces && row.event_faces.length > 0;
            setLastCameraEvent({ ...row, _scanning: !hasfaces });
            if (!hasfaces && row.id) {
                setTimeout(async () => {
                    try {
                        const { data } = await supabase
                            .from('camera_events')
                            .select('*, event_faces(*, residents!resident_id(name, id))')
                            .eq('id', row.id)
                            .single();
                        if (data) setLastCameraEvent(data);
                    } catch {}
                }, 1500);
            }
        });
        return () => { unsub1(); unsub2(); unsub3(); };
    }, [subscribe, deviceMap]);

    const tempSensors = sensors.filter(s => s.sensor_type === 'temperature');
    const humSensors = sensors.filter(s => s.sensor_type === 'humidity');
    const smokeSensors = sensors.filter(s => s.sensor_type === 'smoke');
    const soilSensors = sensors.filter(s => {
        const t = normalizeSensorType(s.sensor_type);
        return t === 'soil_moisture';
    });
    const avgTemp = tempSensors.reduce((a, s) => a + (s.numeric_value || 0), 0) / (tempSensors.length || 1);
    const avgHum = humSensors.reduce((a, s) => a + (s.numeric_value || 0), 0) / (humSensors.length || 1);
    const activeMotions = sensors.filter(s => s.sensor_type === 'motion' && s.numeric_value === 1).length;
    const securityStatus = alerts.some(a => a.priority === 'critical') ? 'warning' : 'secure';

    const filtered = sensors.filter(s => matchesRoomTab(s.roomId, activeTab));

    if (loading) return (
        <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading Overview</div></div>
    );

    const snapshotUrl = lastCameraEvent?.snapshot_path
        ? getPublicUrl('event-snapshots', lastCameraEvent.snapshot_path)
        : null;

    const lastFace = lastCameraEvent?.event_faces?.[0];
    const lastScanning = lastCameraEvent?._scanning && !lastFace;
    const lastResult = lastFace?.classification || 'unknown';
    const lastResidentName = lastFace?.residents?.name;

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Dashboard</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>
                        <Wifi size={12} style={{ color: 'var(--jade-core)', display: 'inline', marginRight: 4 }} />
                        System Online · {sensors.length} sensors active
                    </p>
                </div>
            </div>

            <div className="dash-overview-grid">
                <div className="card dash-camera-card" onClick={() => navigate('/camera')}
                    style={{ padding: 0, overflow: 'hidden', position: 'relative', cursor: 'pointer', background: '#0a0c10' }}>
                    {snapshotUrl ? (
                        <img
                            src={snapshotUrl}
                            alt="Last camera snapshot"
                            loading="lazy"
                            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', objectPosition: 'center', display: 'block' }}
                        />
                    ) : (
                        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(135deg, var(--bg-elevated), var(--bg-base))' }} />
                    )}
                    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(0,0,0,0.92) 0%, rgba(0,0,0,0.25) 55%, rgba(0,0,0,0.05) 100%)', pointerEvents: 'none' }} />
                    <div style={{ position: 'absolute', top: 'var(--s3)', left: 'var(--s3)', display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(0,0,0,0.55)', padding: '4px 10px', borderRadius: 'var(--r-full)', backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,0.12)' }}>
                        <div style={{ width: 7, height: 7, borderRadius: '50%', background: '#ff3b5c', boxShadow: '0 0 8px #ff3b5c', animation: 'alertBreath 2s infinite' }} />
                        <span style={{ fontSize: 10, fontWeight: 700, color: 'white', letterSpacing: '0.05em' }}>LAST SNAPSHOT</span>
                    </div>
                    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: 'var(--s4) var(--s5)', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 'var(--s3)' }}>
                        <div style={{ minWidth: 0 }}>
                            <h2 style={{ color: 'white', fontSize: 'var(--size-md)', fontWeight: 700, marginBottom: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>Front Door Surveillance</h2>
                            <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: 'var(--size-xs)', display: 'flex', alignItems: 'center', gap: 6 }}>
                                <Camera size={12} /> AI Face Recognition Active
                            </p>
                        </div>
                        {lastCameraEvent && (
                            <div style={{ background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.1)', padding: '6px 10px', borderRadius: 'var(--r-md)', textAlign: 'center', flexShrink: 0 }}>
                                <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.55)', textTransform: 'uppercase', marginBottom: 2, letterSpacing: '0.06em' }}>Last Event</div>
                                <div style={{ color: lastScanning ? '#f59e0b' : lastResult === 'resident' ? '#00e5a0' : '#ff3b5c', fontWeight: 700, fontSize: 'var(--size-xs)' }}>
                                    {lastScanning ? 'Scanning...' : lastResult === 'resident' ? (lastResidentName || 'Resident') : 'Unknown Person'}
                                </div>
                            </div>
                        )}
                    </div>
                </div>

                <div className="card dash-stat-card" style={{
                    ...STAT_CARD,
                    background: securityStatus === 'secure' ? 'var(--bg-surface)' : 'rgba(255,59,92,0.05)',
                    borderColor: securityStatus === 'secure' ? 'var(--border-soft)' : 'rgba(255,59,92,0.2)',
                }}>
                    <div style={STAT_HEAD}>
                        {securityStatus === 'secure'
                            ? <ShieldCheck size={18} style={{ color: 'var(--jade-core)' }} />
                            : <ShieldAlert size={18} style={{ color: '#ff3b5c' }} />}
                        <h3 style={STAT_TITLE}>Security</h3>
                    </div>
                    <div style={STAT_GRID}>
                        <div style={STAT_TILE(false)}>
                            <div style={STAT_LABEL}>Motion</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: activeMotions > 0 ? '#9b59ff' : 'var(--text-primary)' }}>{activeMotions}<span style={{ fontSize: 11, fontWeight: 400, color: 'var(--text-muted)', marginLeft: 4 }}>zones</span></div>
                        </div>
                        <div style={STAT_TILE(false)}>
                            <div style={STAT_LABEL}>Alerts</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: alerts.length > 0 ? '#ffb020' : 'var(--text-primary)' }}>{alerts.length}</div>
                        </div>
                    </div>
                </div>

                <div className="card dash-stat-card" style={STAT_CARD}>
                    <div style={STAT_HEAD}>
                        <Thermometer size={18} style={{ color: '#ff6b35' }} />
                        <h3 style={STAT_TITLE}>Climate</h3>
                    </div>
                    <div style={STAT_GRID}>
                        <div style={STAT_TILE(false)}>
                            <div style={STAT_LABEL}>Avg Temp</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: '#ff6b35' }}>{tempSensors.length > 0 ? `${avgTemp.toFixed(1)}°` : '\u2014'}</div>
                        </div>
                        <div style={STAT_TILE(false)}>
                            <div style={STAT_LABEL}>Avg Hum</div>
                            <div style={{ fontWeight: 700, fontSize: 'var(--size-lg)', color: '#00d4ff' }}>{humSensors.length > 0 ? `${avgHum.toFixed(0)}%` : '\u2014'}</div>
                        </div>
                    </div>
                </div>

                <HazardCard
                    icon={Flame}
                    label="Smoke"
                    sensors={smokeSensors}
                    accent="#ff3b5c"
                    alertText="ALERT"
                    kind="smoke"
                />

                <HazardCard
                    icon={Sprout}
                    label="Soil moisture"
                    sensors={soilSensors}
                    accent="#7cb342"
                    alertText="DRY"
                    kind="soil_moisture"
                />
            </div>

            {alerts.length > 0 && (
                <section style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <h3 style={{ fontSize: 'var(--size-sm)', fontWeight: 700, color: 'var(--text-primary)' }}>Recent alerts</h3>
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => navigate('/alerts')}>
                            View all <ChevronRight size={14} />
                        </button>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s2)' }}>
                        {alerts.map(a => (
                            <RecentAlertRow key={a.id} alert={a} onOpen={() => navigate('/alerts')} />
                        ))}
                    </div>
                </section>
            )}

            <div>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--s3)', gap: 'var(--s4)' }}>
                    <h2 style={{ fontSize: 'var(--size-md)', fontWeight: 600 }}>Environmental Sensors</h2>
                    <div style={{ display: 'flex', gap: 6, overflowX: 'auto', scrollbarWidth: 'none' }}>
                        {DASHBOARD_ROOM_TABS.map(tab => {
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
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 'var(--s3)' }}>
                    {filtered.map(sensor => <MiniSensorCard key={sensor.id} sensor={sensor} />)}
                    {filtered.length === 0 && (
                        <div style={{ gridColumn: '1/-1', padding: 'var(--s6)', textAlign: 'center', color: 'var(--text-secondary)' }}>
                            {activeTab === 'all'
                                ? 'No sensor readings yet.'
                                : `No sensors in ${ROOM_LABELS[activeTab] || 'this room'}. Assign devices on the Floor Plan page.`}
                        </div>
                    )}
                </div>
            </div>

            <style>{`
                .dash-overview-grid {
                    display: grid;
                    grid-template-columns: repeat(4, 1fr);
                    grid-auto-rows: minmax(140px, auto);
                    gap: var(--s4);
                }
                .dash-camera-card {
                    grid-column: span 2;
                    grid-row: span 2;
                    min-height: 0;
                }
                .dash-stat-card {
                    min-height: 0;
                }
                @media (max-width: 1100px) {
                    .dash-overview-grid {
                        grid-template-columns: repeat(2, 1fr);
                    }
                    .dash-camera-card {
                        grid-column: span 2;
                        grid-row: span 1;
                        aspect-ratio: 21 / 9;
                    }
                }
                @media (max-width: 640px) {
                    .dash-overview-grid {
                        grid-template-columns: 1fr;
                    }
                    .dash-camera-card {
                        grid-column: auto;
                        aspect-ratio: 16 / 10;
                    }
                }
            `}</style>
        </div>
    );
};

export default DashboardPage;
