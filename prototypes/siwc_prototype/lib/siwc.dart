// Path: prototypes/siwc_prototype/lib/siwc.dart
// Sign in with ChatGPT (open-source public-client flow) in pure Dart:
// dynamic client registration, PKCE, 127.0.0.1 loopback callback, ID-token validation,
// refresh, revocation, model list and a streaming Responses request.
// Ported from the Swift reference in SearchingFool/Safari-ai-agent
// (app/browser-host/Sources/ChatGPTSIWC.swift and ChatGPTResponses.swift).
// No Flutter imports here, so it can be tested with `flutter test` against a mock server.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as pc;

const _dynamicClient = 'dynamic_agent_client';
const _requestedScopes = [
  'openid', 'profile', 'email', 'offline_access', 'resource.invoke', 'chatgpt.tokens.use.direct',
];
const _requiredScopes = {'openid', 'offline_access', 'resource.invoke', 'chatgpt.tokens.use.direct'};
const _credentialKey = 'siwc_credential';
const _hostIdKey = 'siwc_host_id';

/// Where secrets are kept. The app backs this with the platform keychain.
abstract class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SiwcException implements Exception {
  SiwcException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'SiwcException($code): $message';
}

class SiwcCredential {
  SiwcCredential({
    required this.subject,
    required this.email,
    required this.clientId,
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
    required this.scopes,
    required this.accessExpiresAt,
  });

  final String subject;
  final String? email;
  final String clientId;
  final String idToken;
  final String accessToken;
  final String refreshToken;
  final Set<String> scopes;
  final DateTime accessExpiresAt;

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'email': email,
        'clientId': clientId,
        'idToken': idToken,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'scopes': scopes.toList(),
        'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
      };

  static SiwcCredential fromJson(Map<String, dynamic> j) => SiwcCredential(
        subject: j['subject'] as String,
        email: j['email'] as String?,
        clientId: j['clientId'] as String,
        idToken: j['idToken'] as String,
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        scopes: (j['scopes'] as List).cast<String>().toSet(),
        accessExpiresAt: DateTime.parse(j['accessExpiresAt'] as String),
      );
}

class SiwcModel {
  SiwcModel(this.slug, this.displayName);
  final String slug;
  final String displayName;
}

class SiwcClient {
  SiwcClient({
    required this.store,
    required this.openBrowser,
    http.Client? httpClient,
    Uri? discoveryUrl,
    this.resource = 'https://api.openai.com/v1',
    this.expectedIssuer = 'https://auth.openai.com',
    this.agentName = 'LearningCape',
    this.callbackTimeout = const Duration(minutes: 5),
    this.onLog,
    this.onWaitingForCallback,
  })  : _http = httpClient ?? http.Client(),
        discoveryUrl = discoveryUrl ?? Uri.parse('https://auth.openai.com/.well-known/openid-configuration');

  final CredentialStore store;

  /// Opens the system browser. Must return false if it could not be opened.
  final Future<bool> Function(Uri url) openBrowser;
  final http.Client _http;
  final Uri discoveryUrl;
  final String resource;
  final String expectedIssuer;
  final String agentName;
  final Duration callbackTimeout;

  /// Diagnostic log. Never receives tokens or codes.
  final void Function(String line)? onLog;

  /// Called with true just before the browser opens and false when the wait ends.
  /// The iOS app uses it to hold a background task while the user is in Safari.
  final Future<void> Function(bool waiting)? onWaitingForCallback;

  SiwcCredential? _credential;
  SiwcCredential? get credential => _credential;
  bool get canUsePlan => _credential?.scopes.containsAll(_requiredScopes) ?? false;

  void _log(String s) => onLog?.call(s);

  Future<void> load() async {
    final raw = await store.read(_credentialKey);
    if (raw == null) return;
    try {
      _credential = SiwcCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await store.delete(_credentialKey);
    }
  }

  // ---- sign in ------------------------------------------------------------

