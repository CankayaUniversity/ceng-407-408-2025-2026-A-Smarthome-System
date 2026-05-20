import { useState, useEffect, useMemo } from 'react';
import { XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Area, AreaChart, BarChart, Bar } from 'recharts';
import { supabase } from '../services/supabase';
import { TrendingUp, Download, Activity } from 'lucide-react';
import { format, subDays } from 'date-fns';
import {
    getSensorConfig,
    normalizeSensorType,
    formatSensorDisplayValue,
} from '../utils/sensorConfig';

const RANGE_OPTIONS = [
    { id: '1d', label: '24h', days: 1 },
    { id: '7d', label: '7 Days', days: 7 },
    { id: '30d', label: '30 Days', days: 30 },
];

const ANALYTICS_TYPES = ['temperature', 'humidity', 'smoke', 'soil_moisture'];

function downsamplePoints(rows, maxPoints = 120) {
    if (rows.length <= maxPoints) return rows;
    const bucket = Math.ceil(rows.length / maxPoints);
    const out = [];
    for (let i = 0; i < rows.length; i += bucket) {
        const slice = rows.slice(i, i + bucket);
        const avg = slice.reduce((s, r) => s + r.value, 0) / slice.length;
        out.push({
            time: slice[slice.length - 1].time,
            timeFull: slice[slice.length - 1].timeFull,
            value: Math.round(avg * 100) / 100,
        });
    }
    return out;
}

function bucketBooleanSeries(rows, rangeDays) {
    if (!rows.length) return { chartData: [], dryPct: null };
    const dryCount = rows.filter(r => r.value >= 0.5).length;
    const dryPct = Math.round((dryCount / rows.length) * 100);
    const bucketMs = rangeDays <= 1 ? 3600000 : rangeDays <= 7 ? 86400000 : 86400000;
    const buckets = new Map();
    rows.forEach(r => {
        const t = new Date(r.recordedAt).getTime();
        const key = Math.floor(t / bucketMs) * bucketMs;
        if (!buckets.has(key)) buckets.set(key, { dry: 0, total: 0, ts: key });
        const b = buckets.get(key);
        b.total += 1;
        if (r.value >= 0.5) b.dry += 1;
    });
    const chartData = [...buckets.values()]
        .sort((a, b) => a.ts - b.ts)
        .map(b => ({
            time: format(new Date(b.ts), rangeDays <= 1 ? 'HH:mm' : 'MMM d'),
            timeFull: new Date(b.ts).toISOString(),
            value: Math.round((b.dry / b.total) * 100),
            drySamples: b.dry,
            totalSamples: b.total,
        }));
    return { chartData, dryPct };
}

