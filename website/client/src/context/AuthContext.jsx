import { createContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../services/supabase';

export const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const fetchProfile = useCallback(async (userId) => {
        const { data } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .single();
        setProfile(data);
        return data;
    }, []);

    useEffect(() => {
        let mounted = true;

        const { data: { subscription } } = supabase.auth.onAuthStateChange(
            (_event, session) => {
                if (!mounted) return;
                const u = session?.user ?? null;
                setUser(u);
                if (!u) setProfile(null);
                setLoading(false);

                if (u) {
                    setTimeout(() => {
                        fetchProfile(u.id).catch(e => console.error('[Auth] fetchProfile error:', e));
                    }, 0);
                }
            }
        );

        return () => { mounted = false; subscription.unsubscribe(); };
    }, [fetchProfile]);

    const login = async (email, password) => {
        try {
            setError(null);
            setLoading(true);
            const { error: err } = await supabase.auth.signInWithPassword({ email, password });
            if (err) { setError(err.message); return false; }
            return true;
        } finally {
            setLoading(false);
        }
    };

    const register = async (name, email, password) => {
        try {
            setError(null);
            setLoading(true);
            const { error: err } = await supabase.auth.signUp({
                email,
                password,
                options: { data: { name } },
            });
            if (err) { setError(err.message); return false; }
            return true;
        } finally {
            setLoading(false);
        }
    };

    const logout = async () => {
        await supabase.auth.signOut();
        setUser(null);
        setProfile(null);
        window.location.href = '/login';
    };

    const value = {
        user,
        profile,
        loading,
        error,
        login,
        register,
        logout,
        isAuthenticated: !!user,
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
};
