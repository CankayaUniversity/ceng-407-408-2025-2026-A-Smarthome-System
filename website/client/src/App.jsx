import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { SocketProvider } from './context/SocketContext';

// Components
import ProtectedRoute from './components/Layout/ProtectedRoute';
import Layout from './components/Layout/Layout';

// Pages
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import HistoryPage from './pages/HistoryPage';
import CameraPage from './pages/CameraPage';
import AlertsPage from './pages/AlertsPage';
import ResidentsPage from './pages/ResidentsPage';
import SettingsPage from './pages/SettingsPage';
import RoomsPage from './pages/RoomsPage';

function App() {
  return (
    <AuthProvider>
      <SocketProvider>
        <BrowserRouter>
          <Routes>
            {/* Public Auth Route */}
            <Route path="/login" element={<LoginPage />} />

            {/* Protected Routes inside Layout */}
            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route path="/" element={<Navigate to="/dashboard" replace />} />
                <Route path="/dashboard" element={<DashboardPage />} />
                <Route path="/rooms" element={<RoomsPage />} />
                <Route path="/history" element={<HistoryPage />} />
                <Route path="/camera" element={<CameraPage />} />
                <Route path="/alerts" element={<AlertsPage />} />
                <Route path="/residents" element={<ResidentsPage />} />
                <Route path="/settings" element={<SettingsPage />} />
              </Route>
            </Route>

            {/* Fallback */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </SocketProvider>
    </AuthProvider>
  );
}

export default App;
