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
    AccentOption('blue', 'Blue', Color(0xFF1565C0)),
    AccentOption('green', 'Green', Color(0xFF2E7D32)),
    AccentOption('purple', 'Purple', Color(0xFF6A1B9A)),
    AccentOption('teal', 'Teal', Color(0xFF00695C)),
    AccentOption('pink', 'Pink', Color(0xFFC2185B)),
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

  /// PLACEHOLDER
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

  /// Limites das escalas de acessibilidade (80% a 150%).
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

  /// Chame no main(), depois de inicializar o banco e antes do runApp.
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
  final Color bg;         // fundo de telas e barras
  final Color surface;    // cartões e caixas sobre o fundo
  final Color surfaceAlt; // itens de lista, campos de busca
  final Color border;
  final Color text;
  final Color mutedText;
  final Color note;       // caixa de comentário extra
  final Color accent;     // botões, abas, ícones de destaque
  final Color onAccent;   // texto/ícone sobre o accent
  final List<Color> heat; // 5 níveis do heatmap (0 = sem atividade)

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.note,
    required this.accent,
    required this.onAccent,
    required this.heat,
  });

  factory AppColors.of({
    required Brightness brightness,
    required AccentOption accent,
    required HeatmapPalette heatmap,
  }) {
    final dark = brightness == Brightness.dark;
    final accentColor =
        dark ? Color.lerp(accent.color, Colors.white, 0.18)! : accent.color;
    return AppColors(
      bg: dark ? const Color(0xFF121212) : Colors.white,
      surface: dark ? const Color(0xFF1E1E1E) : Colors.white,
      surfaceAlt: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
      border: dark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
      text: dark ? const Color(0xFFECECF1) : const Color(0xFF1A1A2E),
      mutedText: dark ? const Color(0xFFB0B0B8) : const Color(0xFF555555),
      note: dark ? const Color(0xFF3B3320) : const Color(0xFFFFF8E1),
      accent: accentColor,
      onAccent: Colors.white,
      heat: [
        dark ? const Color(0xFF2D333B) : const Color(0xFFEBEDF0),
        ...heatmap.levels,
      ],
    );
  }

  /// Usado quando o tema do app ainda não foi ligado ao AppSettings:
  /// o visual fica igual ao padrão (Satin Gold).
  static final AppColors fallback = AppColors.of(
    brightness: Brightness.light,
    accent: AppOptions.accents.first,
    heatmap: AppOptions.heatmaps.first,
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? text,
    Color? mutedText,
    Color? note,
    Color? accent,
    Color? onAccent,
    List<Color>? heat,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      note: note ?? this.note,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
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
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: c.border),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      // Ícones sem tamanho explícito seguem a escala de ícones.
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
  /// Tamanho de ícone já com a escala de acessibilidade: `context.icon(18)`.
  double icon(double base) =>
      base * (Theme.of(this).extension<AppMetrics>()?.iconScale ?? 1.0);
}
