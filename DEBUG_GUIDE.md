# MagicTapper 调试指南

## 已修复的问题

### 问题 1：点击检测逻辑错误

**原始问题**：
- 右键需要按住 >0.1s，但如果按住时间在 0.1-0.3s 之间，左键条件不满足，右键已触发，导致什么都不会发生

**修复方案**：
- 重构了点击检测逻辑
- 现在：按住 <0.3s 且移动 <5px 都视为有效点击
  - 如果 duration >= 0.1s 且在右侧 → 右键
  - 否则 → 左键

### 问题 2：缺少调试输出

**修复方案**：
- 添加了详细的调试输出到所有关键函数
- 创建了调试版本构建脚本

### 问题 3：系统睡眠唤醒后失效（2026-01-12 修复）

**症状**：
- 系统进入睡眠后再唤醒，应用不再响应触摸
- 需要手动重启应用才能恢复功能

**根本原因**：
- MultitouchSupport 框架的设备连接在系统睡眠后会断开
- 应用没有监听睡眠/唤醒通知，无法自动重新初始化

**修复方案**：

#### 实现睡眠/唤醒监听（AppDelegate.swift）
```swift
// 注册系统通知
private func registerForSleepWakeNotifications() {
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(systemWillSleep),
        name: NSWorkspace.willSleepNotification,
        object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(systemDidWake),
        name: NSWorkspace.didWakeNotification,
        object: nil
    )
}

// 睡眠前停止
@objc private func systemWillSleep() {
    multitouchManager?.stop()
}

// 唤醒后重启（延迟1秒确保设备就绪）
@objc private func systemDidWake() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.restartMultitouchManager()
    }
}
```

**修复效果**：
- ✅ 系统唤醒后自动恢复功能
- ✅ 无需手动重启应用
- ✅ 延迟3秒确保蓝牙设备连接稳定

**增强修复（长时间睡眠）**：
- ✅ 智能重试机制（最多5次）
- ✅ 递增延迟重试（2s, 4s, 6s, 8s）
- ✅ 设备数量检测（确认成功连接）
- ✅ 支持长时间睡眠后蓝牙设备重连

**调试输出示例**：

短时间睡眠（设备立即可用）：
```
💤 System going to sleep - stopping multitouch manager
👀 System woke up - restarting multitouch manager
🔄 Restarting multitouch manager (attempt 1/5)...
✅ Multitouch manager restarted successfully - found 1 device(s)
```

长时间睡眠（需要重试）：
```
💤 System going to sleep - stopping multitouch manager
👀 System woke up - restarting multitouch manager
🔄 Restarting multitouch manager (attempt 1/5)...
⚠️ No multitouch devices found (attempt 1/5)
🔄 Restarting multitouch manager (attempt 2/5)...
✅ Multitouch manager restarted successfully - found 1 device(s)
```

---

### 问题 4：单点和拖拽不灵敏 + 误触问题（2026-01-12 修复）

**症状**：
- 单点击非常不灵敏
- 拖拽不灵敏且出现中断
- 移动页面时误触发点击

**根本原因分析**：
1. **累计移动距离判定错误**：
   - 原代码使用累计移动距离，即使手指回到原点也会累加
   - 导致正常点击时的轻微抖动累积超过阈值，点击被取消

2. **拖拽中断问题**：
   - 拖拽模式下仍然执行表面移动检测
   - 拖拽时手指在表面滑动是正常的，不应该取消拖拽

3. **误触根源**：
   - 表面移动检测触发后 `reset()` + `return`
   - 但用户抬起手指时，触摸结束事件仍被处理
   - 导致即使已取消，仍会触发点击（状态机缺陷）

**修复方案**：

#### 1. 改用直线距离计算（TapDetector.swift）
```swift
// 之前：累计移动距离
accumulatedDistance += stepDistance
if accumulatedDistance > threshold { cancel() }

// 现在：直线距离
let distance = hypot(location.x - startLocation.x,
                     location.y - startLocation.y)
if distance > threshold { markAsMoving() }
```

#### 2. 智能手势识别（TapDetector.swift）
```swift
// 区分快速点击和慢速滚动
let isQuickTap = duration < 0.15s
let isValidTap = (isQuickTap || !hasMovedSignificantly) && ...

// 快速点击（<150ms）：即使有轻微移动也算点击
// 慢速触控：必须无明显移动才算点击
```

