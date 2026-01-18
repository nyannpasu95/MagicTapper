#!/bin/bash

# Debug runner script - runs the app in terminal with console output

echo "=========================================="
echo "MagicTapper 调试运行器"
echo "=========================================="
echo ""
echo "此脚本将在终端中运行应用，显示所有调试输出"
echo ""
echo "调试信息说明："
echo "  📱 = 触摸事件检测"
echo "  🖱️ = 点击已识别"
echo "  ⚠️ = 点击未触发（显示原因）"
echo "  🎯 = 拖拽事件"
echo "  💥 = 鼠标事件合成"
echo ""
echo "按 Ctrl+C 停止应用"
echo ""
echo "=========================================="
echo ""

# 确保停止所有正在运行的实例
killall MagicTapper 2>/dev/null
killall MagicTapper_Debug 2>/dev/null

sleep 1

# 检查是否有调试版本
if [ ! -f "build/MagicTapper_Debug.app/Contents/MacOS/MagicTapper_Debug" ]; then
    echo "❌ 未找到调试版本，正在构建..."
    bash build-debug.sh
    echo ""
fi

echo "🚀 启动调试版本..."
echo ""

# 运行调试版本
build/MagicTapper_Debug.app/Contents/MacOS/MagicTapper_Debug
