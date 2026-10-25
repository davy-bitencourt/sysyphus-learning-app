import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const int kSyncPort = 47821;
const int kSyncClockToleranceMs = 10 * 60 * 1000;
const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int _idLength = 26; 

String generateAccountId() {
  final rnd = Random.secure();
  final chars = List.generate(_idLength, (_) => _alphabet[rnd.nextInt(_alphabet.length)]);
  return formatAccountId(chars.join());
}

String normalizeAccountId(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool isValidAccountId(String input) {
  final n = normalizeAccountId(input);
  return n.length == _idLength && n.split('').every(_alphabet.contains);
}

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
