import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/sync/sync_auth.dart';
import '../data/sync/sync_discovery.dart';
import '../data/sync/sync_http_transport.dart';
import '../data/sync/sync_models.dart';
import '../data/sync/sync_service.dart';
import '../styles/app_theme.dart';

/// Settings > Sync: sincronização entre os seus aparelhos pela rede local.
///
/// A conta é só um ID secreto, sem e-mail. Um aparelho (normalmente o PC) vira
/// o "host" e guarda a cópia central; os outros entram com o ID.
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  SyncStatus? _status;
  List<String> _addresses = [];
  bool _busy = false;
  bool _showId = false;

  SyncService get _svc => SyncService.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await _svc.status();
    final addresses = _svc.role == SyncRole.host ? await _svc.hostAddresses() : <String>[];
    if (!mounted) return;
    setState(() {
      _status = status;
      _addresses = addresses;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    String? id;
    try {
      id = await _svc.createAccount();
    } catch (e) {
      if (mounted) _toast('Could not start this device as host: $e');
    }
    if (mounted) setState(() => _busy = false);
    await _refresh();
    if (id != null && mounted) await _showIdDialog(id);
  }

  Future<void> _showIdDialog(String id) async {
    final c = context.colors;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your sync account ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              formatAccountId(id),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: c.text),
            ),
            const SizedBox(height: 12),
            Text(
              'Type this ID on your other devices (Settings > Sync > Join). '
              'Anyone with it can read and change your synced data on this network, '
              'so keep it private.',
              style: TextStyle(fontSize: 12, color: c.mutedText),
            ),
            if (_addresses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('This device on the network: ${_addresses.join(', ')}',
                style: TextStyle(fontSize: 12, color: c.mutedText)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: formatAccountId(id))),
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _join() async {
    final joined = await showDialog<bool>(context: context, builder: (_) => const _JoinDialog());
    await _refresh();
    if (joined == true) await _syncNow(); // primeira sincronização logo em seguida
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    String message;
    try {
      final report = await _svc.syncNow();
      message = 'Sync finished: $report';
    } catch (e) {
      message = 'Sync failed: $e';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(message);
    await _refresh();
  }

  Future<void> _retryHost() async {
    setState(() => _busy = true);
    try {
      await _svc.restartHosting();
    } catch (e) {
      if (mounted) _toast('Still could not start the host: $e');
    }
    if (mounted) setState(() => _busy = false);
    await _refresh();
  }

  Future<void> _leave() async {
    final isHost = _svc.role == SyncRole.host;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this account?'),
        content: Text(
          isHost
              ? 'This device stops hosting and erases the central copy it was keeping. '
                  'Your own data stays on this device, but your other devices will have '
                  'nowhere to sync until you set up a host again.'
              : 'This device stops syncing. Your data stays here and the host keeps its copy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await _svc.leave();
    if (mounted) setState(() => _busy = false);
    await _refresh();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
        children: _svc.hasAccount ? _buildAccount(context) : _buildSetup(context),
      ),
    );
  }

  // ------------------------------------------------------------ sem conta

  List<Widget> _buildSetup(BuildContext context) {
    final c = context.colors;
    return [
      _card(
        context,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wifi_tethering, size: context.icon(28), color: c.mutedText),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Keep your devices in sync over your home Wi-Fi. No e-mail and no '
                'external server: one device keeps the central copy and the others '
                'sync with it. Your account is just a secret ID.',
                style: TextStyle(fontSize: 12, color: c.mutedText),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _actionCard(
        context,
        icon: Icons.computer_outlined,
        title: 'Create an account on this device',
        text: 'Choose this on the device that stays on your home network, usually the '
            'PC. It keeps the central copy. Keep the app open so the others can sync.',
        button: 'Create account',
        onPressed: _busy ? null : _create,
      ),
      const SizedBox(height: 12),
      _actionCard(
        context,
        icon: Icons.link,
        title: 'Join an existing account',
        text: 'Use this on your other devices. You will need the account ID and to be '
            'on the same Wi-Fi as the host.',
        button: 'Join with an ID',
        onPressed: _busy ? null : _join,
      ),
    ];
  }

  // ------------------------------------------------------------- com conta

  List<Widget> _buildAccount(BuildContext context) {
    final c = context.colors;
    final status = _status;
    final isHost = _svc.role == SyncRole.host;
    final failed = !_svc.isConfigured;

    final masked = formatAccountId(_svc.accountId ?? '').replaceAllMapped(RegExp(r'[A-Z0-9]'), (_) => '•');
    final accountText = _showId ? _svc.accountIdFormatted : masked;

    return [
      _card(
        context,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              failed ? Icons.error_outline : (isHost ? Icons.dns_outlined : Icons.cloud_done_outlined),
              size: context.icon(28),
              color: failed ? const Color(0xFFC62828) : c.accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failed
                        ? 'Not running'
                        : (isHost ? 'Hosting on this device' : 'Connected to ${_svc.hostAddress}'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    failed
                        ? 'The host could not start: ${_svc.hostError ?? 'unknown error'}. '
                            'If a firewall asked for permission, allow it and try again.'
                        : isHost
                            ? 'Your other devices sync with this one while the app is open'
                                '${_addresses.isEmpty ? '.' : ' (${_addresses.join(', ')}).'}'
                            : 'Syncing over your Wi-Fi. If the host changes address, it is found again automatically.',
                    style: TextStyle(fontSize: 12, color: c.mutedText),
                  ),
                  if (isHost && _svc.discoveryError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Automatic discovery is off on this device, so other devices must '
                      'type the address above.',
                      style: TextStyle(fontSize: 11, color: c.mutedText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      if (failed && isHost) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _retryHost,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account ID',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    accountText,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1, color: c.text),
                  ),
                ),
                IconButton(
                  tooltip: _showId ? 'Hide' : 'Show',
                  icon: Icon(_showId ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: context.icon(20), color: c.mutedText),
                  onPressed: () => setState(() => _showId = !_showId),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: Icon(Icons.copy_outlined, size: context.icon(20), color: c.mutedText),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _svc.accountIdFormatted));
                    _toast('ID copied');
                  },
                ),
              ],
            ),
            Text('Anyone with this ID can access your synced data on the network.',
              style: TextStyle(fontSize: 11, color: c.mutedText)),
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
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (_svc.isConfigured && !_busy) ? _syncNow : null,
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
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _busy ? null : _leave,
          child: const Text('Leave this account', style: TextStyle(color: Color(0xFFC62828))),
        ),
      ),
    ];
  }

  // ----------------------------------------------------------------- peças

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

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
    required String button,
    required VoidCallback? onPressed,
  }) {
    final c = context.colors;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.icon(22), color: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 12, color: c.mutedText)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(button),
            ),
          ),
        ],
      ),
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

