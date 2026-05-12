import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { Zap, ArrowRight, Thermometer, Droplets, ShieldCheck, Eye } from 'lucide-react';

const FEATURE_PILLS = [
    { icon: Thermometer, text: 'Climate sensing', color: 'var(--ember-core)' },
    { icon: ShieldCheck, text: 'Face recognition', color: 'var(--jade-core)' },
    { icon: Droplets, text: 'Water detection', color: 'var(--cyan-core)' },
    { icon: Eye, text: 'Live surveillance', color: 'var(--violet-core)' },
];

const LoginPage = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');

    const { login, error, loading, isAuthenticated } = useAuth();

    if (isAuthenticated) return <Navigate to="/dashboard" replace />;

    const handleSubmit = async (e) => {
        e.preventDefault();
        await login(email, password);
    };

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
                        justifyContent: 'center', marginTop: 'var(--s8)'
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
                    <div className="auth-eyebrow">Welcome back</div>
                    <h1 className="auth-title">Sign into your<br />space.</h1>
                    <p className="auth-subtitle">
                        Enter your credentials to access the intelligence dashboard.
                    </p>

                    {error && <div className="auth-error">{error}</div>}

                    <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">Email address</label>
                            <input type="email" className="form-input" placeholder="you@example.com"
                                value={email} onChange={(e) => setEmail(e.target.value)}
                                required disabled={loading} />
                        </div>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">Password</label>
                            <input type="password" className="form-input" placeholder="••••••••"
                                value={password} onChange={(e) => setPassword(e.target.value)}
                                required disabled={loading} minLength={6} />
                        </div>
                        <button type="submit" className="btn btn-primary w-full" disabled={loading}
                            style={{ justifyContent: 'center', height: 52, fontSize: 'var(--size-md)', marginTop: 'var(--s2)', borderRadius: 'var(--r-lg)' }}>
                            {loading
                                ? <div className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} />
                                : <>Sign In <ArrowRight size={18} /></>}
                        </button>
                    </form>

                    <div style={{ marginTop: 'var(--s6)', textAlign: 'center', fontSize: 'var(--size-sm)', color: 'var(--text-muted)' }}>
                        Don&apos;t have an account? Contact your system administrator.
                    </div>
                </div>
            </div>
        </div>
    );
};

export default LoginPage;
