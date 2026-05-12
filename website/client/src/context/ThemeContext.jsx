import { createContext, useCallback, useContext, useEffect, useState } from 'react';

const STORAGE_KEY = 'smarthome.theme';
const DEFAULT_THEME = 'dark';

const ThemeContext = createContext(null);

function readInitialTheme() {
    if (typeof window === 'undefined') return DEFAULT_THEME;
    try {
        const stored = window.localStorage.getItem(STORAGE_KEY);
        if (stored === 'light' || stored === 'dark') return stored;
    } catch {
        // localStorage may be disabled (private mode etc.) — fall back silently.
    }
    return DEFAULT_THEME;
}

export const ThemeProvider = ({ children }) => {
    const [theme, setThemeState] = useState(readInitialTheme);

    useEffect(() => {
        const root = document.documentElement;
        root.dataset.theme = theme;
        try {
            window.localStorage.setItem(STORAGE_KEY, theme);
        } catch {
            // Ignore persistence failures.
        }
    }, [theme]);

    const setTheme = useCallback((next) => {
        setThemeState(next === 'light' ? 'light' : 'dark');
    }, []);

    const toggleTheme = useCallback(() => {
        setThemeState(prev => (prev === 'dark' ? 'light' : 'dark'));
    }, []);

    return (
        <ThemeContext.Provider value={{ theme, setTheme, toggleTheme }}>
            {children}
        </ThemeContext.Provider>
    );
};

export const useTheme = () => {
    const ctx = useContext(ThemeContext);
    if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
    return ctx;
};
