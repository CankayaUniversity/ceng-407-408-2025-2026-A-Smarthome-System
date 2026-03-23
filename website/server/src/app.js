import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import path from 'path';
import { fileURLToPath } from 'url';

import config from './config/env.js';
import errorHandler from './middleware/errorHandler.js';
import { setupSocketHandlers } from './socket/socketHandler.js';

// Routes
import authRoutes from './routes/auth.routes.js';
import sensorRoutes from './routes/sensor.routes.js';
import alertRoutes from './routes/alert.routes.js';
import cameraRoutes from './routes/camera.routes.js';
import residentRoutes from './routes/resident.routes.js';
import deviceRoutes from './routes/device.routes.js';

// ─── Setup ────────────────────────────────────────────────────
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const httpServer = createServer(app);

// ─── Socket.IO ────────────────────────────────────────────────
const io = new Server(httpServer, {
    cors: {
        origin: config.clientUrl,
        methods: ['GET', 'POST'],
    },
});

setupSocketHandlers(io);

// Make io accessible in routes
app.set('io', io);

// ─── Middleware ────────────────────────────────────────────────
app.use(cors({ origin: config.clientUrl, credentials: true }));
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting (different limits for users vs IoT devices)
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100,
    message: { error: 'Too many requests, please try again later.' },
});

const deviceLimiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    max: 30, // ~every 2 seconds
    message: { error: 'Device rate limit exceeded.' },
});

// Static file serving for uploaded images
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// ─── Routes ───────────────────────────────────────────────────
app.use('/api/auth', apiLimiter, authRoutes);
app.use('/api/sensors', deviceLimiter, sensorRoutes);
app.use('/api/alerts', apiLimiter, alertRoutes);
app.use('/api/camera', apiLimiter, cameraRoutes);
app.use('/api/residents', apiLimiter, residentRoutes);
app.use('/api/devices', apiLimiter, deviceRoutes);

// Health check
app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ─── Error Handling ───────────────────────────────────────────
app.use(errorHandler);

// ─── Start Server ─────────────────────────────────────────────
httpServer.listen(config.port, () => {
    console.log(`\n🏠 Smart Home Server running on http://localhost:${config.port}`);
    console.log(`📡 Socket.IO ready for connections`);
    console.log(`🌍 Environment: ${config.nodeEnv}\n`);
});

export default app;
