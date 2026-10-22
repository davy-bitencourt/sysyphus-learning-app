import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Porta do servidor de sincronização (HTTP/TCP) e da descoberta na rede (UDP).
const int kSyncPort = 47821;

/// Diferença máxima de relógio aceita entre aparelhos (também limita replays).
const int kSyncClockToleranceMs = 10 * 60 * 1000;

// Sem I, O, 0 e 1: o ID pode ser digitado à mão sem confundir caracteres.
const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int _idLength = 26; // 26 x 5 bits = 130 bits

/// A conta é só um ID secreto aleatório (sem e-mail, sem dados pessoais).
/// Quem tem o ID acessa a conta: trate-o como uma senha.
String generateAccountId() {
  final rnd = Random.secure();
  final chars = List.generate(_idLength, (_) => _alphabet[rnd.nextInt(_alphabet.length)]);
  return formatAccountId(chars.join());
}

/// Forma canônica: maiúsculas, sem traços, espaços ou outros símbolos.
String normalizeAccountId(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool isValidAccountId(String input) {
  final n = normalizeAccountId(input);
  return n.length == _idLength && n.split('').every(_alphabet.contains);
}

/// XXXXX-XXXXX-XXXXX-XXXXX-XXXXXX
String formatAccountId(String input) {
  final n = normalizeAccountId(input);
  final parts = <String>[];
  var i = 0;
  for (final size in const [5, 5, 5, 5, 6]) {
    if (i >= n.length) break;
    final end = min(i + size, n.length);
    parts.add(n.substring(i, end));
    i = end;
  }
  return parts.join('-');
}

/// Assinatura HMAC-SHA256 de uma requisição. A chave é o próprio ID, que nunca
/// trafega: quem escuta a rede vê só a assinatura. Cobre método, caminho,
/// horário e o hash do corpo (adulterar qualquer um invalida a assinatura).
String signRequest(String accountId, String method, String path, int timeMs, List<int> body) {
  final key = utf8.encode(normalizeAccountId(accountId));
  final bodyHash = sha256.convert(body).toString();
  final message = utf8.encode('${method.toUpperCase()}\n$path\n$timeMs\n$bodyHash');
  return Hmac(sha256, key).convert(message).toString();
}

bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Identificador usado na descoberta (UDP). Não revela o ID: só permite achar
/// o host que pertence à mesma conta.
String discoveryHint(String accountId) => sha256
    .convert(utf8.encode('disc:${normalizeAccountId(accountId)}'))
    .toString()
    .substring(0, 16);
