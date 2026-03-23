import dotenv from 'dotenv';
dotenv.config();

export default {
  port: parseInt(process.env.PORT || '3001', 10),
  jwtSecret: process.env.JWT_SECRET || 'fallback-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  clientUrl: process.env.CLIENT_URL || 'http://localhost:5173',
  masterApiKey: process.env.MASTER_API_KEY || 'fallback-master-key',
  nodeEnv: process.env.NODE_ENV || 'development',
};
