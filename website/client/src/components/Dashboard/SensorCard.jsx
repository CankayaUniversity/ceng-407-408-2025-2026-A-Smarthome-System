import {
    Thermometer,
    Droplets,
    Flame,
    Droplet,
    Eye,
    Scale,
    Sprout,
    Lightbulb
} from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const SENSOR_CONFIG = {
    temperature: { icon: Thermometer, colorClass: 'sensor-icon-temperature', defaultUnit: '°C' },
    humidity: { icon: Droplets, colorClass: 'sensor-icon-humidity', defaultUnit: '%' },
    smoke: { icon: Flame, colorClass: 'sensor-icon-smoke', defaultUnit: 'ppm' },
    water: { icon: Droplet, colorClass: 'sensor-icon-water', defaultUnit: '' },
    motion: { icon: Eye, colorClass: 'sensor-icon-motion', defaultUnit: '' },
    weight: { icon: Scale, colorClass: 'sensor-icon-weight', defaultUnit: 'kg' },
    moisture: { icon: Sprout, colorClass: 'sensor-icon-moisture', defaultUnit: '%' },
    light: { icon: Lightbulb, colorClass: 'sensor-icon-light', defaultUnit: '' },
};

const SensorCard = ({ sensor, isOffline = false }) => {
    const { type, label, value, unit, lastUpdated, deviceName } = sensor;

    const config = SENSOR_CONFIG[type] || SENSOR_CONFIG.temperature;
    const Icon = config.icon;

    const displayValue = value === null || value === undefined
        ? '--'
        : typeof value === 'boolean'
            ? (value ? 'Detected' : 'Normal')
            : Number(value).toFixed(1);

    const displayUnit = unit || config.defaultUnit;

    return (
        <div className={`card ${isOffline ? 'opacity-50' : ''}`}>
            <div className="card-header">
                <div className="flex items-center gap-3">
                    <div className={`sensor-icon ${config.colorClass}`}>
                        <Icon size={24} />
                    </div>
                    <div>
                        <h3 className="card-title" style={{ margin: 0, fontSize: 'var(--font-size-xs)' }}>
                            {label || type}
                        </h3>
                        <span className="text-xs text-muted">
                            {deviceName}
                        </span>
                    </div>
                </div>
                {isOffline && (
                    <span className="badge badge-warning">Offline</span>
                )}
            </div>

            <div className="mt-4">
                <div className="flex items-baseline gap-1">
                    <span className="card-value">{displayValue}</span>
                    <span className="text-secondary font-semibold">{displayUnit}</span>
                </div>

                <div className="mt-2 text-xs text-muted">
                    {lastUpdated
                        ? `Updated ${formatDistanceToNow(new Date(lastUpdated), { addSuffix: true })}`
                        : 'No data yet'}
                </div>
            </div>
        </div>
    );
};

export default SensorCard;