#### 3. 动态表面移动阈值（MultitouchManager.swift）
```swift
// 根据触控速度动态调整
let isQuickTouch = (now - touchStartTime!) < 0.15
let effectiveThreshold = isQuickTouch ? 0.08 : 0.04

// 快速触控：允许 8% 表面移动
// 慢速触控：只允许 4% 表面移动
```

#### 4. 取消标记机制（MultitouchManager.swift）- 关键修复
```swift
private var isCancelled = false

// 表面移动检测时标记取消
if surfaceMovement > threshold {
    tapDetector.reset()
    isCancelled = true  // ← 关键：持久化取消状态
    return
}

// 触摸结束时检查标记
if numTouches == 0 {
    if !isCancelled {
        // 正常处理点击
    }
    isCancelled = false  // 重置标记
}
```

#### 5. 拖拽流畅性保证（MultitouchManager.swift）
```swift
// 拖拽模式下完全禁用表面移动检测
if !isDraggingActive {
    // 只在非拖拽状态下检查表面移动
    if surfaceMovement > threshold {
        cancel()
    }
}
```

**修复效果**：
- ✅ 单点击灵敏度大幅提升
- ✅ 拖拽流畅无中断
- ✅ 移动页面时不再误触
- ✅ 防误触功能保持有效

**关键参数**（MultitouchManager.swift + TapDetector.swift）：
```swift
tapMovementThreshold: 8.0,        // 光标移动阈值（像素）
minTapDuration: 0.03,             // 最小点击时长（秒）
quickTapThreshold: 0.15,          // 快速点击判定阈值（秒）
surfaceMovementThreshold: 0.04,   // 基础表面移动阈值（4%）
quickTouchBonus: 0.08,            // 快速触控表面阈值（8%）
dragThreshold: 2.0                // 拖拽防抖阈值（像素）
```

**调试输出示例**：
```
# 正常点击
✋ Touch ended. Dist: 0.00, Dur: 0.090, Moved: false
✅ Left Click Triggered

# 移动页面（正确取消）
🚫 Surface movement detected: 0.067 > 0.040 (quick: false)
🚫 Touch ended but was cancelled - no click

# 拖拽（流畅）
🎯 Entering drag mode!
🎯 START DRAG at (x, y)
🎯 MOVE DRAG to (x2, y2)  # 持续流畅移动
🎯 END DRAG at (x3, y3)
```

---

## 调试步骤

### 方法 1：使用调试版本（推荐）

```bash
# 运行调试版本（带控制台输出）
bash debug-run.sh
```

这会在终端显示所有调试信息：
- `📱` 触摸事件检测
- `🖱️` 点击已识别
- `⚠️` 点击未触发（显示原因）
- `🎯` 拖拽事件
- `💥` 鼠标事件合成

### 方法 2：查看系统日志

```bash
# 实时查看应用日志
log stream --predicate 'process == "MagicTapper"' --level debug

# 或查看最近的日志
log show --predicate 'process == "MagicTapper"' --last 5m
```

### 方法 3：手动测试

1. 停止所有运行的实例：
   ```bash
   killall MagicTapper
   killall MagicTapper_Debug
   ```

2. 运行调试版本：
   ```bash
   build/MagicTapper_Debug.app/Contents/MacOS/MagicTapper_Debug
   ```

3. 在 Magic Mouse 上测试各种手势，观察终端输出

---

## 测试清单

### 基础触摸检测

运行调试版本后，在 Magic Mouse 上操作并观察输出：

- [ ] **轻触**：应该看到触摸事件，例如：
  ```
  📱 Touches: 1, State: 4, Pos: (0.3, 0.5)
  ```

- [ ] **抬起**：应该看到触摸数为 0

- [ ] **滑动**：应该看到连续的触摸事件，位置坐标变化

### 左键点击测试

- [ ] **快速轻触左侧**：
  ```
  📱 Touches: 1, State: 4, Pos: (0.2, 0.5)  # 按下
  🖱️ Click detected! Right: false, Location: (x, y)  # 识别为左键
  💥 Synthesizing LEFT click at (x, y)  # 合成点击
  ```

- [ ] **点击应该生效**：文件被选中，应用被打开等

### 右键点击测试

