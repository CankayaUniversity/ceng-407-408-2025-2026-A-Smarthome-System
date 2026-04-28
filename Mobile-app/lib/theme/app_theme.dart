import 'package:flutter/material.dart';

/// Mobile-app design tokens — bire-bir
/// `website/client/src/index.css` token setine karşılık gelir.
///
/// Renkler hem dark (default) hem light mod için tanımlıdır.
/// `BuildContext.tokens` extension'ı ile her ekrandan erişilir.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // ─── Background layers ────────────────────────────────────
  final Color bgVoid;
  final Color bgBase;
  final Color bgRaised;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgOverlay;
  final Color bgHighlight;

  // ─── Accent palette ───────────────────────────────────────
  final Color emberCore;
  final Color emberBright;
  final Color emberGlow;
  final Color emberSubtle;

  final Color cyanCore;
  final Color cyanBright;
  final Color cyanGlow;

  final Color violetCore;
  final Color violetBright;
  final Color violetGlow;

  final Color jadeCore;
  final Color jadeGlow;

  final Color amberCore;
  final Color amberGlow;

  final Color crimsonCore;
  final Color crimsonGlow;

  // ─── Text layers ──────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textWhisper;

  // ─── Borders ──────────────────────────────────────────────
  final Color borderDim;
  final Color borderSoft;
  final Color borderMedium;
  final Color borderBright;

  // ─── Sensor accents ───────────────────────────────────────
  final Color sensorTemp;
  final Color sensorHumid;
  final Color sensorSmoke;
  final Color sensorWater;
  final Color sensorMotion;
  final Color sensorMoisture;
  final Color sensorLight;

  // ─── Floor plan blueprint ─────────────────────────────────
  final Color blueprintBg;
  final Color blueprintGrid;
  final Color blueprintFrame;
  final Color blueprintRoomBorder;
  final Color blueprintRoomLabel;
  final Color blueprintRoomMeta;
  final Color blueprintPinBg;
  final Color blueprintPinShadow;

  const AppTokens({
    required this.bgVoid,
    required this.bgBase,
    required this.bgRaised,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgOverlay,
    required this.bgHighlight,
    required this.emberCore,
    required this.emberBright,
    required this.emberGlow,
    required this.emberSubtle,
    required this.cyanCore,
    required this.cyanBright,
    required this.cyanGlow,
    required this.violetCore,
    required this.violetBright,
    required this.violetGlow,
    required this.jadeCore,
    required this.jadeGlow,
    required this.amberCore,
    required this.amberGlow,
    required this.crimsonCore,
    required this.crimsonGlow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textWhisper,
    required this.borderDim,
    required this.borderSoft,
    required this.borderMedium,
    required this.borderBright,
    required this.sensorTemp,
    required this.sensorHumid,
    required this.sensorSmoke,
    required this.sensorWater,
    required this.sensorMotion,
    required this.sensorMoisture,
    required this.sensorLight,
    required this.blueprintBg,
    required this.blueprintGrid,
    required this.blueprintFrame,
    required this.blueprintRoomBorder,
    required this.blueprintRoomLabel,
    required this.blueprintRoomMeta,
    required this.blueprintPinBg,
    required this.blueprintPinShadow,
  });

  factory AppTokens.dark() => const AppTokens(
        bgVoid: Color(0xFF050709),
        bgBase: Color(0xFF080B10),
        bgRaised: Color(0xFF0D1117),
        bgSurface: Color(0xFF111720),
        bgElevated: Color(0xFF161E2A),
        bgOverlay: Color(0xFF1A2232),
        bgHighlight: Color(0xFF1F2A3E),
        emberCore: Color(0xFFFF6B35),
        emberBright: Color(0xFFFF8C5A),
        emberGlow: Color(0x2EFF6B35),
        emberSubtle: Color(0x0AFF6B35),
        cyanCore: Color(0xFF00D4FF),
        cyanBright: Color(0xFF40E0FF),
        cyanGlow: Color(0x2600D4FF),
        violetCore: Color(0xFF9B59FF),
        violetBright: Color(0xFFB07AFF),
        violetGlow: Color(0x269B59FF),
        jadeCore: Color(0xFF00E5A0),
        jadeGlow: Color(0x2600E5A0),
        amberCore: Color(0xFFFFB020),
        amberGlow: Color(0x26FFB020),
        crimsonCore: Color(0xFFFF3B5C),
        crimsonGlow: Color(0x26FF3B5C),
        textPrimary: Color(0xFFF0F4FF),
        textSecondary: Color(0xFF8892A4),
        textMuted: Color(0xFF4C5668),
        textWhisper: Color(0xFF2D3548),
        borderDim: Color(0x0AFFFFFF),
        borderSoft: Color(0x14FFFFFF),
        borderMedium: Color(0x21FFFFFF),
        borderBright: Color(0x38FFFFFF),
        sensorTemp: Color(0xFFFF6B35),
        sensorHumid: Color(0xFF00D4FF),
        sensorSmoke: Color(0xFFFF3B5C),
        sensorWater: Color(0xFF3B9EFF),
        sensorMotion: Color(0xFF9B59FF),
        sensorMoisture: Color(0xFF00E5A0),
        sensorLight: Color(0xFFFFB020),
        blueprintBg: Color(0xFF0A0C10),
        blueprintGrid: Color(0x14FFFFFF),
        blueprintFrame: Color(0x1AFFFFFF),
        blueprintRoomBorder: Color(0x1AFFFFFF),
        blueprintRoomLabel: Color(0xE6FFFFFF),
        blueprintRoomMeta: Color(0x80FFFFFF),
        blueprintPinBg: Color(0xD90F1117),
        blueprintPinShadow: Color(0x80000000),
      );

  factory AppTokens.light() => const AppTokens(
        bgVoid: Color(0xFFF3F5FA),
        bgBase: Color(0xFFFFFFFF),
        bgRaised: Color(0xFFF7F9FC),
        bgSurface: Color(0xFFFFFFFF),
        bgElevated: Color(0xFFF1F4F9),
        bgOverlay: Color(0xFFE9EDF4),
        bgHighlight: Color(0xFFE2E7F0),
        emberCore: Color(0xFFE85D2A),
        emberBright: Color(0xFFFF7A44),
        emberGlow: Color(0x2EE85D2A),
        emberSubtle: Color(0x0FE85D2A),
        cyanCore: Color(0xFF0099C4),
        cyanBright: Color(0xFF00B6E0),
        cyanGlow: Color(0x2E0099C4),
        violetCore: Color(0xFF7A3FE4),
        violetBright: Color(0xFF9462FF),
        violetGlow: Color(0x2E7A3FE4),
        jadeCore: Color(0xFF00A878),
        jadeGlow: Color(0x2E00A878),
        amberCore: Color(0xFFD68910),
        amberGlow: Color(0x2ED68910),
        crimsonCore: Color(0xFFD8284A),
        crimsonGlow: Color(0x2ED8284A),
        textPrimary: Color(0xFF0C121F),
        textSecondary: Color(0xFF4A5468),
        textMuted: Color(0xFF6B7587),
        textWhisper: Color(0xFFAAB2C2),
        borderDim: Color(0x0F0C121F),
        borderSoft: Color(0x1A0C121F),
        borderMedium: Color(0x290C121F),
        borderBright: Color(0x470C121F),
        sensorTemp: Color(0xFFE85D2A),
        sensorHumid: Color(0xFF0099C4),
        sensorSmoke: Color(0xFFD8284A),
        sensorWater: Color(0xFF2C7FD8),
        sensorMotion: Color(0xFF7A3FE4),
        sensorMoisture: Color(0xFF00A878),
        sensorLight: Color(0xFFD68910),
        blueprintBg: Color(0xFFEEF2F8),
        blueprintGrid: Color(0x140C121F),
        blueprintFrame: Color(0x1F0C121F),
        blueprintRoomBorder: Color(0x240C121F),
        blueprintRoomLabel: Color(0xD90C121F),
        blueprintRoomMeta: Color(0x800C121F),
        blueprintPinBg: Color(0xF2FFFFFF),
        blueprintPinShadow: Color(0x1F0F172A),
      );

  @override
  AppTokens copyWith({
    Color? bgVoid,
    Color? bgBase,
    Color? bgRaised,
    Color? bgSurface,
    Color? bgElevated,
    Color? bgOverlay,
    Color? bgHighlight,
    Color? emberCore,
    Color? emberBright,
    Color? emberGlow,
    Color? emberSubtle,
    Color? cyanCore,
    Color? cyanBright,
    Color? cyanGlow,
    Color? violetCore,
    Color? violetBright,
    Color? violetGlow,
    Color? jadeCore,
    Color? jadeGlow,
    Color? amberCore,
    Color? amberGlow,
    Color? crimsonCore,
    Color? crimsonGlow,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textWhisper,
    Color? borderDim,
    Color? borderSoft,
    Color? borderMedium,
    Color? borderBright,
    Color? sensorTemp,
    Color? sensorHumid,
    Color? sensorSmoke,
    Color? sensorWater,
    Color? sensorMotion,
    Color? sensorMoisture,
    Color? sensorLight,
    Color? blueprintBg,
    Color? blueprintGrid,
    Color? blueprintFrame,
    Color? blueprintRoomBorder,
    Color? blueprintRoomLabel,
    Color? blueprintRoomMeta,
    Color? blueprintPinBg,
    Color? blueprintPinShadow,
  }) {
    return AppTokens(
      bgVoid: bgVoid ?? this.bgVoid,
      bgBase: bgBase ?? this.bgBase,
      bgRaised: bgRaised ?? this.bgRaised,
      bgSurface: bgSurface ?? this.bgSurface,
      bgElevated: bgElevated ?? this.bgElevated,
      bgOverlay: bgOverlay ?? this.bgOverlay,
      bgHighlight: bgHighlight ?? this.bgHighlight,
      emberCore: emberCore ?? this.emberCore,
      emberBright: emberBright ?? this.emberBright,
      emberGlow: emberGlow ?? this.emberGlow,
      emberSubtle: emberSubtle ?? this.emberSubtle,
      cyanCore: cyanCore ?? this.cyanCore,
      cyanBright: cyanBright ?? this.cyanBright,
      cyanGlow: cyanGlow ?? this.cyanGlow,
      violetCore: violetCore ?? this.violetCore,
      violetBright: violetBright ?? this.violetBright,
      violetGlow: violetGlow ?? this.violetGlow,
      jadeCore: jadeCore ?? this.jadeCore,
      jadeGlow: jadeGlow ?? this.jadeGlow,
      amberCore: amberCore ?? this.amberCore,
      amberGlow: amberGlow ?? this.amberGlow,
      crimsonCore: crimsonCore ?? this.crimsonCore,
      crimsonGlow: crimsonGlow ?? this.crimsonGlow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textWhisper: textWhisper ?? this.textWhisper,
      borderDim: borderDim ?? this.borderDim,
      borderSoft: borderSoft ?? this.borderSoft,
      borderMedium: borderMedium ?? this.borderMedium,
      borderBright: borderBright ?? this.borderBright,
      sensorTemp: sensorTemp ?? this.sensorTemp,
      sensorHumid: sensorHumid ?? this.sensorHumid,
      sensorSmoke: sensorSmoke ?? this.sensorSmoke,
      sensorWater: sensorWater ?? this.sensorWater,
      sensorMotion: sensorMotion ?? this.sensorMotion,
      sensorMoisture: sensorMoisture ?? this.sensorMoisture,
      sensorLight: sensorLight ?? this.sensorLight,
      blueprintBg: blueprintBg ?? this.blueprintBg,
      blueprintGrid: blueprintGrid ?? this.blueprintGrid,
      blueprintFrame: blueprintFrame ?? this.blueprintFrame,
      blueprintRoomBorder: blueprintRoomBorder ?? this.blueprintRoomBorder,
      blueprintRoomLabel: blueprintRoomLabel ?? this.blueprintRoomLabel,
      blueprintRoomMeta: blueprintRoomMeta ?? this.blueprintRoomMeta,
      blueprintPinBg: blueprintPinBg ?? this.blueprintPinBg,
      blueprintPinShadow: blueprintPinShadow ?? this.blueprintPinShadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bgVoid: Color.lerp(bgVoid, other.bgVoid, t)!,
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgRaised: Color.lerp(bgRaised, other.bgRaised, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgOverlay: Color.lerp(bgOverlay, other.bgOverlay, t)!,
      bgHighlight: Color.lerp(bgHighlight, other.bgHighlight, t)!,
      emberCore: Color.lerp(emberCore, other.emberCore, t)!,
      emberBright: Color.lerp(emberBright, other.emberBright, t)!,
      emberGlow: Color.lerp(emberGlow, other.emberGlow, t)!,
      emberSubtle: Color.lerp(emberSubtle, other.emberSubtle, t)!,
      cyanCore: Color.lerp(cyanCore, other.cyanCore, t)!,
      cyanBright: Color.lerp(cyanBright, other.cyanBright, t)!,
      cyanGlow: Color.lerp(cyanGlow, other.cyanGlow, t)!,
      violetCore: Color.lerp(violetCore, other.violetCore, t)!,
      violetBright: Color.lerp(violetBright, other.violetBright, t)!,
      violetGlow: Color.lerp(violetGlow, other.violetGlow, t)!,
      jadeCore: Color.lerp(jadeCore, other.jadeCore, t)!,
      jadeGlow: Color.lerp(jadeGlow, other.jadeGlow, t)!,
      amberCore: Color.lerp(amberCore, other.amberCore, t)!,
      amberGlow: Color.lerp(amberGlow, other.amberGlow, t)!,
      crimsonCore: Color.lerp(crimsonCore, other.crimsonCore, t)!,
      crimsonGlow: Color.lerp(crimsonGlow, other.crimsonGlow, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textWhisper: Color.lerp(textWhisper, other.textWhisper, t)!,
      borderDim: Color.lerp(borderDim, other.borderDim, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      borderMedium: Color.lerp(borderMedium, other.borderMedium, t)!,
      borderBright: Color.lerp(borderBright, other.borderBright, t)!,
      sensorTemp: Color.lerp(sensorTemp, other.sensorTemp, t)!,
      sensorHumid: Color.lerp(sensorHumid, other.sensorHumid, t)!,
      sensorSmoke: Color.lerp(sensorSmoke, other.sensorSmoke, t)!,
      sensorWater: Color.lerp(sensorWater, other.sensorWater, t)!,
      sensorMotion: Color.lerp(sensorMotion, other.sensorMotion, t)!,
      sensorMoisture: Color.lerp(sensorMoisture, other.sensorMoisture, t)!,
      sensorLight: Color.lerp(sensorLight, other.sensorLight, t)!,
      blueprintBg: Color.lerp(blueprintBg, other.blueprintBg, t)!,
      blueprintGrid: Color.lerp(blueprintGrid, other.blueprintGrid, t)!,
      blueprintFrame: Color.lerp(blueprintFrame, other.blueprintFrame, t)!,
      blueprintRoomBorder:
          Color.lerp(blueprintRoomBorder, other.blueprintRoomBorder, t)!,
      blueprintRoomLabel:
          Color.lerp(blueprintRoomLabel, other.blueprintRoomLabel, t)!,
      blueprintRoomMeta:
          Color.lerp(blueprintRoomMeta, other.blueprintRoomMeta, t)!,
      blueprintPinBg: Color.lerp(blueprintPinBg, other.blueprintPinBg, t)!,
      blueprintPinShadow:
          Color.lerp(blueprintPinShadow, other.blueprintPinShadow, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

/// Centralised ThemeData factory.
class AppTheme {
  static ThemeData dark() {
    final tokens = AppTokens.dark();
    final scheme = ColorScheme.dark(
      primary: tokens.emberCore,
      onPrimary: Colors.white,
      secondary: tokens.cyanCore,
      onSecondary: Colors.white,
      tertiary: tokens.violetCore,
      surface: tokens.bgSurface,
      onSurface: tokens.textPrimary,
      surfaceContainer: tokens.bgRaised,
      surfaceContainerHigh: tokens.bgElevated,
      surfaceContainerHighest: tokens.bgHighlight,
      surfaceContainerLow: tokens.bgRaised,
      surfaceContainerLowest: tokens.bgBase,
      error: tokens.crimsonCore,
      onError: Colors.white,
      outline: tokens.borderMedium,
      outlineVariant: tokens.borderSoft,
    );
    return _build(scheme, tokens, isDark: true);
  }

  static ThemeData light() {
    final tokens = AppTokens.light();
    final scheme = ColorScheme.light(
      primary: tokens.emberCore,
      onPrimary: Colors.white,
      secondary: tokens.cyanCore,
      onSecondary: Colors.white,
      tertiary: tokens.violetCore,
      surface: tokens.bgSurface,
      onSurface: tokens.textPrimary,
      surfaceContainer: tokens.bgRaised,
      surfaceContainerHigh: tokens.bgElevated,
      surfaceContainerHighest: tokens.bgHighlight,
      surfaceContainerLow: tokens.bgRaised,
      surfaceContainerLowest: tokens.bgBase,
      error: tokens.crimsonCore,
      onError: Colors.white,
      outline: tokens.borderMedium,
      outlineVariant: tokens.borderSoft,
    );
    return _build(scheme, tokens, isDark: false);
  }

  static ThemeData _build(ColorScheme scheme, AppTokens tokens,
      {required bool isDark}) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.bgVoid,
      canvasColor: tokens.bgSurface,
      cardColor: tokens.bgSurface,
      dividerColor: tokens.borderSoft,
      extensions: [tokens],
      textTheme: ThemeData(brightness: scheme.brightness)
          .textTheme
          .apply(
            bodyColor: tokens.textPrimary,
            displayColor: tokens.textPrimary,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.bgSurface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
      ),
      iconTheme: IconThemeData(color: tokens.textSecondary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.bgSurface,
        modalBackgroundColor: tokens.bgSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.bgSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.bgElevated,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? tokens.emberCore : tokens.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? tokens.emberGlow : tokens.bgElevated),
      ),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: tokens.emberCore),
    );
  }
}
