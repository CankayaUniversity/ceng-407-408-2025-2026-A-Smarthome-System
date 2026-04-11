import { useState, useEffect } from 'react';
import { XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart } from 'recharts';
import { supabase } from '../services/supabase';
import { TrendingUp, Download, Activity, Thermometer, Droplets, Flame, Waves, Eye } from 'lucide-react';
import { format } from 'date-fns';

const SIC = {
    temperature: { Icon: Thermometer, color: '#ff6b35' },
    humidity: { Icon: Droplets, color: '#00d4ff' },
    smoke: { Icon: Flame, color: '#ff3b5c' },
    water: { Icon: Waves, color: '#3b9eff' },
    motion: { Icon: Eye, color: '#9b59ff' },
};
function getSIC(type) { return SIC[type?.toLowerCase()] || { Icon: Activity, color: '#8892a4' }; }

const CustomTooltip = ({ active, payload, label }) => {
    if (!active || !payload?.length) return null;
    return (
        <div style={{ background: 'rgba(15, 18, 25, 0.95)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 'var(--r-lg)', padding: 'var(--s4)', backdropFilter: 'blur(12px)', boxShadow: '0 16px 40px rgba(0,0,0,0.6)', minWidth: 160 }}>
            <div style={{ fontSize: 'var(--size-xs)', color: 'rgba(255,255,255,0.5)', marginBottom: 'var(--s2)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
            {payload.map(p => (
                <div key={p.dataKey} style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)' }}>
                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: p.color, boxShadow: `0 0 10px ${p.color}` }} />
                    <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-primary)', fontWeight: 600 }}>{p.name}</span>
                    <span style={{ marginLeft: 'auto', fontFamily: 'var(--font-display)', fontSize: 'var(--size-lg)', fontWeight: 800, color: p.color }}>{p.value}</span>
                </div>
            ))}
        </div>
    );
};

