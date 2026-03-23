import { useState, useEffect } from 'react';
import api from '../services/api';
import {
    ShieldAlert, Filter, CheckCircle2, Clock, Flame,
    Waves, Eye, AlertTriangle, ChevronDown
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const ALERT_ICONS = {
    fire: { icon: Flame, color: 'var(--crimson-core)', bg: 'rgba(255,59,92,0.12)' },
    flood: { icon: Waves, color: 'var(--cyan-core)', bg: 'rgba(0,212,255,0.12)' },
    intrusion: { icon: Eye, color: 'var(--violet-core)', bg: 'rgba(155,89,255,0.12)' },
    water_leak: { icon: Waves, color: 'var(--cyan-core)', bg: 'rgba(0,212,255,0.12)' },
    smoke: { icon: Flame, color: 'var(--amber-core)', bg: 'rgba(255,176,32,0.12)' },
    default: { icon: AlertTriangle, color: 'var(--text-muted)', bg: 'var(--border-dim)' },
};

function getAlertIcon(type) {
    return ALERT_ICONS[type?.toLowerCase()] || ALERT_ICONS.default;
}

const AlertsPage = () => {
    const [alerts, setAlerts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filterStatus, setFilterStatus] = useState('all');
    const [filterType, setFilterType] = useState('all');
    const [filterLocation, setFilterLocation] = useState('all');

    const LOCATIONS = ['all', 'Living Room', 'Kitchen', 'Master Bedroom', 'Entrance', 'Bathroom', 'Garden'];

    const fetchAlerts = async () => {
        try {
            const params = {};
            if (filterStatus !== 'all') params.status = filterStatus;
            if (filterType !== 'all') params.type = filterType;
            const res = await api.get('/alerts', { params });
            const raw = Array.isArray(res.data) ? res.data : (res.data.alerts || []);
            setAlerts(raw);
        } catch (err) { console.error(err); }
        finally { setLoading(false); }
    };

    useEffect(() => { fetchAlerts(); }, [filterStatus, filterType]);

    // Client-side location filter
    const filteredAlerts = filterLocation === 'all'
        ? alerts
        : alerts.filter(a => (a.device?.location || '').includes(filterLocation));

    const acknowledge = async (id) => {
        try {
            await api.patch(`/alerts/${id}/acknowledge`);
            setAlerts(prev => prev.map(a =>
                a.id === id ? { ...a, status: 'acknowledged', acknowledgedAt: new Date() } : a
            ));
        } catch (err) { console.error(err); }
    };

    const activeCount = alerts.filter(a => a.status === 'active' || !a.acknowledged).length;
    const criticalCount = alerts.filter(a => a.severity === 'critical' && (a.status === 'active' || !a.acknowledged)).length;

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
                    }}>Security Alerts</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>
                        Environment warnings and intrusion events
                    </p>
                </div>

                {/* Stats */}
                <div style={{ display: 'flex', gap: 'var(--s3)' }}>
                    {activeCount > 0 && (
                        <div style={{
                            background: 'rgba(255,59,92,0.08)', border: '1px solid rgba(255,59,92,0.2)',
                            borderRadius: 'var(--r-lg)', padding: 'var(--s3) var(--s4)', textAlign: 'center'
                        }}>
                            <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'var(--crimson-core)' }}>{activeCount}</div>
                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Active</div>
                        </div>
                    )}
                    {criticalCount > 0 && (
                        <div style={{
                            background: 'rgba(255,176,32,0.08)', border: '1px solid rgba(255,176,32,0.2)',
                            borderRadius: 'var(--r-lg)', padding: 'var(--s3) var(--s4)', textAlign: 'center'
                        }}>
                            <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'var(--amber-core)' }}>{criticalCount}</div>
                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Critical</div>
                        </div>
                    )}
                </div>
            </div>

            {/* Filters row 1 – Status + Type */}
            <div style={{ display: 'flex', gap: 'var(--s3)', marginBottom: 'var(--s3)', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', gap: 'var(--s2)', alignItems: 'center' }}>
                    <Filter size={14} style={{ color: 'var(--text-muted)' }} />
                    {['all', 'active', 'acknowledged'].map(s => (
                        <button
                            key={s}
                            className={`chip ${filterStatus === s ? 'chip-active' : 'chip-inactive'}`}
                            onClick={() => setFilterStatus(s)}
                        >
                            {s.charAt(0).toUpperCase() + s.slice(1)}
                        </button>
                    ))}
                </div>

                <div style={{ display: 'flex', gap: 'var(--s2)', marginLeft: 'auto' }}>
                    {['all', 'fire', 'flood', 'intrusion', 'smoke'].map(t => (
                        <button
                            key={t}
                            className={`chip ${filterType === t ? 'chip-active' : 'chip-inactive'}`}
                            onClick={() => setFilterType(t)}
                        >
                            {t.charAt(0).toUpperCase() + t.slice(1)}
                        </button>
                    ))}
                </div>
            </div>

            {/* Filters row 2 – Location */}
            <div style={{ display: 'flex', gap: 'var(--s2)', marginBottom: 'var(--s6)', flexWrap: 'wrap', alignItems: 'center' }}>
                <span style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', fontWeight: 600 }}>Room:</span>
                {LOCATIONS.map(loc => (
                    <button
                        key={loc}
                        className={`chip ${filterLocation === loc ? 'chip-active' : 'chip-inactive'}`}
                        onClick={() => setFilterLocation(loc)}
                    >
                        {loc === 'all' ? 'All rooms' : loc}
                    </button>
                ))}
            </div>

            {/* Content */}
            {loading ? (
                <div className="loading-container">
                    <div className="spinner" />
                    <div className="loading-text">Loading alerts</div>
                </div>
            ) : filteredAlerts.length === 0 ? (
                <div className="card empty-state">
                    <div className="empty-state-icon"><ShieldAlert size={48} /></div>
                    <h3>All Clear</h3>
                    <p>No alerts match the current filters. Your home is secure.</p>
                </div>
            ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)' }}>
                    {filteredAlerts.map((alert, i) => {
                        const { icon: Icon, color, bg } = getAlertIcon(alert.type);
                        const isActive = alert.status === 'active';
                        const isCritical = alert.severity === 'critical';

                        return (
                            <div
                                key={alert.id}
                                className="card"
                                style={{
                                    display: 'flex', alignItems: 'center', gap: 'var(--s4)',
                                    padding: 'var(--s4) var(--s5)',
                                    borderColor: isActive && isCritical ? 'rgba(255,59,92,0.25)' : undefined,
                                    animation: `fadeIn 0.4s var(--ease-out) ${i * 50}ms both`,
                                    opacity: 0,
                                }}
                            >
                                {/* Icon */}
                                <div style={{
                                    width: 44, height: 44, borderRadius: 'var(--r-lg)',
                                    background: bg, display: 'flex', alignItems: 'center',
                                    justifyContent: 'center', color, flexShrink: 0
                                }}>
                                    <Icon size={20} />
                                </div>

                                {/* Info */}
                                <div style={{ flex: 1, minWidth: 0 }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', marginBottom: 'var(--s1)' }}>
                                        <span style={{
                                            fontFamily: 'var(--font-display)', fontWeight: 700,
                                            fontSize: 'var(--size-base)', letterSpacing: '-0.01em'
                                        }}>
                                            {alert.type?.toUpperCase()}
                                        </span>
                                        <span className={`badge ${isCritical ? 'badge-danger' : 'badge-warning'}`}>
                                            {alert.severity}
                                        </span>
                                    </div>
                                    <div style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginBottom: 'var(--s1)' }}>
                                        {alert.message}
                                    </div>
                                    <div style={{ display: 'flex', gap: 'var(--s4)', fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                                        <span>{alert.device?.name || 'Unknown device'}</span>
                                        {alert.device?.location && (
                                            <><span>·</span>
                                                <span style={{ color: 'var(--text-secondary)', background: 'var(--border-dim)', padding: '0 6px', borderRadius: 'var(--r-full)', fontSize: 10 }}>
                                                    📍 {alert.device.location}
                                                </span></>
                                        )}
                                        <span>·</span>
                                        <span>
                                            {alert.createdAt
                                                ? formatDistanceToNow(new Date(alert.createdAt), { addSuffix: true })
                                                : 'Unknown time'}
                                        </span>
                                    </div>
                                </div>

                                {/* Status / Action */}
                                <div style={{ flexShrink: 0 }}>
                                    {isActive ? (
                                        <button
                                            className="btn btn-ghost btn-sm"
                                            onClick={() => acknowledge(alert.id)}
                                            style={{ display: 'flex', alignItems: 'center', gap: 6 }}
                                        >
                                            <CheckCircle2 size={14} />
                                            Acknowledge
                                        </button>
                                    ) : (
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--jade-core)' }}>
                                            <CheckCircle2 size={14} />
                                            Resolved
                                        </div>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );
};

export default AlertsPage;
