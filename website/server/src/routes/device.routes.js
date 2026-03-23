import { Router } from 'express';
import prisma from '../config/db.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();

// ─── POST /api/devices ────────────────────────────────────────
// Register a new IoT device
router.post('/', authenticate, async (req, res, next) => {
    try {
        const { name, location = 'Home' } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Device name is required.' });
        }

        const device = await prisma.device.create({
            data: {
                userId: req.user.id,
                name,
                location,
            },
        });

        res.status(201).json(device);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/devices ─────────────────────────────────────────
router.get('/', authenticate, async (req, res, next) => {
    try {
        const devices = await prisma.device.findMany({
            where: { userId: req.user.id },
            include: {
                sensors: { select: { id: true, type: true, label: true } },
                _count: { select: { alerts: true, cameraEvents: true } },
            },
            orderBy: { createdAt: 'desc' },
        });

        res.json(devices);
    } catch (error) {
        next(error);
    }
});

// ─── POST /api/devices/:id/sensors ────────────────────────────
// Add a sensor to a device
router.post('/:id/sensors', authenticate, async (req, res, next) => {
    try {
        const { type, label, unit } = req.body;

        if (!type) {
            return res.status(400).json({ error: 'Sensor type is required.' });
        }

        const sensor = await prisma.sensor.create({
            data: {
                deviceId: req.params.id,
                type,
                label: label || type,
                unit: unit || '',
            },
        });

        res.status(201).json(sensor);
    } catch (error) {
        next(error);
    }
});

// ─── DELETE /api/devices/:id ──────────────────────────────────
router.delete('/:id', authenticate, async (req, res, next) => {
    try {
        await prisma.device.delete({
            where: { id: req.params.id },
        });

        res.json({ message: 'Device deleted successfully.' });
    } catch (error) {
        next(error);
    }
});

export default router;
