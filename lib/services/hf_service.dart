import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'gguf_reader.dart';

/// User-tunable Hugging Face access settings (persisted).
class HfSettings {
  HfSettings({
    this.endpoint = defaultEndpoint,
    this.token = '',
    this.proxy = '',
    this.keepFiles = false,
  });

  static const defaultEndpoint = 'https://huggingface.co';

  String endpoint;
  String token;

  /// Optional HTTP proxy, e.g. `http://127.0.0.1:10808`.
  String proxy;

  /// Keep the downloaded GGUF on disk after it is installed into Ollama.
  bool keepFiles;

  String get normalizedEndpoint {
    var e = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    if (e.isEmpty) e = defaultEndpoint;
    if (!e.startsWith('http://') && !e.startsWith('https://')) e = 'https://$e';
    return e;
  }

  static Future<HfSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final env = Platform.environment['HF_ENDPOINT'];
    return HfSettings(
      endpoint: p.getString('hf_endpoint') ??
          (env != null && env.isNotEmpty ? env : defaultEndpoint),
      token: p.getString('hf_token') ?? '',
      proxy: p.getString('hf_proxy') ?? '',
      keepFiles: p.getBool('hf_keep_files') ?? false,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('hf_endpoint', endpoint.trim());
    await p.setString('hf_token', token.trim());
    await p.setString('hf_proxy', proxy.trim());
    await p.setBool('hf_keep_files', keepFiles);
  }
}

/// A parsed Hugging Face reference.
class HfRef {
  const HfRef({
    required this.repo,
    this.revision = 'main',
    this.filePath,
    this.quantHint,
  });

  /// `owner/name`
  final String repo;
  final String revision;

  /// Set when the link points at one specific file.
  final String? filePath;

  /// Set for `owner/repo:Q4_K_M` style references.
  final String? quantHint;

  /// Accepts full URLs (huggingface.co, hf.co, mirrors), `resolve`/`blob`
  /// file links, `owner/repo`, and `owner/repo:QUANT`.
  static HfRef? parse(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^ollama\s+(run|pull)\s+'), '');

    String path;
    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      path = uri.path;
    } else {
      // hf.co/owner/repo or bare owner/repo
      path = s.replaceFirst(
        RegExp(r'^(www\.)?(huggingface\.co|hf\.co|hf-mirror\.com)/'),
        '',
      );
      final q = path.indexOf('?');
      if (q >= 0) path = path.substring(0, q);
    }
    path = Uri.decodeFull(path).replaceAll(RegExp(r'^/+|/+$'), '');
    if (path.startsWith('models/')) path = path.substring(7);

    final parts = path.split('/');
    if (parts.length < 2) return null;
    final owner = parts[0];
    var name = parts[1];
    String? quant;
    if (parts.length == 2 && name.contains(':')) {
      final i = name.indexOf(':');
      quant = name.substring(i + 1);
      name = name.substring(0, i);
    }
    final idRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
    if (!idRe.hasMatch(owner) || !idRe.hasMatch(name)) return null;

    var revision = 'main';
    String? file;
    if (parts.length >= 4 &&
        (parts[2] == 'resolve' || parts[2] == 'blob' || parts[2] == 'tree')) {
      revision = parts[3];
      if (parts.length > 4 && parts[2] != 'tree') {
        file = parts.sublist(4).join('/');
      }
    }
    return HfRef(
      repo: '$owner/$name',
      revision: revision,
      filePath: file,
      quantHint: quant == null || quant.isEmpty ? null : quant,
    );
  }
}

class HfFile {
  const HfFile({required this.path, required this.size, this.sha256});

  final String path;
  final int size;

  /// LFS object id — the SHA-256 of the file contents.
  final String? sha256;

  String get name => path.split('/').last;

  bool get isSplit =>
      RegExp(r'-\d{5}-of-\d{5}\.gguf$', caseSensitive: false).hasMatch(path);

  bool get isProjector => name.toLowerCase().contains('mmproj');

  String? get quant {
    final base = name.replaceAll(RegExp(r'\.gguf$', caseSensitive: false), '');
    final m = RegExp(
      r'(?:^|[-._])((?:i?q\d+(?:_[a-z0-9]+)*)|f16|f32|bf16|fp16)$',
      caseSensitive: false,
    ).firstMatch(base);
    return m?.group(1)?.toUpperCase();
  }
}

