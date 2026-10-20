import 'package:flutter/material.dart';

import '../data/models/sync_models.dart';
import '../data/services/sync_service.dart';
import '../styles/app_theme.dart';

/// Settings > Sync: estado da sincronização entre aparelhos.
///
/// O motor já está pronto, mas só sincroniza quando houver um servidor e uma
/// conta (um SyncTransport atribuído em SyncService.instance.transport).
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  SyncStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await SyncService.instance.status();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    try {
      if (value) {
        await SyncService.instance.enable();
      } else {
        await SyncService.instance.disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refresh();
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    String message;
    try {
      final report = await SyncService.instance.syncNow();
      message = 'Sync finished: $report';
    } catch (e) {
      message = 'Sync failed: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _refresh();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final configured = SyncService.instance.isConfigured;
    final status = _status;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Sync',
          style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            context,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  configured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  size: context.icon(28),
                  color: configured ? c.accent : c.mutedText,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(configured ? 'Connected' : 'Not connected',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
                      const SizedBox(height: 4),
                      Text(
                        configured
                            ? 'Your packages, questions, templates, sessions, tags, study '
                                'progress and media sync between your devices.'
                            : 'No sync server is set up in this build yet. The sync engine is '
                                'ready: once a server and an account are connected, your content '
                                'and study progress will sync between your devices. Until then '
                                'the app works fully offline.',
                        style: TextStyle(fontSize: 12, color: c.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This device',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
                const SizedBox(height: 10),
                _row(context, 'Device ID', status?.deviceId ?? '...'),
                _row(context, 'Pending changes', '${status?.pendingChanges ?? 0}'),
                _row(context, 'Last sync',
                  status?.lastSync == null ? 'Never' : _formatDate(status!.lastSync!)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            context,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Sync this device',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
              subtitle: Text(
                configured
                    ? 'Turning it off clears the queue of pending changes.'
                    : 'Available once a server is connected.',
                style: TextStyle(fontSize: 12, color: c.mutedText),
              ),
              value: status?.enabled ?? false,
              onChanged: (configured && !_busy && status != null) ? _toggle : null,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (configured && !_busy && (status?.enabled ?? false)) ? _syncNow : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.sync, size: context.icon(20)),
              label: Text(_busy ? 'Working...' : 'Sync now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.mutedText)),
          ),
          Expanded(
            child: Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
          ),
        ],
      ),
    );
  }
}
