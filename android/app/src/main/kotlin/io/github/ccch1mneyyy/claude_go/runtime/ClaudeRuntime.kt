package io.github.ccch1mneyyy.claude_go.runtime

import android.content.Context
import android.net.ConnectivityManager
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/**
 * Owns the embedded Linux container: unpacks the rootfs bundled in the APK,
 * installs Claude Code inside it, and runs the localhost bridge. Nothing here
 * depends on Termux.
 */
object ClaudeRuntime {
    private const val ROOTFS_ASSET = "rootfs-arm64-v8a.tar.xz"
    private const val ROOTFS_BYTES = 159_507_856L
    private const val BRIDGE_ASSET = "runtime/bridge.cjs"

    @Volatile private var appContext: Context? = null
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var bridgeProcess: Process? = null
    @Volatile private var installProcess: Process? = null
    @Volatile private var phase = "idle"
    @Volatile private var progress = -1
    @Volatile private var lastError: String? = null
    private val log = StringBuilder()
    private val logLock = Any()

    fun init(context: Context) {
        if (appContext == null) appContext = context.applicationContext
    }

    private fun ctx(): Context = checkNotNull(appContext) { "ClaudeRuntime is not initialized" }

    private fun rootfs(): File = File(ctx().filesDir, "runtime/rootfs")

    private fun marker(): File = File(ctx().filesDir, "runtime/installed.json")

    private fun nativeDir(): String = ctx().applicationInfo.nativeLibraryDir

    private fun prootTmp(): File = File(ctx().cacheDir, "proot-tmp").apply { mkdirs() }

    fun isRuntimeInstalled(): Boolean =
        marker().exists() && File(rootfs(), "usr/local/bin/node").exists()

    fun isClaudeInstalled(): Boolean =
        isRuntimeInstalled() &&
            (File(rootfs(), "usr/local/bin/claude").exists() ||
                File(rootfs(), "root/.local/bin/claude").exists())

    fun status(): Map<String, Any?> = synchronized(logLock) {
        mapOf(
            "installed" to isRuntimeInstalled(),
            "claudeInstalled" to isClaudeInstalled(),
            "bridgeRunning" to (bridgeProcess?.isAlive == true),
            "phase" to phase,
            "progress" to progress,
            "error" to lastError,
            "log" to log.toString(),
        )
    }

