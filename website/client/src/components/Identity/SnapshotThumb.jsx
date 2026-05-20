import { useState } from 'react';
import { ImageOff } from 'lucide-react';
import { snapshotUrl } from '../../utils/snapshotImage';

/**
 * Snapshot thumbnail with visible fallback when Storage file is missing (404).
 * Black box usually means path exists in DB but JPEG was deleted or never uploaded.
 */
export default function SnapshotThumb({
    path,
    alt = '',
    style = {},
    boxStyle = {},
    missingLabel = 'File missing',
}) {
    const [failed, setFailed] = useState(false);
    const url = snapshotUrl(path);

    const box = {
        aspectRatio: '1',
        background: '#0a0c10',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
        ...boxStyle,
    };

    if (!url || failed) {
        return (
            <div style={box} title={!path ? 'No snapshot path in database' : missingLabel}>
                <div style={{ textAlign: 'center', padding: 6 }}>
                    <ImageOff size={18} style={{ color: 'var(--text-muted)', opacity: 0.7 }} />
                    <div style={{ fontSize: 8, color: 'var(--text-muted)', marginTop: 4, lineHeight: 1.2 }}>
                        {!path ? 'No path' : missingLabel}
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div style={box}>
            <img
                src={url}
                alt={alt}
                style={{ width: '100%', height: '100%', objectFit: 'cover', ...style }}
                onError={() => setFailed(true)}
            />
        </div>
    );
}