- [ ] **按住右侧 >0.1s**：
  ```
  📱 Touches: 1, State: 4, Pos: (0.7, 0.5)  # 按下（右侧）
  🖱️ Click detected! Right: true, Location: (x, y)  # 识别为右键
  💥 Synthesizing RIGHT click at (x, y)  # 合成右键
  ```

- [ ] **右键菜单应该弹出**

### 拖拽测试

- [ ] **双击并按住**：
  ```
  # 第一次点击
  📱 Touches: 1, State: 4, Pos: (0.3, 0.5)
  🖱️ Click detected! Right: false, Location: (x, y)
  💥 Synthesizing LEFT click at (x, y)

  # 第二次点击（0.3s内）
  📱 Touches: 1, State: 4, Pos: (0.3, 0.5)
  🎯 Entering drag mode!
  🎯 START DRAG at (x, y)

  # 移动
  🎯 MOVE DRAG to (x2, y2)
  🎯 MOVE DRAG to (x3, y3)

  # 释放
  🎯 END DRAG at (x4, y4)
  ```

- [ ] **文件/窗口应该被拖动**

---

## 常见问题排查

### 问题：没有任何触摸事件

**可能原因**：
1. 不是 Magic Mouse（代码只监听外部设备）
2. MultitouchSupport 框架不可用

**解决方案**：
```bash
# 检查设备
system_profiler SPBluetoothDataType | grep "Magic Mouse"
```

### 问题：有触摸事件但没有点击

查看调试输出中的 `⚠️` 标记，会显示原因：
- `shouldClick: false` - 表示不满足点击条件

**可能原因**：
1. 移动距离过大（>5px）
2. 按住时间过长（>0.3s）
3. 手指在表面移动过大（>0.15 归一化距离）

**解决方案**：
- 调整阈值参数（在 MultitouchManager.swift 中）
- 更快地点击
- 点击时减少移动

### 问题：点击识别但没有生效

查看是否有 `💥 Synthesizing` 输出：

**有输出但不生效**：
- 检查辅助功能权限
- 重新授予权限：
  ```bash
  tccutil reset Accessibility com.magictapper.app.debug
  ```
- 在系统设置中重新启用

**没有输出**：
- 回调未正确设置
- 检查 AppDelegate 的 `onClickSynthesized` 回调

### 问题：拖拽不工作

查看是否有 `🎯` 相关输出：

**没有进入拖拽模式**：
- 两次点击间隔超过 0.3s
- 第一次点击未被正确识别

**进入拖拽但不移动**：
- 移动距离小于 3px（防抖阈值）
- 检查是否有 `MOVE DRAG` 输出

---

## 参数调整

如果需要调整灵敏度，编辑 `MultitouchManager.swift`:

```swift
private var tapDetector = TapDetector(
    tapTimeThreshold: 0.25,          // 最大点击时长（秒）
    tapMovementThreshold: 5.0,       // 最大点击移动距离（像素）
    rightClickTimeThreshold: 0.1,    // 右键最小按住时长（秒）
    doubleTapTimeWindow: 0.3,        // 双击时间窗口（秒）
    dragThreshold: 3.0               // 拖拽防抖阈值（像素）
)
```

以及：

```swift
private var rightClickThreshold: Float = 0.6  // X坐标阈值 (0-1)，大于此值为右侧
private var surfaceMovementThreshold: Float = 0.15  // 表面最大移动距离 (0-1)
```

调整后重新编译：
```bash
bash build.sh
```

---

## 移除调试输出

测试完成后，可以移除调试输出以优化性能：

1. 在 `MultitouchManager.swift` 中删除所有 `print()` 语句
2. 在 `AppDelegate.swift` 中删除所有 `print()` 语句
3. 重新编译：
   ```bash
   bash build.sh
   ```

---

## 性能分析

如果需要分析性能：

```bash
# 使用 Instruments
instruments -t "Time Profiler" build/MagicTapper_Debug.app

# 或使用 sample
sample MagicTapper_Debug 10 -file profile.txt
```

---

## 提交问题

如果问题仍然存在，请收集以下信息：

1. 调试输出（运行 `debug-run.sh` 的完整输出）
2. 系统版本：`sw_vers`
3. 设备信息：`system_profiler SPBluetoothDataType | grep -A 5 "Magic Mouse"`
4. 详细的复现步骤
