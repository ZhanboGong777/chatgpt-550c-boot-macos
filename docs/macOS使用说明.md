# macOS 使用说明

本版本基于 [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) 添加 Mac 支持。双击启动器后播放 550C 动画，再打开 ChatGPT。

## 安装

1. 确认 Mac 已安装 ChatGPT。启动器优先查找 `/Applications/ChatGPT.app` 和 `~/Applications/ChatGPT.app`，并使用应用启动服务补充查找。
2. 下载 Release 中的 macOS 压缩包并解压。
3. 将 `ChatGPT 550C.app` 拖入“应用程序”文件夹。也可放入个人的 `~/Applications` 文件夹。
4. 双击应用。从这个入口打开时才会播放动画。

如需桌面入口，可在 Finder 中为 `ChatGPT 550C.app` 制作替身，再把替身移到桌面。ChatGPT 已在运行时，动画结束后会打开现有应用。

## 动画模式

按住 **Option** 键打开启动器，直到模式选择窗口出现。选择后点“保存并打开”，之后会使用保存的模式。

| 模式 | 行为 |
| --- | --- |
| 完整 550C 动画 | 默认模式，播放 Logo 与终端动画，当前固定源码实测约 11 秒 |
| 快速模式，仅 Logo | 仅播放 Logo，实测约 5 秒 |
| 直接打开 ChatGPT | 省略动画 |

当前源码的节奏较上游说明中的约 90 秒更短。本版本未延长其时间线。

## 跳过和退出

| 操作 | 结果 |
| --- | --- |
| Esc | 跳过动画，打开 ChatGPT |
| 右上角 SKIP | 跳过动画，打开 ChatGPT |
| Command-W | 跳过动画，打开 ChatGPT |
| Command-Q | 退出播放器 |

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
- 想在 Mac 开机时播放：本版本提供的是 ChatGPT 启动前动画，没有自动添加登录项。
- Intel 或较早系统：发布包包含 Intel 架构并以 macOS 13 为构建目标；当前实机验证范围仅为 Apple Silicon 与 macOS 26.3.1。

## 卸载

将 `ChatGPT 550C.app` 及自己创建的桌面替身移到废纸篓即可。若保存过动画模式，偏好域为 `io.github.chatgpt550c.macos`。

## 署名与许可

直接基于项目：[Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot)。动画原稿：[Voidpoket](https://github.com/Voidpoket)。上游移植：[dsh-550c-boot](https://github.com/yannicksong0106/dsh-550c-boot)，Copyright (c) 2026 Ziyang Song。macOS 播放器为本衍生版本新增内容。完整声明见 [NOTICE.md](../NOTICE.md)、[LICENSE](../LICENSE) 和 [TRADEMARKS.md](../TRADEMARKS.md)。
