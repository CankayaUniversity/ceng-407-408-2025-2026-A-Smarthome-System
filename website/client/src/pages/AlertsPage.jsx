import { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';
import { ShieldAlert, Filter, CheckCircle2 } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { getEventMeta, getEventToneStyle, formatPriority, priorityBadgeClass } from '../utils/eventLabels';

const AlertsPage = () => {
    const [alerts, setAlerts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filterStatus, setFilterStatus] = useState('all');

    const fetchAlerts = async () => {
        setLoading(true);
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
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)', flexWrap: 'wrap', gap: 'var(--s4)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Security Alerts</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginTop: 'var(--s2)', maxWidth: 480 }}>
                        Smoke, water, and visitor events from your home. Acknowledge items once you have checked them.
                    </p>
                </div>
                <div style={{ display: 'flex', gap: 'var(--s3)' }}>
                    <div className="card" style={{ padding: 'var(--s3) var(--s5)', textAlign: 'center', minWidth: 88 }}>
                        <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: activeCount > 0 ? 'var(--crimson-core)' : 'var(--text-primary)' }}>{activeCount}</div>
                        <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.08em', marginTop: 2 }}>Active</div>
                    </div>
                    <div className="card" style={{ padding: 'var(--s3) var(--s5)', textAlign: 'center', minWidth: 88 }}>
                        <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: criticalCount > 0 ? 'var(--amber-core)' : 'var(--text-primary)' }}>{criticalCount}</div>
                        <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.08em', marginTop: 2 }}>Critical</div>
                    </div>
                </div>
            </div>

            <div style={{ display: 'flex', gap: 'var(--s2)', alignItems: 'center', marginBottom: 'var(--s6)', flexWrap: 'wrap' }}>
                <Filter size={14} style={{ color: 'var(--text-secondary)' }} />
                {[
                    { id: 'all', label: 'All' },
                    { id: 'active', label: 'Needs attention' },
                    { id: 'acknowledged', label: 'Resolved' },
                ].map(s => (
                    <button key={s.id} className={`chip ${filterStatus === s.id ? 'chip-active' : 'chip-inactive'}`}
                        onClick={() => setFilterStatus(s.id)}>
                        {s.label}
                    </button>
                ))}
            </div>

            {loading ? (
                <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading alerts</div></div>
            ) : alerts.length === 0 ? (
                <div className="card empty-state">
                    <div className="empty-state-icon"><ShieldAlert size={48} /></div>
                    <h3>All clear</h3>
                    <p>No alerts match your filters. Your home looks secure right now.</p>
                </div>
            ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)' }}>
                    {alerts.map((alert, i) => {
                        const meta = getEventMeta(alert.event_type);
                        const tone = getEventToneStyle(meta.tone);
                        const Icon = meta.icon;
                        const isActive = !alert.acknowledged_at;
                        return (
                            <div
                                key={alert.id}
                                className="card"
                                style={{
                                    display: 'flex',
                                    alignItems: 'flex-start',
                                    gap: 'var(--s4)',
                                    padding: 'var(--s4) var(--s5)',
                                    borderColor: isActive ? tone.border : 'var(--border-soft)',
                                    background: isActive ? tone.bg : 'var(--bg-surface)',
                                    animation: `fadeIn 0.4s var(--ease-out) ${i * 40}ms both`,
                                    opacity: 0,
                                }}
                            >
                                <div style={{
                                    width: 44, height: 44, borderRadius: 'var(--r-lg)', flexShrink: 0,
                                    background: 'var(--bg-base)', border: `1px solid ${tone.border}`,
                                    display: 'flex', alignItems: 'center', justifyContent: 'center', color: tone.color,
                                }}>
                                    <Icon size={20} />
                                </div>
                                <div style={{ flex: 1, minWidth: 0 }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', marginBottom: 'var(--s1)', flexWrap: 'wrap' }}>
                                        <span style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--size-base)', letterSpacing: '-0.01em' }}>
                                            {meta.title}
                                        </span>
                                        <span className={`badge ${priorityBadgeClass(alert.priority)}`}>
                                            {formatPriority(alert.priority)}
                                        </span>
                                        {!isActive && <span className="badge badge-success">Resolved</span>}
                                    </div>
                                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', margin: '0 0 var(--s2)', lineHeight: 1.5 }}>
                                        {alert.message || meta.short}
                                    </p>
                                    <span style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>
                                        {alert.created_at ? formatDistanceToNow(new Date(alert.created_at), { addSuffix: true }) : 'Unknown time'}
                                    </span>
                                </div>
                                <div style={{ flexShrink: 0, alignSelf: 'center' }}>
                                    {isActive ? (
                                        <button className="btn btn-primary btn-sm" onClick={() => acknowledge(alert.id)} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                                            <CheckCircle2 size={14} /> Acknowledge
                                        </button>
                                    ) : (
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--jade-core)', fontWeight: 600 }}>
                                            <CheckCircle2 size={14} /> Done
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
