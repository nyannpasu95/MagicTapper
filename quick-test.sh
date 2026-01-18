#!/bin/bash

# Quick test script - tests if the app is working

echo "=========================================="
echo "MagicTapper 快速测试"
echo "=========================================="
echo ""

# 停止所有实例
killall MagicTapper 2>/dev/null
killall MagicTapper_Debug 2>/dev/null
sleep 1

# 检查构建
if [ ! -d "build/MagicTapper.app" ]; then
    echo "❌ 未找到构建文件，正在构建..."
    bash build.sh
    echo ""
fi

echo "📋 测试清单："
echo ""
echo "1. ✓ 启动应用"
echo "   - 打开应用"
echo "   - 授予辅助功能权限（如需要）"
echo ""
echo "2. ✓ 基础测试"
echo "   - 检查菜单栏是否显示鼠标图标 🖱️"
echo "   - 点击图标，查看菜单"
echo ""
echo "3. ✓ 左键测试"
echo "   - 在 Magic Mouse 左侧快速轻触"
echo "   - 应该触发左键点击"
echo ""
echo "4. ✓ 右键测试"
echo "   - 在 Magic Mouse 右侧按住 0.15 秒"
echo "   - 应该弹出右键菜单"
echo ""
echo "5. ✓ 拖拽测试"
echo "   - 在文件上快速点击两次"
echo "   - 第二次按住不放并移动"
echo "   - 文件应该跟随移动"
echo ""
echo "=========================================="
echo ""

# 询问测试方式
echo "选择测试方式："
echo "  1) 正常运行（无调试输出）"
echo "  2) 调试运行（显示详细输出）"
echo ""
read -p "请选择 (1/2): " choice

echo ""

case $choice in
    2)
        echo "🔍 以调试模式运行..."
        echo "   查看终端输出以了解应用行为"
        echo "   按 Ctrl+C 停止"
        echo ""
        sleep 2
        bash debug-run.sh
        ;;
    *)
        echo "🚀 以正常模式运行..."
        echo "   在 Magic Mouse 上测试各种手势"
        echo ""
        open build/MagicTapper.app
        sleep 2

        # 检查是否运行
        if pgrep -x "MagicTapper" > /dev/null; then
            echo "✅ 应用已启动"
            echo ""
            echo "💡 提示："
            echo "   - 如果不工作，运行: bash debug-run.sh"
            echo "   - 查看调试输出以了解问题"
        else
            echo "❌ 应用启动失败"
            echo ""
            echo "尝试调试模式："
            echo "   bash debug-run.sh"
        fi
        ;;
esac

echo ""
