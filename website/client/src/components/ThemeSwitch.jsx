import { Moon, Sun } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';

const TRACK = {
    light: { left: '#1e2433', right: '#eef2f8' },
    dark: { left: '#0a0c10', right: '#252b3a' },
};

const ThemeSwitch = ({ size = 'md', showLabel = false }) => {
    const { theme, toggleTheme } = useTheme();
    const isLight = theme === 'light';

    const dims = size === 'lg'
        ? { w: 56, h: 30, knob: 24, pad: 3 }
        : { w: 48, h: 26, knob: 20, pad: 3 };

    const knobX = isLight ? dims.w - dims.knob - dims.pad : dims.pad;
    const colors = isLight ? TRACK.light : TRACK.dark;

    return (
        <button
            type="button"
            role="switch"
            aria-checked={isLight}
            aria-label={`Switch to ${isLight ? 'dark' : 'light'} mode`}
            onClick={toggleTheme}
            style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 'var(--s2)',
                background: 'transparent',
                border: 'none',
                padding: 0,
                cursor: 'pointer',
                color: 'var(--text-secondary)',
            }}
        >
            <span
                style={{
                    position: 'relative',
                    display: 'block',
                    flexShrink: 0,
                    width: dims.w,
                    height: dims.h,
                    boxSizing: 'border-box',
                    border: `1px solid ${isLight ? 'var(--border-medium)' : 'var(--border-soft)'}`,
                    borderRadius: 'var(--r-full)',
                    overflow: 'hidden',
                    transition: 'border-color var(--t-base) var(--ease-out)',
                    boxShadow: isLight ? '0 2px 8px rgba(15, 23, 42, 0.08)' : 'inset 0 1px 2px rgba(0,0,0,0.35)',
                }}
            >
                <span
                    aria-hidden
                    style={{
                        position: 'absolute',
                        inset: 0,
                        left: 0,
                        width: '50%',
                        background: colors.left,
                    }}
                />
                <span
                    aria-hidden
                    style={{
                        position: 'absolute',
                        inset: 0,
                        left: '50%',
                        width: '50%',
                        background: colors.right,
                    }}
                />
                <Moon
                    size={12}
                    style={{
                        position: 'absolute',
                        left: 7,
                        top: '50%',
                        transform: 'translateY(-50%)',
                        color: isLight ? 'rgba(255,255,255,0.85)' : 'var(--cyan-bright)',
                        transition: 'color var(--t-base) var(--ease-out), opacity var(--t-base) var(--ease-out)',
                        opacity: isLight ? 0.55 : 1,
                        pointerEvents: 'none',
                        zIndex: 1,
                    }}
                />
                <Sun
                    size={12}
                    style={{
                        position: 'absolute',
                        right: 7,
                        top: '50%',
                        transform: 'translateY(-50%)',
                        color: isLight ? 'var(--ember-core)' : 'rgba(255,255,255,0.35)',
                        transition: 'color var(--t-base) var(--ease-out), opacity var(--t-base) var(--ease-out)',
                        opacity: isLight ? 1 : 0.45,
                        pointerEvents: 'none',
                        zIndex: 1,
                    }}
                />
                <span
                    style={{
                        position: 'absolute',
                        top: dims.pad,
                        left: knobX,
                        width: dims.knob,
                        height: dims.knob,
                        background: isLight
                            ? 'linear-gradient(135deg, #fff, #f5f7fb)'
                            : 'linear-gradient(135deg, #3a4256, #252b3a)',
                        borderRadius: '50%',
                        boxShadow: isLight
                            ? '0 2px 6px rgba(15, 23, 42, 0.15)'
                            : '0 2px 6px rgba(0,0,0,0.4)',
                        transition: 'left var(--t-base) var(--ease-out), background var(--t-base) var(--ease-out)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: isLight ? 'var(--ember-core)' : 'var(--cyan-bright)',
                        zIndex: 2,
                    }}
                >
                    {isLight ? <Sun size={11} /> : <Moon size={11} />}
                </span>
            </span>
            {showLabel && (
                <span style={{ fontSize: 'var(--size-xs)', fontWeight: 600, letterSpacing: '0.05em', textTransform: 'uppercase' }}>
                    {isLight ? 'Light' : 'Dark'}
                </span>
            )}
        </button>
    );
};

export default ThemeSwitch;
