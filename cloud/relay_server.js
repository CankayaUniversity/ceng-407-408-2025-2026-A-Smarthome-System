/**
 * ─────────────────────────────────────────────────────────────────
 *  SmartHome — WebSocket Relay Server
 * ─────────────────────────────────────────────────────────────────
 *  Accepts JPEG frames (base64) from the Raspberry Pi streamer
 *  and broadcasts them to every connected viewer (website / mobile).
 *
 *  Protocol
 *  --------
 *  • First message from a socket must be a JSON role declaration:
 *        { "role": "streamer" }   – camera source (only one allowed)
 *        { "role": "viewer" }     – web / mobile consumer
 *
 *  • After registration the streamer sends raw base64 strings;
 *    the server relays them verbatim to all viewers.
 *
 *  Run:  node relay_server.js
 *  Port: 8080 (configurable via PORT env var)
 * ─────────────────────────────────────────────────────────────────
 */

const { WebSocketServer } = require('ws');

const PORT = parseInt(process.env.PORT, 10) || 8080;

const wss = new WebSocketServer({ port: PORT }, () => {
  console.log(`[Relay] WebSocket relay server listening on port ${PORT}`);
});

// ── Client tracking ──────────────────────────────────────────────

const viewers = new Set();
let streamer = null;

// ── Heartbeat (detect dead sockets) ─────────────────────────────

const HEARTBEAT_INTERVAL_MS = 30_000;

function heartbeat() {
  this.isAlive = true;
}

const heartbeatTimer = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('[Relay] Terminating unresponsive client');
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL_MS);

wss.on('close', () => clearInterval(heartbeatTimer));

// ── Connection handler ───────────────────────────────────────────

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  ws.isAlive = true;
  ws.on('pong', heartbeat);
  ws.role = null; // will be set on first message

  console.log(`[Relay] New connection from ${ip}  (total: ${wss.clients.size})`);

  ws.on('message', (data) => {
    // ── Role registration (first message) ──
    if (ws.role === null) {
      try {
        const msg = JSON.parse(data.toString());
        if (msg.role === 'streamer') {
          if (streamer && streamer.readyState === streamer.OPEN) {
            console.log('[Relay] Replacing previous streamer');
            streamer.close(4000, 'Replaced by new streamer');
          }
          ws.role = 'streamer';
          streamer = ws;
          console.log(`[Relay] Streamer registered  (${ip})`);
          return;
        }
        if (msg.role === 'viewer') {
          ws.role = 'viewer';
          viewers.add(ws);
          console.log(`[Relay] Viewer registered     (${ip})  — viewers: ${viewers.size}`);
          return;
        }
        // Unknown role — treat as viewer by default
        ws.role = 'viewer';
        viewers.add(ws);
        console.log(`[Relay] Unknown role, defaulting to viewer (${ip})`);
        return;
      } catch {
        // Non-JSON first message — treat as viewer
        ws.role = 'viewer';
        viewers.add(ws);
        console.log(`[Relay] Non-JSON first message, defaulting to viewer (${ip})`);
      }
    }

    // ── Frame relay (streamer → viewers) ──
    if (ws.role === 'streamer') {
      const frame = Buffer.isBuffer(data) ? data.toString('utf8') : String(data);
      let sent = 0;
      for (const viewer of viewers) {
        if (viewer.readyState === viewer.OPEN) {
          viewer.send(frame);
          sent++;
        }
      }
      // Throttle logging to avoid spam
      if (Math.random() < 0.005) {
        console.log(`[Relay] Broadcast frame to ${sent} viewer(s)`);
      }
      return;
    }

    // Viewers should not be sending data — ignore silently
  });

  ws.on('close', (code, reason) => {
    if (ws.role === 'streamer') {
      console.log(`[Relay] Streamer disconnected  (code ${code})`);
      if (streamer === ws) streamer = null;
    } else {
      viewers.delete(ws);
      console.log(`[Relay] Viewer disconnected    — viewers: ${viewers.size}`);
    }
  });

  ws.on('error', (err) => {
    console.error(`[Relay] Socket error (${ip}):`, err.message);
  });
});

// ── Graceful shutdown ────────────────────────────────────────────

function shutdown(signal) {
  console.log(`\n[Relay] Received ${signal} — shutting down…`);
  clearInterval(heartbeatTimer);
  wss.clients.forEach((ws) => ws.close(1001, 'Server shutting down'));
  wss.close(() => {
    console.log('[Relay] Server closed.');
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
