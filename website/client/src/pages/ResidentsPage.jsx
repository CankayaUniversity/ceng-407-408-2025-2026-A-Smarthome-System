import { useState, useEffect } from 'react';
import { Users, UserPlus, Trash2, Camera, ShieldCheck, X, Upload, CheckCircle } from 'lucide-react';
import { supabase, getPublicUrl } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';

const ResidentsPage = () => {
    const { user } = useAuth();
    const [residents, setResidents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [formName, setFormName] = useState('');
    const [formImage, setFormImage] = useState(null);
    const [formImagePreview, setFormImagePreview] = useState(null);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(null);

    const [captureTarget, setCaptureTarget] = useState(null);
    const [captureImage, setCaptureImage] = useState(null);
    const [capturePreview, setCapturePreview] = useState(null);
    const [captureSaving, setCaptureSaving] = useState(false);
    const [captureSuccess, setCaptureSuccess] = useState(false);

    const fetchResidents = async () => {
        const { data } = await supabase.from('residents').select('*, resident_faces(*)').order('created_at', { ascending: false });
        setResidents(data || []);
        setLoading(false);
    };

    useEffect(() => { fetchResidents(); }, []);

    const handleAdd = async (e) => {
        e.preventDefault();
        if (!formName.trim()) return;
        if (!user?.id) {
            setError('You must be signed in to add a resident.');
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
                if (!uploadErr) photoPath = filePath;
            }

            const { data, error: insertErr } = await supabase.from('residents').insert({
                user_id: user.id,
                name: formName.trim(),
                photo_path: photoPath,
            }).select().single();

            if (insertErr) throw insertErr;
            setResidents(prev => [data, ...prev]);
            setShowModal(false); setFormName(''); setFormImage(null); setFormImagePreview(null);
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
        try {
            const ext = captureImage.name.split('.').pop();
            const filePath = `resident_photos/${captureTarget.id}_${Date.now()}.${ext}`;
            await supabase.storage.from('event-snapshots').upload(filePath, captureImage, { contentType: captureImage.type });
            await supabase.from('residents').update({ photo_path: filePath }).eq('id', captureTarget.id);
            setCaptureSuccess(true);
            await fetchResidents();
            setTimeout(() => { setCaptureTarget(null); setCaptureSuccess(false); }, 1500);
        } catch (err) { console.error(err); }
        finally { setCaptureSaving(false); }
    };

    const handleDelete = async (id) => {
        if (!confirm('Remove this resident?')) return;
        await supabase.from('residents').delete().eq('id', id);
        setResidents(prev => prev.filter(r => r.id !== id));
    };

    return (
        <div>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 'var(--s8)', paddingBottom: 'var(--s6)', borderBottom: '1px solid var(--border-dim)' }}>
                <div>
                    <h1 style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--size-3xl)', fontWeight: 700, letterSpacing: '-0.03em', lineHeight: 1.1 }}>Residents</h1>
                    <p style={{ fontSize: 'var(--size-sm)', color: 'var(--text-muted)', marginTop: 'var(--s2)' }}>Authorized faces for AI recognition</p>
                </div>
                <button className="btn btn-primary" onClick={() => setShowModal(true)}><UserPlus size={16} /> Add Resident</button>
            </div>

            {loading ? (
                <div className="loading-container"><div className="spinner" /><div className="loading-text">Loading residents</div></div>
            ) : residents.length === 0 ? (
                <div className="card empty-state">
                    <div className="empty-state-icon"><Users size={48} /></div>
                    <h3>No Face Profiles</h3>
                    <p>Add residents to enable AI face recognition at your front door.</p>
                    <button className="btn btn-primary" onClick={() => setShowModal(true)} style={{ marginTop: 'var(--s5)' }}><UserPlus size={15} /> Add first resident</button>
                </div>
            ) : (
                <div className="grid grid-3">
                    {residents.map((r, i) => {
                        const face = r.resident_faces?.[0];
                        const photoUrl = face?.image_path ? getPublicUrl('event-snapshots', face.image_path) : (r.photo_path ? getPublicUrl('event-snapshots', r.photo_path) : null);
                        const hasEmbedding = face?.embedding_json || r.embedding;
                        return (
                            <div key={r.id} className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--s4)', animation: `fadeIn 0.4s var(--ease-out) ${i * 60}ms both`, opacity: 0 }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)' }}>
                                    <div style={{ width: 56, height: 56, background: photoUrl ? 'transparent' : 'linear-gradient(135deg, var(--ember-core), var(--violet-core))', borderRadius: 'var(--r-xl)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 'var(--size-xl)', color: 'white', flexShrink: 0, overflow: 'hidden' }}>
                                        {photoUrl ? <img src={photoUrl} alt={r.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : r.name.charAt(0).toUpperCase()}
                                    </div>
                                    <div style={{ flex: 1, minWidth: 0 }}>
                                        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 'var(--size-lg)', letterSpacing: '-0.02em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.name}</div>
                                        <div style={{ fontSize: 'var(--size-xs)', color: 'var(--text-muted)', marginTop: 2 }}>Resident</div>
                                    </div>
                                </div>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s2)', padding: 'var(--s3)', background: 'var(--bg-raised)', borderRadius: 'var(--r-md)', border: '1px solid var(--border-dim)' }}>
                                    <Camera size={14} style={{ color: 'var(--text-muted)' }} />
                                    <span style={{ fontSize: 'var(--size-xs)', color: 'var(--text-secondary)' }}>{hasEmbedding ? 'AI profile ready' : 'No face data yet'}</span>
                                    <div className={`badge ${hasEmbedding ? 'badge-success' : 'badge-neutral'}`} style={{ marginLeft: 'auto' }}>
                                        {hasEmbedding ? <><ShieldCheck size={10} />&nbsp;Active</> : 'Pending'}
                                    </div>
                                </div>
                                <div style={{ display: 'flex', gap: 'var(--s2)', marginTop: 'auto' }}>
                                    <button className="btn btn-ghost btn-sm" style={{ flex: 1, justifyContent: 'center' }} onClick={() => handleCaptureOpen(r)}><Camera size={13} /> Upload Photo</button>
                                    <button className="btn btn-danger btn-sm" onClick={() => handleDelete(r.id)}><Trash2 size={13} /></button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}

            {showModal && (
                <div className="modal-overlay" onClick={() => setShowModal(false)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>Add Resident</h2>
                            <button className="modal-close" onClick={() => setShowModal(false)}><X size={20} /></button>
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
                            <div style={{ display: 'flex', gap: 'var(--s3)', justifyContent: 'flex-end' }}>
                                <button type="button" className="btn btn-ghost" onClick={() => { setShowModal(false); setFormImagePreview(null); }}>Cancel</button>
                                <button type="submit" className="btn btn-primary" disabled={saving}>
                                    {saving ? <div className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : <><UserPlus size={15} /> Add Resident</>}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {captureTarget && (
                <div className="modal-overlay" onClick={() => setCaptureTarget(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>Upload Photo — {captureTarget.name}</h2>
                            <button className="modal-close" onClick={() => setCaptureTarget(null)}><X size={20} /></button>
                        </div>
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
                </div>
            )}
        </div>
    );
};

export default ResidentsPage;
