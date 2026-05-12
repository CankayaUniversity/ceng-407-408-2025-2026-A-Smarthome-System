import { useEffect, useRef, useState } from 'react';
import { Radio, WifiOff, Video, VideoOff } from 'lucide-react';

const DEFAULT_RELAY_URL =
  import.meta.env.VITE_RELAY_WS_URL || 'ws://92.5.17.205:8080';
const RECONNECT_BASE_MS = 1000;
const RECONNECT_MAX_MS  = 16000;

const LiveCameraFeed = ({ url = DEFAULT_RELAY_URL }) => {
  const [isLive, setIsLive]         = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [fps, setFps]               = useState(0);

  const wsRef             = useRef(null);
  const imgRef            = useRef(null);
  const reconnectTimerRef = useRef(null);
  const fpsTimerRef       = useRef(null);
  const delayRef          = useRef(RECONNECT_BASE_MS);
  const frameCountRef     = useRef(0);
  const manuallyClosedRef = useRef(false);

  // ── Internal: tear down the WebSocket cleanly ──────────────
  function teardown() {
    manuallyClosedRef.current = true;
    if (reconnectTimerRef.current) {
      clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
    if (fpsTimerRef.current) {
      clearInterval(fpsTimerRef.current);
      fpsTimerRef.current = null;
    }
    const ws = wsRef.current;
    wsRef.current = null;
    if (ws) { try { ws.close(); } catch {} }
    setIsLive(false);
    setConnecting(false);
    setFps(0);
  }

  // ── Internal: open the WebSocket ───────────────────────────
  function connect() {
    const existing = wsRef.current;
    if (
      existing &&
      (existing.readyState === WebSocket.OPEN ||
       existing.readyState === WebSocket.CONNECTING)
    ) {
      return;
    }
    if (manuallyClosedRef.current) return;

    setConnecting(true);
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      if (manuallyClosedRef.current) { ws.close(); return; }
      console.debug('[LiveCameraFeed] WebSocket open');
      ws.send(JSON.stringify({ role: 'viewer' }));
      setIsLive(true);
      setConnecting(false);
      delayRef.current = RECONNECT_BASE_MS;
      frameCountRef.current = 0;

      if (fpsTimerRef.current) clearInterval(fpsTimerRef.current);
      fpsTimerRef.current = setInterval(() => {
        setFps(frameCountRef.current);
        frameCountRef.current = 0;
      }, 1000);
    };

    ws.onmessage = async (event) => {
      try {
        let payload;
        if (event.data instanceof Blob) {
          payload = await event.data.text();
        } else {
          payload = String(event.data);
        }
        if (!payload || payload === '[object Blob]') return;

        const src = payload.startsWith('data:image')
          ? payload
          : `data:image/jpeg;base64,${payload}`;

        if (imgRef.current) {
          imgRef.current.src = src;
        }
        frameCountRef.current++;
      } catch (err) {
        console.warn('[LiveCameraFeed] Frame decode error:', err);
      }
    };

    ws.onerror = (err) => {
      console.warn('[LiveCameraFeed] WebSocket error:', err);
    };

    ws.onclose = (e) => {
      console.debug('[LiveCameraFeed] WebSocket closed', e.code, e.reason);
      if (fpsTimerRef.current) {
        clearInterval(fpsTimerRef.current);
        fpsTimerRef.current = null;
      }
      setFps(0);
      setIsLive(false);
      setConnecting(false);

      if (!manuallyClosedRef.current) {
        const delay = delayRef.current;
        delayRef.current = Math.min(delay * 2, RECONNECT_MAX_MS);
        reconnectTimerRef.current = setTimeout(connect, delay);
      }
    };
  }

  // ── Cleanup on unmount or url change ───────────────────────
  useEffect(() => {
    return () => { teardown(); };
  }, [url]);

  // ── LIVE toggle ────────────────────────────────────────────
  const handleToggleLive = () => {
    if (isLive || connecting) {
      teardown();
    } else {
      manuallyClosedRef.current = false;
      connect();
    }
  };

  // ── Render ─────────────────────────────────────────────────
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', background: 'var(--bg-base, #0a0c10)', overflow: 'hidden' }}>
      <img
        ref={imgRef}
        alt="Live camera feed"
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: isLive ? 'block' : 'none' }}
      />

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
            {connecting ? <Radio size={28} className="spin-icon" /> : <WifiOff size={28} />}
          </div>
          <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--text-secondary, #aaa)' }}>
            {connecting ? 'Connecting to camera...' : 'Click LIVE to start camera'}
          </div>
          <div style={{ fontSize: 14, color: 'var(--text-muted, #666)', maxWidth: 320 }}>
            {connecting
              ? 'Establishing connection to the relay server.'
              : 'The live feed is on-demand. Press the button below to start streaming.'}
          </div>
        </div>
      )}

      <div style={{ position: 'absolute', bottom: 16, left: '50%', transform: 'translateX(-50%)', zIndex: 3 }}>
        <button
          onClick={handleToggleLive}
          style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '8px 18px',
            background: isLive ? 'rgba(239,68,68,0.9)' : 'rgba(34,197,94,0.9)',
            color: 'white', border: 'none', borderRadius: 999,
            fontSize: 12, fontWeight: 700, cursor: 'pointer',
            backdropFilter: 'blur(6px)',
          }}
        >
          {isLive ? <VideoOff size={14} /> : <Video size={14} />}
          {isLive ? 'STOP' : connecting ? 'CONNECTING...' : 'LIVE'}
        </button>
      </div>

      <style>{`
        .spin-icon { animation: spin 1.2s linear infinite; }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
        @keyframes alertBreath { 0%,100% { opacity: 1; } 50% { opacity: 0.4; } }
      `}</style>
    </div>
  );
};

export default LiveCameraFeed;