  Future<SiwcCredential> signIn() async {
    final config = await _discover();
    final state = _randomUrlSafe(32);
    final nonce = _randomUrlSafe(32);
    final verifier = _randomUrlSafe(64);
    final challenge = _b64url(sha256.convert(ascii.encode(verifier)).bytes);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/auth/callback';
    _log('Loopback listener ready on port ${server.port}');
    final existing = _credential;
    final registeredClient = existing?.clientId ?? _dynamicClient;

    final authUrl = Uri.parse(config['authorization_endpoint'] as String).replace(queryParameters: {
      'client_id': registeredClient,
      'agent_name_hint': agentName,
      'ext_agent_host_id': await _stableHostId(),
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'scope': _requestedScopes.join(' '),
      'resource': resource,
      'state': state,
      'nonce': nonce,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      if (existing != null) 'id_token_hint': existing.idToken,
      if (existing?.email != null) 'login_hint': existing!.email!,
    });

    Map<String, String> callback;
    final waitStarted = DateTime.now();
    try {
      await onWaitingForCallback?.call(true);
      final pending = _waitForCallback(server);
      if (!await openBrowser(authUrl)) {
        throw SiwcException('callback', 'Could not open the browser for sign-in.');
      }
      _log('Browser opened; waiting for the callback');
      callback = await pending.timeout(callbackTimeout,
          onTimeout: () => throw SiwcException('callback', 'Sign-in did not return within the time limit.'));
      _log('Callback received after ${DateTime.now().difference(waitStarted).inSeconds}s');
    } finally {
      await server.close(force: true);
      await onWaitingForCallback?.call(false);
    }

    if (callback['state'] != state) throw SiwcException('state', 'The sign-in state did not match this attempt.');
    if (callback['error'] != null) {
      throw SiwcException('denied', callback['error_description'] ?? callback['error']!);
    }
    final code = callback['code'];
    if (code == null || code.isEmpty) throw SiwcException('client_registration', 'No authorization code was returned.');
    final clientId = _resolveIssuedClientId(callback['client_id'], registeredClient);

    final token = await _tokenRequest(Uri.parse(config['token_endpoint'] as String), {
      'grant_type': 'authorization_code',
      'client_id': clientId,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirectUri,
      'resource': resource,
    });
    final granted = (token['scope'] as String? ?? '').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    if (!granted.containsAll(_requiredScopes)) {
      throw SiwcException('missing_plan_scope', 'The account did not grant plan-based Responses access.');
    }
    final idToken = token['id_token'] as String?;
    if (idToken == null) throw SiwcException('invalid_token', 'No ID token was returned.');
    final identity = await _validateIdToken(idToken, clientId, nonce, Uri.parse(config['jwks_uri'] as String));
    if (existing != null && existing.subject != identity.$1) {
      throw SiwcException('account_changed', 'A different account is saved. Sign out first.');
    }
    final refresh = token['refresh_token'] as String?;
    if (refresh == null || refresh.isEmpty) throw SiwcException('token_exchange', 'No refresh token was returned.');

    final saved = SiwcCredential(
      subject: identity.$1,
      email: identity.$2,
      clientId: clientId,
      idToken: idToken,
      accessToken: token['access_token'] as String,
      refreshToken: refresh,
      scopes: granted,
      accessExpiresAt: DateTime.now().add(Duration(seconds: (token['expires_in'] as num).round())),
    );
    await store.write(_credentialKey, jsonEncode(saved.toJson()));
    _credential = saved;
    _log('Signed in; plan scope granted');
    return saved;
  }

  Future<Map<String, String>> _waitForCallback(HttpServer server) async {
    await for (final req in server) {
      final res = req.response
        ..headers.contentType = ContentType.text
        ..headers.set('Cache-Control', 'no-store');
      final fromLoopback = req.connectionInfo?.remoteAddress.isLoopback ?? false;
      final hostOk = req.headers.value('host') == '127.0.0.1:${server.port}';
      if (!fromLoopback || !hostOk || req.method != 'GET') {
        res.statusCode = 400;
        res.write('Invalid sign-in response.');
        await res.close();
        continue;
      }
      if (req.uri.path != '/auth/callback') {
        res.statusCode = 404;
        res.write('Unknown callback path.');
        await res.close();
        continue;
      }
      res.statusCode = 200;
      res.write('Sign-in returned to $agentName. You can close this page and return to the app.');
      await res.close();
      return req.uri.queryParameters;
    }
    throw SiwcException('callback', 'The loopback listener closed before the callback arrived.');
  }

  String _resolveIssuedClientId(String? fromCallback, String registered) {
    if (registered == _dynamicClient) {
      if (fromCallback == null || fromCallback.isEmpty || fromCallback == _dynamicClient) {
        throw SiwcException('client_registration', 'OpenAI did not return an issued client ID.');
      }
      return fromCallback;
    }
    if (fromCallback != null && fromCallback.isNotEmpty && fromCallback != registered) {
      throw SiwcException('client_registration', 'The callback named a different client ID.');
    }
    return registered;
  }

