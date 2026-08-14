# MagicTapper

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="magictapper-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="magictapper-light.png">
  <img alt="MagicTapper Logo" src="magictapper-light.png">
</picture>

**Finally, tap-to-click for your Apple Magic Mouse!** (v1.2)

English | [中文](README_zh.md) | [日本語](README_ja.md)

MagicTapper brings trackpad-style tap-to-click functionality to the Apple Magic Mouse. Simply tap the left or right side of your mouse surface to click - no more pressing down the button.

## ✨ Features

- 🖱️ **Tap left side** for left-click
- 🖱️ **Hold right side (>0.1s)** for right-click (anti-false-trigger)
- 🖱️ **Double-tap and release** for a system double-click
- 🎯 **Double-tap, hold, and move** to drag & drop
- ⚡ **Fast & responsive** - optimized for minimal latency
- 🚀 **Launch at Login** - auto-start with macOS
- 🎛️ **Easy toggle** on/off from the menu bar
- 🎚️ **Adjustable sensitivity** - fine-tune tap detection without rebuilding
- 🔒 **Privacy-focused** - runs entirely on your Mac, no network access

## 📋 Requirements

- macOS 13.0 (Ventura) or later
- Apple Magic Mouse (1st or 2nd generation)
- Your Magic Mouse must be connected via Bluetooth

## 🚀 Installation

### Quick Install (Recommended)

Use the automatic installation script:

```bash
# Navigate to the repository
cd /path/to/magictapper

# Run the installer
bash install-final.sh
```

The script will:
- Build the optimized version (if needed)
- Stop any running instances
- Backup old version (if exists)
- Install to /Applications
- Guide you through first launch

### Manual Installation

If you prefer manual installation:

```bash
# Option 1: Use pre-built binary
cd /path/to/magictapper
cp -r build/MagicTapper.app /Applications/

# Option 2: Build from source
bash build.sh
cp -r build/MagicTapper.app /Applications/
```

### Grant Permissions

1. Open **MagicTapper** from your Applications folder
2. You'll see a permission request - click **"Open System Settings"**
3. In **Privacy & Security → Accessibility**, enable **MagicTapper** ✓
   - If the app is missing, click the **+** button and add it from `/Applications/MagicTapper.app`
4. Return to MagicTapper – it will begin working automatically once the toggle is on (no relaunch needed)

That's it! You'll see a mouse icon in your menu bar.

## 📖 How to Use

### Basic Usage

1. Look for the **mouse icon** 🖱️ in your menu bar (top-right of screen)
2. **Tap your Magic Mouse** surface:
   - **Quick tap left side** = left-click
   - **Hold right side (≥0.1s)** = right-click (context menu)
   - **Double-tap and release** = double-click
   - **Double-tap, hold, and move** = drag & drop
3. You can still click the mouse button normally - tapping is just an additional way to click

### Menu Bar Controls

Click the mouse icon in your menu bar to access:

- **Status** - Shows if running or disabled
- **Tap to Click** - Enable/disable the feature (checkmark shows when enabled)
- **Launch at Login** - Auto-start with macOS (checkmark when enabled)
- **Pointer Speed** - Adjust global macOS mouse pointer speed with a live slider
- **Sensitivity Settings** - Fine-tune tap detection thresholds in a settings window
- **Accessibility Instructions** - Help with permissions
- **About** - Version info and features
- **Quit** - Exit the app

### Tips

- 💡 **Left-click**: Quick, light tap on the left side
- 💡 **Right-click**: Press and hold (>0.1s) on the right side before releasing
- 💡 **Double-click**: Double-tap quickly and release the second tap without moving
- 💡 **Drag & drop**: Double-tap quickly, keep finger down on the second tap, then move beyond the tap threshold
- 💡 The dividing line between left/right is roughly at 60% from left
- 💡 To disable temporarily, toggle "Tap to Click" off in menu bar
- 💡 Pointer Speed changes the system-wide mouse speed, so it affects other mice too

## 🔧 Auto-Start on Login (Optional)

To have MagicTapper start automatically when you log in:

