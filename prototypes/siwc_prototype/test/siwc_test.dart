// Path: prototypes/siwc_prototype/test/siwc_test.dart
// Runs the whole flow against a local mock of OpenAI's auth and API endpoints.
// The "browser" is an HTTP client that follows the authorize redirect to the app's loopback listener.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as pc;
import 'package:siwc_prototype/siwc.dart';

class MemoryStore implements CredentialStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List bigBytes(BigInt v) {
  final out = <int>[];
  while (v > BigInt.zero) {
    out.insert(0, (v & BigInt.from(255)).toInt());
    v >>= 8;
  }
  return Uint8List.fromList(out);
}

class MockOpenAI {
  late HttpServer server;
  late pc.RSAPrivateKey priv;
  late pc.RSAPublicKey pub;
  final authRequests = <Map<String, String>>[];
  final tokenRequests = <Map<String, String>>[];
  Map<String, dynamic>? lastResponsesBody;
  String? lastBearer;
  int expiresIn = 3600;
  String scope = 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct';
  String? forceState;
  bool tamperSignature = false;
  bool revoked = false;
  String get base => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    final rnd = pc.FortunaRandom()
      ..seed(pc.KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));
    final gen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), rnd));
    final pair = gen.generateKeyPair();
    priv = pair.privateKey;
    pub = pair.publicKey;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  String _idToken(String aud, String nonce) {
    final h = b64(utf8.encode(jsonEncode({'alg': 'RS256', 'kid': 'k1', 'typ': 'JWT'})));
    final p = b64(utf8.encode(jsonEncode({
      'iss': base, 'aud': aud, 'sub': 'user-123', 'email': 'tester@example.com', 'nonce': nonce,
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600,
    })));
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
      ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(priv));
    final sig = signer.generateSignature(Uint8List.fromList(ascii.encode('$h.$p'))).bytes;
    if (tamperSignature) sig[10] ^= 0xff;
    return '$h.$p.${b64(sig)}';
  }

  final _codes = <String, Map<String, String>>{};

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    void sendJson(Object o, [int status = 200]) {
      res.statusCode = status;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode(o));
    }

    switch (req.uri.path) {
      case '/.well-known/openid-configuration':
        sendJson({
          'authorization_endpoint': '$base/authorize', 'token_endpoint': '$base/token',
          'jwks_uri': '$base/jwks', 'revocation_endpoint': '$base/revoke',
        });
      case '/jwks':
        sendJson({'keys': [{'kid': 'k1', 'kty': 'RSA', 'alg': 'RS256', 'use': 'sig',
          'n': b64(bigBytes(pub.modulus!)), 'e': b64(bigBytes(pub.exponent!))}]});
      case '/authorize':
        final q = req.uri.queryParameters;
        authRequests.add(q);
        final code = 'code-${_codes.length}';
        _codes[code] = q;
        final issued = q['client_id'] == 'dynamic_agent_client' ? 'issued-client-1' : q['client_id']!;
        final back = Uri.parse(q['redirect_uri']!).replace(queryParameters: {
          'code': code, 'state': forceState ?? q['state']!, 'client_id': issued,
        });
        res.statusCode = 302;
        res.headers.set('Location', back.toString());
      case '/token':
        final f = Uri.splitQueryString(await utf8.decoder.bind(req).join());
        tokenRequests.add(f);
        if (f['grant_type'] == 'authorization_code') {
          final q = _codes[f['code']];
          final okPkce = q != null && b64(sha256.convert(ascii.encode(f['code_verifier']!)).bytes) == q['code_challenge'];
          if (!okPkce || f['redirect_uri'] != q['redirect_uri'] || f['client_id'] != 'issued-client-1') {
            sendJson({'error': 'invalid_grant'}, 400);
            break;
          }
          sendJson({'access_token': 'access-1', 'refresh_token': 'refresh-1', 'id_token': _idToken('issued-client-1', q['nonce']!),
            'token_type': 'Bearer', 'expires_in': expiresIn, 'scope': scope});
        } else if (f['grant_type'] == 'refresh_token' && f['refresh_token'] == 'refresh-1') {
          sendJson({'access_token': 'access-2', 'refresh_token': 'refresh-2', 'token_type': 'Bearer', 'expires_in': 3600, 'scope': scope});
        } else {
          sendJson({'error': 'invalid_grant'}, 400);
        }
      case '/revoke':
        revoked = true;
        sendJson({});
      case '/v1/models':
        lastBearer = req.headers.value('authorization');
        sendJson({'models': [
          {'slug': 'model-a', 'display_name': 'Model A', 'visibility': 'list'},
          {'slug': 'hidden', 'display_name': 'Hidden', 'visibility': 'hide'},
        ]});
      case '/v1/responses':
        lastBearer = req.headers.value('authorization');
        lastResponsesBody = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        res.headers.contentType = ContentType('text', 'event-stream');
        for (final e in [
          {'type': 'response.created'},
          {'type': 'response.output_text.delta', 'delta': 'Hel'},
          {'type': 'response.output_text.delta', 'delta': 'lo'},
          {'type': 'response.completed', 'response': {'output': [
            {'type': 'message', 'content': [{'type': 'output_text', 'text': 'Hello'}]}]}},
        ]) {
          res.write('event: ${e['type']}\ndata: ${jsonEncode(e)}\n\n');
        }
      default:
        res.statusCode = 404;
    }
    await res.close();
  }
}

