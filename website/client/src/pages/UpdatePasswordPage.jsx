import { useState, useEffect } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { Lock, Eye, EyeOff, ArrowRight, AlertCircle } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import { supabase } from '../services/supabase';
import AuthShell from '../components/AuthShell';

const MIN_PASSWORD_LENGTH = 8;

const UpdatePasswordPage = () => {
    const navigate = useNavigate();
    const {
        completePasswordRecovery,
        isPasswordRecovery,
        isAuthenticated,
        loading: authLoading,
        forcePasswordChange,
    } = useAuth();

    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showNew, setShowNew] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [sessionReady, setSessionReady] = useState(false);
    const [checkingSession, setCheckingSession] = useState(true);

    useEffect(() => {
        let mounted = true;

        const verifyRecoverySession = async () => {
            const { data: { session } } = await supabase.auth.getSession();
            if (!mounted) return;

            const hash = window.location.hash || '';
            const hasAuthHash = hash.includes('access_token')
                || hash.includes('type=recovery')
                || hash.includes('type=signup')
                || hash.includes('type=invite');

            if (session && (isPasswordRecovery || hasAuthHash)) {
                setSessionReady(true);
            } else if (!session && hasAuthHash) {
                // detectSessionInUrl may still be processing
                setTimeout(async () => {
                    const { data: { session: s2 } } = await supabase.auth.getSession();
                    if (mounted && s2) setSessionReady(true);
                    else if (mounted) setSessionReady(false);
                    if (mounted) setCheckingSession(false);
                }, 500);
                return;
            } else {
                setSessionReady(Boolean(session && isPasswordRecovery));
            }
            setCheckingSession(false);
        };

        if (!authLoading) {
            verifyRecoverySession();
        }

        return () => { mounted = false; };
    }, [authLoading, isPasswordRecovery]);

    // First-login forced change uses modal, not this page
    if (!authLoading && isAuthenticated && forcePasswordChange && !isPasswordRecovery) {
        return <Navigate to="/dashboard" replace />;
    }

    if (!authLoading && !checkingSession && !sessionReady) {
        return (
            <AuthShell
                eyebrow="Invalid link"
                title="This reset link is invalid or has expired."
                subtitle="Request a new password reset email to continue."
            >
                <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>
                    <AlertCircle size={16} style={{ display: 'inline', marginRight: 6, verticalAlign: 'text-bottom' }} />
                    The recovery session could not be verified. Links expire after a short time.
                </div>
                <Link to="/forgot-password" className="btn btn-primary w-full" style={{
                    display: 'flex', justifyContent: 'center', height: 52, borderRadius: 'var(--r-lg)', textDecoration: 'none',
                }}>
                    Request a new reset link
                </Link>
                <div style={{ marginTop: 'var(--s6)', textAlign: 'center' }}>
                    <Link to="/login" style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)' }}>Back to sign in</Link>
                </div>
            </AuthShell>
        );
    }

    if (authLoading || checkingSession) {
        return (
            <div className="auth-page" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <div className="spinner" />
            </div>
        );
    }

    const validate = () => {
        if (newPassword.length < MIN_PASSWORD_LENGTH) {
            return `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`;
        }
        if (newPassword !== confirmPassword) {
            return 'Passwords do not match.';
        }
        return null;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        const validationError = validate();
        if (validationError) {
            setError(validationError);
            return;
        }

        setLoading(true);
        setError(null);
        const result = await completePasswordRecovery(newPassword);
        setLoading(false);

        if (result.success) {
            navigate('/login', { replace: true, state: { passwordReset: true } });
        } else {
            setError(result.error || 'Failed to update password. Please try again.');
        }
    };

    return (
        <AuthShell
            eyebrow="Secure reset"
            title="Create a new password."
            subtitle="Choose a strong password you have not used on this account before."
        >
            {error && <div className="auth-error">{error}</div>}

            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                    <label className="form-label">New Password</label>
                    <div style={{ position: 'relative' }}>
                        <input
                            type={showNew ? 'text' : 'password'}
                            className="form-input"
                            placeholder={`Minimum ${MIN_PASSWORD_LENGTH} characters`}
                            value={newPassword}
                            onChange={e => { setNewPassword(e.target.value); setError(null); }}
                            required
                            minLength={MIN_PASSWORD_LENGTH}
                            disabled={loading}
                            autoFocus
                            autoComplete="new-password"
                            style={{ paddingRight: 44 }}
                        />
                        <button
                            type="button"
                            onClick={() => setShowNew(v => !v)}
                            style={{
                                position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
                                background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)',
                            }}
                        >
                            {showNew ? <EyeOff size={16} /> : <Eye size={16} />}
                        </button>
                    </div>
                </div>

                <div className="form-group" style={{ marginBottom: 0 }}>
                    <label className="form-label">Confirm New Password</label>
                    <div style={{ position: 'relative' }}>
                        <input
                            type={showConfirm ? 'text' : 'password'}
                            className="form-input"
                            placeholder="Repeat your new password"
                            value={confirmPassword}
                            onChange={e => { setConfirmPassword(e.target.value); setError(null); }}
                            required
                            disabled={loading}
                            autoComplete="new-password"
                            style={{
                                paddingRight: 44,
                                borderColor: confirmPassword && confirmPassword !== newPassword
                                    ? 'var(--crimson-core)'
                                    : confirmPassword && confirmPassword === newPassword
                                        ? 'var(--jade-core)'
                                        : undefined,
                            }}
                        />
                        <button
                            type="button"
                            onClick={() => setShowConfirm(v => !v)}
                            style={{
                                position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)',
                                background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)',
                            }}
                        >
                            {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
                        </button>
                    </div>
                </div>

                <button
                    type="submit"
                    className="btn btn-primary w-full"
                    disabled={loading || !newPassword || !confirmPassword}
                    style={{ justifyContent: 'center', height: 52, fontSize: 'var(--size-md)', borderRadius: 'var(--r-lg)', marginTop: 'var(--s2)' }}
                >
                    {loading
                        ? <div className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} />
                        : <><Lock size={16} /> Update Password <ArrowRight size={16} /></>}
                </button>
            </form>
        </AuthShell>
    );
};

export default UpdatePasswordPage;
