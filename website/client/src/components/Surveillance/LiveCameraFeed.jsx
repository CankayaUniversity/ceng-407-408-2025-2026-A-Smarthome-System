import { useEffect, useRef, useState, useCallback } from 'react';
import { Radio, WifiOff, RefreshCw } from 'lucide-react';

const DEFAULT_RELAY_URL =
  import.meta.env.VITE_RELAY_WS_URL || 'ws://92.5.17.205:8080';
const RECONNECT_BASE_MS = 1000;
const RECONNECT_MAX_MS  = 16000;

const Status = Object.freeze({
  CONNECTING: 'connecting',
  CONNECTED:  'connected',
  ERROR:      'error',
  CLOSED:     'closed',
});

const LiveCameraFeed = ({ url = DEFAULT_RELAY_URL, autoConnect = true }) => {
  const [status, setStatus] = useState(Status.CLOSED);
  const [fps, setFps]       = useState(0);

  const wsRef        = useRef(null);
  const imgRef       = useRef(null);
  const reconnectRef = useRef(null);
  const delayRef     = useRef(RECONNECT_BASE_MS);
  const mountedRef   = useRef(true);
  const frameCountRef = useRef(0);
  const fpsTimerRef   = useRef(null);

  const connect = useCallback(() => {
    if (!mountedRef.current) return;
    if (wsRef.current) { try { wsRef.current.close(); } catch {} }

    setStatus(Status.CONNECTING);
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      if (!mountedRef.current) return;
      ws.send(JSON.stringify({ role: 'viewer' }));
      setStatus(Status.CONNECTED);
      delayRef.current = RECONNECT_BASE_MS;
      frameCountRef.current = 0;
      fpsTimerRef.current = setInterval(() => {
        if (mountedRef.current) {
          setFps(frameCountRef.current);
          frameCountRef.current = 0;
        }
      }, 1000);
    };

    ws.onmessage = (event) => {
      if (imgRef.current) {
        imgRef.current.src = `data:image/jpeg;base64,${event.data}`;
      }
      frameCountRef.current++;
    };

    ws.onerror = () => {
      if (mountedRef.current) setStatus(Status.ERROR);
    };

    ws.onclose = () => {
      if (!mountedRef.current) return;
      setStatus(Status.CLOSED);
      if (fpsTimerRef.current) clearInterval(fpsTimerRef.current);
      setFps(0);
      const delay = delayRef.current;
      delayRef.current = Math.min(delay * 2, RECONNECT_MAX_MS);
      reconnectRef.current = setTimeout(() => {
        if (mountedRef.current) connect();
      }, delay);
    };
  }, [url]);

  useEffect(() => {
    mountedRef.current = true;
    if (autoConnect) connect();
    return () => {
      mountedRef.current = false;
      if (reconnectRef.current) clearTimeout(reconnectRef.current);
      if (fpsTimerRef.current) clearInterval(fpsTimerRef.current);
      if (wsRef.current) { try { wsRef.current.close(); } catch {} }
    };
  }, [connect, autoConnect]);

  const handleRetry = () => {
    if (reconnectRef.current) clearTimeout(reconnectRef.current);
    delayRef.current = RECONNECT_BASE_MS;
    connect();
  };

  const isLive = status === Status.CONNECTED;

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', background: 'var(--bg-base, #0a0c10)', overflow: 'hidden' }}>
      <img ref={imgRef} alt="Live camera feed" style={{ width: '100%', height: '100%', objectFit: 'cover', display: isLive ? 'block' : 'none' }} />

      {isLive && (
        <>
          <div style={{ position: 'absolute', top: 12, left: 12, display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', background: 'rgba(0,0,0,0.55)', border: '1px solid rgba(255,59,92,0.5)', borderRadius: 999, backdropFilter: 'blur(6px)', color: '#ff3b5c', fontSize: 10, fontWeight: 700, letterSpacing: '0.06em', zIndex: 2 }}>
            <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#ff3b5c', boxShadow: '0 0 8px #ff3b5c', animation: 'alertBreath 2s infinite' }} />
            LIVE
          </div>
          <div style={{ position: 'absolute', top: 12, right: 12, padding: '3px 8px', background: 'rgba(0,0,0,0.5)', borderRadius: 999, color: 'rgba(255,255,255,0.7)', fontSize: 10, fontWeight: 600, fontFamily: 'monospace', zIndex: 2 }}>
            {fps} FPS
          </div>
        </>
      )}

      {!isLive && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: 24, gap: 12 }}>
          <div style={{ width: 64, height: 64, background: 'rgba(255,59,92,0.08)', border: '1px solid rgba(255,59,92,0.2)', borderRadius: 16, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--crimson-core, #ff3b5c)' }}>
            {status === Status.CONNECTING ? <Radio size={28} className="spin-icon" /> : <WifiOff size={28} />}
          </div>
          <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--text-secondary, #aaa)' }}>
            {status === Status.CONNECTING ? 'Connecting to camera...' : 'Live feed unavailable'}
          </div>
          <div style={{ fontSize: 14, color: 'var(--text-muted, #666)', maxWidth: 320 }}>
            {status === Status.CONNECTING ? 'Establishing connection to the relay server.' : 'The camera stream is offline. Click below to retry.'}
          </div>
          {status !== Status.CONNECTING && (
            <button onClick={handleRetry} style={{ marginTop: 8, display: 'inline-flex', alignItems: 'center', gap: 6, padding: '8px 18px', background: 'var(--ember-core, #f97316)', color: 'white', border: 'none', borderRadius: 999, fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>
              <RefreshCw size={13} /> RECONNECT
            </button>
          )}
        </div>
      )}

      <style>{`
        .spin-icon { animation: spin 1.2s linear infinite; }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
      `}</style>
    </div>
  );
};

export default LiveCameraFeed;
