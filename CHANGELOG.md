# 版本记录

## 1.1.0

- 播放 550C 动画时，在后台预先打开 ChatGPT，减少动画结束后的等待。
- 动画结束后保留最后一帧，等待 ChatGPT 窗口准备好，再以约 0.25 秒淡出。
- 获得“辅助功能”权限后，自动将 ChatGPT 窗口铺满当前屏幕的可用区域，保留菜单栏；不进入 macOS 原生全屏空间。
- 在 Option 模式窗口和应用菜单中添加“设置窗口铺满权限”入口；权限由使用者在 macOS 设置中自行授予。
- 未授予窗口调整权限时，仍支持后台预启动和动画淡出，ChatGPT 保持现有窗口大小。
- Command-Q 退出播放器时，已预启动的 ChatGPT 保持运行；不退出或重新启动已有 ChatGPT 实例。

## 1.0.0

- 基于 [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) 添加 macOS 原生播放器。
- 使用 AppKit 与 WKWebView，支持完整动画、仅 Logo 与直接打开三种模式。
- 支持 Esc、SKIP 和 Command-W 跳过动画，以及 Option 启动时的模式选择。
- 提供 Apple Silicon、Intel 和 Universal 构建选项、发布压缩包及 SHA-256 校验文件。
- 保留上游动画、作者署名和 MIT 许可；发布包使用新增的几何风格 550C 图标。

动画原稿及上游移植的完整来源见 [NOTICE.md](NOTICE.md)。本版本的新增内容为 macOS 适配，未改称上游动画为本版本原创。
