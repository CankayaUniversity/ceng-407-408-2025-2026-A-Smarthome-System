import { NavLink } from 'react-router-dom';
import {
    LayoutDashboard,
    TrendingUp,
    Camera,
    ShieldAlert,
    Users,
    Settings,
    LogOut,
    Zap,
    Map,
} from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';

const NAV_ITEMS = [
    { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    { to: '/rooms', icon: Map, label: 'Floor Plan' },
    { to: '/history', icon: TrendingUp, label: 'Analytics' },
    { to: '/camera', icon: Camera, label: 'Surveillance' },
    { to: '/alerts', icon: ShieldAlert, label: 'Alerts' },
    // Face profiles — admin and resident can both manage
    { to: '/residents', icon: Users, label: 'Residents' },
    { to: '/settings', icon: Settings, label: 'Settings' },
];

const Sidebar = () => {
    const { logout, user, profile } = useAuth();

    // Safe avatar initial: prefer profile name, fall back to email, then 'U'
    const displayName = profile?.name || user?.user_metadata?.name || '';
    const avatarInitial = displayName
        ? displayName.trim()[0].toUpperCase()
        : (user?.email ? user.email[0].toUpperCase() : 'U');

    const roleLabel = profile?.role || 'authenticated';

    return (
        <aside className="sidebar animate-slide-left">
            {/* Logo */}
            <div className="sidebar-logo">
                <div className="sidebar-logo-icon">
                    <Zap size={20} />
                </div>
                <div>
                    <div className="sidebar-logo-text">SmartHome</div>
                    <div className="sidebar-logo-sub">Intelligence OS</div>
                </div>
            </div>

            {/* Nav */}
            <nav className="sidebar-nav">
                <div className="sidebar-section-label">Navigation</div>
                {NAV_ITEMS.map(({ to, icon: Icon, label, adminOnly }) => {
                    if (adminOnly && profile?.role !== 'admin') return null;
                    return (
                        <NavLink
                            key={to}
                            to={to}
                            className={({ isActive }) =>
                                `nav-item ${isActive ? 'active' : ''}`
                            }
                        >
                            <span className="nav-dot" />
                            <Icon size={17} className="nav-icon" style={{ flexShrink: 0 }} />
                            <span>{label}</span>
                        </NavLink>
                    );
                })}
            </nav>

            {/* Footer user */}
            <div className="sidebar-footer">
                <div className="sidebar-user" onClick={logout} title="Sign out">
                    <div className="sidebar-avatar">
                        {avatarInitial}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                        <div className="sidebar-user-name" style={{
                            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
                        }}>
                            {displayName || user?.email || 'User'}
                        </div>
                        <div className="sidebar-user-role" style={{
                            color: roleLabel === 'admin' ? 'var(--ember-core)' : 'var(--text-muted)'
                        }}>
                            {roleLabel}
                        </div>
                    </div>
                    <LogOut size={15} style={{ color: 'var(--text-muted)', flexShrink: 0 }} />
                </div>
            </div>
        </aside>
    );
};

export default Sidebar;
