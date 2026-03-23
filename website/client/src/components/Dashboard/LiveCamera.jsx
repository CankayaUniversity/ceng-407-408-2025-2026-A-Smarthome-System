import { useState } from 'react';
import { Camera, Maximize2, AlertCircle } from 'lucide-react';

const LiveCamera = ({ streamUrl, isOnline, fallbackImage }) => {
    const [hasError, setHasError] = useState(false);

    return (
        <div className="card" style={{ padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <div className="card-header" style={{ padding: 'var(--space-4) var(--space-5)', margin: 0, borderBottom: '1px solid var(--color-border)' }}>
                <div className="flex items-center gap-2">
                    <Camera size={18} className="text-muted" />
                    <h3 className="card-title" style={{ margin: 0 }}>Live Feed</h3>
                </div>
                <div className="flex items-center gap-3">
                    {isOnline ? (
                        <span className="badge badge-success">Live</span>
                    ) : (
                        <span className="badge badge-warning text-xs">Offline</span>
                    )}
                    <button className="btn btn-sm btn-secondary" style={{ padding: '4px' }}>
                        <Maximize2 size={16} />
                    </button>
                </div>
            </div>

            <div
                style={{
                    position: 'relative',
                    width: '100%',
                    aspectRatio: '16/9',
                    background: 'var(--color-bg-elevated)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                }}
            >
                {isOnline && !hasError ? (
                    <img
                        src={streamUrl}
                        alt="Live Camera Feed"
                        onError={() => setHasError(true)}
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                ) : (
                    <div className="flex-col items-center text-muted" style={{ gap: 'var(--space-2)' }}>
                        {fallbackImage ? (
                            <img
                                src={fallbackImage}
                                alt="Last known frame"
                                style={{ width: '100%', height: '100%', objectFit: 'cover', opacity: 0.5 }}
                            />
                        ) : (
                            <>
                                <AlertCircle size={32} style={{ opacity: 0.5 }} />
                                <span className="text-sm font-semibold">Camera Offline</span>
                                <span className="text-xs">No active stream available</span>
                            </>
                        )}

                    </div>
                )}

                {/* Timestamp Overlay */}
                {isOnline && !hasError && (
                    <div style={{
                        position: 'absolute',
                        bottom: 'var(--space-2)',
                        right: 'var(--space-3)',
                        background: 'rgba(0,0,0,0.6)',
                        padding: '2px 8px',
                        borderRadius: 'var(--border-radius-sm)',
                        fontSize: 'var(--font-size-xs)',
                        fontFamily: 'monospace',
                        color: 'white',
                        backdropFilter: 'blur(4px)'
                    }}>
                        {new Date().toLocaleTimeString()}
                    </div>
                )}
            </div>
        </div>
    );
};

export default LiveCamera;
