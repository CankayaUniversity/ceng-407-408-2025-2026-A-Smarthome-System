import jwt from 'jsonwebtoken';
import config from '../config/env.js';
import prisma from '../config/db.js';

// ─── JWT Authentication Middleware ────────────────────────────
// Verifies Bearer token for user-facing routes
export const authenticate = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        const token = authHeader.split(' ')[1];
        const decoded = jwt.verify(token, config.jwtSecret);

        const user = await prisma.user.findUnique({
            where: { id: decoded.userId },
            select: { id: true, email: true, name: true, role: true, notificationsOn: true },
        });

        if (!user) {
            return res.status(401).json({ error: 'User not found' });
        }

        req.user = user;
        next();
    } catch (error) {
        if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
            return res.status(401).json({ error: 'Invalid or expired token' });
        }
        next(error);
    }
};

// ─── IoT Device API Key Middleware ────────────────────────────
// Verifies X-API-Key header for device-to-server routes
export const authenticateDevice = async (req, res, next) => {
    try {
        const apiKey = req.headers['x-api-key'];
        if (!apiKey) {
            return res.status(401).json({ error: 'API key required' });
        }

        // Check if it's the master key (for device registration)
        if (apiKey === config.masterApiKey) {
            req.isMaster = true;
            return next();
        }

        // Check device-specific key
        const device = await prisma.device.findUnique({
            where: { apiKey },
            include: { user: { select: { id: true } } },
        });

        if (!device) {
            return res.status(401).json({ error: 'Invalid API key' });
        }

        req.device = device;
        req.userId = device.userId;
        next();
    } catch (error) {
        next(error);
    }
};

// ─── Admin Role Check ─────────────────────────────────────────
export const requireAdmin = (req, res, next) => {
    if (req.user?.role !== 'admin') {
        return res.status(403).json({ error: 'Admin access required' });
    }
    next();
};
