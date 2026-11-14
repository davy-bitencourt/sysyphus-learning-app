import 'package:flutter/material.dart';

import '../data/database_helper.dart';

class AccentOption {
  final String id;
  final String name;
  final Color color;
  const AccentOption(this.id, this.name, this.color);
}

class HeatmapPalette {
  final String id;
  final String name;
  final List<Color> levels;
  const HeatmapPalette(this.id, this.name, this.levels);
}

class LanguageOption {
  final String id;
  final String name;
  const LanguageOption(this.id, this.name);
}

class AppOptions {
  AppOptions._();

  static const List<AccentOption> accents = [
    AccentOption('satin_gold', 'Satin Gold', Color(0xFFCBB080)),
    AccentOption('orange', 'Orange', Color(0xFFE65100)),
    AccentOption('green', 'Green', Color(0xFF2E7D32)),
    AccentOption('blue', 'Blue', Color(0xFF1565C0)),
    AccentOption('purple', 'Purple', Color(0xFF6A1B9A)),
  ];

  static const List<HeatmapPalette> heatmaps = [
    HeatmapPalette('satin_gold', 'Satin Gold', [
      Color(0xFFEAD2AA),
      Color(0xFFCBB080),
      Color(0xFF9A7F53),
      Color(0xFF695231),
    ]),
    HeatmapPalette('orange', 'Orange', [
      Color(0xFFFFE082),
      Color(0xFFFFB300),
      Color(0xFFFF8F00),
      Color(0xFFE65100),
    ]),
    HeatmapPalette('green', 'Green', [
      Color(0xFF9BE9A8),
      Color(0xFF40C463),
      Color(0xFF30A14E),
      Color(0xFF216E39),
    ]),
    HeatmapPalette('blue', 'Blue', [
      Color(0xFFBBDEFB),
      Color(0xFF64B5F6),
      Color(0xFF1E88E5),
      Color(0xFF0D47A1),
    ]),
    HeatmapPalette('purple', 'Purple', [
      Color(0xFFE1BEE7),
      Color(0xFFBA68C8),
      Color(0xFF8E24AA),
      Color(0xFF4A148C),
    ]),
  ];

