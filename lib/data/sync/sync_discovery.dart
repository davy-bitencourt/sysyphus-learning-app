import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sync_auth.dart';

class SyncHost {
  final String address;
  final int port;
  const SyncHost(this.address, this.port);

  @override
  String toString() => '$address:$port';
}

/// Procura, na rede local, o aparelho que hospeda a conta [accountId].
/// Manda um broadcast UDP e escuta as respostas por [timeout]. Redes com
/// isolamento de clientes (Wi-Fi de visitantes, alguns roteadores) bloqueiam
/// isso: nesse caso, digite o endereço do host.
Future<List<SyncHost>> discoverSyncHosts(
  String accountId, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final hint = discoveryHint(accountId);
  final found = <String, SyncHost>{};
  RawDatagramSocket? socket;
  try {
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket = s;
    s.broadcastEnabled = true;

    final sub = s.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = s.receive();
      if (dg == null) return;
      final text = utf8.decode(dg.data, allowMalformed: true);
      final prefix = 'SYSY!1:$hint:';
      if (!text.startsWith(prefix)) return;
      final port = int.tryParse(text.substring(prefix.length));
      if (port == null) return;
      found['${dg.address.address}:$port'] = SyncHost(dg.address.address, port);
    });

    final payload = utf8.encode('SYSY?1:$hint');
    final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final i in interfaces) {
        for (final a in i.addresses) {
          final p = a.address.split('.');
          if (p.length == 4) targets.add(InternetAddress('${p[0]}.${p[1]}.${p[2]}.255')); // supõe máscara /24
        }
      }
    } catch (_) {
      // sem lista de interfaces: fica só o broadcast geral
    }

    // Duas rodadas: pacotes UDP podem se perder.
    for (final t in targets) {
      s.send(payload, t, kSyncPort);
    }
    await Future<void>.delayed(timeout ~/ 3);
    for (final t in targets) {
      s.send(payload, t, kSyncPort);
    }
    await Future<void>.delayed(timeout - timeout ~/ 3);
    await sub.cancel();
  } catch (_) {
    // sem rede ou sem permissão: devolve o que achou (nada)
  } finally {
    socket?.close();
  }
  return found.values.toList();
}
