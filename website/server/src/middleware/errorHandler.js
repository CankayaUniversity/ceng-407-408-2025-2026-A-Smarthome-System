// ─── Global Error Handler Middleware ──────────────────────────
// User-friendly error messages as per NFR 3.5

const errorHandler = (err, req, res, next) => {
    console.error('Error:', err.message);

    // Prisma known errors
    if (err.code === 'P2002') {
        return res.status(409).json({
            error: 'A record with this information already exists.',
        });
    }

    if (err.code === 'P2025') {
        return res.status(404).json({
            error: 'The requested resource was not found.',
        });
    }

    // Validation errors
    if (err.name === 'ValidationError') {
        return res.status(400).json({
            error: err.message,
        });
    }

    // Multer file upload errors
    if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
            error: 'File size is too large. Maximum allowed size is 5MB.',
        });
    }

    // Default server error
    const statusCode = err.statusCode || 500;
    res.status(statusCode).json({
        error: process.env.NODE_ENV === 'development'
            ? err.message
            : 'An unexpected error occurred. Please try again later.',
    });
};

export default errorHandler;
