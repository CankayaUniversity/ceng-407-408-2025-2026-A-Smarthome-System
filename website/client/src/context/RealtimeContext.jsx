import { createContext, useContext, useEffect, useRef, useState, useCallback } from 'react';
import { supabase } from '../services/supabase';
import { useAuth } from '../hooks/useAuth';

const RealtimeContext = createContext(null);

export const RealtimeProvider = ({ children }) => {
    const { isAuthenticated } = useAuth();
    const [isConnected, setIsConnected] = useState(false);
    const listenersRef = useRef({});
    const channelRef = useRef(null);

    useEffect(() => {
        if (!isAuthenticated) {
            if (channelRef.current) {
                supabase.removeChannel(channelRef.current);
                channelRef.current = null;
            }
            setIsConnected(false);
            return;
        }

        const channel = supabase
            .channel('db-changes')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'sensor_readings' },
                (payload) => fire('sensor_reading', payload.new))
            .on('postgres_changes', { event: '*', schema: 'public', table: 'events' },
                (payload) => fire('event', payload.new))
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'camera_events' },
                (payload) => fire('camera_event', payload.new))
            .subscribe((status) => {
                setIsConnected(status === 'SUBSCRIBED');
            });

        channelRef.current = channel;

        return () => {
            supabase.removeChannel(channel);
        };
    }, [isAuthenticated]);

    function fire(type, data) {
        const cbs = listenersRef.current[type] || [];
        cbs.forEach(cb => cb(data));
    }

    const subscribe = useCallback((type, callback) => {
        if (!listenersRef.current[type]) listenersRef.current[type] = [];
        listenersRef.current[type].push(callback);
        return () => {
            listenersRef.current[type] = listenersRef.current[type].filter(cb => cb !== callback);
        };
    }, []);

    return (
        <RealtimeContext.Provider value={{ isConnected, subscribe }}>
            {children}
        </RealtimeContext.Provider>
    );
};

export const useRealtime = () => {
    const ctx = useContext(RealtimeContext);
    if (!ctx) throw new Error('useRealtime must be used within RealtimeProvider');
    return ctx;
};
