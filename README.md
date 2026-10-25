# MyRight

给自己使用的 macOS Finder 右键工具。当前版本 **0.2.1**。

- **新建文件**：Word、Excel、PowerPoint、Pages、Numbers、Keynote、Markdown、TXT。创建标准空白文档，选中后按回车改名，重名时自动编号。
- **在终端打开**：在文件夹空白处打开当前目录，或右键单个文件夹打开该文件夹。
- **拷贝路径**：在空白处拷贝当前目录；右键单个文件或文件夹，拷贝所选项目的完整路径。
- **转换图片格式**：右键单张图片，选择 PNG、JPEG、HEIC 或 TIFF。结果保存在原目录，保留原图，重名时自动编号。
- **安静运行**：右键动作在后台交给主 App，不激活 MyRight 或打开设置窗口。设置通过菜单栏 MyRight 图标中的“MyRight 设置…”打开。

新图标采用深靛蓝底色与自绘的冰银色 R 字标，右下斜笔带有蓝色玻璃质感。设计参考 [Apple 的 App 图标指南](https://developer.apple.com/design/human-interface-guidelines/app-icons/) 中清晰主体、可辨识轮廓及适当层次的方向；使用本项目的矢量绘制源码生成静态 macOS 图标。

第一版的位置范围保持为个人主目录中的本机普通文件和文件夹，暂不覆盖移动硬盘、网络共享和云盘。当前按单个所选项目操作，不提供多选批量转换。

## 使用

1. 打开 `/Applications/MyRight.app`。
2. 点按菜单栏的 MyRight 图标，选择“MyRight 设置…”。设置不会在每次启动或执行右键动作时自动弹出。
3. 如未启用扩展，通过设置窗口的“打开扩展设置”在系统设置中启用 MyRight。
4. 在 Finder 中右键空白处、文件夹或单张图片，使用对应菜单。

首次访问桌面、文稿等受保护位置时，按照 macOS 的提示允许访问相应目录。登录启动状态以设置中显示的系统反馈为准，可自行关闭。

不需要安装 Office 或 iWork 才能创建文档：App 直接复制随包提供的有效空白文档。编辑时需要对应应用或其他兼容软件。iWork 模板由本机 Pages、Numbers 和 Keynote 实际创建、保存，未使用其他格式改扩展名。

图片转换保持原始像素尺寸并处理 EXIF 旋转方向；JPEG 不支持透明背景，透明区域会填充为白色。动画和多页图片会报告错误，避免只保留第一帧。输出是新编码的图片，不承诺保留原图的全部附加元数据。

## 构建与检查

需要 macOS 13+ 和 Apple Command Line Tools。无第三方运行时依赖，不要求完整 Xcode。

```sh
bash scripts/build.sh
bash scripts/test.sh
bash scripts/test_background.sh
bash scripts/test_images.sh
```

输出为 `build/MyRight.app`，默认只为当前 Mac 架构构建并使用本机临时签名。可通过 `MYRIGHT_SIGN_IDENTITY` 指定已有证书。这是本机开发版本，没有公证。

图片编码、剪贴板及完整动作链路检查需要在已登录的 macOS 桌面会话中访问相应系统服务。

安装 App 后，可运行：

```sh
bash scripts/test_finder_dispatch.sh --integration
```

该检查重建 Finder 回传的菜单项，通过真实扩展动作方法、系统后台打开接口及已安装的 App，验证八种文件、拷贝路径和四种图片转换。测试在项目 `build/` 内创建样例文件，暂存并恢复原剪贴板，还会打开测试目录的终端。它会检查 MyRight 没有被激活、没有显示设置窗口。

## 实现

- `Sources/Core`：文件类型、请求协议、目录校验、文件创建、图片转换。
- `Sources/FinderExtension`：Finder 菜单、目录与所选项目上下文、后台动作发送。
- `Sources/App`：菜单栏、设置、登录启动、剪贴板和动作执行。
- `Resources/Templates`：Office 与 iWork 空白文档，构建时直接打包。
- `scripts/generate_icon.swift`：原创矢量图标生成源码，包含多种分辨率。
- `Tests`：协议、防覆盖、目录范围、重建菜单回调、后台启动、剪贴板、图片转换测试。

Finder 回传的菜单项不依赖 `representedObject` 保存动作数据；独立动作方法从扩展主对象取得上下文。发送请求时明确指定同包的主 App，并设置 `activates = false`。主 App 不在重新打开事件或延时启动回调中显示设置。

图片转换使用系统 Image I/O，在后台处理并以“不覆盖”方式写入。Terminal 通过 NSWorkspace 打开目录，不拼接终端命令。不使用辅助功能权限或模拟键盘操作来实现产品功能。

Finder Sync 官方定位是文件同步扩展，本项目使用其菜单能力探索个人工具。具体的系统版本、受保护目录授权和登录启动仍需要真实环境验证。

详细证据、检查范围和历史记录见 [VALIDATION.md](VALIDATION.md)。参考：[Finder Sync](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)、[后台打开配置](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration)、[Image I/O](https://developer.apple.com/documentation/imageio)。
