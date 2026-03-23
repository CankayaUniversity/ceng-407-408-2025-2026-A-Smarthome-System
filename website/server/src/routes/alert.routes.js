import { Router } from 'express';
import prisma from '../config/db.js';
import { authenticate } from '../middleware/auth.js';
import { authenticateDevice } from '../middleware/auth.js';
import { emitNewAlert } from '../socket/socketHandler.js';

const router = Router();

// ─── POST /api/alerts ─────────────────────────────────────────
// IoT device creates a new alert (fire, flood, intrusion, etc.)
router.post('/', authenticateDevice, async (req, res, next) => {
    try {
        const { type, message, severity = 'warning' } = req.body;

        if (!type || !message) {
            return res.status(400).json({ error: 'type and message are required.' });
        }

        const alert = await prisma.alert.create({
            data: {
                deviceId: req.device.id,
                userId: req.userId,
                type,
                message,
                severity,
            },
        });

        // Emit real-time alert
        const io = req.app.get('io');
        emitNewAlert(io, req.userId, alert);

        res.status(201).json(alert);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/alerts ──────────────────────────────────────────
// List alerts with optional filters
router.get('/', authenticate, async (req, res, next) => {
    try {
        const { type, severity, acknowledged, limit = '50', offset = '0' } = req.query;

        const where = { userId: req.user.id };
        if (type) where.type = type;
        if (severity) where.severity = severity;
        if (acknowledged !== undefined) where.acknowledged = acknowledged === 'true';

        const [alerts, total] = await Promise.all([
            prisma.alert.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                take: parseInt(limit, 10),
                skip: parseInt(offset, 10),
                include: { device: { select: { name: true, location: true } } },
            }),
            prisma.alert.count({ where }),
        ]);

        res.json({ alerts, total, limit: parseInt(limit, 10), offset: parseInt(offset, 10) });
    } catch (error) {
        next(error);
    }
});

// ─── PATCH /api/alerts/:id/acknowledge ────────────────────────
router.patch('/:id/acknowledge', authenticate, async (req, res, next) => {
    try {
        const alert = await prisma.alert.update({
            where: { id: req.params.id },
            data: { acknowledged: true },
        });

        res.json(alert);
    } catch (error) {
        next(error);
    }
});

export default router;
