import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../config/db.js';
import config from '../config/env.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();

// ─── POST /api/auth/register ──────────────────────────────────
router.post('/register', async (req, res, next) => {
    try {
        const { email, password, name } = req.body;

        if (!email || !password || !name) {
            return res.status(400).json({ error: 'Email, password, and name are required.' });
        }

        if (password.length < 6) {
            return res.status(400).json({ error: 'Password must be at least 6 characters.' });
        }

        const existingUser = await prisma.user.findUnique({ where: { email } });
        if (existingUser) {
            return res.status(409).json({ error: 'An account with this email already exists.' });
        }

        const hashedPassword = await bcrypt.hash(password, 12);

        const user = await prisma.user.create({
            data: { email, password: hashedPassword, name },
            select: { id: true, email: true, name: true, role: true },
        });

        const token = jwt.sign({ userId: user.id }, config.jwtSecret, {
            expiresIn: config.jwtExpiresIn,
        });

        res.status(201).json({ user, token });
    } catch (error) {
        next(error);
    }
});

// ─── POST /api/auth/login ─────────────────────────────────────
router.post('/login', async (req, res, next) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required.' });
        }

        const user = await prisma.user.findUnique({ where: { email } });
        if (!user) {
            return res.status(401).json({ error: 'Invalid email or password.' });
        }

        const isValidPassword = await bcrypt.compare(password, user.password);
        if (!isValidPassword) {
            return res.status(401).json({ error: 'Invalid email or password.' });
        }

        const token = jwt.sign({ userId: user.id }, config.jwtSecret, {
            expiresIn: config.jwtExpiresIn,
        });

        res.json({
            user: { id: user.id, email: user.email, name: user.name, role: user.role },
            token,
        });
    } catch (error) {
        next(error);
    }
});

// ─── GET /api/auth/me ─────────────────────────────────────────
router.get('/me', authenticate, (req, res) => {
    res.json({ user: req.user });
});

export default router;
