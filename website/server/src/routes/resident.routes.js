import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { fileURLToPath } from 'url';
import prisma from '../config/db.js';
import { authenticate, authenticateDevice } from '../middleware/auth.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Multer config for face profile uploads
const storage = multer.diskStorage({
    destination: path.join(__dirname, '..', '..', 'uploads', 'faces'),
    filename: (req, file, cb) => {
        const uniqueName = `face_${Date.now()}_${Math.round(Math.random() * 1e6)}${path.extname(file.originalname)}`;
        cb(null, uniqueName);
    },
});

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const allowed = /jpeg|jpg|png|webp/;
        const isValid = allowed.test(path.extname(file.originalname).toLowerCase());
        cb(isValid ? null : new Error('Only image files are allowed.'), isValid);
    },
});

const router = Router();

// ─── POST /api/residents ──────────────────────────────────────
// Add a new face profile (User Story 2.4.3)
// Accepts optional: personId (Pi's local ID), embedding (128-dim JSON array)
router.post('/', authenticate, upload.single('image'), async (req, res, next) => {
    try {
        const { name, personId, embedding } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Name is required.' });
        }

        // Parse embedding if provided as a JSON string
        let parsedEmbedding = null;
        if (embedding) {
            try {
                parsedEmbedding = typeof embedding === 'string' ? JSON.parse(embedding) : embedding;
            } catch {
                return res.status(400).json({ error: 'Invalid embedding format. Expected JSON array.' });
            }
        }

        const profile = await prisma.faceProfile.create({
            data: {
                userId: req.user.id,
                name,
                personId: personId || null,
                imagePath: req.file ? `/uploads/faces/${req.file.filename}` : null,
                embedding: parsedEmbedding,
            },
        });

        res.status(201).json(profile);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/residents ───────────────────────────────────────
// Web dashboard access (JWT auth) — returns all profiles for the logged-in user
router.get('/', authenticate, async (req, res, next) => {
    try {
        const profiles = await prisma.faceProfile.findMany({
            where: { userId: req.user.id },
            orderBy: { createdAt: 'desc' },
        });

        res.json(profiles);
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/residents/sync ──────────────────────────────────
// Raspberry Pi device sync (Device API Key auth)
// Returns all face profiles WITH embeddings so Pi can update its local residents.json
router.get('/sync', authenticateDevice, async (req, res, next) => {
    try {
        const profiles = await prisma.faceProfile.findMany({
            where: {
                userId: req.userId,
                embedding: { not: null }, // Only useful if embedding exists
            },
            select: {
                id: true,
                personId: true,
                name: true,
                imagePath: true,
                embedding: true,
                createdAt: true,
            },
            orderBy: { createdAt: 'desc' },
        });

        res.json({ residents: profiles });
    } catch (error) {
        next(error);
    }
});

// ─── PATCH /api/residents/:id/photo ──────────────────────────
// Update only the profile photo for an existing resident
router.patch('/:id/photo', authenticate, upload.single('image'), async (req, res, next) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Image file is required.' });
        }

        const profile = await prisma.faceProfile.update({
            where: { id: req.params.id },
            data: { imagePath: `/uploads/faces/${req.file.filename}` },
        });

        res.json(profile);
    } catch (error) {
        next(error);
    }
});

// ─── DELETE /api/residents/:id ────────────────────────────────
router.delete('/:id', authenticate, async (req, res, next) => {
    try {
        await prisma.faceProfile.delete({
            where: { id: req.params.id },
        });

        res.json({ message: 'Resident profile deleted successfully.' });
    } catch (error) {
        next(error);
    }
});

export default router;