  static const List<LanguageOption> languages = [
    LanguageOption('pt_BR', 'Português (Brasil)'),
    LanguageOption('en', 'English'),
  ];
}

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.system;
  String _accentId = 'satin_gold';
  String _heatmapId = 'satin_gold';
  String _languageId = 'pt_BR';
  double _fontScale = 1.0;
  double _iconScale = 1.0;

  static const double minScale = 0.8;
  static const double maxScale = 1.5;

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  double get iconScale => _iconScale;

  AccentOption get accent => AppOptions.accents.firstWhere(
        (a) => a.id == _accentId,
        orElse: () => AppOptions.accents.first,
      );

  HeatmapPalette get heatmap => AppOptions.heatmaps.firstWhere(
        (p) => p.id == _heatmapId,
        orElse: () => AppOptions.heatmaps.first,
      );

  LanguageOption get language => AppOptions.languages.firstWhere(
        (l) => l.id == _languageId,
        orElse: () => AppOptions.languages.first,
      );

  Future<void> load() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute(
        'CREATE TABLE IF NOT EXISTS app_settings (name TEXT PRIMARY KEY, value TEXT)',
      );
      final rows = await db.rawQuery('SELECT name, value FROM app_settings');
      final map = <String, String?>{
        for (final r in rows) r['name'] as String: r['value'] as String?,
      };
      _themeMode = _parseMode(map['theme_mode']);
      _accentId = map['accent'] ?? _accentId;
      _heatmapId = map['heatmap'] ?? _heatmapId;
      _languageId = map['language'] ?? _languageId;
      _fontScale = _parseScale(map['font_scale']);
      _iconScale = _parseScale(map['icon_scale']);
    } catch (e) {
      debugPrint('Erro ao carregar configurações (usando padrão): $e');
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _save('theme_mode', mode.name);
  }

  Future<void> setAccent(String id) async {
    _accentId = id;
    notifyListeners();
    await _save('accent', id);
  }

  Future<void> setHeatmap(String id) async {
    _heatmapId = id;
    notifyListeners();
    await _save('heatmap', id);
  }

  Future<void> setLanguage(String id) async {
    _languageId = id;
    notifyListeners();
    await _save('language', id);
  }

  /// `save: false` enquanto o slider está sendo arrastado (evita gravar no
  /// banco a cada passo); a gravação acontece no onChangeEnd.
  Future<void> setFontScale(double value, {bool save = true}) async {
    _fontScale = _clampScale(value);
    notifyListeners();
    if (save) await _save('font_scale', _fontScale.toStringAsFixed(2));
  }

  Future<void> setIconScale(double value, {bool save = true}) async {
    _iconScale = _clampScale(value);
    notifyListeners();
    if (save) await _save('icon_scale', _iconScale.toStringAsFixed(2));
  }

  Future<void> resetAccessibility() async {
    _fontScale = 1.0;
    _iconScale = 1.0;
    notifyListeners();
    await _save('font_scale', '1.00');
    await _save('icon_scale', '1.00');
  }

  double _clampScale(double v) => v.clamp(minScale, maxScale).toDouble();

  double _parseScale(String? value) {
    final v = double.tryParse(value ?? '');
    return v == null ? 1.0 : _clampScale(v);
  }

  ThemeMode _parseMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _save(String name, String value) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute(
        'CREATE TABLE IF NOT EXISTS app_settings (name TEXT PRIMARY KEY, value TEXT)',
      );
      await db.rawInsert(
        'INSERT OR REPLACE INTO app_settings (name, value) VALUES (?, ?)',
        [name, value],
      );
    } catch (e) {
      debugPrint('Erro ao salvar configuração $name: $e');
    }
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bgMain;
  final Color bgSecond;
  final Color textMain;
  final Color textSecond;
  final Color accent;
  final List<Color> heat;

  const AppColors({
    required this.bgMain,
    required this.bgSecond,
    required this.textMain,
    required this.textSecond,
    required this.accent,
    required this.heat,
  });

  factory AppColors.of({
    required Brightness brightness,
    required AccentOption accent,
    required HeatmapPalette heatmap,
  }) {
    final dark = brightness == Brightness.dark;
    return AppColors(
      bgMain: dark ? const Color(0xFF121212) : Colors.white,
      bgSecond: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      textMain: dark ? const Color(0xFFECECF1) : const Color(0xFF1A1A2E),
      textSecond: dark ? const Color(0xFFB0B0B8) : const Color(0xFF555555),
      accent: dark ? Color.lerp(accent.color, Colors.white, 0.18)! : accent.color,
      heat: [
        dark ? const Color(0xFF2D333B) : const Color(0xFFEBEDF0),
        ...heatmap.levels,
      ],
    );
  }

  static final AppColors fallback = AppColors.of(
    brightness: Brightness.light,
    accent: AppOptions.accents.first,
    heatmap: AppOptions.heatmaps.first,
  );

  @override
  AppColors copyWith({
    Color? bgMain,
    Color? bgSecond,
    Color? textMain,
    Color? textSecond,
    Color? accent,
    List<Color>? heat,
  }) {
    return AppColors(
      bgMain: bgMain ?? this.bgMain,
      bgSecond: bgSecond ?? this.bgSecond,
      textMain: textMain ?? this.textMain,
      textSecond: textSecond ?? this.textSecond,
      accent: accent ?? this.accent,
      heat: heat ?? this.heat,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.fallback;
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

class AppTheme {
  AppTheme._();

  static ThemeData build(AppSettings settings, Brightness brightness) {
    final c = AppColors.of(
      brightness: brightness,
      accent: settings.accent,
      heatmap: settings.heatmap,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: Colors.white,
      surface: c.bgSecond,
      onSurface: c.textMain,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgMain,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgMain,
        foregroundColor: c.textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: c.textSecond.withValues(alpha: 0.25),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgSecond,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NoTransitionsBuilder(),
          TargetPlatform.iOS: NoTransitionsBuilder(),
          TargetPlatform.macOS: NoTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionsBuilder(),
          TargetPlatform.fuchsia: NoTransitionsBuilder(),
        },
      ),
      iconTheme: IconThemeData(size: 24 * settings.iconScale),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(iconSize: 24 * settings.iconScale),
      ),
      extensions: <ThemeExtension<dynamic>>[
        c,
        AppMetrics(fontScale: settings.fontScale, iconScale: settings.iconScale),
      ],
    );
  }
}

@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  final double fontScale;
  final double iconScale;
  const AppMetrics({required this.fontScale, required this.iconScale});

  @override
  AppMetrics copyWith({double? fontScale, double? iconScale}) => AppMetrics(
        fontScale: fontScale ?? this.fontScale,
        iconScale: iconScale ?? this.iconScale,
      );

  @override
  AppMetrics lerp(ThemeExtension<AppMetrics>? other, double t) {
    if (other is! AppMetrics) return this;
    return AppMetrics(
      fontScale: fontScale + (other.fontScale - fontScale) * t,
      iconScale: iconScale + (other.iconScale - iconScale) * t,
    );
  }
}

extension AppMetricsContext on BuildContext {
  double icon(double base) =>
      base * (Theme.of(this).extension<AppMetrics>()?.iconScale ?? 1.0);
}