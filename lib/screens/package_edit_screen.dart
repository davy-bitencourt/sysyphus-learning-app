import 'package:flutter/material.dart';
import 'package:Sysyphus/data/DAO/package_dao.dart';
import 'package:Sysyphus/data/DAO/session_dao.dart';

class PackageEditScreen extends StatefulWidget {
  final int? packageId;
  final String? initialTitle;
  final int? initialSessionId;

  const PackageEditScreen({
    super.key,
    this.packageId,
    this.initialTitle,
    this.initialSessionId,
  });

  @override
  State<PackageEditScreen> createState() => _PackageEditScreenState();
}

class _PackageEditScreenState extends State<PackageEditScreen> {
  final _titleController = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  int? _selectedSessionId;
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.packageId != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _selectedSessionId = widget.initialSessionId;
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    _sessions = await SessionDao().getAll();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dê um nome ao pacote antes de salvar.')));
      return;
    }

    setState(() => _saving = true);
    final dao = PackageDao();
    try {
      if (_isEditing) {
        await dao.update(widget.packageId!, _selectedSessionId, title);
      } else {
        await dao.insert(_selectedSessionId, title);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    setState(() => _saving = true);
    try {
      await PackageDao().delete(widget.packageId!);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Editar pacote' : 'Novo pacote',
          style: const TextStyle(color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Nome do pacote',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: _selectedSessionId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sem sessão vinculada')),
                    ..._sessions.map((s) => DropdownMenuItem(
                      value: s['id'] as int,
                      child: Text((s['title'] as String?) ?? 'Sessão ${s['id']}'),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedSessionId = v),
                  decoration: InputDecoration(
                    labelText: 'Sessão (opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_saving ? 'Salvando...' : 'Salvar pacote',
                      style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }
}
