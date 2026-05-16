import { useState, useEffect } from 'react';
import { Database, Key, Save, CheckCircle, Palette, Trash2, ShieldAlert, Lock, Eye, EyeOff, Home } from 'lucide-react';
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
    const { profile, user, isAdmin, deleteAuthUser, changePasswordWithVerification } = useAuth();
    const { theme } = useTheme();
    const [saved, setSaved] = useState(false);
    const [nameVal, setNameVal] = useState(profile?.name || '');

    // Password change
    const [currentPw, setCurrentPw] = useState('');
    const [newPw, setNewPw] = useState('');
    const [confirmPw, setConfirmPw] = useState('');
    const [showCurrentPw, setShowCurrentPw] = useState(false);
    const [showNewPw, setShowNewPw] = useState(false);
    const [pwSaving, setPwSaving] = useState(false);
    const [pwError, setPwError] = useState(null);
    const [pwSuccess, setPwSuccess] = useState(false);

    // Household (admin)
    const [householdName, setHouseholdName] = useState('');
    const [householdAddress, setHouseholdAddress] = useState('');
    const [householdSaving, setHouseholdSaving] = useState(false);
    const [householdSaved, setHouseholdSaved] = useState(false);

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

    useEffect(() => {
        supabase.from('household_settings').select('name, address').eq('id', 1).maybeSingle()
            .then(({ data }) => {
                if (data) {
                    setHouseholdName(data.name || '');
                    setHouseholdAddress(data.address || '');
                }
            });
    }, []);

    const handlePasswordChange = async (e) => {
        e.preventDefault();
        setPwError(null);
        setPwSuccess(false);
        if (newPw.length < 8) { setPwError('New password must be at least 8 characters.'); return; }
        if (newPw !== confirmPw) { setPwError('New passwords do not match.'); return; }
        setPwSaving(true);
        const result = await changePasswordWithVerification(currentPw, newPw);
        setPwSaving(false);
        if (result.success) {
            setPwSuccess(true);
            setCurrentPw(''); setNewPw(''); setConfirmPw('');
            setTimeout(() => setPwSuccess(false), 3000);
        } else {
            setPwError(result.error || 'Failed to update password.');
        }
    };

    const handleHouseholdSave = async () => {
        if (!isAdmin || !householdName.trim()) return;
        setHouseholdSaving(true);
        const { error } = await supabase.from('household_settings')
            .update({ name: householdName.trim(), address: householdAddress.trim() || null, updated_at: new Date().toISOString() })
            .eq('id', 1);
        setHouseholdSaving(false);
        if (!error) {
            setHouseholdSaved(true);
            window.dispatchEvent(new CustomEvent('household-updated'));
            setTimeout(() => setHouseholdSaved(false), 2500);
        }
    };

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
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginTop: 'var(--s2)' }}>Manage your profile, household, and how the app looks</p>
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
                <Section icon={Key} title="Account" desc="Your name and sign-in details">
                    <FieldRow label="Name" desc="Shown in the app header and on your profile">
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
                    <FieldRow label="Role" desc="Administrator or resident access">
                        <span className="badge badge-info" style={{ textTransform: 'uppercase' }}>{profile?.role || 'resident'}</span>
                    </FieldRow>
                </Section>

                <Section icon={Lock} title="Password" desc="Update your sign-in password">
                    {pwError && <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{pwError}</div>}
                    {pwSuccess && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--s4)', color: 'var(--jade-core)', fontSize: 'var(--size-sm)' }}>
                            <CheckCircle size={16} /> Password updated successfully.
                        </div>
                    )}
                    <form onSubmit={handlePasswordChange} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">Current Password</label>
                            <div style={{ position: 'relative' }}>
                                <input
                                    type={showCurrentPw ? 'text' : 'password'}
                                    className="form-input"
                                    value={currentPw}
                                    onChange={e => { setCurrentPw(e.target.value); setPwError(null); }}
                                    required
                                    disabled={pwSaving}
                                    autoComplete="current-password"
                                    style={{ paddingRight: 44 }}
                                />
                                <button type="button" onClick={() => setShowCurrentPw(v => !v)}
                                    style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                                    {showCurrentPw ? <EyeOff size={16} /> : <Eye size={16} />}
                                </button>
                            </div>
                        </div>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">New Password</label>
                            <div style={{ position: 'relative' }}>
                                <input
                                    type={showNewPw ? 'text' : 'password'}
                                    className="form-input"
                                    value={newPw}
                                    onChange={e => { setNewPw(e.target.value); setPwError(null); }}
                                    required
                                    minLength={8}
                                    disabled={pwSaving}
                                    autoComplete="new-password"
                                    style={{ paddingRight: 44 }}
                                />
                                <button type="button" onClick={() => setShowNewPw(v => !v)}
                                    style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                                    {showNewPw ? <EyeOff size={16} /> : <Eye size={16} />}
                                </button>
                            </div>
                        </div>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">Confirm New Password</label>
                            <input
                                type="password"
                                className="form-input"
                                value={confirmPw}
                                onChange={e => { setConfirmPw(e.target.value); setPwError(null); }}
                                required
                                disabled={pwSaving}
                                autoComplete="new-password"
                            />
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                            <button type="submit" className="btn btn-primary btn-sm" disabled={pwSaving || !currentPw || !newPw || !confirmPw}>
                                {pwSaving ? <div className="spinner" style={{ width: 14, height: 14, borderWidth: 2 }} /> : <><Lock size={14} /> Update Password</>}
                            </button>
                        </div>
                    </form>
                </Section>

                {isAdmin && (
                    <Section icon={Home} title="Household" desc="Name shown across the dashboard for all users">
                        <FieldRow label="Household Name" desc="e.g. Smith Residence">
                            <input className="form-input" value={householdName} onChange={e => setHouseholdName(e.target.value)} style={{ width: 220 }} />
                        </FieldRow>
                        <FieldRow label="Address" desc="Optional — for reference only">
                            <input className="form-input" value={householdAddress} onChange={e => setHouseholdAddress(e.target.value)} placeholder="Optional" style={{ width: 220 }} />
                        </FieldRow>
                        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--s4)' }}>
                            <button type="button" className="btn btn-primary btn-sm" onClick={handleHouseholdSave} disabled={householdSaving || !householdName.trim()}>
                                {householdSaved ? <><CheckCircle size={14} /> Saved</> : householdSaving ? <div className="spinner" style={{ width: 14, height: 14, borderWidth: 2 }} /> : <><Save size={14} /> Save Household</>}
                            </button>
                        </div>
                    </Section>
                )}

                <Section icon={Palette} title="Appearance" desc="Light or dark interface">
                    <FieldRow
                        label={theme === 'light' ? 'Light mode' : 'Dark mode'}
                        desc="Choose a comfortable look for day or night. Your preference is saved on this device."
                    >
                        <ThemeSwitch size="lg" showLabel />
                    </FieldRow>
                </Section>

                {/* Admin-only: User Management */}
                {isAdmin && (
                    <Section icon={ShieldAlert} title="Household accounts" desc="Admin only — people who can sign in">
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

                <Section icon={Database} title="About this home" desc="Quick status for your setup">
                    {[
                        { label: 'App version', val: 'Smart Home Dashboard 1.0' },
                        { label: 'Cloud connection', val: 'Connected' },
                        { label: 'Face recognition', val: 'Raspberry Pi at front door' },
                    ].map(({ label, val }) => (
                        <FieldRow key={label} label={label}>
                            <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', maxWidth: 360, display: 'inline-block', textAlign: 'right' }}>{val}</span>
                        </FieldRow>
                    ))}
                </Section>
            </div>
        </div>
    );
};

export default SettingsPage;
