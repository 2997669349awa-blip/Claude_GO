import 'package:flutter/material.dart';

import '../app.dart';
import '../models.dart';
import 'chat_page.dart';
import 'cloud_setup_page.dart';
import 'local_setup_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final settings = store.settings;
    final theme = Theme.of(context);
    final userMessages = store.messages
        .where((message) => message.role == ChatRole.user)
        .toList();
    final lastUser = userMessages.isEmpty ? null : userMessages.last;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
          children: [
            Row(
              children: [
                const BrandMark(size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Claude GO',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 27,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'CLAUDE CODE ON MOBILE',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Text(
              '把 Claude Code\n装进口袋。',
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: 16),
            Text(
              '本地容器直接跑在手机上，或者 SSH 连接你的电脑。两种方式，同一个对话界面。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 34),
            const SectionLabel('运行方式'),
            const SizedBox(height: 12),
            ModeCard(
              icon: Icons.terminal_rounded,
              title: '本地容器',
              subtitle: 'Termux + Claude Code，代码和数据留在手机里',
              status: '配置',
              active: settings.mode == BackendMode.local,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocalSetupPage()),
              ),
            ),
            const SizedBox(height: 12),
            ModeCard(
              icon: Icons.laptop_mac_rounded,
              title: '云端电脑',
              subtitle: settings.cloudHost.isEmpty
                  ? 'SSH 连接已安装 Claude Code 的电脑'
                  : '${settings.cloudUser}@${settings.cloudHost}',
              status: settings.cloudHost.isEmpty ? '未绑定' : '已绑定',
              active: settings.mode == BackendMode.cloud,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CloudSetupPage()),
              ),
            ),
            if (lastUser != null) ...[
              const SizedBox(height: 30),
              const SectionLabel('上次对话'),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatPage()),
                  ),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lastUser.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 36),
            Text(
              'Claude GO 是第三方客户端，与 Anthropic 无隶属关系。\n'
              '使用前请确认你已获得所连接服务与账号的授权。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
