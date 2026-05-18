import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

/// Pill-shaped sun/moon toggle that mirrors the web `ThemeSwitch` component.
class ThemeSwitch extends StatelessWidget {
  final String size; // 'md' | 'lg'
  final bool showLabel;

  const ThemeSwitch({
    super.key,
    this.size = 'md',
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tp = context.watch<ThemeProvider>();
    final isLight = !tp.isDark;

    final dims = size == 'lg'
        ? const _Dims(w: 56.0, h: 30.0, knob: 24.0, pad: 3.0)
        : const _Dims(w: 48.0, h: 26.0, knob: 20.0, pad: 3.0);

    final track = isLight
        ? tokens.cyanGlow
        : tokens.bgElevated;
    final border = isLight
        ? tokens.cyanCore.withValues(alpha: 0.4)
        : tokens.borderSoft;

    return InkWell(
      borderRadius: BorderRadius.circular(dims.h),
      onTap: () => context.read<ThemeProvider>().toggle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: dims.w,
              height: dims.h,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(dims.h),
                border: Border.all(color: border),
                boxShadow: isLight
                    ? [
                        BoxShadow(
                          color: tokens.cyanCore.withValues(alpha: 0.18),
                          blurRadius: 16,
                        ),
                      ]
                    : const [],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 7,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.light_mode,
                        size: 12,
                        color: isLight ? tokens.emberCore : tokens.textWhisper,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 7,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.dark_mode,
                        size: 12,
                        color: isLight ? tokens.textWhisper : tokens.cyanCore,
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    top: dims.pad,
                    left: isLight
                        ? (dims.w - dims.knob - dims.pad)
                        : dims.pad,
                    child: Container(
                      width: dims.knob,
                      height: dims.knob,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isLight
                              ? const [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF5F7FB),
                                ]
                              : [
                                  tokens.bgHighlight,
                                  tokens.bgElevated,
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isLight ? Icons.light_mode : Icons.dark_mode,
                        size: 11,
                        color: isLight ? tokens.emberCore : tokens.cyanBright,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                isLight ? 'LIGHT' : 'DARK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dims {
  final double w;
  final double h;
  final double knob;
  final double pad;
  const _Dims({
    required this.w,
    required this.h,
    required this.knob,
    required this.pad,
  });
}
