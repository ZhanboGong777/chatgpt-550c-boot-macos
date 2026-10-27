# macOS Release 发布说明

这是基于 [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) 添加 macOS 支持的衍生版本。准备发布的版本为 `v1.1.1`。

## 上传源码

建议在 GitHub 上 Fork 上游仓库，以保留可见的来源关系，然后把本版本的文件提交到自己的 Fork。如果使用独立仓库，也请完整保留 README 首页的衍生版本说明及上游链接。

上传源码目录中的文件，包括隐藏的 `.github`、`.gitignore` 和 `.gitattributes`。不需要上传 `dist/`、临时构建目录、个人设置或本机测试报告；二进制安装包应作为 Release 附件。

使用 Finder 查看解压后的源码时，可按 **Command-Shift-.** 显示隐藏文件。上传的是项目目录内的内容，使 `README.md` 直接位于仓库根目录。如果通过 Fork 同步此版本，也请同步移除原有的 `icons/*.ico`，与本分发版本的图标说明保持一致。

源码应保留：

- `README.md` 中“基于原项目添加 macOS 支持”的说明。
- 未删减的 `LICENSE` 与 `TRADEMARKS.md`。
- 保留原文并附加 macOS 声明的 `NOTICE.md`。
- `550c-overlay.html` 中的原始来源和版权注释。
- `docs/README.windows-upstream.md` 中保存的上游 README。

本分发版本没有包含上游 OpenAI 商标图标。新增几何风格 550C 图标随 Mac 应用构建，未从本机 ChatGPT 中提取素材。

## 构建 Release 附件

在仓库根目录执行：

```sh
python3 macos/build.py --arch universal
```

将 `dist/` 中生成的以下文件添加到 GitHub Release：

- `ChatGPT-550C-macOS-v1.1.1-universal.zip`
- `SHA256SUMS`

也可用 `--arch arm64` 或 `--arch x86_64` 分别生成单一架构包，文件名中的架构后缀随之变化。各架构只需上传实际构建并检查的文件。

## 创建 GitHub Release

1. 在 GitHub Desktop 中打开本地仓库，检查 **Changes** 中显示的修改，填写提交说明并自行提交，再推送到自己的 GitHub 仓库。更新后的版本号、源码与文档均应一起提交。
2. 在仓库的 Releases 中创建新 Release，标签填写 `macos-v1.1.1`，与 Mac 构建工作流一致。
3. 标题可使用 `ChatGPT 550C macOS v1.1.1`。
4. 使用下方的发布正文，并上传 Mac 压缩包及 SHA-256 校验文件。
5. 检查源码来源说明、附件文件名及测试范围后，再发布 Release。

仓库包含 **Build macOS release** 工作流，可在 Actions 中手动运行，也会在推送 `macos-v*` 标签时构建。它只构建并上传 Actions 附件，不会自动发布 GitHub Release。构建脚本在本机已执行验证；GitHub Actions 需上传到自己的仓库后再实际运行。

如需重新生成用于上传仓库的纯源码 ZIP，可运行：

```sh
python3 scripts/package-source.py
```

解压生成的源码包后，上传其中的项目文件；该包排除了构建缓存、安装包与个人测试数据。

## 可直接使用的发布正文

基于 [Chenchu0o0/chatgpt-550c-boot](https://github.com/Chenchu0o0/chatgpt-550c-boot) 添加 macOS 支持。

v1.1.1 修正启动过程中的进程检测：优先复用已运行且有窗口的 ChatGPT；原进程退出时，继续查找同一路径下的接续进程，并丢弃旧进程的检测结果。动画结束后的等待最多为 8 秒；确实退出或窗口一直未就绪时会提示相应情况。

播放 550C 动画时，仍会在后台预先打开 ChatGPT；动画结束后保留最后一帧，等待窗口准备好，再以约 0.25 秒淡出。

授予“辅助功能”权限后，启动器会把 ChatGPT 窗口铺满当前屏幕的可用区域，保留菜单栏，不进入 macOS 原生全屏空间。该权限仅用于自动窗口调整；不授权也能使用后台预启动与淡出衔接。按住 Option 打开，在模式窗口中点“设置窗口铺满权限”，即可前往系统设置由自己手动授权；应用菜单也提供同名入口。

支持 Esc、SKIP、Command-W 跳过剩余动画；按住 Option 打开可切换模式。Command-Q 退出播放器时，已经预启动的 ChatGPT 会保持运行，原有 ChatGPT 应用也不会被退出或重启。

- Universal 包含 Apple Silicon 与 Intel 两种架构，构建目标为 macOS 13 及以上。
- 实机验证：Apple Silicon，macOS 26.3.1。Intel 与较早系统未实机验证。
- 当前固定动画源码完整模式约 11–14 秒，仅 Logo 约 5 秒；最终切换还取决于 ChatGPT 窗口的准备时间。
- 下载后解压，将应用拖入“应用程序”文件夹。校验值见 `SHA256SUMS`。
- 应用仅有本地 ad-hoc 签名，未使用 Developer ID，也未经 Apple 公证；下载后的首次打开可能受 macOS 门禁限制。

动画原稿作者为 [Voidpoket](https://github.com/Voidpoket)，上游移植来自 [dsh-550c-boot](https://github.com/yannicksong0106/dsh-550c-boot)，Copyright (c) 2026 Ziyang Song。本版本直接基于原仓库提交 [`edb05d5bf72633a9b5b4ee40c36e4fae72cc3359`](https://github.com/Chenchu0o0/chatgpt-550c-boot/commit/edb05d5bf72633a9b5b4ee40c36e4fae72cc3359)，保留原始许可与来源声明。动画及 550C 设定的相关权利归各自作者与权利人所有；本版本新增内容是 macOS 适配。

## 签名说明

仓库的构建流程使用本地 ad-hoc 签名检查应用包完整性，没有 Apple 开发者身份认证或公证。如果后续需要提供 Developer ID 签名和公证版本，应由仓库维护者使用自己的 Apple 开发者账户完成，并相应更新 README 和 Release 的签名说明。
