import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme/app_theme.dart';

/// WebSocket-based live camera viewer (relay protocol: register as viewer, receive base64 JPEG).
class WebSocketLiveView extends StatefulWidget {
  final String url;
  final BoxFit fit;

  /// When `false`, shows standby and does not connect (web LIVE/STOP parity).
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
  bool _handshakeDone = false;
  bool _hasFrame = false;
  bool _connecting = false;
  String? _lastError;
  int _fps = 0;

  Timer? _reconnectTimer;
  Timer? _frameWaitTimer;
  int _reconnectDelay = 1;
  static const int _maxReconnectDelay = 30;
  static const Duration _firstFrameTimeout = Duration(seconds: 20);

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
    _reconnectTimer?.cancel();
    _frameWaitTimer?.cancel();
    _fpsTimer?.cancel();
    _cleanup();
    super.dispose();
  }

  void _teardown() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanup();
    if (mounted) {
      setState(() {
        _handshakeDone = false;
        _hasFrame = false;
        _connecting = false;
        _frameBytes = null;
        _fps = 0;
        _lastError = null;
      });
    }
  }

  Future<void> _connect() async {
    if (!mounted || !widget.enabled) return;
    _cleanup();

    setState(() {
      _connecting = true;
      _handshakeDone = false;
      _hasFrame = false;
      _lastError = null;
    });

    try {
      final uri = Uri.parse(widget.url);
      debugPrint('[WebSocketLiveView] Connecting to $uri');

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      if (!mounted || !widget.enabled) return;

      _channel!.sink.add(jsonEncode({'role': 'viewer'}));
      _handshakeDone = true;

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _frameWaitTimer?.cancel();
      _frameWaitTimer = Timer(_firstFrameTimeout, () {
        if (!mounted || !widget.enabled || _hasFrame) return;
        debugPrint('[WebSocketLiveView] No frame within timeout');
        setState(() {
          _lastError =
              'No video frames yet. Is the Pi running with RELAY_ENABLED=true?';
        });
        _scheduleReconnect();
      });
    } catch (e) {
      debugPrint('[WebSocketLiveView] Connection error: $e');
      if (mounted) {
        setState(() {
          _lastError = e.toString();
        });
      }
      _scheduleReconnect();
    }
  }

  void _cleanup() {
    _frameWaitTimer?.cancel();
    _frameWaitTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _fpsTimer?.cancel();
    _fpsTimer = null;
    _frameCount = 0;
  }

  void _scheduleReconnect() {
    if (!mounted || !widget.enabled) return;
    _cleanup();
    setState(() {
      _connecting = false;
      _handshakeDone = false;
      _hasFrame = false;
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (mounted && widget.enabled) _connect();
    });
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
  }

  void _onMessage(dynamic data) {
    if (!mounted) return;

    try {
      final String payload = data is String
          ? data
          : utf8.decode(data as List<int>);

      if (payload.isEmpty) return;
      if (payload.startsWith('{')) return;

      String b64 = payload;
      if (b64.startsWith('data:image')) {
        final comma = b64.indexOf(',');
        if (comma >= 0) b64 = b64.substring(comma + 1);
      }

      final bytes = base64Decode(b64);
      if (!_hasFrame) {
        _frameWaitTimer?.cancel();
        _reconnectDelay = 1;
        _startFpsCounter();
      }

      setState(() {
        _frameBytes = bytes;
        _hasFrame = true;
        _connecting = false;
        _lastError = null;
      });
      _frameCount++;
    } catch (e) {
      debugPrint('[WebSocketLiveView] Frame decode error: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('[WebSocketLiveView] Stream error: $error');
    if (mounted) {
      setState(() => _lastError = error.toString());
    }
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WebSocketLiveView] Stream closed');
    _scheduleReconnect();
  }

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

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

    if (_hasFrame && _frameBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _frameBytes!,
            fit: widget.fit,
            gaplessPlayback: true,
          ),
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

    final waiting = _connecting || (_handshakeDone && !_hasFrame);
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
              if (waiting)
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
                waiting ? 'Connecting to camera...' : 'Live feed offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _lastError ??
                    (waiting
                        ? 'Relay: ${widget.url}'
                        : 'Stream unavailable — will retry automatically'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              if (!waiting) ...[
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