1. Open **System Settings**
2. Go to **General → Login Items**
3. Click the **+** button
4. Select **MagicTapper** from your Applications folder
5. Click **Add**

Now MagicTapper will launch every time you start your Mac!

## ⚠️ Important Information

### About Private Frameworks

MagicTapper uses Apple's private **MultitouchSupport** framework to detect touches on your Magic Mouse.

**What this means:**

- ✅ **Safe to use** - Many apps use this framework
- ✅ **Works great** on current macOS versions
- ❌ **Not on Mac App Store** - Apple doesn't allow private frameworks in the App Store
- ⚠️ **Future updates** - Could potentially break in a major macOS update (though unlikely based on history)

**Privacy:** The app only monitors your Magic Mouse touches. It doesn't collect data, access the internet, or send information anywhere.

### Accessibility Permissions

MagicTapper requires **Accessibility permissions** to:

1. **Detect** when you tap the Magic Mouse surface
2. **Send** click events to your Mac

These permissions are granted by you in System Settings and can be revoked at any time. The app cannot function without them.

## 🐛 Troubleshooting

### Taps aren't working

**Check permissions:**
1. Go to **System Settings → Privacy & Security → Accessibility**
2. Make sure **MagicTapper** is in the list and **checked** ✓
3. If it disappeared (after rebuilding), click **+** and re-add `/Applications/MagicTapper.app`
4. Toggle the checkbox off/on once — the app will detect the change immediately

**Verify Magic Mouse:**
1. Go to **System Settings → Bluetooth**
2. Your Magic Mouse should show as "Connected"
3. Try moving the mouse to confirm it's working

### App won't launch

**"App is damaged" error:**
- This is normal for apps not from the App Store
- Right-click MagicTapper → **Open** → Click **Open** again in the dialog
- Or: Go to **System Settings → Privacy & Security** and click **Open Anyway**

### Adjusting sensitivity

If taps are too sensitive or not sensitive enough, tune them in the app — no rebuild required:

1. Click the MagicTapper icon in the menu bar
2. Open **Sensitivity Settings…**
3. Drag the sliders — changes apply immediately and persist across launches

What you can tune:

- **Max Tap Duration** — how long a tap may last and still count as a click
- **Movement Tolerance** — how far the cursor may move during a tap
- **Right-Click Hold Time** — minimum hold time on the right side for a right-click
- **Double-Tap Window** — time window for double-tap and drag detection
- **Left/Right Boundary** — where the mouse surface splits into left/right click zones
- **Surface Movement Limit** — how far the finger may slide before a tap is treated as scrolling

Smaller values mean stricter detection, larger values more lenient. Click **Reset to Defaults** to restore the recommended values.

## 🗑️ Uninstalling

To remove MagicTapper:

```bash
# Remove the app
rm -rf /Applications/MagicTapper.app

# Remove from Login Items (if you added it)
# System Settings → General → Login Items → Remove MagicTapper

# Revoke permissions (optional)
# System Settings → Privacy & Security → Accessibility → Remove MagicTapper
```

## 💖 Support the Project

If this project helped you, consider supporting its development:

- ⭐ **Star** this repo on GitHub
- 🐛 **Open an issue** if you find a bug
- 🔀 **Submit a pull request** to contribute
- 📢 **Share** with other Magic Mouse users

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/suyuhang19i)

## 💬 Feedback & Support

Having issues? Want to suggest a feature?

- **Check** the Troubleshooting section above
- **Open an issue** on GitHub if you find a bug
- **Contribute** submit a pull request
- **Share** with others who want tap-to-click for Magic Mouse!

## 🙏 Credits

This was 'vibe coded' using Claude Code (Sonnet 4.5)

Built to solve a frustrating gap in macOS - why doesn't the Magic Mouse have tap-to-click when the trackpad does?

Thanks to the reverse engineering community for documenting the MultitouchSupport framework, making apps like this possible.

---

**Enjoy your new tap-to-click Magic Mouse!** 🎉

*Made for Mac users who love the Magic Mouse but wish it had tap-to-click.*
