import 'package:shared_preferences/shared_preferences.dart';

/// Guarda a ordem manual (lista de ids) de pacotes e templates.
class OrderService {
  static const packagesKey = 'order.packages';
  static const templatesKey = 'order.templates';

  static Future<void> save(String key, List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.map((e) => e.toString()).toList());
  }

  /// Ordena [items] pela ordem salva. Itens sem posição salva (novos)
  /// vão para o fim, mantendo a ordem original entre si.
  static Future<List<T>> apply<T>(
      String key, List<T> items, int? Function(T) idOf) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key)?.map(int.parse).toList() ?? const <int>[];
    if (saved.isEmpty) return items;

    final rank = {for (var i = 0; i < saved.length; i++) saved[i]: i};
    final order = List<int>.generate(items.length, (i) => i)
      ..sort((a, b) {
        final ra = rank[idOf(items[a])] ?? saved.length;
        final rb = rank[idOf(items[b])] ?? saved.length;
        return ra != rb ? ra.compareTo(rb) : a.compareTo(b); // desempate estável
      });
    return [for (final i in order) items[i]];
  }
}
