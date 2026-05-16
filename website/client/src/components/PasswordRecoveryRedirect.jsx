import { useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

/**
 * When Supabase fires PASSWORD_RECOVERY, ensure the user lands on /update-password.
 */
export default function PasswordRecoveryRedirect() {
    const { isPasswordRecovery } = useAuth();
    const location = useLocation();
    const navigate = useNavigate();

    useEffect(() => {
        if (isPasswordRecovery && location.pathname !== '/update-password') {
            navigate('/update-password', { replace: true });
        }
    }, [isPasswordRecovery, location.pathname, navigate]);

    return null;
}
