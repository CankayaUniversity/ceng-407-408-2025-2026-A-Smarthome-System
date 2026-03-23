import { AlertTriangle, Info, CheckCircle, AlertOctagon } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const AlertBanner = ({ alert, onAcknowledge }) => {
    if (!alert) return null;

    const { type, message, severity, createdAt, device } = alert;

    const getSeverityStyle = (severity) => {
        switch (severity) {
            case 'critical':
                return {
                    bannerClass: 'alert-banner-critical',
                    icon: <AlertOctagon size={24} />,
                };
            case 'warning':
                return {
                    bannerClass: 'alert-banner-warning',
                    icon: <AlertTriangle size={24} />,
                };
            case 'info':
                return {
                    bannerClass: 'bg-blue-900/20 border-blue-500 text-blue-400',
                    icon: <Info size={24} />,
                };
            default:
                return {
                    bannerClass: 'bg-gray-800 border-gray-600 text-gray-300',
                    icon: <CheckCircle size={24} />,
                };
        }
    };

    const { bannerClass, icon } = getSeverityStyle(severity);

    return (
        <div className={`alert-banner ${bannerClass}`}>
            <div className="flex-shrink-0">{icon}</div>
            <div className="flex-1 min-w-0">
                <h4 className="font-semibold text-sm">
                    {type.toUpperCase()} ALERT: {device?.name || 'Unknown Device'}
                </h4>
                <p className="text-sm opacity-90 truncate">{message}</p>
                <p className="text-xs opacity-75 mt-1">
                    {formatDistanceToNow(new Date(createdAt), { addSuffix: true })}
                </p>
            </div>
            <button
                onClick={() => onAcknowledge(alert.id)}
                className="btn btn-secondary btn-sm flex-shrink-0"
            >
                Acknowledge
            </button>
        </div>
    );
};

export default AlertBanner;
