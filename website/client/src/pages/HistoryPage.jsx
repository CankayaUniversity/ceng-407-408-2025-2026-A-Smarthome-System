import { useState, useEffect } from 'react';
import {
    XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart
} from 'recharts';
import api from '../services/api';
import { 
    TrendingUp, Calendar, Download, Activity, 
    Thermometer, Droplets, Flame, Waves, Eye, 
    Weight, Sprout, DoorOpen, Lightbulb, Wind, Volume2, Sofa, CheckCircle2
} from 'lucide-react';
import { format, parseISO } from 'date-fns';

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

/* ─── Custom Tooltip ───────────────────────────────────────────── */
const CustomTooltip = ({ active, payload, label }) => {
    if (!active || !payload?.length) return null;
    return (
        <div style={{
            background: 'rgba(15, 18, 25, 0.95)', border: '1px solid rgba(255,255,255,0.1)',
            borderRadius: 'var(--r-lg)', padding: 'var(--s4)',
            backdropFilter: 'blur(12px)', boxShadow: '0 16px 40px rgba(0,0,0,0.6)', minWidth: 160
        }}>
            <div style={{ fontSize: 'var(--size-xs)', color: 'rgba(255,255,255,0.5)', marginBottom: 'var(--s2)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                {label}
            </div>
            {payload.map(p => (
                <div key={p.dataKey} style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)' }}>
                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: p.color, boxShadow: `0 0 10px ${p.color}` }} />
                    <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-primary)', fontWeight: 600 }}>{p.name}</span>
                    <span style={{ marginLeft: 'auto', fontFamily: 'var(--font-display)', fontSize: 'var(--size-lg)', fontWeight: 800, color: p.color }}>
                        {p.value}
                    </span>
                </div>
            ))}
        </div>
    );
};

