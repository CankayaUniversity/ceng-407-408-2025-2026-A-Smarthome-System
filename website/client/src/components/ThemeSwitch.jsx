import { Moon, Sun } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';

const ThemeSwitch = ({ size = 'md', showLabel = false }) => {
    const { theme, toggleTheme } = useTheme();
    const isLight = theme === 'light';

    const dims = size === 'lg'
        ? { w: 56, h: 30, knob: 24, pad: 3 }
        : { w: 48, h: 26, knob: 20, pad: 3 };

    const knobX = isLight ? dims.w - dims.knob - dims.pad : dims.pad;

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
                    display: 'inline-flex',
                    alignItems: 'center',
                    width: dims.w,
                    height: dims.h,
                    background: isLight ? 'var(--cyan-glow)' : 'var(--bg-elevated)',
                    border: `1px solid ${isLight ? 'rgba(0,212,255,0.4)' : 'var(--border-soft)'}`,
                    borderRadius: 'var(--r-full)',
                    transition: 'background var(--t-base) var(--ease-out), border-color var(--t-base) var(--ease-out)',
                    boxShadow: isLight ? '0 0 16px rgba(0,212,255,0.18)' : 'inset 0 1px 2px rgba(0,0,0,0.3)',
                }}
            >
                <Sun
                    size={12}
                    style={{
                        position: 'absolute',
                        left: 7,
                        color: isLight ? 'var(--ember-core)' : 'var(--text-whisper)',
                        transition: 'color var(--t-base) var(--ease-out)',
                        pointerEvents: 'none',
                    }}
                />
                <Moon
                    size={12}
                    style={{
                        position: 'absolute',
                        right: 7,
                        color: isLight ? 'var(--text-whisper)' : 'var(--cyan-core)',
                        transition: 'color var(--t-base) var(--ease-out)',
                        pointerEvents: 'none',
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
                            : 'linear-gradient(135deg, var(--bg-highlight), var(--bg-elevated))',
                        borderRadius: '50%',
                        boxShadow: '0 2px 8px rgba(0,0,0,0.35), 0 0 0 1px rgba(255,255,255,0.04) inset',
                        transition: 'left var(--t-base) var(--ease-out), background var(--t-base) var(--ease-out)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: isLight ? 'var(--ember-core)' : 'var(--cyan-bright)',
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