    fun installRuntime() {
        worker.execute {
            if (isRuntimeInstalled()) {
                phase = "installed"
                progress = 100
                append("容器已安装")
                return@execute
            }
            phase = "extracting"
            progress = 0
            lastError = null
            append("开始解压容器（约 800 MB，首次需要几分钟）…")
            val temp = File(ctx().filesDir, "runtime/rootfs.tmp")
            try {
                temp.deleteRecursively()
                temp.mkdirs()
                ctx().assets.open("runtime/$ROOTFS_ASSET").use { input ->
                    TarExtractor(temp) { read ->
                        progress = ((read * 100) / ROOTFS_BYTES).toInt().coerceIn(0, 100)
                    }.extract(input, ROOTFS_ASSET)
                }
                File(temp, "var/lib/dsh-app/empty").mkdirs()
                File(temp, "var/lib/dsh-app/shm").mkdirs()
                File(temp, "root/.l2s").mkdirs()
                File(temp, "opt/claude-go").mkdirs()
                ctx().assets.open(BRIDGE_ASSET).use { input ->
                    File(temp, "opt/claude-go/bridge.cjs").outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                val target = rootfs()
                target.parentFile?.mkdirs()
                if (target.exists()) target.deleteRecursively()
                if (!temp.renameTo(target)) {
                    throw IllegalStateException("无法移动解压后的容器目录")
                }
                marker().writeText(
                    JSONObject()
                        .put("version", "r15-dsh0.2.2-rc.1-node24.22.1-ubuntu24.04.5")
                        .put("installedAt", System.currentTimeMillis())
                        .toString(),
                )
                phase = "installed"
                progress = 100
                append("容器安装完成")
            } catch (error: Exception) {
                phase = "error"
                lastError = error.message ?: error.toString()
                append("容器安装失败：$lastError")
                temp.deleteRecursively()
            }
        }
    }

    fun installClaudeCode() {
        worker.execute {
            if (!isRuntimeInstalled()) {
                phase = "error"
                lastError = "请先安装容器"
                return@execute
            }
            if (isClaudeInstalled()) {
                phase = "claude-installed"
                append("Claude Code 已安装")
                return@execute
            }
            phase = "installing-claude"
            lastError = null
            append("开始在容器内安装 Claude Code…")
            val base =
                "export PATH=/usr/local/bin:\$PATH; " +
                    "export npm_config_unsafe_perm=true; " +
                    "npm install -g @anthropic-ai/claude-code --no-audit --no-fund"
            var code = runOnce("$base 2>&1")
            if (code != 0) {
                append("镜像源安装失败（退出码 $code），改用 npmjs 重试…")
                code = runOnce("$base --registry=https://registry.npmjs.org 2>&1")
            }
            if (code == 0 && isClaudeInstalled()) {
                phase = "claude-installed"
                append("Claude Code 安装完成")
            } else {
                phase = "error"
                lastError = "Claude Code 安装失败（npm 退出码 $code）"
                append(lastError!!)
            }
        }
    }

    fun startBridge(token: String) {
        worker.execute {
            if (!isRuntimeInstalled()) {
                phase = "error"
                lastError = "请先安装容器"
                return@execute
            }
            if (!isClaudeInstalled()) {
                phase = "error"
                lastError = "请先在容器内安装 Claude Code"
                return@execute
            }
            stopBridgeBlocking()
            ensureBridgeScript()
            phase = "starting-bridge"
            lastError = null
            append("启动本地桥…")
            try {
                val process = launch(
                    "CLAUDE_GO_TOKEN=${shellQuote(token)} " +
                        "exec /usr/local/bin/node /opt/claude-go/bridge.cjs",
                )
                bridgeProcess = process
                phase = "bridge-running"
                append("本地桥已启动（127.0.0.1:8787）")
                Thread({ readOutput(process) }, "claude-go-bridge").start()
            } catch (error: Exception) {
                phase = "error"
                lastError = error.message ?: error.toString()
                append("本地桥启动失败：$lastError")
            }
        }
    }

    fun stopBridge() {
        worker.execute { stopBridgeBlocking() }
    }

    private fun stopBridgeBlocking() {
        val process = bridgeProcess
        bridgeProcess = null
        if (process != null && process.isAlive) {
            process.destroy()
            runCatching { process.waitFor(3, TimeUnit.SECONDS) }
            if (process.isAlive) process.destroyForcibly()
        }
        if (phase == "bridge-running" || phase == "starting-bridge") phase = "stopped"
    }

    private fun ensureBridgeScript() {
        val dir = File(rootfs(), "opt/claude-go").apply { mkdirs() }
        ctx().assets.open(BRIDGE_ASSET).use { input ->
            File(dir, "bridge.cjs").outputStream().use { output -> input.copyTo(output) }
        }
    }

    private fun runOnce(command: String): Int {
        val process = launch(command)
        installProcess = process
        try {
            process.inputStream.bufferedReader().use { reader ->
                var line = reader.readLine()
                while (line != null) {
                    append(line)
                    line = reader.readLine()
                }
            }
            return process.waitFor()
        } finally {
            installProcess = null
        }
    }

    private fun readOutput(process: Process) {
        try {
            process.inputStream.bufferedReader().use { reader ->
                var line = reader.readLine()
                while (line != null) {
                    append(line)
                    line = reader.readLine()
                }
            }
        } catch (_: Exception) {
            // The bridge was stopped.
        }
        if (bridgeProcess === process) {
            bridgeProcess = null
            if (phase == "bridge-running") phase = "stopped"
        }
    }

    private fun append(line: String) {
        synchronized(logLock) {
            log.append(line).append('\n')
            if (log.length > 24_000) log.delete(0, log.length - 24_000)
        }
    }

    /** Android's resolvers are copied into the container before each launch. */
    private fun writeDns() {
        try {
            val manager = ctx().getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val servers = manager.getLinkProperties(manager.activeNetwork)?.dnsServers.orEmpty()
            if (servers.isNotEmpty()) {
                File(rootfs(), "etc/resolv.conf").writeText(
                    servers.joinToString("\n") { "nameserver ${it.hostAddress}" } + "\n",
                )
            }
        } catch (_: Exception) {
            // Keep the rootfs resolver if the system one is unavailable.
        }
    }

    private fun shellQuote(value: String): String =
        "'" + value.replace("'", "'\\''") + "'"

    private fun launch(command: String): Process {
        if (isRuntimeInstalled()) writeDns()
        val root = rootfs().absolutePath
        val native = nativeDir()
        val tmp = prootTmp().absolutePath
        val argv = mutableListOf(
            "$native/libproot.so",
            "--kill-on-exit",
            "--link2symlink",
            "--sysvipc",
            "-L",
            "-0",
            "--rootfs=$root",
            "--cwd=/root",
            "-b", "/dev",
            "-b", "/dev/urandom:/dev/random",
            "-b", "/proc",
            "-b", "/proc/self/fd:/dev/fd",
            "-b", "/proc/self/fd/0:/dev/stdin",
            "-b", "/proc/self/fd/1:/dev/stdout",
            "-b", "/proc/self/fd/2:/dev/stderr",
            "-b", "/sys",
            "-b", "$root/var/lib/dsh-app/empty:/sys/fs/selinux",
            "-b", "$root/var/lib/dsh-app/shm:/dev/shm",
            "-b", "/system",
            "-b", "/apex",
            "-b", "/storage/emulated/0",
            "/usr/bin/env",
            "-i",
            "HOME=/root",
            "USER=root",
            "LOGNAME=root",
            "SHELL=/bin/bash",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "LANG=C.UTF-8",
            "TERM=xterm-256color",
            "TMPDIR=/tmp",
            "DSH_HOME=/root/.dsh",
            "XDG_DATA_DIRS=/usr/local/share:/usr/share:/system",
            "pnpm_config_registry=https://registry.npmmirror.com/",
            "UV_USE_IO_URING=0",
            "NARB_DISABLE_NATIVE_CACHE=1",
            "NODE_OPTIONS=--dns-result-order=ipv4first",
            "/bin/sh",
            "-c",
            command,
        )
        val builder = ProcessBuilder(argv)
        builder.directory(File(ctx().filesDir, "runtime"))
        builder.redirectErrorStream(true)
        val env = builder.environment()
        env["PROOT_LOADER"] = "$native/libproot-loader.so"
        env["PROOT_TMP_DIR"] = tmp
        env["PROOT_L2S_DIR"] = "$root/root/.l2s"
        env["LD_LIBRARY_PATH"] = native
        return builder.start()
    }
}