void main() {
  late MockOpenAI mock;
  late MemoryStore store;
  late http.Client browser;

  SiwcClient client() => SiwcClient(
        store: store,
        discoveryUrl: Uri.parse('${mock.base}/.well-known/openid-configuration'),
        resource: '${mock.base}/v1',
        expectedIssuer: mock.base,
        callbackTimeout: const Duration(seconds: 10),
        // Stands in for Safari: follows the authorize redirect to the loopback listener.
        openBrowser: (u) async {
          browser.get(u).ignore();
          return true;
        },
      );

  setUpAll(() async {
    mock = MockOpenAI();
    await mock.start();
  });
  tearDownAll(() => mock.server.close(force: true));
  setUp(() {
    store = MemoryStore();
    browser = http.Client();
    mock
      ..forceState = null
      ..tamperSignature = false
      ..expiresIn = 3600
      ..revoked = false
      ..scope = 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct'
      ..authRequests.clear()
      ..tokenRequests.clear();
  });

  test('first sign-in registers dynamically, validates the ID token and stores the credential', () async {
    final c = client();
    final cred = await c.signIn();
    expect(cred.clientId, 'issued-client-1');
    expect(cred.email, 'tester@example.com');
    expect(c.canUsePlan, isTrue);
    final q = mock.authRequests.single;
    expect(q['client_id'], 'dynamic_agent_client');
    expect(q['redirect_uri'], matches(r'^http://127\.0\.0\.1:\d+/auth/callback$'));
    expect(q['code_challenge_method'], 'S256');
    expect(q['ext_agent_host_id'], matches(r'^urn:uuid:[0-9a-f-]{36}$'));
    expect(q['scope'], contains('chatgpt.tokens.use.direct'));
    expect(store.map['siwc_credential'], isNotNull);
  });

  test('second sign-in reuses the issued client ID and the same host ID', () async {
    final c = client();
    await c.signIn();
    await c.signIn();
    expect(mock.authRequests[1]['client_id'], 'issued-client-1');
    expect(mock.authRequests[1]['ext_agent_host_id'], mock.authRequests[0]['ext_agent_host_id']);
    expect(mock.authRequests[1]['id_token_hint'], isNotNull);
  });

  test('credential survives a restart; models and a streamed answer work', () async {
    await client().signIn();
    final c = client();
    await c.load();
    final models = await c.models();
    expect(models.map((m) => m.slug), ['model-a']);
    final deltas = <String>[];
    expect(await c.ask('model-a', 'hi', onDelta: deltas.add), 'Hello');
    expect(deltas.join(), 'Hello');
    expect(mock.lastBearer, 'Bearer access-1');
    expect(mock.lastResponsesBody!['store'], false);
    expect(mock.lastResponsesBody!['stream'], true);
  });

  test('an expiring access token is renewed and the new refresh token saved', () async {
    mock.expiresIn = 30;
    final c = client();
    await c.signIn();
    await c.models();
    expect(mock.lastBearer, 'Bearer access-2');
    expect(c.credential!.refreshToken, 'refresh-2');
  });

  test('a mismatched state is rejected', () async {
    mock.forceState = 'attacker';
    await expectLater(client().signIn(), throwsA(isA<SiwcException>().having((e) => e.code, 'code', 'state')));
    expect(store.map['siwc_credential'], isNull);
  });

  test('a forged ID token signature is rejected', () async {
    mock.tamperSignature = true;
    await expectLater(client().signIn(), throwsA(isA<SiwcException>().having((e) => e.code, 'code', 'invalid_token')));
  });

  test('sign-in without the plan scope is rejected', () async {
    mock.scope = 'openid profile email offline_access';
    await expectLater(client().signIn(), throwsA(isA<SiwcException>().having((e) => e.code, 'code', 'missing_plan_scope')));
  });

  test('sign-out revokes and clears the credential', () async {
    final c = client();
    await c.signIn();
    expect(await c.signOut(), isTrue);
    expect(mock.revoked, isTrue);
    expect(store.map['siwc_credential'], isNull);
  });

  test('the wait times out if the browser never returns', () async {
    final c = SiwcClient(
      store: store,
      discoveryUrl: Uri.parse('${mock.base}/.well-known/openid-configuration'),
      expectedIssuer: mock.base,
      callbackTimeout: const Duration(milliseconds: 300),
      openBrowser: (_) async => true,
    );
    await expectLater(c.signIn(), throwsA(isA<SiwcException>().having((e) => e.code, 'code', 'callback')));
  });
}
