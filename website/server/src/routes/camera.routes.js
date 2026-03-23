import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import prisma from '../config/db.js';
import { authenticate } from '../middleware/auth.js';
import { authenticateDevice } from '../middleware/auth.js';
import { emitCameraEvent } from '../socket/socketHandler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Multer config for camera image uploads
const storage = multer.diskStorage({
    destination: path.join(__dirname, '..', '..', 'uploads', 'camera'),
    filename: (req, file, cb) => {
        const uniqueName = `cam_${Date.now()}_${Math.round(Math.random() * 1e6)}${path.extname(file.originalname)}`;
        cb(null, uniqueName);
    },
});

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
    fileFilter: (req, file, cb) => {
        const allowed = /jpeg|jpg|png|webp/;
        const isValid = allowed.test(path.extname(file.originalname).toLowerCase());
        cb(isValid ? null : new Error('Only image files are allowed.'), isValid);
    },
});

const router = Router();

// ─── POST /api/camera/events ──────────────────────────────────
// IoT device (Raspberry Pi) sends face recognition result with optional image.
// Body fields (multipart/form-data):
//   result       : "authorized" | "unauthorized" | "unknown"
//   person_id    : person_id from residents.json (e.g. "res_9938d435") — used to resolve faceProfileId
//   match_score  : euclidean distance score from FaceMatcher (float)
//   image        : JPEG file (optional)
router.post('/events', authenticateDevice, upload.single('image'), async (req, res, next) => {
    try {
        const { result = 'unknown', person_id, match_score } = req.body;

        // Try to resolve person_id → FaceProfile in DB (if authorized match)
        let resolvedFaceProfileId = null;
        if (person_id) {
            const profile = await prisma.faceProfile.findFirst({
                where: { userId: req.userId, personId: person_id },
                select: { id: true },
            });
            if (profile) resolvedFaceProfileId = profile.id;
        }

        const event = await prisma.cameraEvent.create({
            data: {
                deviceId: req.device.id,
                imagePath: req.file ? `/uploads/camera/${req.file.filename}` : null,
                result,
                faceProfileId: resolvedFaceProfileId,
                confidence: match_score ? parseFloat(match_score) : null,
            },
        });

        // Emit real-time camera event to connected dashboard clients
        const io = req.app.get('io');
        emitCameraEvent(io, req.userId, event);

        res.status(201).json(event);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/camera/events ───────────────────────────────────
router.get('/events', authenticate, async (req, res, next) => {
    try {
        const { result, limit = '20', offset = '0' } = req.query;

        const devices = await prisma.device.findMany({
            where: { userId: req.user.id },
            select: { id: true },
        });
        const deviceIds = devices.map((d) => d.id);

        const where = { deviceId: { in: deviceIds } };
        if (result) where.result = result;

        const [events, total] = await Promise.all([
            prisma.cameraEvent.findMany({
                where,
                orderBy: { createdAt: 'desc' },
                take: parseInt(limit, 10),
                skip: parseInt(offset, 10),
                include: {
                    device: { select: { name: true } },
                    faceProfile: { select: { name: true } },
                },
            }),
            prisma.cameraEvent.count({ where }),
        ]);

        res.json({ events, total });
    } catch (error) {
        next(error);
    }
});

export default router;
