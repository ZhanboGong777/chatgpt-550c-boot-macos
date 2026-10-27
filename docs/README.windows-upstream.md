<div align="center">

# ChatGPT 550C Boot

**为 ChatGPT for Windows 增加一段「启动前」全屏开机动画。**

以播放器覆盖层实现，不修改、不注入 ChatGPT/Codex 客户端任何文件，删除目录即完全卸载。

[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%2F%2011-0078D4?logo=windows&logoColor=white)](#环境要求)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Dependencies](https://img.shields.io/badge/dependencies-Chrome%20%7C%20Edge-lightgrey)](#环境要求)
[![No Admin](https://img.shields.io/badge/admin-not%20required-success)](#设计原则)

[工作原理](#工作原理) · [快速开始](#快速开始) · [参数](#参数) · [目录结构](#目录结构) · [已知限制](#已知限制)

</div>

![动画预览](examples/preview.png)

---

## 概述

ChatGPT 桌面应用（Microsoft Store 包 `OpenAI.Codex`，显示名「ChatGPT」）以只读方式安装，
无法在其中安全注入启动画面。本项目采用**启动前覆盖层（pre-launch overlay）**方案：

启动器先用 Chrome/Edge 以 kiosk 全屏模式载入一个自包含的 HTML 动画，播放结束后关闭覆盖层，
再通过 AppUserModelID 拉起 ChatGPT。整个过程不接触客户端资源、不写注册表、不需要管理员权限。

动画本体为致敬《流浪地球2》中 550C 的界面演绎，包含 Logo 书写与 47 节点覆写全流程，约 90 秒，可随时跳过。

## 特性

| 特性 | 说明 |
| --- | --- |
| 🎬 全屏开机动画 | 单个自包含 HTML，无网络请求、无外部依赖，离线可用 |
| ⏱ 三种模式 | `full`（完整）/ `simple`（仅 Logo）/ `off`（跳过动画直接启动） |
| ⏭ 随时跳过 | 动画期间按 <kbd>Esc</kbd> 或点击右上角 **SKIP** |
| 🧹 隔离运行 | 使用独立的临时浏览器配置目录，不影响日常浏览器数据 |
| 🗑 干净卸载 | 无注册表项、无系统目录写入，删除目录即卸载 |
| 🔒 零侵入客户端 | 不修改商店应用资源、不注入进程、无需管理员权限 |

## 工作原理

```
用户双击 ChatGPT.lnk / ChatGPT.cmd
        │
        ▼
launcher/ChatGPT-boot.ps1
        │  以 --kiosk 全屏打开 550c-overlay.html
        │  （独立临时配置目录，与日常浏览器隔离）
        ▼
   播放 550C 开机动画（约 90 秒，可 Esc / SKIP 跳过）
        │  动画结束 → 窗口标题变为 __550C_DONE__
        ▼
   关闭覆盖层 → 经 AUMID 启动 ChatGPT
```

**关键实现细节**

- **完成信号**：动画结束时将窗口标题置为 `__550C_DONE__`，启动器轮询该标题，
  最长等待 150 秒兜底。窗口被手动关闭时亦视为结束。
- **启动方式**：优先使用 AUMID（`OpenAI.Codex_<PublisherId>!App`）经
  `shell:AppsFolder` 启动，以保留正确的任务栏图标与窗口分组；
  仅在 AUMID 不可用时回退到 `Get-AppxPackage` 解析出的可执行文件路径。
- **浏览器隔离**：每次运行创建 `%TEMP%\chatgpt-boot-<GUID>` 作为
  `--user-data-dir`，因此不会读写你日常 Chrome/Edge 的配置、书签或登录状态；
  运行结束自动删除，并会在下次启动时清理超过 1 小时的残留目录。

> **关于包名**：商店包内部名为 `OpenAI.Codex`，但其**显示名为「ChatGPT」**，
> 即 ChatGPT for Windows 桌面应用（桌面版内置 Codex 能力）。
> 本项目启动的是 **ChatGPT 桌面应用**，与 Codex CLI 无关。

## 环境要求

- **操作系统**：Windows 10 / 11（开发与验证于 Windows 11）
- **ChatGPT 桌面应用**：Microsoft Store 包 `OpenAI.Codex`
- **浏览器**：Chrome 或 Edge（任一，用于渲染动画覆盖层）
- **权限**：普通用户即可，无需管理员

## 快速开始

```powershell
# 克隆或下载解压后，在本项目根目录执行

# 完整模式（默认，约 90 秒）
powershell -NoProfile -ExecutionPolicy Bypass -File launcher\ChatGPT-boot.ps1

# 仅 Logo 快速版（约 5 秒）
powershell -NoProfile -ExecutionPolicy Bypass -File launcher\ChatGPT-boot.ps1 -Mode simple

# 关闭动画，直接启动（等价于直接打开 ChatGPT）
powershell -NoProfile -ExecutionPolicy Bypass -File launcher\ChatGPT-boot.ps1 -Mode off
```

也可直接双击 `launcher\ChatGPT.cmd`。

### 创建桌面快捷方式

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Create-ChatGPTShortcut.ps1
```

运行后在桌面生成带 ChatGPT 图标的「ChatGPT」快捷方式；也可直接双击 `tools\install.bat` 一键完成。

> ⚠️ 若桌面已存在同名 `ChatGPT.lnk`，将被**覆盖且不备份**，执行前请注意。
> 另有 `-Location Taskbar` 参数，但 Windows 的任务栏固定状态由系统数据库维护，
> 仅写入固定目录**不会**让图标出现在任务栏上，该选项仅供实验。

## 参数

| 参数 | 取值 | 默认 | 说明 |
| --- | --- | --- | --- |
| `-Mode` | `full` / `simple` / `off` | `full` | 动画模式。`off` 表示不播放动画，直接启动 ChatGPT |
| `-DelaySec` | `0` – `60` | `1` | 动画结束后、拉起 ChatGPT 前的缓冲秒数 |

## 目录结构

```
chatgpt-550c-boot/
├── 550c-overlay.html                # 动画本体（自包含 HTML + CSS + JS）
├── launcher/
│   ├── ChatGPT-boot.ps1             # 启动器主脚本
│   └── ChatGPT.cmd                  # 双击入口
├── tools/
│   ├── Create-ChatGPTShortcut.ps1   # 桌面快捷方式创建
│   └── install.bat                  # 一键安装
├── icons/                           # 快捷方式图标（商标素材，见 TRADEMARKS.md）
├── docs/使用说明.md                  # 中文使用文档
├── examples/preview.png             # 动画预览图
├── LICENSE                          # MIT
├── NOTICE.md                        # 来源与版权声明（动画为派生作品）
└── TRADEMARKS.md                    # 商标与第三方素材说明
```

## 设计原则

1. **零侵入**：不修改、不注入、不打补丁，客户端资源保持原样。
2. **可完全卸载**：不在注册表或系统目录留下任何痕迹，删除目录即卸载干净。
3. **最小权限**：以普通用户身份运行，不请求提权。
4. **网络行为一致**：不修改任何网络设置，联网与登录行为与直接打开 ChatGPT 完全相同。

## 已知限制

- 依赖本机已安装的 Chrome 或 Edge；两者都不存在时会提示并直接启动 ChatGPT（无动画）。
- 动画依赖浏览器的窗口标题上报完成信号，因此不能改用无界面（headless）方式渲染。
- 覆盖层最长停留 150 秒，超时后自动关闭并继续启动 ChatGPT。
- 本项目是「启动前覆盖层」，并非修改客户端启动画面 —— 商店版资源为只读，无法安全注入。

## 卸载

1. 删除项目目录。
2. 如已创建，删除桌面「ChatGPT.lnk」。
3. 若某次运行被强制中断，可手动删除 `%TEMP%\chatgpt-boot-*` 残留目录（启动器也会自动清理超过 1 小时的残留）。

## 疑难排查

| 现象 | 原因与处理 |
| --- | --- |
| 双击后提示 `ChatGPT (OpenAI.Codex) not found.` | 未安装商店版 ChatGPT 桌面应用，或包名不符。可用 `Get-AppxPackage OpenAI.Codex` 确认。 |
| 提示 `Chrome/Edge not found.` | 未检测到 Chrome 或 Edge，将直接启动 ChatGPT。 |
| 首次运行先出现浏览器欢迎页 | 新配置目录的首次启动行为。后续运行会直接进入动画。 |
| 动画不播放，直接打开了 ChatGPT | 可能使用了 `-Mode off`，或未检测到浏览器。 |
| 任务栏出现空白图标 | 说明 AUMID 启动失败并回退到了可执行文件路径，可检查 `Get-StartApps` 是否包含 ChatGPT。 |

## 来源与致谢

> ⚠️ **`550c-overlay.html` 不是本项目的原创作品。** 它是派生作品，
> 完整来源与版权声明见 [NOTICE.md](NOTICE.md)。

| 部分 | 作者 | 说明 |
| --- | --- | --- |
| 动画原稿 | [Voidpoket](https://github.com/Voidpoket) | 550C 片头页面原稿，动画的实际创作者。配色、面板布局、时间线节奏均出自此稿 |
| 移植与定点改写 | [dsh-550c-boot](https://github.com/yannicksong0106/dsh-550c-boot) · Ziyang Song | `Copyright (c) 2026 Ziyang Song`，MIT 许可。其 `assets/550C-source.html` 即本动画的直接来源 |
| 本仓库调整 | 本项目 | 跳过按钮、触屏合成点击抑制等少量修改 |

「550C」设定出自电影《流浪地球2》（The Wandering Earth II）。该美术设定的相关权利
不属于本项目，也不属于上述任何一位代码作者。

## 免责声明

本项目为个人学习与美化用途，与 OpenAI 无任何关联，未获其授权或认可。
`icons/` 中的图标为 OpenAI 的 ChatGPT 商标素材，**不在 MIT 授权范围内**，
仅用于展示与个人使用；如需分发请自行替换为可授权素材，详见 [TRADEMARKS.md](TRADEMARKS.md)。
本项目不修改 ChatGPT 客户端本体，不涉及任何破解、越狱或逆向工程。

## 许可

本项目**自行编写**的部分（`launcher/`、`tools/`、文档）以 [MIT License](LICENSE) 授权。

`550c-overlay.html` 为派生作品，同时受上游 MIT 许可约束，版权声明与来源见 [NOTICE.md](NOTICE.md)。
`icons/` 与「550C」美术设定的说明见 [TRADEMARKS.md](TRADEMARKS.md)。