// ---------------------------------------------------------------------------
// Entrar numa conta
// ---------------------------------------------------------------------------

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _idController = TextEditingController();
  final _hostController = TextEditingController();
  List<SyncHost> _found = [];
  bool _searching = false;
  bool _searched = false;
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  bool get _idValid => isValidAccountId(_idController.text);

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    final hosts = await SyncService.instance.findHosts(_idController.text);
    if (!mounted) return;
    setState(() {
      _found = hosts;
      _searching = false;
      _searched = true;
      if (hosts.length == 1) _hostController.text = hosts.first.toString();
    });
  }

  Future<void> _connect() async {
    final text = _hostController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Pick a host or type its address.');
      return;
    }
    final parts = text.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? (int.tryParse(parts[1]) ?? kSyncPort) : kSyncPort;

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await SyncService.instance.joinAccount(id: _idController.text, host: host, port: port);
      if (mounted) Navigator.pop(context, true);
    } on SyncAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not connect to $host: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Join an account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _idController,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Account ID', hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXXX'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: (_idValid && !_searching && !_connecting) ? _search : null,
              icon: _searching
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_find),
              label: Text(_searching ? 'Searching...' : 'Find on Wi-Fi'),
            ),
            if (_found.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final h in _found)
                    ChoiceChip(
                      label: Text(h.toString()),
                      selected: _hostController.text == h.toString(),
                      onSelected: (_) => setState(() => _hostController.text = h.toString()),
                    ),
                ],
              ),
            ] else if (_searched && !_searching) ...[
              const SizedBox(height: 8),
              Text(
                'No host found. Make sure the host app is open on the same Wi-Fi, '
                'or type its address below.',
                style: TextStyle(fontSize: 12, color: c.mutedText),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Host address', hintText: '192.168.0.12'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFC62828))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _connecting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (_idValid && !_connecting) ? _connect : null,
          child: Text(_connecting ? 'Connecting...' : 'Connect'),
        ),
      ],
    );
  }
}
