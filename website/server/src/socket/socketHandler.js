import jwt from 'jsonwebtoken';
import config from '../config/env.js';

// ─── Socket.IO Event Handlers ─────────────────────────────────

export function setupSocketHandlers(io) {
    // JWT authentication for socket connections
    io.use((socket, next) => {
        const token = socket.handshake.auth?.token;
        if (!token) {
            return next(new Error('Authentication required'));
        }

        try {
            const decoded = jwt.verify(token, config.jwtSecret);
            socket.userId = decoded.userId;
            next();
        } catch (err) {
            next(new Error('Invalid token'));
        }
    });

    io.on('connection', (socket) => {
        console.log(`🔌 Client connected: ${socket.id} (User: ${socket.userId})`);

        // Join user-specific room for targeted notifications
        socket.join(`user:${socket.userId}`);

        socket.on('disconnect', () => {
            console.log(`🔌 Client disconnected: ${socket.id}`);
        });
    });

    return io;
}

// ─── Emit Helpers ─────────────────────────────────────────────
// Call these from controllers/services to push real-time updates

export function emitSensorUpdate(io, userId, data) {
    io.to(`user:${userId}`).emit('sensor:update', data);
}

export function emitNewAlert(io, userId, alert) {
    io.to(`user:${userId}`).emit('alert:new', alert);
}

export function emitCameraEvent(io, userId, event) {
    io.to(`user:${userId}`).emit('camera:event', event);
}
