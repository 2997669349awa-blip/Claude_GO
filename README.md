# Claude GO

把 Claude Code 装进口袋的第三方 Android 客户端。两种运行方式，同一个对话界面：

- **本地容器**：在 App 内置的 PRoot 容器里运行 Claude Code，代码和数据留在手机上。
- **云端电脑**：通过 SSH 连接已经装好 Claude Code 的电脑，手机只负责发指令和看结果。

Claude GO 不是 Anthropic 官方产品，也不包含 Claude Code 的二进制文件。Claude Code、Claude 名称与相关图形归 Anthropic 所有。

## 功能

- 会话抽屉：多会话历史、自动标题、本地持久化、删除
- 桌宠 Spark：18 组动作；10 秒无触摸转入待机，待机时左右瞟眼，再持续 10 秒睡觉；可在设置里关闭
- 流式输出、工具调用卡片、会话续聊（`--resume`）
- Anthropic 兼容接口：可填官方 API、第三方中转或 DeepSeek 的 Anthropic 端点
- 模型映射：主模型 / Opus / Sonnet / Haiku / 子代理
- 权限模式：计划模式、自动接受编辑、完全放行
- 本地存储可选内部或外部，并写明速度与持久化差异
- 后台保护：前台服务 + 唤醒锁 + 忽略电池优化，可手动开关

## 本地模式准备

1. 打开“本地容器”，点 **安装容器**：把内置的 Ubuntu + Node 运行时解压到 App 私有目录（约 800 MB，需要约 1 GB 空闲空间）。
2. 点 **安装 Claude Code**：在容器内执行 npm 安装，需要网络。
3. 点 **启动本地桥**：容器内的 Node 桥监听 `127.0.0.1:8787`。
4. 进入对话。每条消息都会送进容器里的 Claude Code，输出实时传回。

容器和工作区都在 App 私有目录，不依赖 Termux；卸载 App 会一起删除。API Key 不写入容器文件，由 App 在每次请求时注入。

## 云端模式准备

1. 电脑上安装并登录 Claude Code，确认终端里能直接运行 `claude`。
2. 开启 SSH，手机能访问电脑的地址和端口。
3. 在“云端电脑”页填写主机、端口、用户名、密码或私钥、工作目录。
4. 点“测试连接”，通过后进入对话。

## 构建

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Android 侧需要 `android/local.properties` 指向 SDK，`android/key.properties` 指向签名密钥。两者都不入库。

APK 还依赖内置 Linux 运行时：

- `android/app/src/main/assets/runtime/rootfs-arm64-v8a.tar.xz`：Ubuntu 24.04 + Node 24 的 rootfs（约 159 MB，来自 DSH runtime，因超过 GitHub 单文件限制而不入库）。
- `android/app/src/main/assets/runtime/manifest.json`、`licenses/`、`bridge.cjs`：运行时清单、许可证和本地桥。
- `android/app/src/main/jniLibs/arm64-v8a/`：proot、loader、talloc、android-shmem。

对应的开源许可证在 `assets/runtime/licenses/` 中随 APK 一起分发。

## 免责声明

- 本项目与 Anthropic 无隶属关系，未获得其背书。
- 项目不捆绑、不分发 Claude Code，也不提供任何 API Key。
- 使用第三方接口、订阅账号或中转服务时，请自行确认符合相应服务条款与当地法律。
- 本地模式在 App 内置的 PRoot 容器中运行；系统清理 App 时容器进程也会停止。
- 当前为早期版本，可能有未完成的交互和兼容性问题。

## 许可

AGPL-3.0，见 [LICENSE](LICENSE)。
