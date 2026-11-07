import 'models.dart';

class AppSettings {
  BackendMode mode = BackendMode.local;

  String baseUrl = 'https://api.deepseek.com/anthropic';
  String apiKey = '';
  String model = 'deepseek-flash[1m]';
  String opusModel = 'deepseek-flash[1m]';
  String sonnetModel = 'deepseek-flash[1m]';
  String haikuModel = 'deepseek-flash';
  String subagentModel = 'deepseek-flash';

  /// plan / acceptEdits / bypassPermissions
  String permissionMode = 'acceptEdits';

  bool protectBackground = false;
  bool externalStorage = false;

  String localWorkspace = r'$HOME/ClaudeGO';
  String localToken = '';
  String? localSessionId;

  String cloudHost = '';
  int cloudPort = 22;
  String cloudUser = '';
  String cloudPassword = '';
  String cloudPrivateKey = '';
  String cloudWorkspace = '~';
  String cloudClaudePath = 'claude';
  String? cloudSessionId;

  String? get sessionId =>
      mode == BackendMode.local ? localSessionId : cloudSessionId;

  set sessionId(String? value) {
    if (mode == BackendMode.local) {
      localSessionId = value;
    } else {
      cloudSessionId = value;
    }
  }

  Map<String, String> get claudeEnv => {
    'ANTHROPIC_BASE_URL': baseUrl,
    'ANTHROPIC_AUTH_TOKEN': apiKey,
    'ANTHROPIC_MODEL': model,
    'ANTHROPIC_DEFAULT_OPUS_MODEL': opusModel,
    'ANTHROPIC_DEFAULT_SONNET_MODEL': sonnetModel,
    'ANTHROPIC_DEFAULT_HAIKU_MODEL': haikuModel,
    'CLAUDE_CODE_SUBAGENT_MODEL': subagentModel,
  };

  String get permissionLabel => switch (permissionMode) {
    'plan' => '计划模式',
    'bypassPermissions' => '完全放行',
    _ => '自动接受编辑',
  };
}