/* ─── Main Page ───────────────────────────────────────────────── */
const HistoryPage = () => {
    const [sensors, setSensors] = useState([]);
    const [selected, setSelected] = useState(null);
    const [range, setRange] = useState('7d');
    const [chartData, setChartData] = useState([]);
    const [loading, setLoading] = useState(true);
    const [fetching, setFetching] = useState(false);

    useEffect(() => {
        const fetchSensors = async () => {
            try {
                const res = await api.get('/sensors/latest');
                const raw = Array.isArray(res.data) ? res.data : (res.data.sensors || []);
                const s = raw.map(x => ({ ...x, id: x.sensorId || x.id }));
                setSensors(s);
                // Auto-select first temperature sensor if available, else first sensor
                const defaultSens = s.find(x => x.type === 'temperature') || s[0];
                if (defaultSens) setSelected(defaultSens.id);
            } catch (err) { console.error(err); }
            finally { setLoading(false); }
        };
        fetchSensors();
    }, []);

    useEffect(() => {
        if (!selected) return;
        const fetchHistory = async () => {
            setFetching(true);
            try {
                const days = range === '1d' ? 1 : range === '7d' ? 7 : 30;
                const from = new Date();
                from.setDate(from.getDate() - days);
                const res = await api.get('/sensors/history', {
                    params: { sensorId: selected, from: from.toISOString() }
                });
                const readings = res.data.readings || [];
                const isBoolean = sensors.find(s => s.id === selected)?.type === 'motion' || sensors.find(s => s.id === selected)?.type === 'door';
                
                const mapped = readings.map(r => ({
                    time: format(parseISO(r.createdAt), range === '1d' ? 'HH:mm' : (range === '7d' ? 'MMM d, HH:mm' : 'MMM d')),
                    value: isBoolean ? (parseFloat(r.value) > 0 ? 1 : 0) : parseFloat(r.value),
                    raw: r.value
                }));
                // Filter out extremely dense data for 30d by sampling if needed (recharts handles it mostly ok, but for visual clarity)
                setChartData(mapped);
            } catch (err) { console.error(err); }
            finally { setFetching(false); }
        };
        fetchHistory();
    }, [selected, range, sensors]);

    const activeSensor = sensors.find(s => s.id === selected);
    const sic = getSIC(activeSensor?.type);
    const color = sic.color;
    const Icon = sic.Icon;
    
    // Check if the sensor is boolean-type for graph formatting
    const isBooleanChart = activeSensor?.type === 'motion' || activeSensor?.type === 'door';

    // Calc stats
    const vals = chartData.map(d => d.value);
    const min = vals.length ? Math.min(...vals).toFixed(1) : '—';
    const max = vals.length ? Math.max(...vals).toFixed(1) : '—';
    const avg = vals.length ? (vals.reduce((a,b)=>a+b,0)/vals.length).toFixed(1) : '—';

    // Download CSV
    const downloadCSV = () => {
        if (!chartData.length) return;
        const csv = 'Time,Value\n' + chartData.map(d => `"${d.time}",${d.value}`).join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${activeSensor?.label || 'sensor'}_history_${range}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    if (loading) return (
        <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading telemetry</div></div>
    );

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s6)', height: '100%' }}>
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s2)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Analytics</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>Historical telemetry & trends</p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--text-primary)', background: 'var(--bg-surface)', border: '1px solid var(--border-soft)', borderRadius: 'var(--r-full)', padding: '6px 14px', fontWeight: 600 }}>
                    <Activity size={14} style={{ color: 'var(--violet-core)' }} />
                    {sensors.length} Data Streams
                </div>
            </div>

            {/* Premium Selector Strip */}
            <div style={{ display: 'flex', gap: 'var(--s3)', overflowX: 'auto', paddingBottom: 'var(--s3)', margin: '0 -1px', 
                          /* ensure scroll is visible on desktop */ scrollbarWidth: 'thin', scrollbarColor: 'rgba(255,255,255,0.2) transparent' }}>
                {sensors.map(s => {
                    const isSel = s.id === selected;
                    const sSic = getSIC(s.type);
                    const SIcon = sSic.Icon;
                    return (
                        <div
                            key={s.id}
                            onClick={() => setSelected(s.id)}
                            style={{
                                display: 'flex', alignItems: 'center', gap: 'var(--s3)',
                                padding: '10px 14px', borderRadius: 'var(--r-lg)',
                                background: isSel ? `linear-gradient(135deg, ${sSic.color}25, transparent)` : 'var(--bg-surface)',
                                border: `1px solid ${isSel ? sSic.color + '80' : 'var(--border-soft)'}`,
                                cursor: 'pointer', minWidth: 160, flexShrink: 0,
                                transition: 'all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1)',
                                boxShadow: isSel ? `inset 0 0 20px ${sSic.color}15, 0 4px 12px rgba(0,0,0,0.2)` : 'none',
                                filter: (!isSel && selected) ? 'opacity(0.6)' : 'none',
                            }}
                            onMouseEnter={e => { if(!isSel) { e.currentTarget.style.filter = 'opacity(1)'; e.currentTarget.style.borderColor = 'var(--text-muted)'; } }}
                            onMouseLeave={e => { if(!isSel) { e.currentTarget.style.filter = selected ? 'opacity(0.6)' : 'none'; e.currentTarget.style.borderColor = 'var(--border-soft)'; } }}
                        >
                            <div style={{ width: 32, height: 32, borderRadius: 'var(--r-md)', background: isSel ? `${sSic.color}30` : `${sSic.color}15`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: sSic.color }}>
                                <SIcon size={16} />
                            </div>
                            <div>
                                <div style={{ fontSize: 13, fontWeight: 700, color: isSel ? 'white' : 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: 100 }}>{s.label}</div>
                                <div style={{ fontSize: 10, color: 'var(--text-muted)', textTransform: 'uppercase' }}>{s.type}</div>
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* Chart Area */}
            <div style={{
                background: 'var(--bg-surface)', borderRadius: 'var(--r-2xl)', border: '1px solid var(--border-soft)',
                padding: 'var(--s6)', position: 'relative', overflow: 'hidden', flex: 1, minHeight: 450,
                display: 'flex', flexDirection: 'column'
            }}>
                {/* Background glow behind chart */}
                <div style={{ position: 'absolute', top: '-10%', left: '20%', width: '60%', height: '50%', background: `${color}10`, filter: 'blur(100px)', borderRadius: '50%', pointerEvents: 'none' }} />

                {/* Chart Header & Controls */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--s6)', position: 'relative', zIndex: 10 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)' }}>
                        <div style={{ width: 48, height: 48, borderRadius: 'var(--r-xl)', background: `${color}15`, border: `1px solid ${color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', color, boxShadow: `0 0 20px ${color}20` }}>
                            <Icon size={24} />
                        </div>
                        <div>
                            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'white' }}>{activeSensor?.label}</h2>
                            <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)' }}>{activeSensor?.deviceName} · {activeSensor?.type}</p>
                        </div>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)', alignItems: 'flex-end' }}>
                        {/* Segmented Time Control */}
                        <div style={{ display: 'flex', background: 'var(--bg-base)', borderRadius: 'var(--r-full)', padding: 4, border: '1px solid var(--border-dim)' }}>
                            {[{ id: '1d', label: '24h' }, { id: '7d', label: '7 Days' }, { id: '30d', label: '30 Days' }].map(r => (
                                <button
                                    key={r.id}
                                    onClick={() => setRange(r.id)}
                                    style={{
                                        padding: '6px 16px', borderRadius: 'var(--r-full)', border: 'none',
                                        background: range === r.id ? 'var(--text-primary)' : 'transparent',
                                        color: range === r.id ? 'var(--bg-base)' : 'var(--text-muted)',
                                        fontSize: 12, fontWeight: 700, cursor: 'pointer', transition: 'all 0.2s',
                                    }}
                                >
                                    {r.label}
                                </button>
                            ))}
                        </div>
                        <button onClick={downloadCSV} style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', fontSize: 12, display: 'flex', alignItems: 'center', gap: 4, cursor: 'pointer', transition: 'color 0.2s' }} onMouseEnter={e => e.currentTarget.style.color='white'} onMouseLeave={e => e.currentTarget.style.color='var(--text-muted)'}>
                            <Download size={14} /> Export CSV
                        </button>
                    </div>
                </div>

                {/* The Graph */}
                <div style={{ flex: 1, position: 'relative', minHeight: 250 }}>
                    {fetching ? (
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 'var(--s3)' }}>
                            <div className="spinner" style={{ borderColor: `${color}40`, borderTopColor: color }} />
                            <div style={{ color: 'var(--text-muted)', fontSize: 'var(--size-sm)' }}>Aggregating data...</div>
                        </div>
                    ) : chartData.length === 0 ? (
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 'var(--s3)' }}>
                            <div style={{ width: 64, height: 64, borderRadius: '50%', background: 'rgba(255,255,255,0.02)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'rgba(255,255,255,0.1)' }}>
                                <Activity size={32} />
                            </div>
                            <div style={{ color: 'var(--text-muted)', fontWeight: 600 }}>No telemetry for this period</div>
                        </div>
                    ) : (
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={chartData} margin={{ top: 20, right: 0, left: -20, bottom: 0 }}>
                                <defs>
                                    <linearGradient id="colorGrad" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="0%" stopColor={color} stopOpacity={0.4} />
                                        <stop offset="100%" stopColor={color} stopOpacity={0.0} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="4 4" stroke="rgba(255,255,255,0.04)" vertical={false} />
                                <XAxis 
                                    dataKey="time" 
                                    tick={{ fill: 'var(--text-muted)', fontSize: 10, fontWeight: 600 }} 
                                    axisLine={{ stroke: 'rgba(255,255,255,0.1)' }} 
                                    tickLine={false} 
                                    tickMargin={12}
                                    minTickGap={20}
                                />
                                <YAxis 
                                    tick={{ fill: 'var(--text-muted)', fontSize: 10, fontWeight: 600 }} 
                                    axisLine={false} 
                                    tickLine={false} 
                                    tickMargin={8}
                                    domain={isBooleanChart ? [-0.2, 1.2] : ['auto', 'auto']}
                                />
                                <Tooltip content={<CustomTooltip />} cursor={{ stroke: 'rgba(255,255,255,0.1)', strokeWidth: 1, strokeDasharray: '4 4' }} />
                                <Area 
                                    type="monotone" 
                                    dataKey="value" 
                                    name={activeSensor?.label} 
                                    stroke={color} 
                                    strokeWidth={3} 
                                    fill="url(#colorGrad)" 
                                    dot={false}
                                    activeDot={{ r: 6, fill: color, stroke: '#111318', strokeWidth: 2, boxShadow: `0 0 10px ${color}` }} 
                                    animationDuration={500}
                                />
                            </AreaChart>
                        </ResponsiveContainer>
                    )}
                </div>

                {/* Stats Footer */}
                {chartData.length > 0 && !fetching && (
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--s4)', marginTop: 'var(--s6)', paddingTop: 'var(--s6)', borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                        {[
                            { label: 'Minimum', val: min, unit: activeSensor?.unit },
                            { label: 'Maximum', val: max, unit: activeSensor?.unit },
                            { label: 'Average', val: avg, unit: activeSensor?.unit },
                            { label: 'Readings', val: chartData.length, unit: '' },
                        ].map((stat, i) => (
                            <div key={i} style={{ padding: '0 var(--s2)' }}>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>{stat.label}</div>
                                <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
                                    <span style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'white' }}>{stat.val}</span>
                                    {stat.unit && <span style={{ fontSize: 12, color: color, fontWeight: 700 }}>{stat.unit}</span>}
                                </div>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};

export default HistoryPage;
