/**
 * ─────────────────────────────────────────────────────────────
 *   IoT Smart Home — Database Seed Script
 *   [MOCK_DATA] tag marks everything that is demo data.
 *   To remove mock data: search & delete all [MOCK_DATA] blocks.
 * ─────────────────────────────────────────────────────────────
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// ── Helper: random float in range ─────────────────────────────
const rand = (min, max) => Math.random() * (max - min) + min;
const randInt = (min, max) => Math.round(rand(min, max));

// ── Sine-wave + noise for realistic sensor time series ─────────
function sensorValue(type, i, totalPoints) {
    const cyclePos = (i / totalPoints) * Math.PI * 2;
    switch (type) {
        case 'temperature':
            return parseFloat((21 + Math.sin(cyclePos * 2) * 3 + rand(-0.4, 0.4)).toFixed(1));
        case 'humidity':
            return parseFloat((50 + Math.sin(cyclePos) * 12 + rand(-1, 1)).toFixed(1));
        case 'smoke':
            return parseFloat((Math.random() < 0.97 ? rand(0, 4) : rand(35, 90)).toFixed(1));
        case 'water':
            return 0; // [MOCK_DATA] always dry
        case 'motion':
            // More motion during "day" hours
            return i % 16 < 12 && Math.random() > 0.65 ? 1 : 0;
        case 'weight':
            return parseFloat((rand(0.6, 1.8)).toFixed(2));
        case 'moisture':
            return parseFloat((70 - (i / totalPoints) * 40 + rand(-2, 2)).toFixed(1));
        case 'light':
            return parseFloat((rand(100, 800)).toFixed(0));
        case 'door':
            return Math.random() > 0.85 ? 1 : 0; // 15% chance open
        case 'window':
            return Math.random() > 0.75 ? 1 : 0; // 25% chance open
        case 'co2':
            return parseFloat((400 + Math.sin(cyclePos) * 200 + rand(-20, 20)).toFixed(0));
        case 'noise':
            return parseFloat((rand(30, 75)).toFixed(1));
        case 'pressure':
            return parseFloat((1013 + Math.sin(cyclePos) * 5 + rand(-1, 1)).toFixed(1));
        default:
            return parseFloat(rand(0, 100).toFixed(1));
    }
}

async function main() {
    console.log('🌱 Starting database seeding...');

    // ── [MOCK_DATA] Users ──────────────────────────────────────
    const adminHash = await bcrypt.hash('admin123', 10);
    const residentHash = await bcrypt.hash('resident123', 10);

    const admin = await prisma.user.upsert({
        where: { email: 'admin@smarthome.local' },
        update: {},
        create: {
            email: 'admin@smarthome.local',
            password: adminHash,
            name: 'System Admin',
            role: 'admin',
        },
    });

    const resident1 = await prisma.user.upsert({
        where: { email: 'deniz@smarthome.local' },
        update: {},
        create: {
            email: 'deniz@smarthome.local',
            password: residentHash,
            name: 'Deniz Yılmaz',
            role: 'resident',
        },
    });

    console.log(`✅ Created users: ${admin.email}, ${resident1.email}`);

    // ── [MOCK_DATA] Devices per room ───────────────────────────
    const ROOMS = [
        {
            name: 'Main RPi Controller',
            location: 'Living Room',
            icon: 'sofa',
            sensors: [
                { type: 'temperature', label: 'Living Room Temp', unit: '°C' },
                { type: 'humidity', label: 'Living Room Humidity', unit: '%' },
                { type: 'motion', label: 'Living Room Motion', unit: '' },
                { type: 'light', label: 'Living Room Light', unit: 'lux' },
                { type: 'co2', label: 'CO₂ Level', unit: 'ppm' },
                { type: 'noise', label: 'Sound Level', unit: 'dB' },
            ],
        },
        {
            name: 'Kitchen Hub',
            location: 'Kitchen',
            icon: 'utensils',
            sensors: [
                { type: 'temperature', label: 'Kitchen Temp', unit: '°C' },
                { type: 'smoke', label: 'Smoke Detector', unit: 'ppm' },
                { type: 'humidity', label: 'Kitchen Humidity', unit: '%' },
                { type: 'water', label: 'Leak Sensor', unit: '' },
                { type: 'weight', label: 'Pet Feeder Weight', unit: 'kg' },
            ],
        },
        {
            name: 'Bedroom Sensor Node',
            location: 'Master Bedroom',
            icon: 'bed',
            sensors: [
                { type: 'temperature', label: 'Bedroom Temp', unit: '°C' },
                { type: 'humidity', label: 'Bedroom Humidity', unit: '%' },
                { type: 'motion', label: 'Bedroom Motion', unit: '' },
                { type: 'noise', label: 'Sleep Noise Level', unit: 'dB' },
                { type: 'light', label: 'Bedroom Light', unit: 'lux' },
            ],
        },
        {
            name: 'Front Door Node',
            location: 'Entrance',
            icon: 'door',
            sensors: [
                { type: 'motion', label: 'Entrance Motion', unit: '' },
                { type: 'door', label: 'Front Door', unit: '' },
                { type: 'light', label: 'Porch Light Sensor', unit: 'lux' },
                { type: 'temperature', label: 'Outdoor Temp', unit: '°C' },
            ],
        },
        {
            name: 'Bathroom Sensor',
            location: 'Bathroom',
            icon: 'shower',
            sensors: [
                { type: 'humidity', label: 'Bathroom Humidity', unit: '%' },
                { type: 'temperature', label: 'Bathroom Temp', unit: '°C' },
                { type: 'water', label: 'Flood Sensor', unit: '' },
                { type: 'motion', label: 'Bathroom Motion', unit: '' },
            ],
        },
        {
            name: 'Garden Node',
            location: 'Garden',
            icon: 'flower',
            sensors: [
                { type: 'moisture', label: 'Soil Moisture', unit: '%' },
                { type: 'temperature', label: 'Outdoor Temp', unit: '°C' },
                { type: 'light', label: 'Sunlight Intensity', unit: 'lux' },
                { type: 'humidity', label: 'Garden Humidity', unit: '%' },
            ],
        },
    ];

    const createdDevices = [];
    for (const room of ROOMS) {
        const device = await prisma.device.create({
            data: {
                userId: admin.id,
                name: room.name,
                location: room.location,
                status: 'online',
            },
        });

        const sensors = [];
        for (const s of room.sensors) {
            const sensor = await prisma.sensor.create({
                data: { deviceId: device.id, type: s.type, label: s.label, unit: s.unit },
            });
            sensors.push(sensor);
        }
        createdDevices.push({ device, sensors });
    }
    console.log(`✅ Created ${ROOMS.length} devices with sensors`);

    // ── [MOCK_DATA] Historical Readings — 7 days back ──────────
    console.log('📊 Generating 7-day historical sensor data…');
    const READINGS_PER_SENSOR = 336; // every 30 min for 7 days
    const now = new Date();
    const allReadings = [];

    for (const { sensors } of createdDevices) {
        for (const sensor of sensors) {
            for (let i = READINGS_PER_SENSOR - 1; i >= 0; i--) {
                allReadings.push({
                    sensorId: sensor.id,
                    value: sensorValue(sensor.type, i, READINGS_PER_SENSOR),
                    createdAt: new Date(now.getTime() - i * 30 * 60 * 1000),
                });
            }
        }
    }

    // Insert in batches of 1000 to avoid memory issues
    for (let i = 0; i < allReadings.length; i += 1000) {
        await prisma.sensorReading.createMany({ data: allReadings.slice(i, i + 1000) });
    }
    console.log(`✅ Generated ${allReadings.length} sensor readings`);

    // ── [MOCK_DATA] Alerts ─────────────────────────────────────
    const mainDevice = createdDevices[0].device;
    const kitchenDevice = createdDevices[1].device;
    const entranceDevice = createdDevices[3].device;

    await prisma.alert.createMany({
        data: [
            {
                deviceId: kitchenDevice.id, userId: admin.id,
                type: 'fire', message: 'High smoke levels detected in Kitchen!',
                severity: 'critical', acknowledged: false,
                createdAt: new Date(now.getTime() - 1000 * 60 * 4),
            },
            {
                deviceId: entranceDevice.id, userId: admin.id,
                type: 'intrusion', message: 'Motion detected at Front Door while system armed.',
                severity: 'warning', acknowledged: true,
                createdAt: new Date(now.getTime() - 1000 * 60 * 60 * 2),
            },
            {
                deviceId: kitchenDevice.id, userId: admin.id,
                type: 'fire', message: 'Smoke sensor spike — possible cooking activity.',
                severity: 'critical', acknowledged: true,
                createdAt: new Date(now.getTime() - 1000 * 60 * 60 * 8),
            },
            {
                deviceId: entranceDevice.id, userId: admin.id,
                type: 'intrusion', message: 'Doorbell motion — package delivery.',
                severity: 'warning', acknowledged: true,
                createdAt: new Date(now.getTime() - 1000 * 60 * 60 * 8.5),
            },
            {
                deviceId: mainDevice.id, userId: admin.id,
                type: 'flood', message: 'Water leak sensor triggered in basement.',
                severity: 'critical', acknowledged: true,
                createdAt: new Date(now.getTime() - 1000 * 60 * 60 * 24),
            },
            {
                deviceId: mainDevice.id, userId: admin.id,
                type: 'intrusion', message: 'Motion detected in living room at 3:40 AM.',
                severity: 'critical', acknowledged: true,
                createdAt: new Date(now.getTime() - 1000 * 60 * 60 * 30),
            },
        ],
    });
    console.log('✅ Generated mock alerts');

    // ── [MOCK_DATA] Residents / Face Profiles ──────────────────
    await prisma.faceProfile.createMany({
        data: [
            { userId: admin.id, name: 'Deniz Yılmaz', imagePath: null },
            { userId: admin.id, name: 'Ayşe Yılmaz', imagePath: null },
            { userId: admin.id, name: 'Mehmet Öztürk', imagePath: null },
        ],
    });
    console.log('✅ Created mock residents (face profiles)');

    console.log('\n✨ Seeding complete!');
    console.log('─── Test Credentials ────────────────────────');
    console.log('Admin:    admin@smarthome.local / admin123');
    console.log('Resident: deniz@smarthome.local / resident123');
    console.log('─────────────────────────────────────────────\n');
}

main()
    .catch((e) => { console.error(e); process.exit(1); })
    .finally(async () => { await prisma.$disconnect(); });
