#!/bin/bash

# Final installation script for optimized MagicTapper v1.1

set -e

APP_NAME="MagicTapper"
BUILD_PATH="build/MagicTapper.app"
INSTALL_PATH="/Applications/MagicTapper.app"

echo "=========================================="
echo "MagicTapper v1.1 最终安装"
echo "=========================================="
echo ""
echo "✅ 优化版本 - 已移除所有调试输出"
echo "✅ 性能提升 - 更快的响应速度"
echo "✅ 生产就绪 - 适合日常使用"
echo ""

# 检查构建文件
if [ ! -d "$BUILD_PATH" ]; then
    echo "❌ 未找到构建文件"
    echo "正在构建优化版本..."
    echo ""
    bash build.sh
    echo ""
fi

# 显示版本信息
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$BUILD_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$BUILD_PATH/Contents/Info.plist" 2>/dev/null || echo "unknown")

echo "📦 准备安装："
echo "   应用版本: $VERSION (Build $BUILD)"
echo "   构建类型: Production (Optimized)"
echo "   架构: Universal Binary (arm64 + x86_64)"
echo ""

# 停止正在运行的实例
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "🛑 停止正在运行的实例..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 2
fi

# 备份旧版本（如果存在）
if [ -d "$INSTALL_PATH" ]; then
    echo "📦 备份旧版本..."
    BACKUP_PATH="/Applications/MagicTapper_backup_$(date +%Y%m%d_%H%M%S).app"
    mv "$INSTALL_PATH" "$BACKUP_PATH"
    echo "   旧版本已备份到: $BACKUP_PATH"
    echo ""
fi

# 安装新版本
echo "📥 安装新版本到 /Applications..."
cp -r "$BUILD_PATH" "$INSTALL_PATH"

# 验证安装
if [ -d "$INSTALL_PATH" ]; then
    echo "✅ 安装成功！"
    echo ""

    # 显示功能列表
    echo "=========================================="
    echo "功能列表"
    echo "=========================================="
    echo ""
    echo "✨ 左键点击"
    echo "   在 Magic Mouse 左侧快速轻触"
    echo ""
    echo "✨ 右键点击"
    echo "   在 Magic Mouse 右侧按住 ≥0.1秒"
    echo ""
    echo "✨ 拖拽操作"
    echo "   快速双击，第二次按住不放并移动"
    echo ""
    echo "✨ 开机自启动"
    echo "   菜单栏 > Launch at Login"
    echo ""
    echo "✨ 启用/禁用"
    echo "   菜单栏 > Tap to Click"
    echo ""
    echo "=========================================="
    echo ""

    # 询问是否立即启动
    read -p "是否立即启动应用？(Y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo "🚀 启动 MagicTapper..."
        open "$INSTALL_PATH"
        sleep 2

        # 检查是否成功启动
        if pgrep -x "$APP_NAME" > /dev/null; then
            echo "✅ 应用已成功启动"
            echo ""
            echo "💡 提示："
            echo "   • 查看菜单栏的鼠标图标 🖱️"
            echo "   • 首次运行需要授予辅助功能权限"
            echo "   • 在菜单中可以设置开机自启动"
            echo ""
        else
            echo "⚠️ 应用可能未成功启动"
            echo "   请手动从 Launchpad 或 Applications 文件夹启动"
            echo ""
        fi
    else
        echo ""
        echo "✅ 安装完成"
        echo ""
        echo "启动方式："
        echo "   • Launchpad > MagicTapper"
        echo "   • Finder > 应用程序 > MagicTapper.app"
        echo "   • 命令行: open /Applications/MagicTapper.app"
        echo ""
    fi

    echo "=========================================="
    echo "安装完成！"
    echo "=========================================="
    echo ""
    echo "📚 文档："
    echo "   • 功能说明: newfeature.md"
    echo "   • 调试指南: DEBUG_GUIDE.md"
    echo "   • 优化记录: OPTIMIZATION.md"
    echo ""
    echo "🐛 问题排查："
    echo "   如遇问题，运行: bash debug-run.sh"
    echo ""
    echo "感谢使用 MagicTapper v$VERSION！"
    echo ""

else
    echo "❌ 安装失败"
    exit 1
fi