  // ---- tokens -------------------------------------------------------------

  Future<String> validAccessToken() async {
    final current = _credential;
    if (current == null || !current.scopes.containsAll(_requiredScopes)) {
      throw SiwcException('missing_plan_scope', 'Not signed in with plan access.');
    }
    if (current.accessExpiresAt.difference(DateTime.now()) > const Duration(minutes: 2)) {
      return current.accessToken;
    }
    final config = await _discover();
    final token = await _tokenRequest(Uri.parse(config['token_endpoint'] as String), {
      'grant_type': 'refresh_token',
      'client_id': current.clientId,
      'refresh_token': current.refreshToken,
      'resource': resource,
    });
    final granted = (token['scope'] as String? ?? '').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    final refresh = token['refresh_token'] as String?;
    if (!granted.containsAll(_requiredScopes) || refresh == null || refresh.isEmpty) {
      throw SiwcException('missing_plan_scope', 'Renewal did not keep plan access. Sign in again.');
    }
    final renewed = SiwcCredential(
      subject: current.subject,
      email: current.email,
      clientId: current.clientId,
      idToken: current.idToken,
      accessToken: token['access_token'] as String,
      refreshToken: refresh,
      scopes: granted,
      accessExpiresAt: DateTime.now().add(Duration(seconds: (token['expires_in'] as num).round())),
    );
    await store.write(_credentialKey, jsonEncode(renewed.toJson()));
    _credential = renewed;
    _log('Access token renewed');
    return renewed.accessToken;
  }

  /// Returns true if the refresh token was revoked at OpenAI. Local credentials are removed either way.
  Future<bool> signOut() async {
    final current = _credential;
    if (current == null) return true;
    var revoked = false;
    try {
      final endpoint = (await _discover())['revocation_endpoint'] as String?;
      if (endpoint != null) {
        final r = await _http.post(Uri.parse(endpoint), body: {
          'token': current.refreshToken,
          'token_type_hint': 'refresh_token',
          'client_id': current.clientId,
        });
        revoked = r.statusCode == 200;
      }
    } catch (_) {
      revoked = false;
    }
    await store.delete(_credentialKey);
    _credential = null;
    return revoked;
  }

