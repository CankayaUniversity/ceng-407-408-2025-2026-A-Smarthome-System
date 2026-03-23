import { Router } from 'express';
import prisma from '../config/db.js';
import { authenticate } from '../middleware/auth.js';
import { authenticateDevice } from '../middleware/auth.js';
import { emitSensorUpdate } from '../socket/socketHandler.js';

const router = Router();

// ─── POST /api/sensors/readings ───────────────────────────────
// IoT device pushes sensor data (authenticated via API Key)
router.post('/readings', authenticateDevice, async (req, res, next) => {
    try {
        const { sensorId, value, readings } = req.body;

        // Support both single reading and batch readings
        if (readings && Array.isArray(readings)) {
            // Batch insert: [{ sensorId, value }, ...]
            const created = await prisma.sensorReading.createMany({
                data: readings.map((r) => ({
                    sensorId: r.sensorId,
                    value: r.value,
                })),
            });

            // Emit real-time update
            const io = req.app.get('io');
            emitSensorUpdate(io, req.userId, { type: 'batch', count: created.count });

            return res.status(201).json({ created: created.count });
        }

        if (!sensorId || value === undefined) {
            return res.status(400).json({ error: 'sensorId and value are required.' });
        }

        const reading = await prisma.sensorReading.create({
            data: { sensorId, value },
        });

        // Emit real-time update
        const io = req.app.get('io');
        const sensor = await prisma.sensor.findUnique({ where: { id: sensorId } });
        emitSensorUpdate(io, req.userId, {
            sensorId,
            type: sensor?.type,
            value,
            unit: sensor?.unit,
            timestamp: reading.createdAt,
        });

        res.status(201).json(reading);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/sensors/latest ──────────────────────────────────
// Get latest reading for all sensors of current user
router.get('/latest', authenticate, async (req, res, next) => {
    try {
        const devices = await prisma.device.findMany({
            where: { userId: req.user.id },
            include: {
                sensors: {
                    include: {
                        readings: {
                            orderBy: { createdAt: 'desc' },
                            take: 1,
                        },
                    },
                },
            },
        });

        // Flatten to a clean response
        const sensorData = devices.flatMap((device) =>
            device.sensors.map((sensor) => ({
                sensorId: sensor.id,
                deviceId: device.id,
                deviceName: device.name,
                type: sensor.type,
                label: sensor.label,
                unit: sensor.unit,
                value: sensor.readings[0]?.value ?? null,
                lastUpdated: sensor.readings[0]?.createdAt ?? null,
            }))
        );

        res.json(sensorData);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/sensors/history ─────────────────────────────────
// Historical data with date range filter (User Story 2.3.2)
router.get('/history', authenticate, async (req, res, next) => {
    try {
        const { sensorId, from, to, limit = '500' } = req.query;

        if (!sensorId) {
            return res.status(400).json({ error: 'sensorId query parameter is required.' });
        }

        // Verify sensor belongs to user
        const sensor = await prisma.sensor.findUnique({
            where: { id: sensorId },
            include: { device: { select: { userId: true } } },
        });

        if (!sensor || sensor.device.userId !== req.user.id) {
            return res.status(404).json({ error: 'Sensor not found.' });
        }

        const where = { sensorId };
        if (from || to) {
            where.createdAt = {};
            if (from) where.createdAt.gte = new Date(from);
            if (to) where.createdAt.lte = new Date(to);
        }

        const readings = await prisma.sensorReading.findMany({
            where,
            orderBy: { createdAt: 'asc' },
            take: parseInt(limit, 10),
            select: { id: true, value: true, createdAt: true },
        });

        res.json({
            sensorId,
            type: sensor.type,
            unit: sensor.unit,
            label: sensor.label,
            count: readings.length,
            readings,
        });
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/sensors ─────────────────────────────────────────
// List all sensors for current user
router.get('/', authenticate, async (req, res, next) => {
    try {
        const devices = await prisma.device.findMany({
            where: { userId: req.user.id },
            include: { sensors: true },
        });

        const sensors = devices.flatMap((d) =>
            d.sensors.map((s) => ({ ...s, deviceName: d.name }))
        );

        res.json(sensors);
    } catch (error) {
        next(error);
    }
});

export default router;
