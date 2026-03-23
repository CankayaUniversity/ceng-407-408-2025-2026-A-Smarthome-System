import React, { createContext, useState, useEffect, useCallback } from 'react';
import api from '../services/api';

export const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [token, setToken] = useState(localStorage.getItem('token'));
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // Initialize Auth State from backend
    const initAuth = useCallback(async () => {
        if (!token) {
            setLoading(false);
            return;
        }

        try {
            setLoading(true);
            const res = await api.get('/auth/me');
            setUser(res.data.user);
            localStorage.setItem('user', JSON.stringify(res.data.user));
        } catch (err) {
            console.error('Failed to initialize auth', err);
            logout(); // clear invalid token
        } finally {
            setLoading(false);
        }
    }, [token]);

    useEffect(() => {
        initAuth();
    }, [initAuth]);

    // Login handler
    const login = async (email, password) => {
        try {
            setError(null);
            setLoading(true);
            const res = await api.post('/auth/login', { email, password });

            const { token: newToken, user: userData } = res.data;

            localStorage.setItem('token', newToken);
            localStorage.setItem('user', JSON.stringify(userData));

            setToken(newToken);
            setUser(userData);

            return true;
        } catch (err) {
            setError(err.response?.data?.error || 'Login failed');
            return false;
        } finally {
            setLoading(false);
        }
    };

    // Register handler
    const register = async (name, email, password) => {
        try {
            setError(null);
            setLoading(true);
            const res = await api.post('/auth/register', { name, email, password });

            const { token: newToken, user: userData } = res.data;

            localStorage.setItem('token', newToken);
            localStorage.setItem('user', JSON.stringify(userData));

            setToken(newToken);
            setUser(userData);

            return true;
        } catch (err) {
            setError(err.response?.data?.error || 'Registration failed');
            return false;
        } finally {
            setLoading(false);
        }
    };

    // Logout handler
    const logout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        setToken(null);
        setUser(null);
        window.location.href = '/login'; // Redirect to login
    };

    const value = {
        user,
        token,
        loading,
        error,
        login,
        register,
        logout,
        isAuthenticated: !!user && !!token,
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
};
