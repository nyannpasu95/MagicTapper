#!/bin/bash

# MagicTapper v1.1 测试和安装脚本

set -e  # 遇到错误立即退出

APP_NAME="MagicTapper"
BUILD_PATH="build/MagicTapper.app"
INSTALL_PATH="/Applications/MagicTapper.app"

echo "=========================================="
echo "MagicTapper v1.1 测试和安装向导"
echo "=========================================="
echo ""

# 步骤1：卸载旧版本
echo "【步骤 1/5】检查并卸载旧版本..."
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "  → 正在退出旧版本..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 2
fi

if [ -d "$INSTALL_PATH" ]; then
    echo "  → 正在删除旧版本..."
    rm -rf "$INSTALL_PATH"
    echo "  ✓ 旧版本已删除"
else
    echo "  ✓ 未检测到已安装的版本"
fi
echo ""

# 步骤2：验证构建
echo "【步骤 2/5】验证构建文件..."
if [ ! -d "$BUILD_PATH" ]; then
    echo "  ✗ 错误：未找到构建文件"
    echo "  请先运行: bash build.sh"
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$BUILD_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$BUILD_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown")

echo "  应用版本: $VERSION"
echo "  最低系统版本: macOS $MIN_OS"
echo "  ✓ 构建文件验证成功"
echo ""

# 步骤3：测试运行
echo "【步骤 3/5】启动测试版本..."
echo ""
echo "  正在打开 $BUILD_PATH"
echo ""
open "$BUILD_PATH"

echo "=========================================="
echo "请进行以下测试："
echo "=========================================="
echo ""
echo "✓ 基础测试"
echo "  1. 检查菜单栏是否显示鼠标图标"
echo "  2. 点击菜单栏图标，检查菜单内容"
echo "  3. 确认状态显示为 'Status: Running'"
echo ""
echo "✓ 点击测试（在 Magic Mouse 上）"
echo "  4. 左键点击：在鼠标左侧轻触"
echo "  5. 右键点击：在鼠标右侧按住 >0.1秒"
echo ""
echo "✓ 拖拽测试"
echo "  6. 拖拽文件：快速点击两次，第二次按住不放并移动"
echo "  7. 拖拽窗口：在窗口标题栏双击并按住移动"
echo ""
echo "✓ 功能测试"
echo "  8. 切换 'Tap to Click' 开关"
echo "  9. 查看 'About MagicTapper' 信息"
echo " 10. 测试 'Launch at Login' 功能"
echo ""
echo "=========================================="
echo ""

# 等待用户确认
read -p "测试完成后，是否安装到 /Applications? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "安装已取消。"
    echo ""
    echo "如需手动测试，运行："
    echo "  open $BUILD_PATH"
    echo ""
    echo "如需手动安装，运行："
    echo "  cp -r $BUILD_PATH /Applications/"
    echo ""
    exit 0
fi

echo ""

# 步骤4：退出测试版本
echo "【步骤 4/5】退出测试版本..."
if pgrep -x "$APP_NAME" > /dev/null; then
    killall "$APP_NAME" 2>/dev/null || true
    sleep 2
    echo "  ✓ 测试版本已退出"
else
    echo "  ✓ 测试版本未在运行"
fi
echo ""

# 步骤5：安装
echo "【步骤 5/5】安装到 /Applications..."
cp -r "$BUILD_PATH" "$INSTALL_PATH"

# 验证安装
if [ -d "$INSTALL_PATH" ]; then
    echo "  ✓ 安装成功！"
    echo ""
    echo "=========================================="
    echo "✅ MagicTapper v$VERSION 已安装"
    echo "=========================================="
    echo ""
    echo "安装路径: $INSTALL_PATH"
    echo ""

    # 询问是否立即启动
    read -p "是否立即启动应用？(y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "正在启动 MagicTapper..."
        open "$INSTALL_PATH"
        sleep 2
        echo ""
        echo "✓ 应用已启动"
        echo ""
        echo "提示："
        echo "  • 首次运行需要授予无障碍权限"
        echo "  • 在菜单栏点击鼠标图标可查看选项"
        echo "  • 如需设置开机自启动，请在菜单中启用 'Launch at Login'"
    else
        echo ""
        echo "你可以随时从以下位置启动应用："
        echo "  • Launchpad > MagicTapper"
        echo "  • /Applications/MagicTapper.app"
    fi
else
    echo "  ✗ 安装失败"
    exit 1
fi

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
