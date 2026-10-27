# ChatGPT 550C Boot macOS

**基于 [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) 添加 macOS 支持的衍生版本。** 本版本新增 Mac 原生启动器和构建打包流程，沿用上游的 550C 动画。动画原稿作者为 **[Voidpoket](https://github.com/Voidpoket)**，上游移植来自 **[dsh-550c-boot](https://github.com/yannicksong0106/dsh-550c-boot)**，版权声明见 [NOTICE.md](NOTICE.md)。

双击 `ChatGPT 550C.app`，播放器在全屏动画背后预先打开 ChatGPT。动画结束后保留最后一帧，等待 ChatGPT 窗口准备好，再以约 **0.25 秒**淡出并切换到 ChatGPT。授权窗口调整后，ChatGPT 会铺满当前屏幕的可用区域，保留菜单栏，不切换到 macOS 原生全屏空间。

这是基于原项目新增的 macOS 启动体验；当前版本不设置 Mac 登录自启动，也不修改 ChatGPT 客户端。

## macOS 版本新增内容

- 使用 AppKit 与系统 WebKit 播放本地动画，无需 Chrome、Edge 或额外网页依赖。
- 支持完整动画、仅 Logo、直接打开三种模式。
- 支持 Esc、右上角 SKIP 和 Command-W 跳过；Command-Q 关闭播放器，已预启动的 ChatGPT 保持运行。
- 跳过按钮在 Logo 阶段也可使用，并调整其顶部位置以适应刘海屏。
- 播放动画时在后台预先打开 ChatGPT，减少动画结束后的等待。
- 动画结束后保留最后一帧，等待目标窗口准备好，再以约 0.25 秒淡出。
- 获得“辅助功能”权限后，将 ChatGPT 窗口铺满当前屏幕的可用区域，保留菜单栏；不进入新的原生全屏空间。
- 未授予窗口调整权限时，仍可预启动 ChatGPT 和淡出衔接，窗口保持现有大小。
- 提供从源码构建的脚本、Mac 发布压缩包和 SHA-256 校验文件。

macOS 启动器与打包代码位于 [`macos/`](macos/)，原 Windows 启动器保留在 [`launcher/`](launcher/)。[上游 README 在线版](https://github.com/Chenchu0o0/chatgpt-550c-boot/blob/edb05d5bf72633a9b5b4ee40c36e4fae72cc3359/README.md) 可用于查阅原项目说明；[本地原文存档](docs/README.windows-upstream.md) 保留其原有内容，其中相对链接对应上游仓库目录。

## 下载和使用

1. 在本仓库的 **Releases** 中下载 `ChatGPT-550C-macOS-v1.1.0-universal.zip`。
2. 解压，将 `ChatGPT 550C.app` 拖入“应用程序”文件夹。
3. 确认已安装 ChatGPT，双击 `ChatGPT 550C.app` 即可播放。
4. 如需自动铺满 ChatGPT 窗口，按住 **Option** 键打开启动器，点“设置窗口铺满权限”，在 macOS 设置中手动授予 `ChatGPT 550C` “辅助功能”权限。
5. 如需更改模式，同样按住 **Option** 键打开启动器，选择后保存。应用菜单中的“设置窗口铺满权限…”也可打开权限设置。

本启动器仅使用“辅助功能”权限来检测和调整 ChatGPT 主窗口；后台预启动和动画淡出不依赖这项权限。权限须由使用者自行授予，启动器不会自动启用。更新后若开关已开启但仍不能铺满，请按[使用说明](docs/macOS使用说明.md)重新添加当前版本的授权条目。

发布包采用本地 ad-hoc 签名，未使用 Apple Developer ID 签名，也未经 Apple 公证。从互联网下载后，macOS 可能阻止首次打开。请先核验下载来源及校验值，再自行决定是否按 [Apple 官方说明](https://support.apple.com/zh-cn/102445) 打开。

完整操作见 [macOS 使用说明](docs/macOS使用说明.md)。

## 兼容性和验证范围

| 项目 | 状态 |
| --- | --- |
| 构建目标 | macOS 13 及以上 |
| Universal 发布包 | 包含 Apple Silicon `arm64` 与 Intel `x86_64` 两种架构 |
| 实机验证 | Apple Silicon，macOS 26.3.1 |
| 未实机验证 | Intel Mac 及较早的 macOS 版本 |
| 动画时长 | 当前固定源码完整模式约 11–14 秒，仅 Logo 约 5 秒 |

上游 README 提到约 90 秒；本版本沿用的固定提交中，动画时间线已较短，以上时长来自本机实测，最终切换还取决于 ChatGPT 窗口的准备时间。动画内容仍以随包源码为准。

基础播放验证覆盖 47 个节点完成与最终画面、快速模式、跳过、超时保护及打开 ChatGPT。v1.1.0 通过 86 项衔接状态检查，并在本机验证后台预启动、授权后的窗口铺满及淡出切换；ChatGPT 已运行时，动画结束至切换完成约 0.4 秒。首次进程冷启动未实机计时。窗口自动铺满需要使用者在自己的 Mac 上授予“辅助功能”权限。

## 从源码构建

需要 macOS、Python 3，以及包含 Swift 编译器的 Xcode Command Line Tools。进入仓库根目录执行：

```sh
python3 macos/build.py --arch universal
```

也可仅构建单一架构：

```sh
python3 macos/build.py --arch arm64
python3 macos/build.py --arch x86_64
```

发布文件输出到 `dist/`。构建流程不从本机 ChatGPT 中提取图标，生成的应用使用本版本制作的几何风格 550C 图标。

## 原作者与来源

| 部分 | 来源与作者 |
| --- | --- |
| 本版本直接基于的项目 | [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) |
| 固定基础版本 | [`edb05d5bf72633a9b5b4ee40c36e4fae72cc3359`](https://github.com/Chenchu0o0/chatgpt-550c-boot/commit/edb05d5bf72633a9b5b4ee40c36e4fae72cc3359) |
| 550C 动画原稿 | [Voidpoket](https://github.com/Voidpoket) |
| 动画的上游移植与定点改写 | [dsh-550c-boot](https://github.com/yannicksong0106/dsh-550c-boot)，Copyright (c) 2026 Ziyang Song |
| 本衍生版本新增 | macOS 原生播放器、构建打包脚本、几何图标与 Mac 文档 |

`550c-overlay.html` 保留原始内容和原作者声明，macOS 启动器仅在载入时注入适配逻辑。完整来源与许可见 [NOTICE.md](NOTICE.md) 和 [LICENSE](LICENSE)。

## 许可与第三方素材

代码沿用上游 **MIT License**；新增 macOS 代码同样按该许可证提供。原始版权声明完整保留。

上游的 OpenAI 商标图标未纳入本分发版本，Windows 脚本可使用其原有图标回退逻辑。“550C”的电影设定、ChatGPT 与 OpenAI 名称和商标仍归各自权利人所有；代码的 MIT 许可证不授予这些第三方权利。见 [TRADEMARKS.md](TRADEMARKS.md)。本项目与 OpenAI、电影权利方及上游作者之间不存在官方合作或背书关系。

## 发布到自己的 GitHub

请保留本 README 中的衍生版本说明及来源链接，并保留 `LICENSE`、`NOTICE.md`、`TRADEMARKS.md`。在 GitHub Desktop 中检查本地修改、提交并推送后，再创建 Release。版本变化见 [CHANGELOG.md](CHANGELOG.md)，源码上传和 Release 附件步骤见 [macOS Release 发布说明](docs/macOS-Release说明.md)。
