import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { RealtimeProvider } from './context/RealtimeContext';
import { ThemeProvider } from './context/ThemeContext';

import ProtectedRoute from './components/Layout/ProtectedRoute';
import Layout from './components/Layout/Layout';
import ChangePasswordModal from './components/ChangePasswordModal';
import PasswordRecoveryRedirect from './components/PasswordRecoveryRedirect';

import LoginPage from './pages/LoginPage';
import ForgotPasswordPage from './pages/ForgotPasswordPage';
import UpdatePasswordPage from './pages/UpdatePasswordPage';
import DashboardPage from './pages/DashboardPage';
import HistoryPage from './pages/HistoryPage';
import CameraPage from './pages/CameraPage';
import AlertsPage from './pages/AlertsPage';
import ResidentsPage from './pages/ResidentsPage';
import SettingsPage from './pages/SettingsPage';
import RoomsPage from './pages/RoomsPage';
import IdentityPage from './pages/IdentityPage';

import { useAuth } from './hooks/useAuth';

/**
 * GlobalOverlays — renders app-wide overlays that need access to AuthContext.
 * Must be inside AuthProvider but outside individual pages.
 */
function GlobalOverlays() {
    const { forcePasswordChange, isAuthenticated, isPasswordRecovery } = useAuth();
    if (isAuthenticated && forcePasswordChange && !isPasswordRecovery) {
        return <ChangePasswordModal />;
    }
    return null;
}

function App() {
    return (
        <ThemeProvider>
            <AuthProvider>
                <RealtimeProvider>
                    <BrowserRouter>
                        <PasswordRecoveryRedirect />
                        <GlobalOverlays />

                        <Routes>
                            <Route path="/login" element={<LoginPage />} />
                            <Route path="/forgot-password" element={<ForgotPasswordPage />} />
                            <Route path="/update-password" element={<UpdatePasswordPage />} />
                            <Route element={<ProtectedRoute />}>
                                <Route element={<Layout />}>
                                    <Route path="/" element={<Navigate to="/dashboard" replace />} />
                                    <Route path="/dashboard" element={<DashboardPage />} />
                                    <Route path="/rooms" element={<RoomsPage />} />
                                    <Route path="/history" element={<HistoryPage />} />
                                    <Route path="/camera" element={<CameraPage />} />
                                    <Route path="/identity" element={<IdentityPage />} />
                                    <Route path="/alerts" element={<AlertsPage />} />
                                    <Route path="/residents" element={<ResidentsPage />} />
                                    <Route path="/settings" element={<SettingsPage />} />
                                </Route>
                            </Route>
                            <Route path="*" element={<Navigate to="/" replace />} />
                        </Routes>
                    </BrowserRouter>
                </RealtimeProvider>
            </AuthProvider>
        </ThemeProvider>
    );
}

export default App;
