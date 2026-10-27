# macOS 使用说明

本版本基于 [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) 添加 Mac 支持。双击启动器后播放 550C 动画，同时在后台预先打开 ChatGPT。动画结束后保留最后一帧，等 ChatGPT 窗口准备好，再以约 0.25 秒淡出并切换到 ChatGPT。

## 安装

1. 确认 Mac 已安装 ChatGPT。启动器优先查找 `/Applications/ChatGPT.app` 和 `~/Applications/ChatGPT.app`，并使用应用启动服务补充查找。
2. 下载 Release 中的 macOS 压缩包并解压。
3. 将 `ChatGPT 550C.app` 拖入“应用程序”文件夹。也可放入个人的 `~/Applications` 文件夹。
4. 双击应用。从这个入口打开时才会播放动画。

如需桌面入口，可在 Finder 中为 `ChatGPT 550C.app` 制作替身，再把替身移到桌面。ChatGPT 已在运行且有窗口时，启动器会直接使用现有进程，不会退出或重新启动它。若应用在启动过程中更换进程，播放器会继续寻找同一路径下的接续进程。

## 设置窗口铺满权限

自动调整窗口需要 macOS 的“辅助功能”权限。请按以下步骤由自己授权：

1. 按住 **Option** 键打开 `ChatGPT 550C.app`。
2. 在模式选择窗口中点“设置窗口铺满权限”。也可在播放器的应用菜单中选择“设置窗口铺满权限…”。
3. 在打开的系统权限页面中，为 `ChatGPT 550C` 手动启用“辅助功能”访问。若列表尚未列出应用，请将已安装的 `ChatGPT 550C.app` 添加到该页面。
4. 关闭权限设置，再次打开启动器。

授权后，播放器会在切换到 ChatGPT 前，将它的窗口铺满**当前屏幕的可用区域**。菜单栏保留，窗口不会进入 macOS 原生全屏空间。

本启动器只使用这项权限来检测和调整 ChatGPT 主窗口。不授权也能播放动画、在后台预启动 ChatGPT，并完成淡出衔接；ChatGPT 窗口会保持现有大小。启动器不会替你授权。关于这项系统权限，可参阅 [Apple 官方说明](https://support.apple.com/zh-cn/guide/mac-help/mh43185/mac)。

### 升级后显示已授权，但窗口仍不能铺满

本地 ad-hoc 签名与具体构建版本相关。更新后，macOS 可能仍保留旧版本的授权条目，即使开关显示已开启，新版也不能使用。先退出启动器，在“辅助功能”列表中移除它的旧条目，再点加号选择当前安装的 `ChatGPT 550C.app`，由自己重新开启权限后运行。只需处理这个启动器的条目。相关机制见 [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。

## 动画模式

按住 **Option** 键打开启动器，直到模式选择窗口出现。选择后点“保存并打开”，之后会使用保存的模式。

| 模式 | 行为 |
| --- | --- |
| 完整 550C 动画 | 默认模式，播放 Logo 与终端动画，当前固定源码约 11–14 秒 |
| 快速模式，仅 Logo | 仅播放 Logo，实测约 5 秒 |
| 直接打开 ChatGPT | 省略动画 |

上述为动画本体时长，最终切换还取决于 ChatGPT 窗口的准备时间。当前源码的节奏较上游说明中的约 90 秒更短，本版本未延长其时间线。

## 跳过和退出

| 操作 | 结果 |
| --- | --- |
| Esc | 跳过剩余动画，待 ChatGPT 准备好后淡出 |
| 右上角 SKIP | 跳过剩余动画，待 ChatGPT 准备好后淡出 |
| Command-W | 跳过剩余动画，待 ChatGPT 准备好后淡出 |
| Command-Q | 退出播放器；已预启动的 ChatGPT 保持运行 |

## 首次打开与校验

发布包仅有本地 ad-hoc 签名，未使用 Apple Developer ID，也未经 Apple 公证。下载的应用可能受到 macOS 门禁检查限制。

可以在下载目录使用随 Release 附带的校验文件确认压缩包完整性：

```sh
shasum -a 256 -c SHA256SUMS
```

仅下载某个架构时，可运行 `shasum -a 256 文件名.zip`，与 `SHA256SUMS` 中相应文件的值对照。校验值验证下载完整性，不代替对发布者和源码的判断。

如果系统阻止打开，请核实来源后自行决定是否按照 [Apple 官方说明](https://support.apple.com/zh-cn/102445) 操作。无需关闭系统安全功能。

## 常见情况

- 提示找不到 ChatGPT：先安装 ChatGPT，通常将它放到“应用程序”文件夹即可。
- 动画还没播完：可以按 Esc 或点击 SKIP；播放器另有 150 秒超时保护。
- 动画停在最后一帧：播放器正在等待 ChatGPT 窗口准备好，最多等待 8 秒；期间检测到接续进程后会继续切换。
- 提示 ChatGPT 已关闭或未完成启动：等待期限内没有找到可用的 ChatGPT 进程。重新打开启动器；若反复出现，请先直接打开 ChatGPT，确认它能正常运行。
- 提示窗口尚未准备好：ChatGPT 仍在运行，但还没有可切换的窗口，可从 Dock 打开它。
- ChatGPT 没有铺满窗口：检查 `ChatGPT 550C` 的“辅助功能”权限；后台预启动与动画淡出不受此项权限影响。
- 想在 Mac 开机时播放：本版本提供的是 ChatGPT 启动前动画，没有自动添加登录项。
- Intel 或较早系统：发布包包含 Intel 架构并以 macOS 13 为构建目标；当前实机验证范围仅为 Apple Silicon 与 macOS 26.3.1。

## 卸载

将 `ChatGPT 550C.app` 及自己创建的桌面替身移到废纸篓即可。若保存过动画模式，偏好域为 `io.github.chatgpt550c.macos`。

## 署名与许可

直接基于项目：[Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot)。动画原稿：[Voidpoket](https://github.com/Voidpoket)。上游移植：[dsh-550c-boot](https://github.com/yannicksong0106/dsh-550c-boot)，Copyright (c) 2026 Ziyang Song。macOS 播放器为本衍生版本新增内容。完整声明见 [NOTICE.md](../NOTICE.md)、[LICENSE](../LICENSE) 和 [TRADEMARKS.md](../TRADEMARKS.md)。
