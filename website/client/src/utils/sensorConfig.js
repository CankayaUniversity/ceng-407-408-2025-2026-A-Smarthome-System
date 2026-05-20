import { Thermometer, Droplets, Flame, Sprout, Eye, DoorOpen, Activity, Wind } from 'lucide-react';

/** Legacy DB rows used `water`; hardware is a soil moisture probe. */
export function normalizeSensorType(type) {
    if (!type) return type;
    const t = String(type).toLowerCase();
    return t === 'water' ? 'soil_moisture' : t;
}

export const SENSOR_CONFIG = {
    temperature: { icon: Thermometer, color: '#ff6b35', label: 'Temperature', unit: '°C', chartUnit: '°C' },
    humidity: { icon: Droplets, color: '#00d4ff', label: 'Humidity', unit: '%', chartUnit: '%' },
    smoke: { icon: Flame, color: '#ff3b5c', label: 'Smoke / gas', unit: '', chartUnit: '', boolean: true },
    soil_moisture: { icon: Sprout, color: '#7cb342', label: 'Soil moisture', unit: '', chartUnit: '', boolean: true },
    motion: { icon: Eye, color: '#9b59ff', label: 'Motion', unit: '', chartUnit: '', boolean: true },
    door: { icon: DoorOpen, color: '#00e5a0', label: 'Door', unit: '', chartUnit: '', boolean: true },
    co2: { icon: Wind, color: '#a0f080', label: 'CO₂', unit: 'ppm', chartUnit: 'ppm' },
};

export function getSensorConfig(type) {
    const key = normalizeSensorType(type);
    return SENSOR_CONFIG[key] || { icon: Activity, color: '#8892a4', label: key || 'Sensor', unit: '', chartUnit: '' };
}

/** 1 = dry soil (needs watering), 0 = moist — opposite of legacy "leak" wording. */
export function formatSoilMoistureValue(val) {
    const n = parseFloat(val);
    if (Number.isNaN(n)) return '—';
    return n >= 0.5 ? 'Dry' : 'Moist';
}

export function isSoilMoistureAlert(val) {
    return parseFloat(val) >= 0.5;
}

export function formatSensorDisplayValue(sensorType, val) {
    const type = normalizeSensorType(sensorType);
    if (val === null || val === undefined) return '—';
    const cfg = getSensorConfig(type);
    if (type === 'soil_moisture') return formatSoilMoistureValue(val);
    if (cfg.boolean) return parseFloat(val) >= 0.5 ? 'Active' : 'Clear';
    return `${parseFloat(val).toFixed(1)}${cfg.unit || ''}`;
}

export function isSensorAlert(sensorType, val) {
    const type = normalizeSensorType(sensorType);
    if (type === 'smoke') return parseFloat(val) > 0;
    if (type === 'soil_moisture') return isSoilMoistureAlert(val);
    return false;
}
