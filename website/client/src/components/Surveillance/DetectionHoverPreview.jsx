import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { Shield, ShieldOff } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const PREVIEW_W = 240;
const PREVIEW_H = 180;
const GAP = 12;

const DetectionHoverPreview = ({ event, anchorRect, snapshotUrl }) => {
    const [pos, setPos] = useState(() => computePosition(anchorRect));

    useEffect(() => {
        setPos(computePosition(anchorRect));
    }, [anchorRect]);

    if (!event || !anchorRect) return null;

    const face = event.event_faces?.[0];
    const isKnown = face?.classification === 'resident';
    const personName = face?.residents?.name || (isKnown ? 'Authorized Person' : 'Unknown Person');

    const node = (
        <div
            style={{
                position: 'fixed',
                top: pos.top,
                left: pos.left,
                width: PREVIEW_W,
                zIndex: 5000,
                pointerEvents: 'none',
                animation: 'hoverPreviewIn 180ms var(--ease-out) both',
            }}
        >
            <div
                style={{
                    background: 'var(--bg-elevated)',
                    border: '1px solid var(--border-medium)',
                    borderRadius: 'var(--r-lg)',
                    boxShadow: 'var(--shadow-modal)',
                    overflow: 'hidden',
                    backdropFilter: 'blur(16px)',
                }}
            >
                <div
                    style={{
                        width: '100%',
                        height: PREVIEW_H,
                        background: '#0a0c10',
                        position: 'relative',
                        overflow: 'hidden',
                    }}
                >
                    {snapshotUrl ? (
                        <img
                            src={snapshotUrl}
                            alt="Detection preview"
                            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                        />
                    ) : (
                        <div
                            style={{
                                position: 'absolute',
                                inset: 0,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                color: 'var(--text-muted)',
                                fontSize: 'var(--size-xs)',
                                letterSpacing: '0.08em',
                                textTransform: 'uppercase',
                            }}
                        >
                            No image
                        </div>
                    )}
                    <div
                        style={{
                            position: 'absolute',
                            top: 8,
                            left: 8,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 6,
                            padding: '3px 8px',
                            background: 'rgba(0,0,0,0.55)',
                            border: `1px solid ${isKnown ? 'rgba(0,229,160,0.4)' : 'rgba(255,59,92,0.4)'}`,
                            borderRadius: 'var(--r-full)',
                            color: isKnown ? '#00e5a0' : '#ff3b5c',
                            fontSize: 10,
                            fontWeight: 700,
                            letterSpacing: '0.06em',
                            textTransform: 'uppercase',
                            backdropFilter: 'blur(6px)',
                        }}
                    >
                        {isKnown ? <Shield size={11} /> : <ShieldOff size={11} />}
                        {isKnown ? 'Resident' : 'Unknown'}
                    </div>
                </div>
                <div style={{ padding: 'var(--s3) var(--s4)' }}>
                    <div
                        style={{
                            fontSize: 'var(--size-sm)',
                            fontWeight: 700,
                            color: 'var(--text-primary)',
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                        }}
                    >
                        {personName}
                    </div>
                    <div style={{ fontSize: 'var(--size-xxs)', color: 'var(--text-muted)', marginTop: 2 }}>
                        {event.created_at
                            ? formatDistanceToNow(new Date(event.created_at), { addSuffix: true })
                            : 'Just now'}
                    </div>
                </div>
            </div>
            <style>{`
                @keyframes hoverPreviewIn {
                    from { opacity: 0; transform: translateY(4px) scale(0.98); }
                    to   { opacity: 1; transform: translateY(0) scale(1); }
                }
            `}</style>
        </div>
    );

    return createPortal(node, document.body);
};

function computePosition(rect) {
    if (!rect) return { top: 0, left: 0 };
    const vw = typeof window !== 'undefined' ? window.innerWidth : 1280;
    const vh = typeof window !== 'undefined' ? window.innerHeight : 800;

    let left = rect.left - PREVIEW_W - GAP;
    if (left < GAP) {
        // Flip to the right of the anchor when there's no room on the left.
        left = rect.right + GAP;
    }
    if (left + PREVIEW_W + GAP > vw) {
        left = Math.max(GAP, vw - PREVIEW_W - GAP);
    }

    const PREVIEW_TOTAL_H = PREVIEW_H + 64;
    let top = rect.top + rect.height / 2 - PREVIEW_TOTAL_H / 2;
    if (top < GAP) top = GAP;
    if (top + PREVIEW_TOTAL_H + GAP > vh) {
        top = Math.max(GAP, vh - PREVIEW_TOTAL_H - GAP);
    }

    return { top, left };
}

export default DetectionHoverPreview;
