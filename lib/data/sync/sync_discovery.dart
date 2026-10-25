import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'sync_auth.dart';

class SyncHost {
  final String address;
  final int port;
  const SyncHost(this.address, this.port);

  @override
  String toString() => '$address:$port';
}

/// Identificador usado na descoberta (UDP). Não revela o ID: só permite achar
/// o host que pertence à mesma conta.
String discoveryHint(String accountId) => sha256
    .convert(utf8.encode('disc:${normalizeAccountId(accountId)}'))
    .toString()
    .substring(0, 16);

String _requestOf(String hint) => 'SYSY?1:$hint';
String _replyPrefixOf(String hint) => 'SYSY!1:$hint:';

/// Endereços IPv4 desta máquina na rede (vazio se não for possível listar).
Future<List<String>> localIPv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [for (final i in interfaces) for (final a in i.addresses) a.address];
  } catch (_) {
    return const [];
  }
}

/// Lado do host: responde na porta UDP [kSyncPort] a quem procura esta conta,
/// informando a porta HTTP (lida na hora, pois só se sabe depois do bind).
/// Lança se não conseguir abrir o socket.
Future<RawDatagramSocket> startDiscoveryResponder(String accountId, int Function() httpPort) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kSyncPort, reuseAddress: true);
  final hint = discoveryHint(accountId);
  final request = _requestOf(hint);
  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final dg = socket.receive();
    if (dg == null) return;
    if (utf8.decode(dg.data, allowMalformed: true) == request) {
      socket.send(utf8.encode('${_replyPrefixOf(hint)}${httpPort()}'), dg.address, dg.port);
    }
  });
  return socket;
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
  final prefix = _replyPrefixOf(hint);
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
      if (!text.startsWith(prefix)) return;
      final port = int.tryParse(text.substring(prefix.length));
      if (port == null) return;
      found['${dg.address.address}:$port'] = SyncHost(dg.address.address, port);
    });

    final payload = utf8.encode(_requestOf(hint));
    final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
    for (final address in await localIPv4Addresses()) {
      final p = address.split('.');
      if (p.length == 4) targets.add(InternetAddress('${p[0]}.${p[1]}.${p[2]}.255')); // supõe máscara /24
    }

    // Duas rodadas: pacotes UDP podem se perder.
    void broadcast() {
      for (final t in targets) {
        s.send(payload, t, kSyncPort);
      }
    }

    broadcast();
    await Future<void>.delayed(timeout ~/ 3);
    broadcast();
    await Future<void>.delayed(timeout - timeout ~/ 3);
    await sub.cancel();
  } catch (_) {
    // sem rede ou sem permissão: devolve o que achou (nada)
  } finally {
    socket?.close();
  }
  return found.values.toList();
}
