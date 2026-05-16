import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';

const ProtectedRoute = () => {
    const { isAuthenticated, loading, isPasswordRecovery } = useAuth();

    if (loading) {
        return (
            <div className="auth-page">
                <div className="spinner"></div>
            </div>
        );
    }

    if (isPasswordRecovery) {
        return <Navigate to="/update-password" replace />;
    }

    return isAuthenticated ? <Outlet /> : <Navigate to="/login" replace />;
};

export default ProtectedRoute;
