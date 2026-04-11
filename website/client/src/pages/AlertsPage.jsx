import { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';
import {
    ShieldAlert, Filter, CheckCircle2, Flame,
    Waves, Eye, AlertTriangle
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const ALERT_ICONS = {
    fire_alert: { icon: Flame, color: 'var(--crimson-core)', bg: 'rgba(255,59,92,0.12)' },
    flood: { icon: Waves, color: 'var(--cyan-core)', bg: 'rgba(0,212,255,0.12)' },
    stranger_detected: { icon: Eye, color: 'var(--violet-core)', bg: 'rgba(155,89,255,0.12)' },
    low_moisture: { icon: Waves, color: 'var(--cyan-core)', bg: 'rgba(0,212,255,0.12)' },
    default: { icon: AlertTriangle, color: 'var(--text-muted)', bg: 'var(--border-dim)' },
};
function getAlertIcon(type) {
    return ALERT_ICONS[type?.toLowerCase()] || ALERT_ICONS.default;
}

const AlertsPage = () => {
    const [alerts, setAlerts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filterStatus, setFilterStatus] = useState('all');

    const fetchAlerts = async () => {
        try {
            let query = supabase.from('events').select('*').order('created_at', { ascending: false }).limit(50);
            if (filterStatus === 'active') query = query.is('acknowledged_at', null);
            if (filterStatus === 'acknowledged') query = query.not('acknowledged_at', 'is', null);
            const { data } = await query;
            setAlerts(data || []);
        } catch (err) { console.error(err); }
        finally { setLoading(false); }
    };

    useEffect(() => { fetchAlerts(); }, [filterStatus]);

    const acknowledge = async (id) => {
        try {
            await supabase.from('events').update({ acknowledged_at: new Date().toISOString(), status: 'acknowledged' }).eq('id', id);
            setAlerts(prev => prev.map(a => a.id === id ? { ...a, acknowledged_at: new Date().toISOString(), status: 'acknowledged' } : a));
        } catch (err) { console.error(err); }
    };

    const activeCount = alerts.filter(a => !a.acknowledged_at).length;
    const criticalCount = alerts.filter(a => a.priority === 'critical' && !a.acknowledged_at).length;

    return (
        <div>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Security Alerts</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>Environment warnings and intrusion events</p>
                </div>
                <div style={{ display: 'flex', gap: 'var(--s3)' }}>
                    {activeCount > 0 && (
                        <div style={{ background: 'rgba(255,59,92,0.08)', border: '1px solid rgba(255,59,92,0.2)', borderRadius: 'var(--r-lg)', padding: 'var(--s3) var(--s4)', textAlign: 'center' }}>
                            <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'var(--crimson-core)' }}>{activeCount}</div>
                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Active</div>
                        </div>
                    )}
                    {criticalCount > 0 && (
                        <div style={{ background: 'rgba(255,176,32,0.08)', border: '1px solid rgba(255,176,32,0.2)', borderRadius: 'var(--r-lg)', padding: 'var(--s3) var(--s4)', textAlign: 'center' }}>
                            <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'var(--amber-core)' }}>{criticalCount}</div>
                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Critical</div>
                        </div>
                    )}
                </div>
            </div>

            <div style={{ display: 'flex', gap: 'var(--s2)', alignItems: 'center', marginBottom: 'var(--s6)' }}>
                <Filter size={14} style={{ color: 'var(--text-muted)' }} />
                {['all', 'active', 'acknowledged'].map(s => (
                    <button key={s} className={`chip ${filterStatus === s ? 'chip-active' : 'chip-inactive'}`}
                        onClick={() => setFilterStatus(s)}>
                        {s.charAt(0).toUpperCase() + s.slice(1)}
                    </button>
                ))}
            </div>

            {loading ? (
                <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading alerts</div></div>
            ) : alerts.length === 0 ? (
                <div className="card empty-state">
                    <div className="empty-state-icon"><ShieldAlert size={48} /></div>
                    <h3>All Clear</h3>
                    <p>No alerts match the current filters. Your home is secure.</p>
                </div>
            ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)' }}>
                    {alerts.map((alert, i) => {
                        const { icon: Icon, color, bg } = getAlertIcon(alert.event_type);
                        const isActive = !alert.acknowledged_at;
                        const isCritical = alert.priority === 'critical';
                        return (
                            <div key={alert.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)', padding: 'var(--s4) var(--s5)', borderColor: isActive && isCritical ? 'rgba(255,59,92,0.25)' : undefined, animation: `fadeIn 0.4s var(--ease-out) ${i * 50}ms both`, opacity: 0 }}>
                                <div style={{ width: 44, height: 44, borderRadius: 'var(--r-lg)', background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', color, flexShrink: 0 }}>
                                    <Icon size={20} />
                                </div>
                                <div style={{ flex: 1, minWidth: 0 }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', marginBottom: 'var(--s1)' }}>
                                        <span style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--size-base)', letterSpacing: '-0.01em' }}>{alert.event_type?.toUpperCase()}</span>
                                        <span className={`badge ${isCritical ? 'badge-danger' : 'badge-warning'}`}>{alert.priority}</span>
                                    </div>
                                    <div style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginBottom: 'var(--s1)' }}>{alert.message}</div>
                                    <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                                        {alert.created_at ? formatDistanceToNow(new Date(alert.created_at), { addSuffix: true }) : 'Unknown time'}
                                    </div>
                                </div>
                                <div style={{ flexShrink: 0 }}>
                                    {isActive ? (
                                        <button className="btn btn-ghost btn-sm" onClick={() => acknowledge(alert.id)} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                            <CheckCircle2 size={14} /> Acknowledge
                                        </button>
                                    ) : (
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--jade-core)' }}>
                                            <CheckCircle2 size={14} /> Resolved
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
