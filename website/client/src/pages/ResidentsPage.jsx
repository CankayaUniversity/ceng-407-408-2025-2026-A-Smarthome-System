import { useState, useEffect } from 'react';
import ModalOverlay from '../components/ModalOverlay';
import { Users, UserPlus, Trash2, Camera, ShieldCheck, X, Upload, CheckCircle, RefreshCw, Mail, KeyRound, Copy, Check, UserCheck } from 'lucide-react';
import { supabase, getPublicUrl } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';

/* ─── Avatar fallback: initials with gradient ──────────────── */
function AvatarInitials({ name, size = 56 }) {
    const initials = name
        ? name.trim().split(/\s+/).slice(0, 2).map(w => w[0]?.toUpperCase() ?? '').join('')
        : '?';
    return (
        <div style={{
            width: size, height: size, flexShrink: 0,
            background: 'linear-gradient(135deg, var(--ember-core), var(--violet-core))',
            borderRadius: 'var(--r-xl)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: 'var(--font-display)', fontWeight: 800,
            fontSize: size * 0.35, color: 'white',
        }}>
            {initials || '?'}
        </div>
    );
}

/* ─── Email Sent success modal ──────────────────────────────── */
function EmailSentModal({ name, email, onClose }) {
    return (
        <ModalOverlay onClose={onClose}>
            <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
                <div className="modal-header">
                    <h2 style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--jade-core)' }}>
                        <CheckCircle size={20} /> Account Created
                    </h2>
                    <button className="modal-close" onClick={onClose}><X size={20} /></button>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 'var(--s5)', padding: 'var(--s6) 0', textAlign: 'center' }}>
                    <div style={{
                        width: 64, height: 64, borderRadius: '50%',
                        background: 'rgba(0,229,160,0.1)', border: '2px solid rgba(0,229,160,0.25)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center'
                    }}>
                        <Mail size={28} style={{ color: 'var(--jade-core)' }} />
                    </div>
                    <div>
                        <div style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-lg)', fontWeight: 700, marginBottom: 'var(--s2)' }}>
                            Setup email sent!
                        </div>
                        <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', lineHeight: 1.7, maxWidth: 320 }}>
                            An account has been created for <strong style={{ color: 'var(--text-primary)' }}>{name}</strong>.
                            A password setup link has been sent to <span style={{ fontFamily: 'monospace', color: 'var(--cyan-core)' }}>{email}</span>.
                        </p>
                        <p style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 'var(--s3)' }}>
                            The resident will be prompted to set their own password when they click the link.
                        </p>
                    </div>
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                    <button className="btn btn-primary" onClick={onClose}>Done</button>
                </div>
            </div>
        </ModalOverlay>
    );
}

