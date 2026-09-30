import 'package:flutter/material.dart';

import '../styles/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  final List<Map<String, dynamic>> _settings = const [
    {'icon': Icons.settings,        'title': 'General',       'sub': 'Language • Studying • System-wide'},
    {'icon': Icons.rate_review,     'title': 'Reviewing',     'sub': 'Scheduling • Keep screen on'},
    {'icon': Icons.sync,            'title': 'Sync',          'sub': 'Account • Automatic synchronization'},
    {'icon': Icons.notifications,   'title': 'Notifications', 'sub': 'Notify when • Vibrate • Blink light'},
    {'icon': Icons.palette,         'title': 'Appearance',    'sub': 'Themes • Accent • Heatmap'},
    {'icon': Icons.tune,            'title': 'Controls',      'sub': 'Gestures • Keyboard • Bluetooth'},
    {'icon': Icons.accessibility,   'title': 'Accessibility', 'sub': 'Card zoom • Answer button size'},
    {'icon': Icons.tune,            'title': 'Advanced',      'sub': 'Workrounds • Plugins'},
    {'icon': Icons.info_outline,    'title': 'About',         'sub': ' '},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.colors.text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Barra de busca
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista de itens
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
                        size: 18,
                        color: context.colors.text,
                      ),
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text,
                      ),
                    ),
                    subtitle: Text(
                      item['sub'] as String,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                    onTap: () {
                      if (item['title'] == 'General') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GeneralSettingsScreen()),
                        );
                      } else if (item['title'] == 'Appearance') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AppearanceSettingsScreen()),
                        );
                      }
                    },
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 16, color: context.colors.border),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Settings > General: idioma (placeholder).
class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        final c = context.colors;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: c.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'General',
              style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _sectionTitle(context, 'Language'),
              const SizedBox(height: 8),
              _languageTile(context, s),
            ],
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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.text),
      ),
    );
  }

  Widget _languageTile(BuildContext context, AppSettings s) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.language, color: c.text),
        title: Text(
          'App language',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
        ),
        subtitle: Text(s.language.name, style: TextStyle(fontSize: 12, color: c.mutedText)),
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
                  'App language',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.text),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Placeholder: translations are not available yet. '
                  'Your choice is saved for when they are.',
                  style: TextStyle(fontSize: 12, color: c.mutedText),
                ),
              ),
              ...AppOptions.languages.map((l) => ListTile(
                    title: Text(l.name, style: TextStyle(color: c.text)),
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

/// Settings > Appearance: tema claro/escuro, cor de destaque e paleta do heatmap.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        final c = context.colors;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: c.text),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Appearance',
              style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _sectionTitle(context, 'Theme'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (selection) => s.setThemeMode(selection.first),
                ),
              ),
              const SizedBox(height: 28),

              _sectionTitle(context, 'Accent color'),
              Text(
                'Buttons, tabs and highlights',
                style: TextStyle(fontSize: 12, color: c.mutedText),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppOptions.accents.map((a) => _accentSwatch(context, s, a)).toList(),
              ),
              const SizedBox(height: 28),

              _sectionTitle(context, 'Heatmap colors'),
              const SizedBox(height: 8),
              ...AppOptions.heatmaps.map((p) => _heatmapOption(context, s, p)),
            ],
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
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.text),
      ),
    );
  }

  Widget _accentSwatch(BuildContext context, AppSettings s, AccentOption a) {
    final c = context.colors;
    final selected = s.accent.id == a.id;
    return GestureDetector(
      onTap: () => s.setAccent(a.id),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: a.color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? c.text : Colors.transparent, width: 2.5),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }

  Widget _heatmapOption(BuildContext context, AppSettings s, HeatmapPalette p) {
    final c = context.colors;
    final selected = s.heatmap.id == p.id;
    return GestureDetector(
      onTap: () => s.setHeatmap(p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.accent : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(p.name, style: TextStyle(fontSize: 14, color: c.text)),
            ),
            ...[c.heat[0], ...p.levels].map(
              (color) => Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 10),
              Icon(Icons.check, size: 18, color: c.accent),
            ],
          ],
        ),
      ),
    );
  }
}