class HfException implements Exception {
  HfException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class HfService {
  HfService._();

  static HttpClient createClient(HfSettings settings) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25)
      ..idleTimeout = const Duration(seconds: 30);
    final proxy = settings.proxy.trim();
    if (proxy.isNotEmpty) {
      final hostPort = proxy
          .replaceFirst(RegExp(r'^[a-zA-Z0-9]+://'), '')
          .replaceAll(RegExp(r'/+$'), '');
      client.findProxy = (_) => 'PROXY $hostPort';
    } else {
      client.findProxy = HttpClient.findProxyFromEnvironment;
    }
    return client;
  }

  static String fileUrl(HfSettings settings, HfRef ref, String path) {
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return '${settings.normalizedEndpoint}/${ref.repo}/resolve/'
        '${Uri.encodeComponent(ref.revision)}/$encoded?download=true';
  }

  /// Opens a GET that follows redirects manually so the auth header is only
  /// ever sent to the original host (CDN links are pre-signed).
  static Future<HttpClientResponse> open(
    HttpClient client,
    Uri uri, {
    String token = '',
    int? rangeStart,
    int? rangeEnd,
    void Function(HttpClientRequest request)? onRequest,
  }) async {
    final origin = uri.host;
    var current = uri;
    for (var hop = 0; hop < 8; hop++) {
      final req = await client.getUrl(current);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.userAgentHeader, 'MindGrid');
      if (token.isNotEmpty && current.host == origin) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (rangeStart != null) {
        req.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=$rangeStart-${rangeEnd ?? ''}',
        );
      }
      onRequest?.call(req);
      final res = await req.close();
      if (res.isRedirect ||
          (res.statusCode >= 301 && res.statusCode <= 308 &&
              res.headers.value(HttpHeaders.locationHeader) != null)) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        await res.drain<void>();
        if (loc == null) throw HfException('Redirect without location');
        current = current.resolve(loc);
        continue;
      }
      return res;
    }
    throw HfException('Too many redirects');
  }

  static String _httpError(int status) => switch (status) {
        401 => 'Unauthorized (401) — this repo needs a Hugging Face token.',
        403 => 'Access denied (403) — accept the model license on Hugging '
            'Face or check your token.',
        404 => 'Not found (404) — check the repository or file name.',
        429 => 'Rate limited (429) — try again shortly.',
        _ => 'HTTP $status',
      };

  /// Lists GGUF files in a repository.
  static Future<List<HfFile>> listGgufFiles(
    HfRef ref,
    HfSettings settings,
  ) async {
    final client = createClient(settings);
    try {
      final uri = Uri.parse(
        '${settings.normalizedEndpoint}/api/models/${ref.repo}/tree/'
        '${Uri.encodeComponent(ref.revision)}?recursive=true',
      );
      final res = await open(client, uri, token: settings.token.trim())
          .timeout(const Duration(seconds: 40));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw HfException(_httpError(res.statusCode),
            statusCode: res.statusCode);
      }
      final json = jsonDecode(body);
      if (json is! List) throw HfException('Unexpected response from Hub');
      final files = <HfFile>[];
      for (final e in json.whereType<Map>()) {
        final path = e['path']?.toString() ?? '';
        if (e['type'] != 'file' || !path.toLowerCase().endsWith('.gguf')) {
          continue;
        }
        final lfs = e['lfs'];
        final size = (lfs is Map ? lfs['size'] : null) ?? e['size'];
        files.add(
          HfFile(
            path: path,
            size: size is num ? size.toInt() : 0,
            sha256: lfs is Map ? lfs['oid']?.toString() : null,
          ),
        );
      }
      files.sort((a, b) => a.size.compareTo(b.size));
      return files;
    } on HfException {
      rethrow;
    } on TimeoutException {
      throw HfException('Connection timed out — check network, mirror or proxy.');
    } on SocketException catch (e) {
      throw HfException('Network error: ${e.message}');
    } on HandshakeException {
      throw HfException(
        'Secure connection failed — the Hub may be blocked on this network. '
        'Set a mirror endpoint or proxy.',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Downloads just enough of the file's start into [partPath] to parse the
  /// GGUF header, so the Modelfile can be configured before the full
  /// download. The bytes stay in the part file and are reused on resume.
  static Future<GgufMetadata> fetchHeader({
    required String url,
    required String partPath,
    required HfSettings settings,
    int totalSize = 0,
  }) async {
    final part = File(partPath);
    await part.parent.create(recursive: true);
    var want = 8 * 1024 * 1024;
    const maxHeader = 128 * 1024 * 1024;

    while (true) {
      final have = await part.exists() ? await part.length() : 0;
      if (have > 16) {
        try {
          return await GgufReader.read(partPath);
        } on GgufFormatException catch (e) {
          if (!e.truncated) rethrow;
        }
      }
      if (totalSize > 0 && have >= totalSize) {
        throw GgufFormatException('File is not a valid GGUF.');
      }
      if (have >= maxHeader) {
        throw GgufFormatException('GGUF header is unexpectedly large.');
      }
      while (want <= have) {
        want *= 2;
      }
      final end = totalSize > 0 && want > totalSize ? totalSize : want;

      final client = createClient(settings);
      try {
        final res = await open(
          client,
          Uri.parse(url),
          token: settings.token.trim(),
          rangeStart: have,
          rangeEnd: end - 1,
        ).timeout(const Duration(seconds: 40));
        if (res.statusCode == 200 && have > 0) {
          // Server ignored the range — start over.
          await res.drain<void>();
          await part.delete();
          continue;
        }
        if (res.statusCode != 206 && res.statusCode != 200) {
          await res.drain<void>();
          throw HfException(_httpError(res.statusCode),
              statusCode: res.statusCode);
        }
        final sink = part.openWrite(mode: FileMode.append);
        var written = 0;
        try {
          await for (final chunk in res.timeout(const Duration(seconds: 40))) {
            final room = (end - have) - written;
            if (room <= 0) break;
            if (chunk.length > room) {
              sink.add(chunk.sublist(0, room));
              written += room;
              break;
            }
            sink.add(chunk);
            written += chunk.length;
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (written == 0) throw HfException('No data received from Hub');
      } on TimeoutException {
        throw HfException('Connection timed out — check network, mirror or proxy.');
      } on SocketException catch (e) {
        throw HfException('Network error: ${e.message}');
      } on HandshakeException {
        throw HfException(
          'Secure connection failed — the Hub may be blocked on this network.',
        );
      } finally {
        client.close(force: true);
      }
    }
  }
}
