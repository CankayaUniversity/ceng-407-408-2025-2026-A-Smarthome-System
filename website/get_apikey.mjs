import { PrismaClient } from '@prisma/client';
const p = new PrismaClient();
const d = await p.device.findFirst();
if (d) console.log('API_KEY=' + d.apiKey);
else console.log('No device found - run seed first');
await p.$disconnect();
