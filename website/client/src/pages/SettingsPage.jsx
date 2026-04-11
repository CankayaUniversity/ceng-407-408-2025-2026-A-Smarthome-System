import { useState } from 'react';
import { Settings, Shield, Bell, Database, Key, Save, CheckCircle } from 'lucide-react';
import { supabase } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';

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
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 'var(--s6)', paddingBlock: 'var(--s4)', borderBottom: '1px solid var(--border-dim)' }}>
            <div style={{ flex: 1 }}>
                <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600 }}>{label}</div>
                {desc && <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 2 }}>{desc}</div>}
            </div>
            <div style={{ flexShrink: 0 }}>{children}</div>
        </div>
    );
}

function Toggle({ value, onChange }) {
    return (
        <button role="switch" aria-checked={value} onClick={() => onChange(!value)}
            style={{ width: 44, height: 24, borderRadius: 'var(--r-full)', background: value ? 'var(--ember-core)' : 'var(--bg-elevated)', border: `1px solid ${value ? 'var(--ember-core)' : 'var(--border-soft)'}`, cursor: 'pointer', transition: 'all var(--t-base) var(--ease-out)', position: 'relative', display: 'inline-flex', alignItems: 'center', boxShadow: value ? '0 0 16px var(--ember-glow)' : 'none' }}>
            <div style={{ width: 18, height: 18, borderRadius: '50%', background: 'white', position: 'absolute', left: value ? 22 : 2, transition: 'left var(--t-base) var(--ease-out)', boxShadow: '0 2px 6px rgba(0,0,0,0.3)' }} />
        </button>
    );
}

const SettingsPage = () => {
    const { profile, user } = useAuth();
    const [saved, setSaved] = useState(false);
    const [nameVal, setNameVal] = useState(profile?.name || '');
    const [settings, setSettings] = useState({
        alertsEnabled: true,
        emailNotify: false,
        armedMode: false,
        autoAcknowledge: false,
    });

    const handleSave = async () => {
        if (nameVal !== profile?.name) {
            await supabase.from('profiles').update({ name: nameVal }).eq('id', user.id);
        }
        setSaved(true);
        setTimeout(() => setSaved(false), 2500);
    };

    const toggle = (key) => setSettings(prev => ({ ...prev, [key]: !prev[key] }));

    return (
        <div>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Settings</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>System configuration and preferences</p>
                </div>
                <button className="btn btn-primary" onClick={handleSave} style={{ gap: 'var(--s2)' }}>
                    {saved ? <><CheckCircle size={15} /> Saved!</> : <><Save size={15} /> Save Changes</>}
                </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s5)' }}>
                <Section icon={Key} title="Account" desc="Your profile and credentials">
                    <FieldRow label="Name" desc="Your display name throughout the system">
                        <input className="form-input" value={nameVal} onChange={e => setNameVal(e.target.value)} style={{ width: 220 }} />
                    </FieldRow>
                    <FieldRow label="Email" desc="Sign-in email address">
                        <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{profile?.email || user?.email}</span>
                    </FieldRow>
                    <FieldRow label="Role" desc="Access level">
                        <span className="badge badge-info" style={{ textTransform: 'uppercase' }}>{profile?.role || 'resident'}</span>
                    </FieldRow>
                </Section>

                <Section icon={Shield} title="Security & Arming" desc="System protection settings">
                    <FieldRow label="Armed Mode" desc="Trigger alerts on any motion or intrusion event">
                        <Toggle value={settings.armedMode} onChange={() => toggle('armedMode')} />
                    </FieldRow>
                    <FieldRow label="Auto-acknowledge low severity" desc="Automatically dismiss info-level alerts within 10 minutes">
                        <Toggle value={settings.autoAcknowledge} onChange={() => toggle('autoAcknowledge')} />
                    </FieldRow>
                </Section>

                <Section icon={Bell} title="Notifications" desc="Alert delivery preferences">
                    <FieldRow label="Enable Alerts" desc="Receive security alerts in the dashboard">
                        <Toggle value={settings.alertsEnabled} onChange={() => toggle('alertsEnabled')} />
                    </FieldRow>
                    <FieldRow label="Email Notifications" desc="Send critical alerts to your email address">
                        <Toggle value={settings.emailNotify} onChange={() => toggle('emailNotify')} />
                    </FieldRow>
                </Section>

                <Section icon={Database} title="System Information" desc="Live infrastructure status">
                    {[
                        { label: 'Platform', val: 'IoT Smart Home System v1.0' },
                        { label: 'Database', val: 'Supabase (PostgreSQL)' },
                        { label: 'Gateway', val: 'FastAPI + Supabase SDK' },
                        { label: 'Frontend', val: 'React 19 + Vite' },
                        { label: 'AI Module', val: 'Python face-recognition (Raspberry Pi)' },
                    ].map(({ label, val }) => (
                        <FieldRow key={label} label={label}>
                            <span style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{val}</span>
                        </FieldRow>
                    ))}
                </Section>
            </div>
        </div>
    );
};

export default SettingsPage;
