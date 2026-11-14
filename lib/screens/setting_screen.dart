import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  final List<Map<String, dynamic>> _settings = const [
    {'id': 'general',       'icon': Icons.settings,      'title': 'settings.general',       'sub': 'settings.general.sub'},
    // {'id': 'reviewing',     'icon': Icons.rate_review,   'title': 'settings.reviewing',     'sub': 'settings.reviewing.sub'},
    {'id': 'sync',          'icon': Icons.sync,          'title': 'settings.sync',          'sub': 'settings.sync.sub'},
    // {'id': 'notifications', 'icon': Icons.notifications, 'title': 'settings.notifications', 'sub': 'settings.notifications.sub'},
    {'id': 'appearance',    'icon': Icons.palette,       'title': 'settings.appearance',    'sub': 'settings.appearance.sub'},
    // {'id': 'controls',      'icon': Icons.tune,          'title': 'settings.controls',      'sub': 'settings.controls.sub'},
    {'id': 'accessibility', 'icon': Icons.accessibility, 'title': 'settings.accessibility', 'sub': 'settings.accessibility.sub'},
    // {'id': 'advanced',      'icon': Icons.tune,          'title': 'settings.advanced',      'sub': 'settings.advanced.sub'},
    // {'id': 'about',         'icon': Icons.info_outline,  'title': 'settings.about',         'sub': 'settings.about.sub'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgMain,
      appBar: AppBar(
        backgroundColor: context.colors.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.tr('settings.title'), style: bigText(fontWeight: FontWeight.bold, color: context.colors.textMain),
        ),
      ),
      body: SafeArea(
          top: false,
          child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          const SizedBox(height: 16),

          Column(
            children: List.generate(_settings.length, (i) {
              final item = _settings[i];
              final isLast = i == _settings.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        item['icon'] as IconData,
                        size: context.icon(18),
                        color: context.colors.textMain,
                      ),
                    ),
                    title: Text(context.tr(item['title'] as String), style: mediumText(fontWeight: FontWeight.normal, color: context.colors.textMain,),),
                    subtitle: Text(
                      context.tr(item['sub'] as String), style: smallText(fontWeight: FontWeight.normal, color: context.colors.textSecond)),
                    trailing: Icon(Icons.chevron_right, color: context.colors.textSecond),
                    onTap: () {
                      if (item['id'] == 'general') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GeneralSettingsScreen()));
                      } else if (item['id'] == 'appearance') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()));
                      } else if (item['id'] == 'accessibility') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibilitySettingsScreen()));
                      } else if (item['id'] == 'sync') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncSettingsScreen()));
                      }
                    },
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 16, color: context.colors.bgSecond),
                ],
              );
            }),
          ),
        ],
      ),
        ),
    );
  }
}

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.colors.textMain),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('settings.general'),
              style: TextStyle(color: context.colors.textMain, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: SafeArea(
          top: false, 
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _sectionTitle(context, context.tr('general.language')),
              const SizedBox(height: 8),
              _languageTile(context, s),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textMain),
      ),
    );
  }

  Widget _languageTile(BuildContext context, AppSettings s) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.bgSecond, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.language, color: context.colors.textMain),
        title: Text(
          context.tr('general.appLanguage'),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textMain),
        ),
        subtitle: Text(s.language.name, style: TextStyle(fontSize: 12, color: context.colors.textSecond)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () => _pickLanguage(context, s),
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, AppSettings s) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final c = sheetContext.colors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  sheetContext.tr('general.appLanguage'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textMain),
                ),
              ),
              ...AppOptions.languages.map((l) => ListTile(
                    title: Text(l.name, style: TextStyle(color: context.colors.textMain)),
                    trailing: l.id == s.language.id ? Icon(Icons.check, color: c.accent) : null,
                    onTap: () {
                      s.setLanguage(l.id);
                      Navigator.pop(sheetContext);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.colors.textMain),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('settings.appearance'),
              style: TextStyle(color: context.colors.textMain, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: SafeArea(
          top: false, 
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _sectionTitle(context, context.tr('appearance.theme')),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(context.tr('appearance.system')),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(context.tr('appearance.light')),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(context.tr('appearance.dark')),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (selection) => s.setThemeMode(selection.first),
                ),
              ),
              const SizedBox(height: 28),

              _sectionTitle(context, context.tr('appearance.accent')),
              Text(
                context.tr('appearance.accentHint'),
                style: smallText(fontWeight: FontWeight.normal, color: context.colors.textSecond),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppOptions.accents.map((a) => _accentSwatch(context, s, a)).toList(),
              ),
              const SizedBox(height: 28),

              _sectionTitle(context, context.tr('appearance.heatmap')),
              const SizedBox(height: 8),
              ...AppOptions.heatmaps.map((p) => _heatmapOption(context, s, p)),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text, style: mediumText(fontWeight: FontWeight.normal, color: context.colors.textMain)),
    );
  }

  Widget _accentSwatch(BuildContext context, AppSettings s, AccentOption a) {
    final selected = s.accent.id == a.id;
    return GestureDetector(
      onTap: () => s.setAccent(a.id),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: a.color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? context.colors.textMain : Colors.transparent, width: 2.5),
        ),
        child: selected ? Icon(Icons.check, color: Colors.white, size: context.icon(20)) : null,
      ),
    );
  }

  Widget _heatmapOption(BuildContext context, AppSettings s, HeatmapPalette p) {
    final selected = s.heatmap.id == p.id;
    return GestureDetector(
      onTap: () => s.setHeatmap(p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.bgSecond,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? context.colors.accent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(p.name, style: smallText(fontWeight: FontWeight.normal, color: context.colors.textMain)),
            ),
            ...[context.colors.heat[0], ...p.levels].map(
              (color) => Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              Icon(Icons.check, size: context.icon(18), color: context.colors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.colors.textMain),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('settings.accessibility'),
              style: bigText(fontWeight: FontWeight.normal, color: context.colors.textMain),
            ),
          ),
          body: SafeArea(
          top: false, 
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _sectionTitle(context, context.tr('a11y.fontSize')),
              Text(context.tr('a11y.fontSizeHint'), style: smallText(fontWeight: FontWeight.normal, color: context.colors.textSecond)),
              const SizedBox(height: 8),
              _scaleSlider(
                context,
                value: s.fontScale,
                small: Text('A', style: smallText(fontWeight: FontWeight.normal, color: context.colors.textSecond)),
                large: Text('A', style: bigText(fontWeight: FontWeight.normal, color: context.colors.textSecond)),
                onChanged: (v) => s.setFontScale(v, save: false),
                onChangeEnd: (v) => s.setFontScale(v),
              ),
              _fontPreview(context, s),
              const SizedBox(height: 28),

              _sectionTitle(context, context.tr('a11y.iconSize')),
              Text(context.tr('a11y.iconSizeHint'), style: smallText(fontWeight: FontWeight.normal, color: context.colors.textSecond)),

              const SizedBox(height: 8),
              _scaleSlider(
                context,
                value: s.iconScale,
                small: Icon(Icons.circle, size: context.icon(10), color: context.colors.textSecond),
                large: Icon(Icons.circle, size: context.icon(22), color: context.colors.textSecond),
                onChanged: (v) => s.setIconScale(v, save: false),
                onChangeEnd: (v) => s.setIconScale(v),
              ),
              _iconPreview(context, s),
              const SizedBox(height: 28),

              OutlinedButton.icon(
                onPressed: s.resetAccessibility,
                icon: const Icon(Icons.restart_alt),
                label: Text(context.tr('a11y.reset')),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textMain),
      ),
    );
  }

  Widget _scaleSlider(
    BuildContext context, {
    required double value,
    required Widget small,
    required Widget large,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Row(
      children: [
        small,
        Expanded(
          child: Slider(
            value: value,
            min: AppSettings.minScale,
            max: AppSettings.maxScale,
            divisions: 7,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        large,
      ],
    );
  }

  Widget _fontPreview(BuildContext context, AppSettings s) {

    Widget row(String label, TextStyle base) {
      final pt = (base.fontSize! * s.fontScale).round();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(context.tr('a11y.sampleText', {'label': label}), style: base.copyWith(color: context.colors.textMain))),
            Text('$pt pt', style: TextStyle(fontSize: 12, color: context.colors.textSecond)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.colors.bgSecond, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          row(context.tr('a11y.large'), bigText(fontWeight: FontWeight.normal, color: context.colors.textMain)),
          row(context.tr('a11y.medium'), mediumText(fontWeight: FontWeight.normal, color: context.colors.textMain)),
          row(context.tr('a11y.small'), smallText(fontWeight: FontWeight.normal, color: context.colors.textMain)),
        ],
      ),
    );
  }

  Widget _iconPreview(BuildContext context, AppSettings s) {
    final c = context.colors;
    final px = (24 * s.iconScale).round();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.bgSecond, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.home_outlined, size: context.icon(24), color: context.colors.textMain),
              const SizedBox(width: 12),
              Icon(Icons.bar_chart_outlined, size: context.icon(24), color: context.colors.textMain),
              const SizedBox(width: 12),
              Icon(Icons.settings, size: context.icon(24), color: context.colors.textMain),
              const SizedBox(width: 12),
              Icon(Icons.edit_outlined, size: context.icon(24), color: context.colors.textMain),
            ],
          ),
          Text('$px px', style: TextStyle(fontSize: 12, color: context.colors.textSecond)),
        ],
      ),
    );
  }
}