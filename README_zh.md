# MagicTapper

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="magictapper-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="magictapper-light.png">
  <img alt="MagicTapper Logo" src="magictapper-light.png">
</picture>

**让你的 Apple Magic Mouse 支持轻点点击！** (v1.1)

[English](README.md) | 中文 | [日本語](README_ja.md)

MagicTapper 为 Apple Magic Mouse 带来了类似触控板的轻点点击功能。只需轻触鼠标表面即可点击，无需再按压按钮。

## ✨ 功能特性

- 🖱️ **轻点左侧** → 左键点击
- 🖱️ **长按右侧（>0.1秒）** → 右键点击（防误触）
- 🎯 **双击并按住** → 拖拽
- ⚡ **快速响应** - 优化至最低延迟
- 🚀 **开机自启** - 随 macOS 自动启动
- 🎛️ **轻松切换** - 菜单栏一键开关
- 🔒 **注重隐私** - 完全本地运行，无网络访问

## 📋 系统要求

- macOS 13.0（Ventura）或更高版本
- Apple Magic Mouse（第一代或第二代）
- 通过蓝牙连接

## 🚀 安装

### 快速安装（推荐）

使用自动安装脚本：

```bash
# 进入仓库目录
cd /path/to/magictapper

# 运行安装脚本
bash install-final.sh
```

脚本将会：
- 构建优化版本（如需要）
- 停止正在运行的实例
- 备份旧版本（如存在）
- 安装到 /Applications
- 引导首次启动

### 手动安装

```bash
# 方式一：使用预编译版本
cd /path/to/magictapper
cp -r build/MagicTapper.app /Applications/

# 方式二：从源码构建
bash build.sh
cp -r build/MagicTapper.app /Applications/
```

### 授予权限

1. 从"应用程序"文件夹打开 **MagicTapper**
2. 看到权限请求时，点击 **"打开系统设置"**
3. 在 **隐私与安全性 → 辅助功能** 中启用 **MagicTapper** ✓
   - 如果应用不在列表中，点击 **+** 按钮添加 `/Applications/MagicTapper.app`
4. 返回 MagicTapper — 权限开启后自动开始工作（无需重启）

完成！你会在菜单栏看到鼠标图标。

## 📖 使用方法

### 基本操作

1. 在菜单栏（屏幕右上角）找到 **鼠标图标** 🖱️
2. **轻触 Magic Mouse 表面**：
   - **快速轻点左侧** = 左键点击
   - **长按右侧（≥0.1秒）** = 右键点击（上下文菜单）
   - **双击并按住** = 拖拽
3. 你仍然可以正常按压鼠标按钮 — 轻点只是额外的点击方式

### 菜单栏控制

点击菜单栏的鼠标图标可访问：

- **Status** - 显示运行状态
- **Tap to Click** - 开启/关闭功能（勾选表示已启用）
- **Launch at Login** - 随 macOS 自动启动（勾选表示已启用）
- **Accessibility Instructions** - 权限设置帮助
- **About** - 版本信息和功能介绍
- **Quit** - 退出应用

### 使用技巧

- 💡 **左键点击**：在左侧快速轻点
- 💡 **右键点击**：在右侧按住超过 0.1 秒后松开
- 💡 **拖拽**：快速双击，第二次点击时保持按住，然后移动
- 💡 左右分界线大约在左起 60% 的位置
- 💡 临时禁用：在菜单栏关闭 "Tap to Click"

## ⚠️ 重要说明

### 关于私有框架

MagicTapper 使用 Apple 的私有框架 **MultitouchSupport** 来检测 Magic Mouse 上的触摸。

**这意味着：**

- ✅ **可以安全使用** - 许多应用都在使用此框架
- ✅ **在当前 macOS 版本上运行良好**
- ❌ **无法上架 Mac App Store** - Apple 不允许 App Store 应用使用私有框架
- ⚠️ **未来更新** - 可能在重大 macOS 更新后失效（根据历史经验，可能性较低）

**隐私保护：** 应用仅监控 Magic Mouse 的触摸。不收集数据，不访问网络，不发送任何信息。

## 🐛 故障排除

### 轻点不起作用

**检查权限：**
1. 前往 **系统设置 → 隐私与安全性 → 辅助功能**
2. 确保 **MagicTapper** 在列表中并已 **勾选** ✓
3. 如果消失了（重新构建后），点击 **+** 重新添加 `/Applications/MagicTapper.app`
4. 将复选框关闭再打开一次 — 应用会立即检测到变化

**检查 Magic Mouse：**
1. 前往 **系统设置 → 蓝牙**
2. 确认 Magic Mouse 显示为"已连接"
3. 移动鼠标确认其正常工作

### 应用无法启动

**"应用已损坏"错误：**
- 这是非 App Store 应用的正常现象
- 右键点击 MagicTapper → **打开** → 在对话框中再次点击 **打开**
- 或者：前往 **系统设置 → 隐私与安全性**，点击 **仍要打开**

## 🗑️ 卸载

```bash
# 删除应用
rm -rf /Applications/MagicTapper.app

# 从登录项移除（如果添加过）
# 系统设置 → 通用 → 登录项 → 移除 MagicTapper

# 撤销权限（可选）
# 系统设置 → 隐私与安全性 → 辅助功能 → 移除 MagicTapper
```

## 💖 支持项目

如果这个项目对你有帮助，欢迎支持开发：

- ⭐ 在 GitHub 上点个 Star
- 🐛 发现 Bug 请提 Issue
- 🔀 欢迎提交 Pull Request
- 📢 分享给其他 Magic Mouse 用户

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/your_username)

## 🙏 致谢

使用 Claude Code（Sonnet 4.5）通过"氛围编程"创建

为了解决 macOS 的一个遗憾而制作 — 为什么触控板有轻点点击，Magic Mouse 却没有？

感谢逆向工程社区对 MultitouchSupport 框架的解析和文档化，使得这类应用成为可能。

---

**享受全新的轻点点击 Magic Mouse 吧！** 🎉

*为热爱 Magic Mouse 但希望它能轻点点击的 Mac 用户而作。*
