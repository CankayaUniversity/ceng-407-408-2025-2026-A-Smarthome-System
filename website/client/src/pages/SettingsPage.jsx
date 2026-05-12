import { useState, useEffect } from 'react';
import { Database, Key, Save, CheckCircle, Palette, Users, Trash2, ShieldAlert } from 'lucide-react';
import { supabase } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';
import { useTheme } from '../context/ThemeContext';
import ThemeSwitch from '../components/ThemeSwitch';

function Section({ icon: Icon, title, desc, children }) {
    return (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)', padding: 'var(--s5) var(--s6)', borderBottom: '1px solid var(--border-dim)', background: 'var(--bg-raised)' }}>
                <div style={{ width: 40, height: 40, background: 'var(--ember-trace)', border: '1px solid rgba(255,107,53,0.15)', borderRadius: 'var(--r-md)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ember-core)', flexShrink: 0 }}>
                    <Icon size={18} />
                </div>
                <div>
                    <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--size-md)' }}>{title}</div>
                    <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)' }}>{desc}</div>
                </div>
            </div>
            <div style={{ padding: 'var(--s6)' }}>{children}</div>
        </div>
    );
}

function FieldRow({ label, desc, children }) {
    return (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 'var(--s6)', paddingBlock: 'var(--s4)', borderBottom: '1px solid var(--border-dim)' }}>
            <div style={{ flex: 1 }}>
                <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600 }}>{label}</div>
                {desc && <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 2 }}>{desc}</div>}
            </div>
            <div style={{ flexShrink: 0 }}>{children}</div>
        </div>
    );
}

const SettingsPage = () => {
    const { profile, user, isAdmin, deleteAuthUser } = useAuth();
    const { theme } = useTheme();
    const [saved, setSaved] = useState(false);
    const [nameVal, setNameVal] = useState(profile?.name || '');

    // Admin: all users list
    const [allProfiles, setAllProfiles] = useState([]);
    const [loadingProfiles, setLoadingProfiles] = useState(false);
    const [deleteError, setDeleteError] = useState(null);
    const [deletingId, setDeletingId] = useState(null);

    useEffect(() => {
        if (!isAdmin) return;
        setLoadingProfiles(true);
        supabase.from('profiles').select('*').order('created_at', { ascending: true })
            .then(({ data }) => { setAllProfiles(data || []); setLoadingProfiles(false); });
    }, [isAdmin]);

    const streamUrl = import.meta.env.VITE_CAMERA_STREAM_URL || '';

    const dirty = nameVal !== (profile?.name || '');

    const handleSave = async () => {
        if (!dirty || !user?.id) {
            setSaved(true);
            setTimeout(() => setSaved(false), 2500);
            return;
        }
        try {
            await supabase.from('profiles').update({ name: nameVal }).eq('id', user.id);
            setSaved(true);
            setTimeout(() => setSaved(false), 2500);
        } catch (err) {
            console.error('[Settings] save failed:', err);
        }
    };

    return (
        <div>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Settings</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>Account and appearance preferences</p>
                </div>
                <button
                    className="btn btn-primary"
                    onClick={handleSave}
                    disabled={!dirty && !saved}
                    style={{ gap: 'var(--s2)', opacity: !dirty && !saved ? 0.55 : 1 }}
                >
                    {saved ? <><CheckCircle size={15} /> Saved!</> : <><Save size={15} /> Save Changes</>}
                </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s5)' }}>
                <Section icon={Key} title="Account" desc="Your profile and credentials">
                    <FieldRow label="Name" desc="Your display name throughout the system">
                        <input
                            className="form-input"
                            value={nameVal}
                            onChange={e => setNameVal(e.target.value)}
                            style={{ width: 220 }}
                        />
                    </FieldRow>
                    <FieldRow label="Email" desc="Sign-in email address">
                        <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{profile?.email || user?.email}</span>
                    </FieldRow>
                    <FieldRow label="Role" desc="Access level">
                        <span className="badge badge-info" style={{ textTransform: 'uppercase' }}>{profile?.role || 'resident'}</span>
                    </FieldRow>
                </Section>

                <Section icon={Palette} title="Appearance" desc="Interface theme">
                    <FieldRow
                        label={theme === 'light' ? 'Light Mode' : 'Dark Mode'}
                        desc="Toggle between the cinematic dark theme and a daylight-friendly light theme. Your choice persists across sessions."
                    >
                        <ThemeSwitch size="lg" showLabel />
                    </FieldRow>
                </Section>

                {/* Admin-only: User Management */}
                {isAdmin && (
                    <Section icon={ShieldAlert} title="User Management" desc="Admin only — manage all system accounts">
                        {deleteError && (
                            <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{deleteError}</div>
                        )}
                        {loadingProfiles ? (
                            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', padding: 'var(--s4)', color: 'var(--text-muted)' }}>
                                <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> Loading accounts...
                            </div>
                        ) : allProfiles.length === 0 ? (
                            <div style={{ color: 'var(--text-muted)', fontSize: 'var(--size-sm)', padding: 'var(--s4)' }}>No profiles found.</div>
                        ) : (
                            allProfiles.map(p => (
                                <FieldRow
                                    key={p.id}
                                    label={p.name || p.email || 'Unknown'}
                                    desc={`${p.email || '—'} · ${p.role || 'resident'}`}
                                >
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)' }}>
                                        <span className={`badge ${p.role === 'admin' ? 'badge-warning' : 'badge-neutral'}`} style={{ textTransform: 'uppercase' }}>
                                            {p.role || 'resident'}
                                        </span>
                                        {p.id !== user?.id && (
                                            <button
                                                className="btn btn-danger btn-sm"
                                                disabled={deletingId === p.id}
                                                onClick={async () => {
                                                    if (!confirm(`Delete account for "${p.name || p.email}"? This cannot be undone.`)) return;
                                                    setDeletingId(p.id);
                                                    setDeleteError(null);
                                                    const result = await deleteAuthUser(p.id);
                                                    if (result.success) {
                                                        setAllProfiles(prev => prev.filter(x => x.id !== p.id));
                                                    } else {
                                                        setDeleteError(result.error || 'Delete failed');
                                                    }
                                                    setDeletingId(null);
                                                }}
                                                title="Delete this user account"
                                            >
                                                {deletingId === p.id
                                                    ? <div className="spinner" style={{ width: 12, height: 12, borderWidth: 2 }} />
                                                    : <Trash2 size={13} />}
                                            </button>
                                        )}
                                        {p.id === user?.id && (
                                            <span style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)' }}>You</span>
                                        )}
                                    </div>
                                </FieldRow>
                            ))
                        )}
                    </Section>
                )}

                <Section icon={Database} title="System Information" desc="Live infrastructure status">
                    {[
                        { label: 'Platform', val: 'IoT Smart Home System v1.0' },
                        { label: 'Database', val: 'Supabase (PostgreSQL)' },
                        { label: 'Gateway', val: 'FastAPI + Supabase SDK' },
                        { label: 'Frontend', val: 'React 19 + Vite' },
                        { label: 'AI Module', val: 'Python face-recognition (Raspberry Pi)' },
                        { label: 'Live Camera Stream', val: streamUrl || 'Not configured' },
                    ].map(({ label, val }) => (
                        <FieldRow key={label} label={label}>
                            <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', fontFamily: 'monospace', wordBreak: 'break-all', maxWidth: 360, display: 'inline-block', textAlign: 'right' }}>{val}</span>
                        </FieldRow>
                    ))}
                </Section>
            </div>
        </div>
    );
};

export default SettingsPage;
