import {
    Flame, Waves, Eye, ShieldCheck, DoorOpen, AlertTriangle, Bell, Wind,
} from 'lucide-react';

const EVENT_META = {
    fire_alert: {
        title: 'Smoke or gas detected',
        short: 'Smoke alert',
        icon: Flame,
        tone: 'critical',
    },
    fire_alert_cleared: {
        title: 'Smoke alert cleared',
        short: 'Smoke cleared',
        icon: Flame,
        tone: 'info',
    },
    stranger_detected: {
        title: 'Unknown visitor',
        short: 'Unknown visitor',
        icon: Eye,
        tone: 'warning',
    },
    resident_entry: {
        title: 'Resident recognized',
        short: 'Resident entry',
        icon: ShieldCheck,
        tone: 'success',
    },
    resident_detected: {
        title: 'Resident recognized',
        short: 'Resident detected',
        icon: ShieldCheck,
        tone: 'success',
    },
    flood: {
        title: 'Water leak detected',
        short: 'Water leak',
        icon: Waves,
        tone: 'critical',
    },
    flood_cleared: {
        title: 'Water leak cleared',
        short: 'Leak cleared',
        icon: Waves,
        tone: 'info',
    },
    motion_detected: {
        title: 'Motion detected',
        short: 'Motion',
        icon: Eye,
        tone: 'warning',
    },
    door_open: {
        title: 'Door opened',
        short: 'Door open',
        icon: DoorOpen,
        tone: 'warning',
    },
    low_moisture: {
        title: 'Low soil moisture',
        short: 'Low moisture',
        icon: Wind,
        tone: 'warning',
    },
};

const TONE_STYLES = {
    critical: { color: 'var(--crimson-core)', bg: 'var(--crimson-glow)', border: 'rgba(216, 40, 74, 0.25)' },
    warning: { color: 'var(--amber-core)', bg: 'var(--amber-glow)', border: 'rgba(214, 137, 16, 0.25)' },
    info: { color: 'var(--text-secondary)', bg: 'var(--bg-elevated)', border: 'var(--border-soft)' },
    success: { color: 'var(--jade-core)', bg: 'var(--jade-glow)', border: 'rgba(0, 168, 120, 0.25)' },
};

function humanizeType(type) {
    if (!type) return 'System alert';
    return type
        .replace(/_/g, ' ')
        .replace(/\b\w/g, c => c.toUpperCase());
}

export function getEventMeta(eventType) {
    const key = eventType?.toLowerCase();
    const meta = EVENT_META[key];
    if (meta) return { ...meta, key };
    return {
        key,
        title: humanizeType(eventType),
        short: humanizeType(eventType),
        icon: AlertTriangle,
        tone: 'warning',
    };
}

export function getEventToneStyle(tone) {
    return TONE_STYLES[tone] || TONE_STYLES.warning;
}

export function formatPriority(priority) {
    const p = priority?.toLowerCase();
    if (p === 'critical') return 'Critical';
    if (p === 'high') return 'High';
    if (p === 'medium') return 'Medium';
    if (p === 'low') return 'Low';
    if (p === 'info') return 'Info';
    return priority ? String(priority) : 'Alert';
}

export function priorityBadgeClass(priority) {
    const p = priority?.toLowerCase();
    if (p === 'critical') return 'badge-danger';
    if (p === 'info') return 'badge-neutral';
    return 'badge-warning';
}

export const DEFAULT_ALERT_ICON = Bell;
