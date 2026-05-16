import { Zap, Thermometer, Droplets, ShieldCheck, Eye } from 'lucide-react';

const FEATURE_PILLS = [
    { icon: Thermometer, text: 'Climate sensing', color: 'var(--ember-core)' },
    { icon: ShieldCheck, text: 'Face recognition', color: 'var(--jade-core)' },
    { icon: Droplets, text: 'Water detection', color: 'var(--cyan-core)' },
    { icon: Eye, text: 'Live surveillance', color: 'var(--violet-core)' },
];

/**
 * Shared layout for unauthenticated auth pages (login, forgot password, update password).
 */
export default function AuthShell({ eyebrow, title, subtitle, children }) {
    return (
        <div className="auth-page">
            <div className="auth-visual">
                <div className="auth-visual-content">
                    <div className="auth-visual-badge">
                        <Zap size={12} />
                        IoT Intelligence Platform
                    </div>
                    <div className="auth-visual-title">
                        Your home,<br />
                        <span>always aware.</span>
                    </div>
                    <p className="auth-visual-desc">
                        A unified command interface for your connected space.
                        Real-time awareness, predictive protection, seamless control.
                    </p>
                    <div style={{
                        display: 'flex', flexWrap: 'wrap', gap: 'var(--s3)',
                        justifyContent: 'center', marginTop: 'var(--s8)',
                    }}>
                        {FEATURE_PILLS.map(({ icon: Icon, text, color }) => (
                            <div key={text} style={{
                                display: 'flex', alignItems: 'center', gap: 'var(--s2)',
                                background: 'rgba(255,255,255,0.05)',
                                border: '1px solid rgba(255,255,255,0.1)',
                                borderRadius: 'var(--r-full)',
                                padding: '8px 16px',
                                fontSize: 'var(--size-xs)',
                                color: 'var(--text-secondary)',
                                backdropFilter: 'blur(8px)',
                            }}>
                                <Icon size={13} style={{ color }} />
                                {text}
                            </div>
                        ))}
                    </div>
                </div>
            </div>

            <div className="auth-panel">
                <div className="auth-form-wrap">
                    {eyebrow && <div className="auth-eyebrow">{eyebrow}</div>}
                    <h1 className="auth-title">{title}</h1>
                    {subtitle && <p className="auth-subtitle">{subtitle}</p>}
                    {children}
                </div>
            </div>
        </div>
    );
}