const CustomTooltip = ({ active, payload, label, booleanMode, isSoil }) => {
    if (!active || !payload?.length) return null;
    const p = payload[0];
    const val = p?.value;
    let valueLabel = val;
    if (booleanMode && isSoil) {
        valueLabel = `${val}% dry`;
    } else if (booleanMode) {
        valueLabel = `${val}% active`;
    }
    return (
        <div style={{ background: 'rgba(15, 18, 25, 0.95)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 'var(--r-lg)', padding: 'var(--s4)', minWidth: 160 }}>
            <div style={{ fontSize: 'var(--size-xs)', color: 'rgba(255,255,255,0.5)', marginBottom: 'var(--s2)', fontWeight: 600 }}>{label}</div>
            <div style={{ fontSize: 'var(--size-sm)', fontWeight: 700, color: p.color }}>{valueLabel}</div>
        </div>
    );
};

const HistoryPage = () => {
    const [sensorTypes, setSensorTypes] = useState([]);
    const [selected, setSelected] = useState('temperature');
    const [range, setRange] = useState('7d');
    const [rawRows, setRawRows] = useState([]);
    const [rangeFrom, setRangeFrom] = useState(null);
    const [loading, setLoading] = useState(true);
    const [fetching, setFetching] = useState(false);

    const rangeMeta = RANGE_OPTIONS.find(r => r.id === range) || RANGE_OPTIONS[1];
    const normalizedSelected = normalizeSensorType(selected);
    const cfg = getSensorConfig(normalizedSelected);
    const Icon = cfg.icon;
    const color = cfg.color;
    const isBoolean = Boolean(cfg.boolean);
    const isSoil = normalizedSelected === 'soil_moisture';

    useEffect(() => {
        const fetchTypes = async () => {
            const { data } = await supabase
                .from('sensor_readings')
                .select('sensor_type')
                .order('recorded_at', { ascending: false })
                .limit(300);
            const unique = [...new Set((data || []).map(r => normalizeSensorType(r.sensor_type)))];
            const ordered = ANALYTICS_TYPES.filter(t => unique.includes(t));
            const rest = unique.filter(t => !ANALYTICS_TYPES.includes(t) && t !== 'motion');
            setSensorTypes([...ordered, ...rest]);
            if (ordered.includes('temperature')) setSelected('temperature');
            else if (ordered.length) setSelected(ordered[0]);
            setLoading(false);
        };
        fetchTypes();
    }, []);

    useEffect(() => {
        const fetchHistory = async () => {
            setFetching(true);
            try {
                const from = subDays(new Date(), rangeMeta.days);
                setRangeFrom(from);
                const typesToQuery = normalizedSelected === 'soil_moisture'
                    ? ['soil_moisture', 'water']
                    : [normalizedSelected];

                const { data } = await supabase
                    .from('sensor_readings')
                    .select('numeric_value, recorded_at, sensor_type')
                    .in('sensor_type', typesToQuery)
                    .gte('recorded_at', from.toISOString())
                    .order('recorded_at', { ascending: true })
                    .limit(2000);

                setRawRows(data || []);
            } catch (err) {
                console.error(err);
                setRawRows([]);
            } finally {
                setFetching(false);
            }
        };
        fetchHistory();
    }, [selected, range, rangeMeta.days, normalizedSelected]);

    const chartData = useMemo(() => {
        const fmt = range === '1d' ? 'HH:mm' : (range === '7d' ? 'MMM d, HH:mm' : 'MMM d');
        const mapped = rawRows.map(r => ({
            recordedAt: r.recorded_at,
            value: Number(r.numeric_value),
            time: format(new Date(r.recorded_at), fmt),
            timeFull: r.recorded_at,
        }));

        if (isBoolean && isSoil) {
            return bucketBooleanSeries(mapped, rangeMeta.days).chartData;
        }
        if (isBoolean) {
            const { chartData: barData } = bucketBooleanSeries(mapped, rangeMeta.days);
            return barData;
        }
        return downsamplePoints(mapped);
    }, [rawRows, range, rangeMeta.days, isBoolean, isSoil]);

    const soilDryPct = useMemo(() => {
        if (!isSoil || !rawRows.length) return null;
        const dry = rawRows.filter(r => Number(r.numeric_value) >= 0.5).length;
        return Math.round((dry / rawRows.length) * 100);
    }, [rawRows, isSoil]);

    const vals = chartData.map(d => d.value);
    const unit = cfg.chartUnit || cfg.unit || '';
    const fmtNum = (n) => (isBoolean ? `${n}%` : `${n}${unit}`);
    const min = vals.length ? fmtNum(Math.min(...vals).toFixed(isBoolean ? 0 : 1)) : '—';
    const max = vals.length ? fmtNum(Math.max(...vals).toFixed(isBoolean ? 0 : 1)) : '—';
    const avg = vals.length ? fmtNum((vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(isBoolean ? 0 : 1)) : '—';
    const latestRaw = rawRows.length ? rawRows[rawRows.length - 1] : null;
    const latest = latestRaw
        ? formatSensorDisplayValue(normalizedSelected, latestRaw.numeric_value)
        : '—';

    const rangeLabel = rangeFrom
        ? `${format(rangeFrom, 'MMM d, yyyy HH:mm')} → ${format(new Date(), 'MMM d, yyyy HH:mm')}`
        : RANGE_OPTIONS.find(r => r.id === range)?.label;

    const downloadCSV = () => {
        if (!rawRows.length) return;
        const csv = 'Time,Value\n' + rawRows.map(r =>
            `"${format(new Date(r.recorded_at), 'yyyy-MM-dd HH:mm:ss')}",${r.numeric_value}`,
        ).join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${normalizedSelected}_history_${range}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    if (loading) {
        return (
            <div className="loading-container">
                <div className="spinner" />
                <div className="loading-text">Loading telemetry</div>
            </div>
        );
    }

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s6)', height: '100%' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s2)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Analytics</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginTop: 'var(--s1)' }}>
                        Temperature, humidity, smoke, and soil moisture trends
                    </p>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 'var(--size-xs)', color: 'var(--text-primary)', background: 'var(--bg-surface)', border: '1px solid var(--border-soft)', borderRadius: 'var(--r-full)', padding: '6px 14px', fontWeight: 600 }}>
                    <Activity size={14} style={{ color: 'var(--violet-core)' }} />
                    {sensorTypes.length} sensor type{sensorTypes.length !== 1 ? 's' : ''}
                </div>
            </div>

            <div style={{ display: 'flex', gap: 'var(--s3)', overflowX: 'auto', paddingBottom: 'var(--s3)' }}>
                {sensorTypes.map(type => {
                    const isSel = type === selected;
                    const sCfg = getSensorConfig(type);
                    const SIcon = sCfg.icon;
                    return (
                        <div
                            key={type}
                            onClick={() => setSelected(type)}
                            style={{
                                display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: '10px 14px',
                                borderRadius: 'var(--r-lg)', background: isSel ? `linear-gradient(135deg, ${sCfg.color}25, transparent)` : 'var(--bg-surface)',
                                border: `1px solid ${isSel ? sCfg.color + '80' : 'var(--border-soft)'}`,
                                cursor: 'pointer', minWidth: 140, flexShrink: 0,
                                opacity: !isSel ? 0.65 : 1,
                            }}
                        >
                            <div style={{ width: 32, height: 32, borderRadius: 'var(--r-md)', background: `${sCfg.color}15`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: sCfg.color }}>
                                <SIcon size={16} />
                            </div>
                            <div style={{ fontSize: 13, fontWeight: 700, color: isSel ? 'var(--text-primary)' : 'var(--text-secondary)' }}>
                                {sCfg.label}
                            </div>
                        </div>
                    );
                })}
            </div>

            <div style={{ background: 'var(--bg-surface)', borderRadius: 'var(--r-2xl)', border: '1px solid var(--border-soft)', padding: 'var(--s6)', flex: 1, minHeight: 450, display: 'flex', flexDirection: 'column' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--s6)', flexWrap: 'wrap', gap: 'var(--s4)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)' }}>
                        <div style={{ width: 48, height: 48, borderRadius: 'var(--r-xl)', background: `${color}15`, border: `1px solid ${color}30`, display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
                            <Icon size={24} />
                        </div>
                        <div>
                            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 800, color: 'var(--text-primary)' }}>{cfg.label}</h2>
                            <p style={{ fontSize: 'var(--size-xs)', color: 'var(--text-secondary)', marginTop: 4, lineHeight: 1.45 }}>
                                {rangeLabel}
                            </p>
                            <p style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', marginTop: 2 }}>
                                {rawRows.length} raw reading{rawRows.length !== 1 ? 's' : ''}
                                {chartData.length !== rawRows.length && !isBoolean ? ` · ${chartData.length} shown (downsampled)` : ''}
                                {isSoil && soilDryPct != null ? ` · ${soilDryPct}% of samples dry` : ''}
                            </p>
                        </div>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s3)', alignItems: 'flex-end' }}>
                        <div style={{ display: 'flex', background: 'var(--bg-base)', borderRadius: 'var(--r-full)', padding: 4, border: '1px solid var(--border-dim)' }}>
                            {RANGE_OPTIONS.map(r => (
                                <button
                                    key={r.id}
                                    onClick={() => setRange(r.id)}
                                    style={{
                                        padding: '6px 16px', borderRadius: 'var(--r-full)', border: 'none',
                                        background: range === r.id ? 'var(--text-primary)' : 'transparent',
                                        color: range === r.id ? 'var(--bg-base)' : 'var(--text-muted)',
                                        fontSize: 12, fontWeight: 700, cursor: 'pointer',
                                    }}
                                >
                                    {r.label}
                                </button>
                            ))}
                        </div>
                        <button onClick={downloadCSV} type="button" style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', fontSize: 12, display: 'flex', alignItems: 'center', gap: 4, cursor: 'pointer' }}>
                            <Download size={14} /> Export CSV
                        </button>
                    </div>
                </div>

                {isBoolean && (
                    <p style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginBottom: 'var(--s4)', marginTop: -8 }}>
                        {isSoil
                            ? 'Chart shows % of readings per period that were dry (1 = dry soil, 0 = moist).'
                            : 'Chart shows % of readings per period that were active.'}
                    </p>
                )}

                <div style={{ flex: 1, position: 'relative', height: 300 }}>
                    {fetching ? (
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 'var(--s3)' }}>
                            <div className="spinner" style={{ borderColor: `${color}40`, borderTopColor: color }} />
                            <div style={{ color: 'var(--text-muted)', fontSize: 'var(--size-sm)' }}>Loading readings…</div>
                        </div>
                    ) : chartData.length === 0 ? (
                        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 'var(--s3)' }}>
                            <TrendingUp size={32} style={{ color: 'var(--border-medium)' }} />
                            <div style={{ color: 'var(--text-muted)', fontWeight: 600 }}>No readings in this period</div>
                        </div>
                    ) : isBoolean ? (
                        <ResponsiveContainer width="100%" height={300}>
                            <BarChart data={chartData} margin={{ top: 12, right: 8, left: -10, bottom: 0 }}>
                                <CartesianGrid strokeDasharray="4 4" stroke="var(--border-dim)" vertical={false} />
                                <XAxis dataKey="time" tick={{ fill: 'var(--text-secondary)', fontSize: 10 }} axisLine={{ stroke: 'var(--border-soft)' }} tickLine={false} minTickGap={24} />
                                <YAxis domain={[0, 100]} tick={{ fill: 'var(--text-secondary)', fontSize: 10 }} axisLine={false} tickLine={false} unit="%" />
                                <Tooltip content={<CustomTooltip booleanMode isSoil={isSoil} />} />
                                <Bar dataKey="value" name={isSoil ? 'Dry %' : 'Active %'} fill={color} radius={[4, 4, 0, 0]} maxBarSize={48} />
                            </BarChart>
                        </ResponsiveContainer>
                    ) : (
                        <ResponsiveContainer width="100%" height={300}>
                            <AreaChart data={chartData} margin={{ top: 20, right: 8, left: -10, bottom: 0 }}>
                                <defs>
                                    <linearGradient id="colorGrad" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="0%" stopColor={color} stopOpacity={0.4} />
                                        <stop offset="100%" stopColor={color} stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="4 4" stroke="var(--border-dim)" vertical={false} />
                                <XAxis dataKey="time" tick={{ fill: 'var(--text-secondary)', fontSize: 10 }} axisLine={{ stroke: 'var(--border-soft)' }} tickLine={false} minTickGap={28} />
                                <YAxis tick={{ fill: 'var(--text-secondary)', fontSize: 10 }} axisLine={false} tickLine={false} unit={unit} />
                                <Tooltip content={<CustomTooltip />} />
                                <Area type="monotone" dataKey="value" name={cfg.label} stroke={color} strokeWidth={2} fill="url(#colorGrad)" dot={false} />
                            </AreaChart>
                        </ResponsiveContainer>
                    )}
                </div>

                {chartData.length > 0 && !fetching && (
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 'var(--s4)', marginTop: 'var(--s6)', paddingTop: 'var(--s6)', borderTop: '1px solid var(--border-dim)' }}>
                        {[
                            { label: 'Latest', val: latest },
                            { label: 'Min', val: min },
                            { label: 'Max', val: max },
                            { label: 'Average', val: avg },
                            { label: 'Samples', val: String(rawRows.length) },
                        ].map((stat, i) => (
                            <div key={i} style={{ padding: 'var(--s3)', borderRadius: 'var(--r-md)', background: 'var(--bg-raised)', border: '1px solid var(--border-dim)' }}>
                                <div style={{ fontSize: 11, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>{stat.label}</div>
                                <span style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-xl)', fontWeight: 800, color: 'var(--text-primary)' }}>{stat.val}</span>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};

export default HistoryPage;
