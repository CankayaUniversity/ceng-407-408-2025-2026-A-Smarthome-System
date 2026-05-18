import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme/app_theme.dart';

/// WebSocket-based live camera viewer.
///
/// Connects to the cloud relay server, registers as a "viewer",
/// and renders incoming base64-encoded JPEG frames in real time.
///
/// Features:
///   - Automatic reconnection with exponential back-off
///   - FPS counter overlay
///   - Graceful disposal of resources
class WebSocketLiveView extends StatefulWidget {
  /// WebSocket relay URL (e.g. ws://92.5.17.205:8080).
  final String url;

  /// How the image should be inscribed into the widget bounds.
  final BoxFit fit;

  /// When `false`, the widget shows a placeholder and does NOT establish a
  /// WebSocket connection (matching the web LIVE/STOP button semantics).
  /// Flipping this to `true` connects; flipping back to `false` cleanly
  /// closes the socket so the relay can stop the streamer.
  final bool enabled;

  const WebSocketLiveView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.enabled = true,
  });

  @override
  State<WebSocketLiveView> createState() => _WebSocketLiveViewState();
}

class _WebSocketLiveViewState extends State<WebSocketLiveView> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Uint8List? _frameBytes;
  bool _connected = false;
  bool _connecting = false;
  int _fps = 0;

  // Reconnect back-off
  Timer? _reconnectTimer;
  int _reconnectDelay = 1; // seconds
  static const int _maxReconnectDelay = 30;

  // FPS counter
  int _frameCount = 0;
  Timer? _fpsTimer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _connect();
  }

  @override
  void didUpdateWidget(covariant WebSocketLiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _reconnectDelay = 1;
        _connect();
      } else {
        _teardown();
      }
    } else if (widget.url != oldWidget.url && widget.enabled) {
      _reconnectDelay = 1;
      _connect();
    }
  }

  @override
  void dispose() {
    _cleanup();
    _reconnectTimer?.cancel();
    _fpsTimer?.cancel();
    super.dispose();
  }

  /// User-initiated teardown (also called when [enabled] flips false).
  /// Cancels any pending reconnect and drops the connection so the relay
  /// counts one fewer viewer.
  void _teardown() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanup();
    if (mounted) {
      setState(() {
        _connected = false;
        _connecting = false;
        _frameBytes = null;
        _fps = 0;
      });
    }
  }

  // ── Connection lifecycle ────────────────────────────────────

  void _connect() {
    if (!mounted) return;
    _cleanup();

    setState(() {
      _connecting = true;
      _connected = false;
    });

    try {
      final uri = Uri.parse(widget.url);
      _channel = WebSocketChannel.connect(uri);

      // Register as viewer
      _channel!.sink.add(jsonEncode({'role': 'viewer'}));

      // Start listening for frames
      _subscription = _channel!.stream.listen(
        _onFrame,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Mark connected after a short delay (allows handshake)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _channel != null) {
          setState(() {
            _connected = true;
            _connecting = false;
          });
          _reconnectDelay = 1; // reset back-off
          _startFpsCounter();
        }
      });
    } catch (e) {
      debugPrint('[WebSocketLiveView] Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _fpsTimer?.cancel();
    _fpsTimer = null;
    _frameCount = 0;
  }

  void _scheduleReconnect() {
    if (!mounted || !widget.enabled) return;
    setState(() {
      _connected = false;
      _connecting = false;
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (mounted && widget.enabled) _connect();
    });
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
  }

  // ── Frame handling ──────────────────────────────────────────

  void _onFrame(dynamic data) {
    if (!mounted) return;
    try {
      final String b64 = data is String ? data : utf8.decode(data as List<int>);
      final bytes = base64Decode(b64);
      setState(() => _frameBytes = bytes);
      _frameCount++;
    } catch (e) {
      // Silently skip malformed frames
    }
  }

  void _onError(Object error) {
    debugPrint('[WebSocketLiveView] Stream error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WebSocketLiveView] Stream closed');
    _scheduleReconnect();
  }

  // ── FPS counter ─────────────────────────────────────────────

  void _startFpsCounter() {
    _fpsTimer?.cancel();
    _frameCount = 0;
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _fps = _frameCount;
          _frameCount = 0;
        });
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Standby — parent has not enabled the stream yet (web LIVE/STOP parity).
    if (!widget.enabled) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.bgElevated, tokens.bgBase],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_outlined,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 8),
                Text(
                  'Live feed is paused',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Press GO LIVE to start streaming',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Connected and receiving frames
    if (_connected && _frameBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _frameBytes!,
            fit: widget.fit,
            gaplessPlayback: true, // prevents flicker between frames
          ),

          // LIVE badge — top left
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                border: Border.all(
                  color: tokens.crimsonCore.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: tokens.crimsonCore,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tokens.crimsonCore,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FPS counter — top right
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$_fps FPS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Connecting / offline state
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tokens.bgElevated, tokens.bgBase],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_connecting)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: tokens.emberCore,
                  ),
                )
              else
                Icon(
                  Icons.videocam_off_outlined,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              const SizedBox(height: 10),
              Text(
                _connecting ? 'Connecting to camera...' : 'Live feed offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _connecting
                    ? 'Establishing WebSocket connection'
                    : 'Stream unavailable — will retry automatically',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_connecting) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () {
                    _reconnectTimer?.cancel();
                    _reconnectDelay = 1;
                    _connect();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'RECONNECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.emberCore,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
