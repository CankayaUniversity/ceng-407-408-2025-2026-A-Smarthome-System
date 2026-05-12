import { useState } from 'react';
import { Lock, Eye, EyeOff, ShieldCheck, ArrowRight } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

/**
 * ChangePasswordModal — ilk girişte force_password_change flag'i true olan
 * kullanıcılara gösterilen tam-ekran overlay modal.
 * Kullanıcı şifresini değiştirmeden sistemi kullanamaaz.
 */
const ChangePasswordModal = () => {
    const { changePassword, logout, profile, user } = useAuth();
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showNew, setShowNew] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [success, setSuccess] = useState(false);

    const displayName = profile?.name || user?.user_metadata?.name || user?.email?.split('@')[0] || 'User';

    const validate = () => {
        if (newPassword.length < 8) return 'Password must be at least 8 characters.';
        if (newPassword !== confirmPassword) return 'Passwords do not match.';
        return null;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        const validationError = validate();
        if (validationError) { setError(validationError); return; }

        setLoading(true);
        setError(null);

        const result = await changePassword(newPassword);
        if (result.success) {
            setSuccess(true);
        } else {
            setError(result.error || 'Failed to update password. Please try again.');
        }
        setLoading(false);
    };

    const strength = (() => {
        if (!newPassword) return 0;
        let score = 0;
        if (newPassword.length >= 8) score++;
        if (newPassword.length >= 12) score++;
        if (/[A-Z]/.test(newPassword)) score++;
        if (/[0-9]/.test(newPassword)) score++;
        if (/[^A-Za-z0-9]/.test(newPassword)) score++;
        return score;
    })();

    const strengthLabel = ['', 'Weak', 'Fair', 'Good', 'Strong', 'Excellent'][strength] || '';
    const strengthColor = ['', '#ff3b5c', '#ffb020', '#ffb020', '#00e5a0', '#00e5a0'][strength] || 'transparent';

    if (success) {
        return (
            <div className="change-pw-overlay">
                <div className="change-pw-card">
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 'var(--s5)', textAlign: 'center', padding: 'var(--s8) 0' }}>
                        <div style={{
                            width: 72, height: 72, borderRadius: '50%',
                            background: 'rgba(0,229,160,0.12)', border: '2px solid rgba(0,229,160,0.3)',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            animation: 'successPop 0.5s var(--ease-out)'
                        }}>
                            <ShieldCheck size={36} style={{ color: 'var(--jade-core)' }} />
                        </div>
                        <div>
                            <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-xl)', fontWeight: 700, marginBottom: 'var(--s2)' }}>
                                Password Updated!
                            </div>
                            <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)' }}>
                                Your account is now secure. Welcome to SmartHome, {displayName}.
                            </p>
                        </div>
                        <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>
                            Redirecting you to the dashboard...
                        </div>
                    </div>
                </div>
                <style>{`
                    @keyframes successPop {
                        from { transform: scale(0.5); opacity: 0; }
                        to   { transform: scale(1);   opacity: 1; }
                    }
                `}</style>
            </div>
        );
    }

    return (
        <div className="change-pw-overlay">
            <div className="change-pw-card">
                {/* Header */}
                <div style={{ marginBottom: 'var(--s6)', textAlign: 'center' }}>
                    <div style={{
                        width: 56, height: 56, borderRadius: 'var(--r-xl)',
                        background: 'linear-gradient(135deg, var(--ember-core), var(--violet-core))',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        margin: '0 auto var(--s4)',
                        boxShadow: '0 0 32px rgba(255,107,53,0.35)'
                    }}>
                        <Lock size={24} style={{ color: 'white' }} />
                    </div>
                    <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-2xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.2, marginBottom: 'var(--s2)' }}>
                        Set Your Password
                    </div>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', lineHeight: 1.6 }}>
                        Welcome, <strong style={{ color: 'var(--text-primary)' }}>{displayName}</strong>!
                        This is your first login. Please create a new secure password to continue.
                    </p>
                </div>

                {/* Notice Banner */}
                <div style={{
                    display: 'flex', alignItems: 'flex-start', gap: 'var(--s3)',
                    padding: 'var(--s3) var(--s4)', marginBottom: 'var(--s6)',
                    background: 'rgba(255,176,32,0.08)', border: '1px solid rgba(255,176,32,0.2)',
                    borderRadius: 'var(--r-md)'
                }}>
                    <div style={{ fontSize: 'var(--size-xs)', color: 'var(--amber-core)', lineHeight: 1.5 }}>
                        🔒 You are setting up your account password. Please choose a strong password to secure your profile.
                    </div>
                </div>

                {error && <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{error}</div>}

                <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}>
                    {/* New Password */}
                    <div className="form-group" style={{ marginBottom: 0 }}>
                        <label className="form-label">New Password</label>
                        <div style={{ position: 'relative' }}>
                            <input
                                type={showNew ? 'text' : 'password'}
                                className="form-input"
                                placeholder="Minimum 8 characters"
                                value={newPassword}
                                onChange={e => { setNewPassword(e.target.value); setError(null); }}
                                required
                                minLength={8}
                                disabled={loading}
                                autoFocus
                                style={{ paddingRight: 44 }}
                            />
                            <button
                                type="button"
                                onClick={() => setShowNew(v => !v)}
                                style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center' }}
                            >
                                {showNew ? <EyeOff size={16} /> : <Eye size={16} />}
                            </button>
                        </div>
                        {/* Strength meter */}
                        {newPassword && (
                            <div style={{ marginTop: 'var(--s2)' }}>
                                <div style={{ display: 'flex', gap: 4, marginBottom: 4 }}>
                                    {[1, 2, 3, 4, 5].map(i => (
                                        <div key={i} style={{
                                            flex: 1, height: 3, borderRadius: 2,
                                            background: i <= strength ? strengthColor : 'var(--border-soft)',
                                            transition: 'background 0.3s'
                                        }} />
                                    ))}
                                </div>
                                <div style={{ fontSize: 'var(--size-xxs)', color: strengthColor, fontWeight: 600 }}>
                                    {strengthLabel}
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Confirm Password */}
                    <div className="form-group" style={{ marginBottom: 0 }}>
                        <label className="form-label">Confirm Password</label>
                        <div style={{ position: 'relative' }}>
                            <input
                                type={showConfirm ? 'text' : 'password'}
                                className="form-input"
                                placeholder="Repeat your new password"
                                value={confirmPassword}
                                onChange={e => { setConfirmPassword(e.target.value); setError(null); }}
                                required
                                disabled={loading}
                                style={{
                                    paddingRight: 44,
                                    borderColor: confirmPassword && confirmPassword !== newPassword
                                        ? 'var(--crimson-core)'
                                        : confirmPassword && confirmPassword === newPassword
                                            ? 'var(--jade-core)'
                                            : undefined
                                }}
                            />
                            <button
                                type="button"
                                onClick={() => setShowConfirm(v => !v)}
                                style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center' }}
                            >
                                {showConfirm ? <EyeOff size={16} /> : <Eye size={16} />}
                            </button>
                        </div>
                        {confirmPassword && confirmPassword !== newPassword && (
                            <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--crimson-core)', marginTop: 'var(--s1)' }}>
                                Passwords do not match
                            </div>
                        )}
                    </div>

                    <button
                        type="submit"
                        className="btn btn-primary w-full"
                        disabled={loading || !newPassword || !confirmPassword}
                        style={{ justifyContent: 'center', height: 52, fontSize: 'var(--size-md)', borderRadius: 'var(--r-lg)', marginTop: 'var(--s2)' }}
                    >
                        {loading
                            ? <div className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} />
                            : <><Lock size={16} /> Set New Password <ArrowRight size={16} /></>}
                    </button>
                </form>

                <div style={{ marginTop: 'var(--s5)', textAlign: 'center' }}>
                    <button
                        type="button"
                        onClick={logout}
                        style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', fontSize: 'var(--size-xs)', fontFamily: 'var(--font-body)' }}
                    >
                        Sign out instead
                    </button>
                </div>
            </div>

            <style>{`
                .change-pw-overlay {
                    position: fixed;
                    inset: 0;
                    background: rgba(5, 7, 9, 0.92);
                    backdrop-filter: blur(16px);
                    z-index: 9999;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: var(--s6);
                    animation: fadeIn 0.3s var(--ease-out);
                }
                .change-pw-card {
                    width: 100%;
                    max-width: 440px;
                    background: var(--bg-elevated);
                    border: 1px solid var(--border-medium);
                    border-radius: var(--r-2xl);
                    padding: var(--s10);
                    box-shadow: var(--shadow-modal);
                    animation: modalSlide 0.4s var(--ease-out);
                }
            `}</style>
        </div>
    );
};

export default ChangePasswordModal;
