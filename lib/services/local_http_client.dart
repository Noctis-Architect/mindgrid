import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP clients that reach localhost and LAN hosts directly.
///
/// Dart's [HttpClient] follows [Platform.environment] proxy variables but does
/// not reliably honour `no_proxy` for loopback addresses. On systems with a
/// local proxy (e.g. VPN/clash on 127.0.0.1:10808), Ollama requests fail with
/// HTTP 503 unless we bypass the proxy for local targets.
http.Client createLocalHttpClient({String? host}) {
  return IOClient(_createUnderlyingClient(host: host));
}

http.Client createClientForBase(String baseUrl) {
  try {
    return createLocalHttpClient(host: Uri.parse(baseUrl).host);
  } catch (_) {
    return createLocalHttpClient();
  }
}

HttpClient _createUnderlyingClient({String? host}) {
  final client = HttpClient();
  client.findProxy = (uri) => _findProxy(uri, preferredHost: host);
  return client;
}

String _findProxy(Uri uri, {String? preferredHost}) {
  if (shouldBypassProxy(uri.host)) return 'DIRECT';
  if (preferredHost != null &&
      preferredHost.isNotEmpty &&
      shouldBypassProxy(preferredHost)) {
    return 'DIRECT';
  }
  return HttpClient.findProxyFromEnvironment(uri);
}

bool shouldBypassProxy(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1') {
    return true;
  }
  if (_isPrivateOrLoopbackIp(normalized)) return true;
  return _matchesNoProxy(normalized);
}

bool _isPrivateOrLoopbackIp(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
  final a = octets[0]!;
  final b = octets[1]!;
  if (a == 127) return true;
  if (a == 10) return true;
  if (a == 192 && b == 168) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}

bool _matchesNoProxy(String host) {
  final raw = Platform.environment['no_proxy'] ??
      Platform.environment['NO_PROXY'] ??
      '';
  if (raw.trim().isEmpty) return false;
  for (final entry in raw.split(',')) {
    if (_hostMatchesNoProxyEntry(host, entry.trim())) return true;
  }
  return false;
}

bool _hostMatchesNoProxyEntry(String host, String entry) {
  if (entry.isEmpty) return false;
  final normalizedEntry = entry.toLowerCase();
  if (normalizedEntry == '*') return true;

  if (normalizedEntry.contains('/')) {
    return _hostMatchesCidr(host, normalizedEntry);
  }

  if (normalizedEntry.startsWith('.')) {
    final suffix = normalizedEntry.substring(1);
    return host == suffix || host.endsWith(normalizedEntry);
  }

  return host == normalizedEntry;
}

bool _hostMatchesCidr(String host, String cidr) {
  // Common no_proxy CIDRs — enough for typical dev setups.
  if (cidr == '127.0.0.0/8') return host.startsWith('127.');
  if (cidr == '10.0.0.0/8') return host.startsWith('10.');
  if (cidr == '192.168.0.0/16') return host.startsWith('192.168.');
  if (cidr == '172.16.0.0/12') {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    return a == 172 && b != null && b >= 16 && b <= 31;
  }
  return false;
}
