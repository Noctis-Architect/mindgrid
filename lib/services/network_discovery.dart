import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'local_http_client.dart';
import 'ollama_runtime.dart';

class NetworkDiscoveryService {
  static const ollamaPort = 11434;
  static const _cacheTtl = Duration(minutes: 5);

  List<String>? _cachedHosts;
  DateTime? _cacheTime;

  Future<List<String>> discoverOllamaBases({
    String? primaryUrl,
    Duration timeout = const Duration(milliseconds: 800),
    int maxConcurrent = 48,
  }) async {
    final bases = <String>{};
    void add(String? url) {
      if (url == null || url.trim().isEmpty) return;
      bases.add(OllamaRuntime.normalizeOllamaBase(url.trim()));
    }

    add(primaryUrl);
    add('http://127.0.0.1:$ollamaPort');

    // Fast path: if localhost responds, skip full subnet scan.
    final local = await findFirstReachableBase(
      ['http://127.0.0.1:$ollamaPort'],
      timeout: const Duration(milliseconds: 1500),
    );
    if (local != null) {
      add(local);
      return bases.toList();
    }

    final hosts = await _collectSubnetHosts();
    final found = await _scanHosts(
      hosts,
      timeout: timeout,
      maxConcurrent: maxConcurrent,
    );
    for (final host in found) {
      add('http://$host:$ollamaPort');
    }

    return bases.toList();
  }

  Future<List<String>> _collectSubnetHosts() async {
    final now = DateTime.now();
    if (_cachedHosts != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl) {
      return _cachedHosts!;
    }

    final hosts = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;

          // Priority: gateway (.1), self, neighbors, then limited sweep.
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          final self = int.tryParse(parts[3]) ?? 0;
          hosts.add('$prefix.1');
          hosts.add(addr.address);
          if (self > 1) hosts.add('$prefix.${self - 1}');
          if (self < 254) hosts.add('$prefix.${self + 1}');
          for (var i = 2; i <= 20; i++) {
            hosts.add('$prefix.$i');
          }
          for (var i = 230; i <= 254; i++) {
            hosts.add('$prefix.$i');
          }
        }
      }
    } catch (_) {}

    final list = hosts.toList();
    _cachedHosts = list;
    _cacheTime = now;
    return list;
  }

  Future<List<String>> _scanHosts(
    List<String> hosts, {
    required Duration timeout,
    required int maxConcurrent,
  }) async {
    if (hosts.isEmpty) return [];

    final found = <String>[];
    for (var i = 0; i < hosts.length; i += maxConcurrent) {
      final batch = hosts.skip(i).take(maxConcurrent).toList();
      final results = await Future.wait(batch.map((host) async {
        final client = createLocalHttpClient(host: host);
        try {
          final uri = Uri.parse('http://$host:$ollamaPort/api/tags');
          final response = await client
              .get(uri, headers: {'Accept': 'application/json'})
              .timeout(timeout);
          if (response.statusCode == 200) return host;
        } catch (_) {
        } finally {
          client.close();
        }
        return null;
      }));
      found.addAll(results.whereType<String>());
    }
    return found;
  }

  Future<String?> findFirstReachableBase(
    List<String> bases, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    for (final base in bases) {
      try {
        final client = createClientForBase(base);
        try {
          final uri = Uri.parse('$base/api/tags');
          final response = await client
              .get(uri, headers: headers ?? {'Accept': 'application/json'})
              .timeout(timeout);
          if (response.statusCode == 200) return base;
        } finally {
          client.close();
        }
      } catch (_) {}
    }
    return null;
  }
}
