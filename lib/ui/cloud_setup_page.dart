import 'package:flutter/material.dart';

import '../app.dart';
import '../backends.dart';
import '../models.dart';
import 'chat_page.dart';
import 'widgets.dart';

class CloudSetupPage extends StatefulWidget {
  const CloudSetupPage({super.key});

  @override
  State<CloudSetupPage> createState() => _CloudSetupPageState();
}

class _CloudSetupPageState extends State<CloudSetupPage> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  final _key = TextEditingController();
  final _workspace = TextEditingController();
  final _claudePath = TextEditingController();
  bool _useKey = false;
  bool _loaded = false;
  bool _testing = false;
  String? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final settings = StoreScope.of(context).settings;
    _host.text = settings.cloudHost;
    _port.text = '${settings.cloudPort}';
    _user.text = settings.cloudUser;
    _password.text = settings.cloudPassword;
    _key.text = settings.cloudPrivateKey;
    _workspace.text = settings.cloudWorkspace;
    _claudePath.text = settings.cloudClaudePath;
    _useKey = settings.cloudPrivateKey.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    _key.dispose();
    _workspace.dispose();
    _claudePath.dispose();
    super.dispose();
  }

  void _apply() {
    final store = StoreScope.of(context);
    final settings = store.settings;
    settings.cloudHost = _host.text.trim();
    settings.cloudPort = int.tryParse(_port.text.trim()) ?? 22;
    settings.cloudUser = _user.text.trim();
    settings.cloudPassword = _questionPassword();
    settings.cloudPrivateKey = _useKey ? _key.text.trim() : '';
    settings.cloudWorkspace = _workspace.text.trim().isEmpty
        ? '~'
        : _workspace.text.trim();
    settings.cloudClaudePath = _claudePath.text.trim().isEmpty
        ? 'claude'
        : _claudePath.text.trim();
  }

  String _questionPassword() =>
      _useKey ? '' : _password.text;

  Future<void> _test() async {
    _apply();
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final text = await CloudBackend(
        StoreScope.of(context).settings,
      ).test();
      if (!mounted) return;
      setState(() {
        _testing = false;
        _result = text.isEmpty ? '连接成功，但没有读到 Claude Code 版本。' : text;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _result = '连接失败：$error';
      });
    }
  }

  Future<void> _enter() async {
    final store = StoreScope.of(context);
    _apply();
    await store.setMode(BackendMode.cloud);
    await store.save();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('云端电脑')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          Text('连接你的电脑。', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            '电脑上已经装好 Claude Code 并开启了 SSH。Claude GO 通过 SSH '
            '把指令发过去，把流式输出拉回手机。代码和执行都在电脑上。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LabeledField(
                  label: '主机',
                  controller: _host,
                  hint: '192.168.1.10 或主机名',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledField(
                  label: '端口',
                  controller: _port,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: '用户名',
            controller: _user,
            hint: '电脑登录用户名',
          ),
          const SizedBox(height: 18),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('密码')),
              ButtonSegment(value: true, label: Text('私钥')),
            ],
            selected: {_useKey},
            onSelectionChanged: (value) =>
                setState(() => _useKey = value.first),
          ),
          const SizedBox(height: 12),
          if (_useKey)
            LabeledField(
              label: '私钥（PEM / OpenSSH）',
              controller: _key,
              hint: '-----BEGIN OPENSSH PRIVATE KEY-----',
              maxLines: 6,
            )
          else
            LabeledField(
              label: '密码',
              controller: _password,
              obscure: true,
            ),
          const SizedBox(height: 14),
          LabeledField(
            label: '工作目录',
            controller: _workspace,
            hint: '~/projects 或 /home/you/code',
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Claude 命令',
            controller: _claudePath,
            hint: 'claude 或 ~/.local/bin/claude',
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_rounded, size: 18),
            label: Text(_testing ? '正在连接…' : '测试连接'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SelectableText(
                _result!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _host.text.trim().isEmpty ? null : _enter,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('保存并进入对话'),
          ),
          const SizedBox(height: 26),
          const SectionLabel('电脑端要求'),
          const SizedBox(height: 10),
          Text(
            '1. 安装并登录 Claude Code，确认终端里能直接运行 claude。\n'
            '2. 开启 SSH 服务，手机能 ping 通这台电脑。\n'
            '3. 工作目录必须存在；Claude Code 会在该目录里读写文件。\n'
            '4. 如果使用密码登录，电脑需要允许 PasswordAuthentication。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 20),
          Text(
            '云端模式不会把电脑上的文件复制到手机；手机只负责发指令和看结果。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }
}
