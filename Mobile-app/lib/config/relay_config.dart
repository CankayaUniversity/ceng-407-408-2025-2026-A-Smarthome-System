/// WebSocket relay for on-demand live camera (same as web `VITE_RELAY_WS_URL`).
class RelayConfig {
  static const String relayWsUrl = String.fromEnvironment(
    'RELAY_WS_URL',
    defaultValue: 'ws://165.245.243.130:8080',
  );
}