const HistoryPage = () => {
    const [sensorTypes, setSensorTypes] = useState([]);
    const [selected, setSelected] = useState(null);
    const [range, setRange] = useState('7d');
    const [chartData, setChartData] = useState([]);
    const [loading, setLoading] = useState(true);
    const [fetching, setFetching] = useState(false);

    useEffect(() => {
        const fetchTypes = async () => {
            const { data } = await supabase
                .from('sensor_readings')
                .select('sensor_type')
                .order('recorded_at', { ascending: false })
                .limit(200);
            const unique = [...new Set((data || []).map(r => r.sensor_type))];
            setSensorTypes(unique);
            if (unique.length > 0) setSelected(unique.includes('temperature') ? 'temperature' : unique[0]);
            setLoading(false);
        };
        fetchTypes();
    }, []);

    useEffect(() => {
        if (!selected) return;
        const fetchHistory = async () => {
            setFetching(true);
            try {
                const days = range === '1d' ? 1 : range === '7d' ? 7 : 30;
                const from = new Date();
                from.setDate(from.getDate() - days);
                const { data } = await supabase
                    .from('sensor_readings')
                    .select('*')
                    .eq('sensor_type', selected)
                    .gte('recorded_at', from.toISOString())
                    .order('recorded_at', { ascending: true })
                    .limit(1000);

                const mapped = (data || []).map(r => ({
                    time: format(new Date(r.recorded_at), range === '1d' ? 'HH:mm' : (range === '7d' ? 'MMM d, HH:mm' : 'MMM d')),
                    value: r.numeric_value,
                }));
                setChartData(mapped);
            } catch (err) { console.error(err); }
            finally { setFetching(false); }
        };
        fetchHistory();
    }, [selected, range]);

    const sic = getSIC(selected);
    const color = sic.color;
    const Icon = sic.Icon;

    const vals = chartData.map(d => d.value);
    const min = vals.length ? Math.min(...vals).toFixed(1) : '\u2014';
    const max = vals.length ? Math.max(...vals).toFixed(1) : '\u2014';
    const avg = vals.length ? (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1) : '\u2014';

    const downloadCSV = () => {
        if (!chartData.length) return;
        const csv = 'Time,Value\n' + chartData.map(d => `"${d.time}",${d.value}`).join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url; a.download = `${selected}_history_${range}.csv`; a.click();
        URL.revokeObjectURL(url);
    };

    if (loading) return <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading telemetry</div></div>;

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s6)', height: '100%' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s2)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Analytics</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s1)' }}>Historical telemetry & trends</p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--text-primary)', background: 'var(--bg-surface)', border: '1px solid var(--border-soft)', borderRadius: 'var(--r-full)', padding: '6px 14px', fontWeight: 600 }}>
                    <Activity size={14} style={{ color: 'var(--violet-core)' }} />
                    {sensorTypes.length} Data Streams
                </div>
            </div>

            <div style={{ display: 'flex', gap: 'var(--s3)', overflowX: 'auto', paddingBottom: 'var(--s3)' }}>
                {sensorTypes.map(type => {
                    const isSel = type === selected;
                    const sSic = getSIC(type);
                    const SIcon = sSic.Icon;
                    return (
                        <div key={type} onClick={() => setSelected(type)}
                            style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: '10px 14px', borderRadius: 'var(--r-lg)', background: isSel ? `linear-gradient(135deg, ${sSic.color}25, transparent)` : 'var(--bg-surface)', border: `1px solid ${isSel ? sSic.color + '80' : 'var(--border-soft)'}`, cursor: 'pointer', minWidth: 140, flexShrink: 0, transition: 'all 0.2s', filter: (!isSel && selected) ? 'opacity(0.6)' : 'none' }}>
                            <div style={{ width: 32, height: 32, borderRadius: 'var(--r-md)', background: `${sSic.color}15`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: sSic.color }}>
                                <SIcon size={16} />
                            </div>
                            <div>
                                <div style={{ fontSize: 13, fontWeight: 700, color: isSel ? 'white' : 'var(--text-primary)', textTransform: 'capitalize' }}>{type}</div>
                            </div>
                        </div>
                    );
                })}
            </div>

            <div style={{ background: 'var(--bg-surface)', borderRadius: 'var(--r-2xl)', border: '1px solid var(--border-soft)', padding: 'var(--s6)', flex: 1, minHeight: 450, display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--s6)', position: 'relative', zIndex: 10 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)' }}>
                        <div style={{ width: 48, height: 48, borderRadius: 'var(--r-xl)', background: `${color}15`, border: `1px solid ${color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
                            <Icon size={24} />
                        </div>
                        <div>
                            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'white', textTransform: 'capitalize' }}>{selected}</h2>
                        </div>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)', alignItems: 'flex-end' }}>
                        <div style={{ display: 'flex', background: 'var(--bg-base)', borderRadius: 'var(--r-full)', padding: 4, border: '1px solid var(--border-dim)' }}>
                            {[{ id: '1d', label: '24h' }, { id: '7d', label: '7 Days' }, { id: '30d', label: '30 Days' }].map(r => (
                                <button key={r.id} onClick={() => setRange(r.id)}
                                    style={{ padding: '6px 16px', borderRadius: 'var(--r-full)', border: 'none', background: range === r.id ? 'var(--text-primary)' : 'transparent', color: range === r.id ? 'var(--bg-base)' : 'var(--text-muted)', fontSize: 12, fontWeight: 700, cursor: 'pointer', transition: 'all 0.2s' }}>
                                    {r.label}
                                </button>
                            ))}
                        </div>
                        <button onClick={downloadCSV} style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', fontSize: 12, display: 'flex', alignItems: 'center', gap: 4, cursor: 'pointer' }}>
                            <Download size={14} /> Export CSV
                        </button>
                    </div>
                </div>

                <div style={{ flex: 1, position: 'relative', minHeight: 250 }}>
                    {fetching ? (
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 'var(--s3)' }}>
                            <div className="spinner" style={{ borderColor: `${color}40`, borderTopColor: color }} />
                            <div style={{ color: 'var(--text-muted)', fontSize: 'var(--size-sm)' }}>Aggregating data...</div>
                        </div>
                    ) : chartData.length === 0 ? (
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 'var(--s3)' }}>
                            <Activity size={32} style={{ color: 'rgba(255,255,255,0.1)' }} />
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
                                <XAxis dataKey="time" tick={{ fill: 'var(--text-muted)', fontSize: 10 }} axisLine={{ stroke: 'rgba(255,255,255,0.1)' }} tickLine={false} minTickGap={20} />
                                <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 10 }} axisLine={false} tickLine={false} />
                                <Tooltip content={<CustomTooltip />} />
                                <Area type="monotone" dataKey="value" name={selected} stroke={color} strokeWidth={3} fill="url(#colorGrad)" dot={false} animationDuration={500} />
                            </AreaChart>
                        </ResponsiveContainer>
                    )}
                </div>

                {chartData.length > 0 && !fetching && (
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 'var(--s4)', marginTop: 'var(--s6)', paddingTop: 'var(--s6)', borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                        {[{ label: 'Minimum', val: min }, { label: 'Maximum', val: max }, { label: 'Average', val: avg }, { label: 'Readings', val: chartData.length }].map((stat, i) => (
                            <div key={i}>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>{stat.label}</div>
                                <span style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'white' }}>{stat.val}</span>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};

export default HistoryPage;