const ResidentsPage = () => {
    const { user, isAdmin, createResidentAccount } = useAuth();
    // State for adding account to existing resident
    const [createAccountTarget, setCreateAccountTarget] = useState(null);
    const [createAccountEmail, setCreateAccountEmail] = useState('');
    const [createAccountSaving, setCreateAccountSaving] = useState(false);
    const [createAccountError, setCreateAccountError] = useState(null);
    const [residents, setResidents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [formName, setFormName] = useState('');
    const [formImage, setFormImage] = useState(null);
    const [formImagePreview, setFormImagePreview] = useState(null);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(null);

    // Account creation fields
    const [createAccount, setCreateAccount] = useState(false);
    const [accountEmail, setAccountEmail] = useState('');

    // Credentials / email sent modal state
    const [emailSent, setEmailSent] = useState(null);

    const [captureTarget, setCaptureTarget] = useState(null);
    const [captureImage, setCaptureImage] = useState(null);
    const [capturePreview, setCapturePreview] = useState(null);
    const [captureSaving, setCaptureSaving] = useState(false);
    const [captureSuccess, setCaptureSuccess] = useState(false);
    const [refreshing, setRefreshing] = useState(false);

    const loadResidentsRows = async () => {
        const { data } = await supabase.from('residents').select('*').order('created_at', { ascending: false });
        return data || [];
    };

    const fetchResidents = async () => {
        setLoading(true);
        setResidents(await loadResidentsRows());
        setLoading(false);
    };

    const handleRefreshList = async () => {
        setRefreshing(true);
        try {
            setResidents(await loadResidentsRows());
        } finally {
            setRefreshing(false);
        }
    };

    useEffect(() => { fetchResidents(); }, []);

    const resetModal = () => {
        setShowModal(false);
        setFormName('');
        setFormImage(null);
        setFormImagePreview(null);
        setCreateAccount(false);
        setAccountEmail('');
        setError(null);
    };

    const handleAdd = async (e) => {
        e.preventDefault();
        if (!isAdmin) {
            setError('Only administrators can add residents.');
            return;
        }
        if (!formName.trim()) return;
        if (!user?.id) {
            setError('You must be signed in to add a resident.');
            return;
        }
        if (createAccount && !accountEmail.trim()) {
            setError('Please enter an email address for the account.');
            return;
        }

        setSaving(true); setError(null);
        try {
            let photoPath = null;
            if (formImage) {
                const ext = formImage.name.split('.').pop();
                const filePath = `resident_photos/${Date.now()}.${ext}`;
                const { error: uploadErr } = await supabase.storage
                    .from('event-snapshots')
                    .upload(filePath, formImage, { contentType: formImage.type });
                if (uploadErr) throw new Error(`Storage upload failed: ${uploadErr.message}. Check bucket policies in Supabase Dashboard.`);
                photoPath = filePath;
            }

            const { data, error: insertErr } = await supabase.from('residents').insert({
                user_id: null,
                name: formName.trim(),
                photo_path: photoPath,
                account_email: (createAccount && accountEmail.trim()) ? accountEmail.trim() : null,
            }).select().single();

            if (insertErr) throw insertErr;

            // Create auth account if requested
            if (createAccount && accountEmail.trim()) {
                const result = await createResidentAccount(formName.trim(), accountEmail.trim());
                if (!result.success) {
                    setError(`Resident added, but account creation failed: ${result.error}`);
                    setSaving(false);
                    return;
                }
                const { data: updated } = await supabase.from('residents')
                    .update({ account_email: accountEmail.trim(), auth_user_id: result.userId })
                    .eq('id', data.id)
                    .select()
                    .single();
                setResidents(prev => [{ ...(updated || { ...data, account_email: accountEmail.trim(), auth_user_id: result.userId }) }, ...prev]);
                resetModal();
                setEmailSent({ name: formName.trim(), email: accountEmail.trim() });
            } else {
                setResidents(prev => [{ ...data }, ...prev]);
                resetModal();
            }
        } catch (err) {
            setError(err.message || 'Failed to add resident');
        } finally { setSaving(false); }
    };

    const handleFormImageChange = (e) => {
        const file = e.target.files[0] || null;
        setFormImage(file);
        if (file) {
            const reader = new FileReader();
            reader.onload = ev => setFormImagePreview(ev.target.result);
            reader.readAsDataURL(file);
        } else { setFormImagePreview(null); }
    };

    const handleCaptureOpen = (resident) => {
        setCaptureTarget(resident);
        setCaptureImage(null); setCapturePreview(null); setCaptureSuccess(false);
    };

    const handleCaptureImageChange = (e) => {
        const file = e.target.files[0] || null;
        setCaptureImage(file);
        if (file) {
            const reader = new FileReader();
            reader.onload = ev => setCapturePreview(ev.target.result);
            reader.readAsDataURL(file);
        } else { setCapturePreview(null); }
    };

    const handleCaptureSubmit = async (e) => {
        e.preventDefault();
        if (!captureImage) return;
        setCaptureSaving(true);
        setError(null);
        try {
            const ext = captureImage.name.split('.').pop();
            const filePath = `resident_photos/${captureTarget.id}_${Date.now()}.${ext}`;
            const { error: uploadErr } = await supabase.storage.from('event-snapshots').upload(filePath, captureImage, { contentType: captureImage.type });
            if (uploadErr) throw new Error(`Storage upload failed: ${uploadErr.message}. Check bucket policies in Supabase Dashboard.`);
            const { error: updateErr } = await supabase.from('residents').update({ photo_path: filePath }).eq('id', captureTarget.id);
            if (updateErr) throw updateErr;
            setCaptureSuccess(true);
            await fetchResidents();
            setTimeout(() => { setCaptureTarget(null); setCaptureSuccess(false); }, 1500);
        } catch (err) {
            console.error(err);
            setError(err.message || 'Photo upload failed');
        }
        finally { setCaptureSaving(false); }
    };

    const handleDelete = async (id) => {
        if (!isAdmin) return;
        if (!confirm('Remove this resident?')) return;
        await supabase.from('residents').delete().eq('id', id);
        setResidents(prev => prev.filter(r => r.id !== id));
    };

    return (
        <div>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Residents</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginTop: 'var(--s2)', maxWidth: 640, lineHeight: 1.6 }}>
                        Add household members so the front-door camera can recognize them. Upload a clear, front-facing photo for each person.
                        Optional login accounts let residents sign in to view their own dashboard.
                    </p>
                </div>
                <div style={{ display: 'flex', gap: 'var(--s2)', flexShrink: 0 }}>
                    <button type="button" className="btn btn-ghost" onClick={handleRefreshList} disabled={refreshing || loading} title="Refresh list">
                        {refreshing ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><RefreshCw size={16} /> Refresh</>}
                    </button>
                    {isAdmin && (
                        <button className="btn btn-primary" onClick={() => setShowModal(true)}><UserPlus size={16} /> Add Resident</button>
                    )}
                </div>
            </div>

            {loading ? (
                <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading residents</div></div>
            ) : residents.length === 0 ? (
                <div className="card empty-state">
                    <div className="empty-state-icon"><Users size={48} /></div>
                    <h3>No Face Profiles</h3>
                    <p>Add residents to enable AI face recognition at your front door.</p>
                    {isAdmin && (
                        <button className="btn btn-primary" onClick={() => setShowModal(true)} style={{ marginTop: 'var(--s5)' }}><UserPlus size={15} /> Add first resident</button>
                    )}
                </div>
            ) : (
                <div className="grid grid-3">
                    {residents.map((r, i) => {
                        const photoUrl = r.photo_path ? getPublicUrl('event-snapshots', r.photo_path) : null;
                        const rawEmb = r.embedding;
                        const hasEmbedding = Array.isArray(rawEmb)
                            ? rawEmb.length > 0
                            : Boolean(rawEmb);
                        const hasPhoto = Boolean(r.photo_path);
                        let statusLine;
                        let badgeContent;
                        let badgeClass;
                        if (hasEmbedding) {
                            statusLine = 'Ready for recognition at the front door.';
                            badgeContent = (<><ShieldCheck size={10} />&nbsp;Recognized</>);
                            badgeClass = 'badge-success';
                        } else if (hasPhoto) {
                            statusLine = 'Photo saved. Face profile is being prepared — tap Refresh in a few seconds.';
                            badgeContent = 'Processing';
                            badgeClass = 'badge-warning';
                        } else {
                            statusLine = 'Add a clear, front-facing photo to enable recognition.';
                            badgeContent = 'No photo';
                            badgeClass = 'badge-neutral';
                        }

                        // Safe name for display
                        const safeName = r.name || 'Unknown';

                        return (
                            <div key={r.id} className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)', animation: `fadeIn 0.4s var(--ease-out) ${i * 60}ms both`, opacity: 0 }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)' }}>
                                    {/* Avatar: photo or initials fallback */}
                                    <div style={{ width: 56, height: 56, flexShrink: 0, borderRadius: 'var(--r-xl)', overflow: 'hidden' }}>
                                        {photoUrl
                                            ? <img
                                                src={photoUrl}
                                                alt={safeName}
                                                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                                onError={e => { e.currentTarget.style.display = 'none'; }}
                                            />
                                            : <AvatarInitials name={safeName} size={56} />
                                        }
                                    </div>
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--size-lg)', letterSpacing: '-0.02em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{safeName}</div>
                                        <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 2 }}>Resident</div>
                                    </div>
                                </div>
                                <div style={{ display: 'flex', alignItems: 'flex-start', gap: 'var(--s2)', padding: 'var(--s3)', background: 'var(--bg-raised)', borderRadius: 'var(--r-md)', border: '1px solid var(--border-dim)' }}>
                                    <Camera size={14} style={{ color: 'var(--text-muted)', marginTop: 2, flexShrink: 0 }} />
                                    <span style={{ fontSize: 'var(--size-xs)', color: 'var(--text-secondary)', lineHeight: 1.45 }}>{statusLine}</span>
                                    <div className={`badge ${badgeClass}`} style={{ marginLeft: 'auto', flexShrink: 0, alignSelf: 'flex-start' }}>
                                        {badgeContent}
                                    </div>
                                </div>
                                <div style={{ display: 'flex', gap: 'var(--s2)', marginTop: 'auto' }}>
                                    <button className="btn btn-ghost btn-sm" style={{ flex: 1, justifyContent: 'center' }} onClick={() => handleCaptureOpen(r)}><Camera size={13} /> Upload Photo</button>
                                    {isAdmin && !r.account_email && (
                                        <button
                                            className="btn btn-ghost btn-sm"
                                            style={{ flex: 1, justifyContent: 'center', borderColor: 'rgba(155,89,255,0.3)', color: 'var(--violet-core)' }}
                                            onClick={() => { setCreateAccountTarget(r); setCreateAccountEmail(''); setCreateAccountError(null); }}
                                            title="Create login account for this resident"
                                        >
                                            <UserCheck size={13} /> Create Account
                                        </button>
                                    )}
                                    {r.account_email && (
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 'var(--size-xxs)', color: 'var(--jade-core)', padding: '0 var(--s2)' }} title={r.account_email}>
                                            <CheckCircle size={11} /> Linked
                                        </div>
                                    )}
                                    {isAdmin && (
                                        <button className="btn btn-danger btn-sm" onClick={() => handleDelete(r.id)}><Trash2 size={13} /></button>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}

            {/* Add Resident Modal */}
            {showModal && (
                <ModalOverlay onClose={resetModal}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>Add Resident</h2>
                            <button className="modal-close" onClick={resetModal}><X size={20} /></button>
                        </div>
                        {error && <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{error}</div>}
                        <form onSubmit={handleAdd} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s5)' }}>
                            <div className="form-group" style={{ marginBottom: 0 }}>
                                <label className="form-label">Full Name</label>
                                <input type="text" className="form-input" placeholder="e.g. John Doe" value={formName} onChange={e => setFormName(e.target.value)} required disabled={saving} autoFocus />
                            </div>
                            <div className="form-group" style={{ marginBottom: 0 }}>
                                <label className="form-label">Face Photo <span style={{ color: 'var(--text-muted)', fontWeight: 400 }}>(optional)</span></label>
                                {formImagePreview && <div style={{ marginBottom: 'var(--s3)' }}><img src={formImagePreview} alt="Preview" style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 'var(--r-xl)', border: '2px solid var(--border-dim)' }} /></div>}
                                <input type="file" accept="image/jpeg,image/png,image/webp" className="form-input" onChange={handleFormImageChange} disabled={saving} style={{ paddingTop: 6 }} />
                            </div>

                            {/* Admin-only: Create Account Section */}
                            {isAdmin && (
                                <div style={{
                                    padding: 'var(--s4)',
                                    background: createAccount ? 'rgba(155,89,255,0.06)' : 'var(--bg-raised)',
                                    border: `1px solid ${createAccount ? 'rgba(155,89,255,0.25)' : 'var(--border-soft)'}`,
                                    borderRadius: 'var(--r-md)',
                                    transition: 'all 0.25s var(--ease-out)'
                                }}>
                                    <label style={{ display: 'flex', alignItems: 'center', gap: 'var(--s3)', cursor: 'pointer', userSelect: 'none' }}>
                                        <input
                                            type="checkbox"
                                            checked={createAccount}
                                            onChange={e => { setCreateAccount(e.target.checked); if (!e.target.checked) setAccountEmail(''); }}
                                            disabled={saving}
                                            style={{ width: 16, height: 16, accentColor: 'var(--violet-core)', cursor: 'pointer' }}
                                        />
                                        <div>
                                            <div style={{ fontSize: 'var(--size-sm)', fontWeight: 600, color: 'var(--text-primary)' }}>
                                                Create a login account for this resident
                                            </div>
                                            <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 2 }}>
                                                An email invite will be sent so they can set their own password
                                            </div>
                                        </div>
                                    </label>

                                    {/* Email input — animated reveal */}
                                    <div style={{
                                        overflow: 'hidden',
                                        maxHeight: createAccount ? 80 : 0,
                                        opacity: createAccount ? 1 : 0,
                                        transition: 'max-height 0.3s var(--ease-out), opacity 0.3s var(--ease-out)',
                                        marginTop: createAccount ? 'var(--s3)' : 0
                                    }}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)' }}>
                                            <Mail size={15} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                                            <input
                                                type="email"
                                                className="form-input"
                                                placeholder="resident@example.com"
                                                value={accountEmail}
                                                onChange={e => setAccountEmail(e.target.value)}
                                                required={createAccount}
                                                disabled={saving || !createAccount}
                                                style={{ flex: 1 }}
                                            />
                                        </div>
                                    </div>
                                </div>
                            )}

                            <div style={{ display: 'flex', gap: 'var(--s3)', justifyContent: 'flex-end' }}>
                                <button type="button" className="btn btn-ghost" onClick={resetModal}>Cancel</button>
                                <button type="submit" className="btn btn-primary" disabled={saving}>
                                    {saving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><UserPlus size={15} /> Add Resident</>}
                                </button>
                            </div>
                        </form>
                    </div>
                </ModalOverlay>
            )}

            {/* Email Sent Modal */}
            {emailSent && (
                <EmailSentModal
                    name={emailSent.name}
                    email={emailSent.email}
                    onClose={() => setEmailSent(null)}
                />
            )}

            {/* Create Account for Existing Resident Modal */}
            {createAccountTarget && (
                <ModalOverlay onClose={() => setCreateAccountTarget(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
                        <div className="modal-header">
                            <h2 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                <UserCheck size={18} style={{ color: 'var(--violet-core)' }} />
                                Create Account — {createAccountTarget.name}
                            </h2>
                            <button className="modal-close" onClick={() => setCreateAccountTarget(null)}><X size={20} /></button>
                        </div>
                        <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-secondary)', marginBottom: 'var(--s5)', lineHeight: 1.6 }}>
                            We will email this person a secure link to choose their own password. You will not see or set their password.
                        </p>
                        {createAccountError && <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{createAccountError}</div>}
                        <form
                            onSubmit={async (e) => {
                                e.preventDefault();
                                if (!createAccountEmail.trim()) return;
                                setCreateAccountSaving(true);
                                setCreateAccountError(null);
                                const result = await createResidentAccount(createAccountTarget.name, createAccountEmail.trim());
                                if (!result.success) {
                                    setCreateAccountError(result.error || 'Account creation failed');
                                    setCreateAccountSaving(false);
                                    return;
                                }
                                await supabase.from('residents')
                                    .update({
                                        account_email: createAccountEmail.trim(),
                                        auth_user_id: result.userId,
                                    })
                                    .eq('id', createAccountTarget.id);
                                setResidents(prev => prev.map(r =>
                                    r.id === createAccountTarget.id
                                        ? { ...r, account_email: createAccountEmail.trim(), auth_user_id: result.userId }
                                        : r
                                ));
                                setCreateAccountTarget(null);
                                setCreateAccountSaving(false);
                                setEmailSent({ name: createAccountTarget.name, email: createAccountEmail.trim() });
                            }}
                            style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)' }}
                        >
                            <div className="form-group" style={{ marginBottom: 0 }}>
                                <label className="form-label">Email Address</label>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)' }}>
                                    <Mail size={15} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                                    <input
                                        type="email"
                                        className="form-input"
                                        placeholder="resident@example.com"
                                        value={createAccountEmail}
                                        onChange={e => setCreateAccountEmail(e.target.value)}
                                        required
                                        autoFocus
                                        disabled={createAccountSaving}
                                        style={{ flex: 1 }}
                                    />
                                </div>
                            </div>
                            <div style={{ display: 'flex', gap: 'var(--s3)', justifyContent: 'flex-end' }}>
                                <button type="button" className="btn btn-ghost" onClick={() => setCreateAccountTarget(null)}>Cancel</button>
                                <button type="submit" className="btn btn-primary" disabled={createAccountSaving || !createAccountEmail.trim()} style={{ background: 'var(--violet-core)' }}>
                                    {createAccountSaving
                                        ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} />
                                        : <><UserCheck size={15} /> Create Account</>}
                                </button>
                            </div>
                        </form>
                    </div>
                </ModalOverlay>
            )}


            {/* Upload Photo Modal */}
            {captureTarget && (
                <ModalOverlay onClose={() => setCaptureTarget(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>Upload Photo — {captureTarget.name || 'Resident'}</h2>
                            <button className="modal-close" onClick={() => setCaptureTarget(null)}><X size={20} /></button>
                        </div>
                        {error && <div className="auth-error" style={{ marginBottom: 'var(--s4)' }}>{error}</div>}
                        {captureSuccess ? (
                            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 'var(--s4)', padding: 'var(--s8) 0' }}>
                                <CheckCircle size={48} style={{ color: 'var(--jade-core)' }} />
                                <div style={{ fontWeight: 600 }}>Photo updated successfully!</div>
                            </div>
                        ) : (
                            <form onSubmit={handleCaptureSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s5)' }}>
                                <div className="form-group" style={{ marginBottom: 0 }}>
                                    <label className="form-label">Face Photo</label>
                                    {capturePreview && <div style={{ marginBottom: 'var(--s3)' }}><img src={capturePreview} alt="Preview" style={{ width: 100, height: 100, objectFit: 'cover', borderRadius: 'var(--r-xl)', border: '2px solid var(--border-dim)' }} /></div>}
                                    <input type="file" accept="image/jpeg,image/png,image/webp" className="form-input" onChange={handleCaptureImageChange} disabled={captureSaving} style={{ paddingTop: 6 }} />
                                </div>
                                <div style={{ display: 'flex', gap: 'var(--s3)', justifyContent: 'flex-end' }}>
                                    <button type="button" className="btn btn-ghost" onClick={() => setCaptureTarget(null)}>Cancel</button>
                                    <button type="submit" className="btn btn-primary" disabled={captureSaving || !captureImage}>
                                        {captureSaving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><Upload size={15} /> Save Photo</>}
                                    </button>
                                </div>
                            </form>
                        )}
                    </div>
                </ModalOverlay>
            )}
        </div>
    );
};

export default ResidentsPage;
