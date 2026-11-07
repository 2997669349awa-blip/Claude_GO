import 'package:flutter/material.dart';

import '../app.dart';
import '../native.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _opus = TextEditingController();
  final _sonnet = TextEditingController();
  final _haiku = TextEditingController();
  final _subagent = TextEditingController();
  bool _loaded = false;
  String _permission = 'acceptEdits';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final settings = StoreScope.of(context).settings;
    _baseUrl.text = settings.baseUrl;
    _apiKey.text = settings.apiKey;
    _model.text = settings.model;
    _opus.text = settings.opusModel;
    _sonnet.text = settings.sonnetModel;
    _haiku.text = settings.haikuModel;
    _subagent.text = settings.subagentModel;
    _permission = settings.permissionMode;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _opus.dispose();
    _sonnet.dispose();
    _haiku.dispose();
    _subagent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = StoreScope.of(context);
    final settings = store.settings;
    settings.baseUrl = _baseUrl.text.trim();
    settings.apiKey = _apiKey.text.trim();
    settings.model = _model.text.trim();
    settings.opusModel = _opus.text.trim();
    settings.sonnetModel = _sonnet.text.trim();
    settings.haikuModel = _haiku.text.trim();
    settings.subagentModel = _subagent.text.trim();
    settings.permissionMode = _permission;
    await store.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
  }

  Future<void> _setStorage(bool external) async {
    final store = StoreScope.of(context);
    setState(() {
      store.settings.externalStorage = external;
      store.settings.localWorkspace = external
          ? '/storage/emulated/0/ClaudeGO'
          : r'$HOME/ClaudeGO';
    });
    if (external) {
      await Native.requestExternalStorage();
    }
    await store.save();
  }

  Future<void> _setProtection(bool enabled) async {
    final store = StoreScope.of(context);
    setState(() => store.settings.protectBackground = enabled);
    if (enabled) {
      await Native.startProtection();
      await Native.requestIgnoreBatteryOptimizations();
    } else {
      await Native.stopProtection();
    }
    await store.save();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final settings = store.settings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 34),
        children: [
          const SectionLabel('API 接入'),
          const SizedBox(height: 10),
          Text(
            '使用 Anthropic 兼容接口。第三方中转、DeepSeek 的 Anthropic 端点都填在这里。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Base URL',
            controller: _baseUrl,
            hint: 'https://api.deepseek.com/anthropic',
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'API Key',
            controller: _apiKey,
            obscure: true,
            hint: 'sk-…',
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: '主模型',
            controller: _model,
            hint: 'deepseek-flash[1m]',
          ),
          const SizedBox(height: 14),
          LabeledField(label: 'Opus 映射', controller: _opus),
          const SizedBox(height: 14),
          LabeledField(label: 'Sonnet 映射', controller: _sonnet),
          const SizedBox(height: 14),
          LabeledField(label: 'Haiku 映射', controller: _haiku),
          const SizedBox(height: 14),
          LabeledField(label: '子代理模型', controller: _subagent),
          const SizedBox(height: 28),
          const SectionLabel('权限模式'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [
                ('plan', '计划模式'),
                ('acceptEdits', '自动接受编辑'),
                ('bypassPermissions', '完全放行'),
              ])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: _permission == option.$1,
                  onSelected: (_) => setState(() => _permission = option.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _permission == 'plan'
                ? '只读分析，不改文件、不跑危险命令。'
                : (_permission == 'bypassPermissions'
                      ? '所有工具调用直接放行。只建议在你完全信任的项目里使用。'
                      : '自动接受文件编辑，其余敏感操作仍按 Claude Code 的默认策略处理。'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          const SectionLabel('本地存储'),
          const SizedBox(height: 10),
          _StorageOption(
            title: '内部存储',
            subtitle: r'$HOME/ClaudeGO',
            detail: '速度快，适合 node_modules、git 和大量小文件；卸载 App 后数据一起删除。',
            selected: !settings.externalStorage,
            onTap: () => _setStorage(false),
          ),
          const SizedBox(height: 10),
          _StorageOption(
            title: '外部存储',
            subtitle: '/storage/emulated/0/ClaudeGO',
            detail: '卸载后仍保留，方便用文件管理器访问；FUSE 较慢，符号链接和执行权限可能受限。',
            selected: settings.externalStorage,
            onTap: () => _setStorage(true),
          ),
          const SizedBox(height: 28),
          const SectionLabel('后台保护'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SwitchListTile.adaptive(
              value: settings.protectBackground,
              onChanged: _setProtection,
              title: const Text('保持会话运行'),
              subtitle: const Text(
                '前台服务 + 唤醒锁，并请求忽略电池优化。会增加耗电，但锁屏或切后台时任务不容易被系统杀掉。',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('桌宠'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SwitchListTile.adaptive(
              value: settings.showPet,
              onChanged: (value) async {
                setState(() => settings.showPet = value);
                await store.save();
              },
              title: const Text('显示 Spark'),
              subtitle: const Text(
                '聊天页左下角。10 秒无触摸会转入待机，待机时左右瞟眼，再持续 10 秒会睡觉。',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionLabel('关于'),
          const SizedBox(height: 10),
          Text(
            'Claude GO 0.2.0\n'
            '第三方 Claude Code 手机客户端。与 Anthropic 无隶属关系，'
            '不包含 Anthropic 的官方 App 或 Claude Code 二进制。\n\n'
            '本地模式依赖 Termux；云端模式依赖你电脑上的 SSH 与 Claude Code。',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 12),
          SelectableText(
            'https://github.com/2997669349awa-blip/Claude_GO',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageOption extends StatelessWidget {
  const _StorageOption({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
