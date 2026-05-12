import { createContext, useState, useEffect, useCallback } from 'react';
import { supabase } from '../services/supabase';

export const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [forcePasswordChange, setForcePasswordChange] = useState(false);

    const fetchProfile = useCallback(async (userId) => {
        const { data } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .single();
        setProfile(data);
        return data;
    }, []);

    const refreshProfile = useCallback(async () => {
        if (!user?.id) return;
        return fetchProfile(user.id);
    }, [user, fetchProfile]);

    useEffect(() => {
        let mounted = true;

        const { data: { subscription } } = supabase.auth.onAuthStateChange(
            (_event, session) => {
                if (!mounted) return;

                // Password recovery link clicked — show password change modal
                if (_event === 'PASSWORD_RECOVERY') {
                    const u = session?.user ?? null;
                    setUser(u);
                    setLoading(false);
                    setForcePasswordChange(true);
                    if (u) {
                        setTimeout(() => {
                            fetchProfile(u.id).catch(e => console.error('[Auth] fetchProfile error:', e));
                        }, 0);
                    }
                    return;
                }

                const u = session?.user ?? null;
                setUser(u);
                if (!u) {
                    setProfile(null);
                    setForcePasswordChange(false);
                }
                setLoading(false);

                if (u) {
                    // Check force_password_change flag in user metadata
                    const needsChange = u.user_metadata?.force_password_change === true;
                    setForcePasswordChange(needsChange);

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

    /**
     * Admin tarafından bir Resident hesabı oluşturur.
     * Şifreyi kimse görmez — rastgele UUID şifre arka planda oluşturulur,
     * ardından Supabase resident'a "Şifreni belirle" maili gönderir.
     */
    const createResidentAccount = async (name, email) => {
        // A cryptographically random password nobody will ever see or use
        const dummyPassword = (
            typeof crypto !== 'undefined' && crypto.randomUUID
                ? crypto.randomUUID() + crypto.randomUUID()
                : Math.random().toString(36).repeat(4)
        );

        try {
            const { data, error: err } = await supabase.auth.signUp({
                email,
                password: dummyPassword,
                options: {
                    data: {
                        name,
                        role: 'resident',
                        force_password_change: true,
                    },
                },
            });

            if (err) throw err;
            if (!data?.user) throw new Error('Account creation returned no user. The email may already be registered.');

            // Send password-setup email — resident clicks the link and sets their own password
            const { error: resetErr } = await supabase.auth.resetPasswordForEmail(email, {
                redirectTo: `${window.location.origin}/login`,
            });
            if (resetErr) console.warn('[Auth] resetPasswordForEmail failed:', resetErr.message);

            return { success: true, userId: data.user.id };
        } catch (err) {
            return { success: false, error: err.message };
        }
    };

    /**
     * Resident ilk girişinden sonra şifresini değiştirir ve force_password_change flag'ini temizler.
     */
    const changePassword = async (newPassword) => {
        try {
            const { error: err } = await supabase.auth.updateUser({
                password: newPassword,
                data: { force_password_change: false },
            });
            if (err) throw err;
            setForcePasswordChange(false);
            return { success: true };
        } catch (err) {
            return { success: false, error: err.message };
        }
    };

    /**
     * Admin tarafından bir auth kullanıcısını siler (SECURITY DEFINER RPC).
     */
    const deleteAuthUser = async (targetUserId) => {
        try {
            const { data, error: err } = await supabase.rpc('delete_auth_user', {
                target_user_id: targetUserId,
            });
            if (err) throw err;
            if (data?.success === false) throw new Error(data.error || 'Delete failed');
            return { success: true };
        } catch (err) {
            return { success: false, error: err.message };
        }
    };

    const logout = async () => {
        await supabase.auth.signOut();
        setUser(null);
        setProfile(null);
        setForcePasswordChange(false);
        window.location.href = '/login';
    };

    const isAdmin = profile?.role === 'admin';

    const value = {
        user,
        profile,
        loading,
        error,
        login,
        register,
        logout,
        isAuthenticated: !!user,
        isAdmin,
        forcePasswordChange,
        createResidentAccount,
        changePassword,
        deleteAuthUser,
        refreshProfile,
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
};