  Future<Map<String, dynamic>> _discover() async {
    final r = await _http.get(discoveryUrl);
    if (r.statusCode != 200) throw SiwcException('discovery', 'Could not load the OpenID configuration.');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _tokenRequest(Uri endpoint, Map<String, String> body) async {
    final r = await _http.post(endpoint, body: body);
    if (r.statusCode != 200) {
      String detail = '';
      try {
        detail = '${(jsonDecode(r.body) as Map)['error'] ?? ''}';
      } catch (_) {}
      throw SiwcException('http_${r.statusCode}', 'Token endpoint returned ${r.statusCode} $detail');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if ('${j['token_type']}'.toLowerCase() != 'bearer' ||
        (j['access_token'] as String? ?? '').isEmpty ||
        ((j['expires_in'] as num?) ?? 0) <= 0) {
      throw SiwcException('token_exchange', 'The token response was not usable.');
    }
    return j;
  }

  Future<(String, String?)> _validateIdToken(String jwt, String clientId, String nonce, Uri jwksUri) async {
    SiwcException bad(String why) => SiwcException('invalid_token', 'ID token rejected: $why');
    final parts = jwt.split('.');
    if (parts.length != 3) throw bad('format');
    final header = jsonDecode(utf8.decode(_b64urlDecode(parts[0]))) as Map<String, dynamic>;
    final payload = jsonDecode(utf8.decode(_b64urlDecode(parts[1]))) as Map<String, dynamic>;
    if (header['alg'] != 'RS256') throw bad('algorithm');
    if (payload['iss'] != expectedIssuer) throw bad('issuer');
    final aud = payload['aud'];
    final audList = aud is List ? aud.cast<String>() : [if (aud is String) aud];
    if (!audList.contains(clientId)) throw bad('audience');
    if ((audList.length > 1 || payload['azp'] != null) && payload['azp'] != clientId) throw bad('authorized party');
    final exp = payload['exp'];
    if (exp is! num || exp <= DateTime.now().millisecondsSinceEpoch / 1000) throw bad('expired');
    if (payload['nonce'] != nonce) throw bad('nonce');
    final sub = payload['sub'];
    if (sub is! String || sub.isEmpty) throw bad('subject');

    final r = await _http.get(jwksUri);
    if (r.statusCode != 200) throw bad('key set unavailable');
    final keys = ((jsonDecode(r.body) as Map<String, dynamic>)['keys'] as List).cast<Map<String, dynamic>>();
    final key = keys.where((k) =>
        k['kid'] == header['kid'] &&
        k['kty'] == 'RSA' &&
        (k['alg'] == null || k['alg'] == 'RS256') &&
        (k['use'] == null || k['use'] == 'sig'));
    if (key.isEmpty) throw bad('signing key not found');
    final pub = pc.RSAPublicKey(_bigInt(_b64urlDecode(key.first['n'] as String)),
        _bigInt(_b64urlDecode(key.first['e'] as String)));
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
      ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(pub));
    var ok = false;
    try {
      ok = signer.verifySignature(Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
          pc.RSASignature(_b64urlDecode(parts[2])));
    } catch (_) {
      ok = false;
    }
    if (!ok) throw bad('signature');
    return (sub, payload['email'] as String?);
  }

  Future<String> _stableHostId() async {
    final existing = await store.read(_hostIdKey);
    if (existing != null) return existing;
    final b = _randomBytes(16);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final id = 'urn:uuid:${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
    await store.write(_hostIdKey, id);
    return id;
  }

  // ---- models and inference -----------------------------------------------

  Future<List<SiwcModel>> models() async {
    final r = await _http.get(Uri.parse('$resource/models'),
        headers: {'Authorization': 'Bearer ${await validAccessToken()}'});
    if (r.statusCode != 200) {
      throw SiwcException('http_${r.statusCode}', 'Model list returned ${r.statusCode}: ${_clip(r.body)}');
    }
    final list = ((jsonDecode(r.body) as Map<String, dynamic>)['models'] as List? ?? []).cast<Map<String, dynamic>>();
    return [
      for (final m in list)
        if (m['visibility'] == 'list') SiwcModel(m['slug'] as String, (m['display_name'] ?? m['slug']) as String),
    ];
  }

  /// One non-stored, streamed Responses request. Returns the full text.
  Future<String> ask(String model, String prompt, {void Function(String delta)? onDelta}) async {
    final req = http.Request('POST', Uri.parse('$resource/responses'))
      ..headers['Authorization'] = 'Bearer ${await validAccessToken()}'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'input': [
          {'role': 'user', 'content': prompt},
        ],
        'store': false,
        'stream': true,
      });
    final res = await _http.send(req);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = await res.stream.bytesToString();
      throw SiwcException('http_${res.statusCode}', 'Responses returned ${res.statusCode}: ${_clip(body)}');
    }
    await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      Map<String, dynamic> event;
      try {
        event = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      switch (event['type']) {
        case 'response.output_text.delta':
          final d = event['delta'];
          if (d is String) onDelta?.call(d);
        case 'response.completed':
          final output = ((event['response'] as Map?)?['output'] as List? ?? []);
          final text = StringBuffer();
          for (final item in output) {
            if (item is Map && item['type'] == 'message') {
              for (final c in (item['content'] as List? ?? [])) {
                if (c is Map && c['type'] == 'output_text') text.write(c['text']);
              }
            }
          }
          return text.toString();
        case 'response.failed':
          final err = ((event['response'] as Map?)?['error'] as Map?)?['message'];
          throw SiwcException('stream', '${err ?? 'Unknown model error.'}');
        case 'response.incomplete':
          throw SiwcException('stream', 'The response was incomplete.');
      }
    }
    throw SiwcException('stream', 'The stream ended without a completed response.');
  }

  // ---- helpers ------------------------------------------------------------

  static String _clip(String s) => s.length > 300 ? s.substring(0, 300) : s;
  static final _rng = Random.secure();
  static Uint8List _randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));
  static String _randomUrlSafe(int n) => _b64url(_randomBytes(n));
  static String _b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  static Uint8List _b64urlDecode(String s) => base64Url.decode(s.padRight(s.length + (4 - s.length % 4) % 4, '='));
  static BigInt _bigInt(Uint8List bytes) {
    var v = BigInt.zero;
    for (final b in bytes) {
      v = (v << 8) | BigInt.from(b);
    }
    return v;
  }
}
