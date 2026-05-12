import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import ThemeSwitch from '../ThemeSwitch';
import { useRealtime } from '../../context/RealtimeContext';

const Layout = () => {
    const { isConnected } = useRealtime();

    return (
        <div className="app-layout">
            <Sidebar />
            <main className="main-content">
                <header className="header">
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--s4)' }}>
                        <ThemeSwitch />
                        <div className="system-status">
                            <span className={isConnected ? 'status-pulse' : ''} style={{
                                width: 6, height: 6, borderRadius: '50%',
                                background: isConnected ? 'var(--jade-core)' : 'var(--text-muted)',
                                display: 'inline-block', flexShrink: 0
                            }} />
                            {isConnected ? 'System Online' : 'Connecting...'}
                        </div>
                    </div>
                </header>
                <div className="page-container animate-fade-in">
                    <Outlet />
                </div>
            </main>
        </div>
    );
};

export default Layout;
