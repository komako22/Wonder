## Wonder v0.5.4

### 关键修复

- 完全移除 macOS 的 `CGEvent` Command+C 模拟，不再有任何路径发送 C 键。
- 完全移除 Windows 的 `keybd_event` Ctrl+C 模拟，不再通过键盘注入读取选区。
- 划词只使用 macOS Accessibility 和 Windows UI Automation。
- 普通点击、双击桌面应用和 Shift+其他按键不会触发剪贴板读取或翻译气泡。
- 保留鼠标拖动距离判断，只有真实拖动选区才会读取文本。
- 设置页不再提供会修改剪贴板的“仅安全复制”模式。

### 下载说明

- `Wonder-v0.5.4-macOS-arm64.dmg`：Apple Silicon Mac 安装镜像。
- `Wonder-v0.5.4-macOS-arm64.zip`：Apple Silicon Mac 应用压缩包。
- `Wonder-v0.5.4-windows-x64.exe`：64 位 Windows 自包含单文件程序。

### 已知限制

不暴露 Accessibility / UI Automation 文本的应用无法进行划词翻译；Wonder 不再使用模拟复制作为兼容兜底，以确保不会改动剪贴板或误发送键盘输入。
