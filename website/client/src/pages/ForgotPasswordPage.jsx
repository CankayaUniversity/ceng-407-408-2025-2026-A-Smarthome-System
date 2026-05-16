import { useState } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { Mail, ArrowLeft, Send, CheckCircle } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import AuthShell from '../components/AuthShell';

const ForgotPasswordPage = () => {
    const { requestPasswordReset, isAuthenticated, isPasswordRecovery, loading: authLoading } = useAuth();
    const [email, setEmail] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [sent, setSent] = useState(false);

    if (!authLoading && isAuthenticated && !isPasswordRecovery) {
        return <Navigate to="/dashboard" replace />;
    }

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError(null);
        setLoading(true);
        const result = await requestPasswordReset(email);
        setLoading(false);
        if (result.success) {
            setSent(true);
        } else {
            setError(result.error || 'Could not send reset email. Please try again.');
        }
    };

    return (
        <AuthShell
            eyebrow="Account recovery"
            title={sent ? 'Check your inbox.' : 'Reset your password.'}
            subtitle={
                sent
                    ? 'If an account exists for that address, you will receive a reset link shortly.'
                    : 'Enter the email associated with your account and we will send you a secure reset link.'
            }
        >
            {sent ? (
                <div className="auth-success-banner" style={{
                    display: 'flex', alignItems: 'flex-start', gap: 'var(--s3)',
                    padding: 'var(--s4)', marginBottom: 'var(--s5)',
                    background: 'rgba(0,229,160,0.08)', border: '1px solid rgba(0,229,160,0.25)',
                    borderRadius: 'var(--r-md)', fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', lineHeight: 1.6,
                }}>
                    <CheckCircle size={20} style={{ color: 'var(--jade-core)', flexShrink: 0, marginTop: 2 }} />
                    <span>
                        A password reset link has been sent to your email address.
                        Please check your inbox and spam folder.
                    </span>
                </div>
            ) : (
                <>
                    {error && <div className="auth-error">{error}</div>}
                    <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                        <div className="form-group" style={{ marginBottom: 0 }}>
                            <label className="form-label">Email address</label>
                            <div style={{ position: 'relative' }}>
                                <Mail size={16} style={{
                                    position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)',
                                    color: 'var(--text-muted)', pointerEvents: 'none',
                                }} />
                                <input
                                    type="email"
                                    className="form-input"
                                    placeholder="you@example.com"
                                    value={email}
                                    onChange={e => setEmail(e.target.value)}
                                    required
                                    disabled={loading}
                                    autoFocus
                                    style={{ paddingLeft: 42 }}
                                />
                            </div>
                        </div>
                        <button
                            type="submit"
                            className="btn btn-primary w-full"
                            disabled={loading || !email.trim()}
                            style={{ justifyContent: 'center', height: 52, fontSize: 'var(--size-md)', borderRadius: 'var(--r-lg)' }}
                        >
                            {loading
                                ? <div className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} />
                                : <><Send size={16} /> Send Reset Link</>}
                        </button>
                    </form>
                </>
            )}

            <div style={{ marginTop: 'var(--s6)', textAlign: 'center' }}>
                <Link
                    to="/login"
                    style={{
                        display: 'inline-flex', alignItems: 'center', gap: 6,
                        fontSize: 'var(--size-sm)', color: 'var(--text-muted)', textDecoration: 'none',
                    }}
                >
                    <ArrowLeft size={14} /> Back to sign in
                </Link>
            </div>
        </AuthShell>
    );
};

export default ForgotPasswordPage;
