import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/services/local_http_client.dart';

void main() {
  group('shouldBypassProxy', () {
    test('bypasses loopback hosts', () {
      expect(shouldBypassProxy('127.0.0.1'), isTrue);
      expect(shouldBypassProxy('localhost'), isTrue);
      expect(shouldBypassProxy('::1'), isTrue);
    });

    test('bypasses private LAN hosts', () {
      expect(shouldBypassProxy('192.168.1.50'), isTrue);
      expect(shouldBypassProxy('10.0.0.5'), isTrue);
      expect(shouldBypassProxy('172.16.0.2'), isTrue);
    });

    test('does not bypass public hosts', () {
      expect(shouldBypassProxy('ollama.com'), isFalse);
      expect(shouldBypassProxy('8.8.8.8'), isFalse);
    });
  });
}
