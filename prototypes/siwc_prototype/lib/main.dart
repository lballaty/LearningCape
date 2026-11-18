// Path: prototypes/siwc_prototype/lib/main.dart
// Minimal screen to test Sign in with ChatGPT on macOS, iPad and iPhone.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'siwc.dart';

class KeychainStore implements CredentialStore {
  final _s = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

void main() => runApp(const MaterialApp(title: 'SIWC prototype', home: PrototypePage()));

class PrototypePage extends StatefulWidget {
  const PrototypePage({super.key});
  @override
  State<PrototypePage> createState() => _PrototypePageState();
}

class _PrototypePageState extends State<PrototypePage> {
  static const _bg = MethodChannel('siwc/background');
  late final SiwcClient _client;
  final _log = <String>[];
  final _prompt = TextEditingController(text: 'Reply with one short sentence confirming you can hear me.');
  List<SiwcModel> _models = [];
  String? _model;
  String _answer = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _client = SiwcClient(
      store: KeychainStore(),
      agentName: 'LearningCape prototype',
      openBrowser: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
      onLog: _say,
      onWaitingForCallback: (waiting) async {
        if (defaultTargetPlatform != TargetPlatform.iOS) return;
        try {
          await _bg.invokeMethod(waiting ? 'begin' : 'end');
        } catch (_) {/* channel missing: carry on */}
      },
    );
    _client.load().then((_) => setState(() {}));
  }

  void _say(String s) => setState(() => _log.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}  $s'));

  Future<void> _run(String label, Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      _say('$label: OK');
    } catch (e) {
      _say('$label: FAILED  $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _client.credential;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with ChatGPT prototype')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(c == null ? 'Not signed in' : 'Signed in as ${c.email ?? c.subject}\nPlan access: ${_client.canUsePlan}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: _busy ? null : () => _run('Sign in', () async => _client.signIn()), child: const Text('1. Sign in')),
            FilledButton(
                onPressed: _busy || c == null
                    ? null
                    : () => _run('Models', () async {
                          final m = await _client.models();
                          setState(() {
                            _models = m;
                            _model = m.isEmpty ? null : m.first.slug;
                          });
                          _say('${m.length} models: ${m.map((x) => x.slug).join(', ')}');
                        }),
                child: const Text('2. List models')),
            OutlinedButton(
                onPressed: _busy || c == null
                    ? null
                    : () => _run('Sign out', () async => _say('Revoked at OpenAI: ${await _client.signOut()}')),
                child: const Text('Sign out')),
          ]),
          if (_models.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _model,
              isExpanded: true,
              items: [for (final m in _models) DropdownMenuItem(value: m.slug, child: Text('${m.displayName} (${m.slug})'))],
              onChanged: (v) => setState(() => _model = v),
            ),
            TextField(controller: _prompt, decoration: const InputDecoration(labelText: 'Prompt')),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: _busy || _model == null
                    ? null
                    : () => _run('Ask', () async {
                          setState(() => _answer = '');
                          final full = await _client.ask(_model!, _prompt.text,
                              onDelta: (d) => setState(() => _answer += d));
                          setState(() => _answer = full);
                        }),
                child: const Text('3. Ask')),
            if (_answer.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(_answer)),
          ],
          const Divider(height: 32),
          const Text('Log (no tokens are shown)', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(_log.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ]),
      ),
    );
  }
}
