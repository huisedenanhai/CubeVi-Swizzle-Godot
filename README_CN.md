<div align="center">

[English](./README.md) | [中文](./README_CN.md)

</div>

# CubeVi Swizzle Godot

Godot 光场显示器支持，适配 [Companion 01](https://www.openstageai.com/companion1) 设备。移植自[官方 Unity SDK](https://github.com/CubeVi/CubeVi-Swizzle-Unity)。

目前已在 macOS/Linux (Wayland) 上测试通过。使用 HDMI 线连接显示器后，按照以下平台设置进行配置。

## 平台

### macOS

1. 系统设置 -> 显示器。将分辨率设置为 720x1280

Mac 会对所有显示器应用相同的 DPI 缩放。需要手动降低分辨率以获得正确的最终输出尺寸。

![](./imgs/settings.png)

2. 从 Windows 机器复制设备校准信息。

该设备仅官方支持 Windows。在 Windows 机器上安装 [OpenstageAI](https://www.openstageai.com/openstageAI)，连接设备并进行校准。

校准结果位于 `%APPDATA%\OpenstageAI\deviceConfig.json`。将该文件发送到 Mac，放置到 `~/Library/Application\ Support/OpenstageAI/deviceConfig.json`（如果文件夹不存在需手动创建）。

3. 用 Godot 打开项目

需要手动禁用编辑器中的嵌入窗口。

点击运行按钮。带有视差效果的 3D 内容将显示在显示器上。

### Linux (Wayland)

1. 将设备校准信息从 Windows 机器复制到 `~/.config/OpenstageAI/deviceConfig.json`

2. 用 Godot 打开项目
