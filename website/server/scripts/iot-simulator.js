/**
 * IoT Simulator Script
 * Simulates a Raspberry Pi sending sensor data every 5 seconds.
 * 
 * Usage: 
 *   node iot-simulator.js <API_URL> <API_KEY> <DEVICE_ID>
 */

import axios from 'axios';

const API_URL = process.argv[2] || 'http://localhost:3001/api';
const API_KEY = process.argv[3] || 'TEST_API_KEY_123';
const DEVICE_ID = process.argv[4] || '1'; // Assuming ID 1 from seeder

console.log(`🚀 Starting IoT Simulator...`);
console.log(`API URL: ${API_URL}`);
console.log(`Device ID: ${DEVICE_ID}`);

// Default sensor values
let sensors = {
    temperature: { id: 1, val: 22.5 },
    humidity: { id: 2, val: 45.0 },
    smoke: { id: 3, val: 0.1 },
    water: { id: 4, val: 0 }, // boolean 0/1
    motion: { id: 5, val: 0 },
    weight: { id: 6, val: 1.2 },
    moisture: { id: 7, val: 56.4 },
    light: { id: 8, val: 1 }
};

const sendReadings = async () => {
    // 1. Mutate values slightly for realism
    sensors.temperature.val += (Math.random() * 0.4) - 0.2; // +/- 0.2
    sensors.humidity.val += (Math.random() * 1.0) - 0.5;
    sensors.smoke.val = Math.max(0, sensors.smoke.val + (Math.random() * 0.1) - 0.05);
    // Random motion event (10% chance)
    sensors.motion.val = Math.random() > 0.9 ? 1 : 0;

    // 2. Prepare payload
    const readings = Object.values(sensors).map(s => ({
        sensorId: s.id,
        value: parseFloat(s.val.toFixed(2))
    }));

    try {
        const res = await axios.post(`${API_URL}/sensors/readings`, {
            readings
        }, {
            headers: {
                'x-api-key': API_KEY,
                'x-device-id': DEVICE_ID,
                'Content-Type': 'application/json'
            }
        });

        console.log(`[${new Date().toLocaleTimeString()}] ✅ Sent ${readings.length} readings (Status: ${res.status})`);
        if (sensors.motion.val === 1) {
            console.log(`  --> 🏃 Motion Detected!`);
        }

    } catch (err) {
        console.error(`[${new Date().toLocaleTimeString()}] ❌ Failed to send readings:`, err.message);
        if (err.response) {
            console.error(err.response.data);
        }
    }
};

// Initial push
sendReadings();

// Send every 5 seconds
setInterval(sendReadings, 5000);

// Occasional critical alert simulation (every 30 seconds for demo)
setInterval(async () => {
    if (Math.random() > 0.7) {
        console.log(`🚨 Generating simulated critical alert...`);
        try {
            await axios.post(`${API_URL}/alerts`, {
                type: 'fire',
                message: `Smoke levels spiked to ${(sensors.smoke.val + 50).toFixed(1)} ppm in Living Room!`,
                severity: 'critical'
            }, {
                headers: {
                    'x-api-key': API_KEY,
                    'x-device-id': DEVICE_ID
                }
            });
            console.log(`[${new Date().toLocaleTimeString()}] ✅ Alert sent successfully`);
        } catch (err) {
            console.error(`[${new Date().toLocaleTimeString()}] ❌ Failed to send alert:`, err.message);
        }
    }
}, 30000);
