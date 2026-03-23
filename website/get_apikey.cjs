const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();
p.device.findFirst().then(d => {
    if (d) console.log('API_KEY=' + d.apiKey);
    else console.log('No device found');
    return p.$disconnect();
}).catch(e => { console.error(e); process.exit(1); });
