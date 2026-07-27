# MagicTapper

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="magictapper-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="magictapper-light.png">
  <img alt="MagicTapper Logo" src="magictapper-light.png">
</picture>

**Finally, tap-to-click for your Apple Magic Mouse!** (v1.1)

🌐 English | [中文](README_zh.md) | [日本語](README_ja.md)

🔗 **Website:** [https://nyannpasu95.github.io/MagicTapper/](https://nyannpasu95.github.io/MagicTapper/)

MagicTapper brings trackpad-style tap-to-click functionality to the Apple Magic Mouse. Simply tap the left or right side of your mouse surface to click - no more pressing down the button. **Plus, double-tap and hold to drag** just like your MacBook trackpad!

## ✨ Features

### 🎯 **Double-Tap and Hold to Drag** (The #1 Feature!)
Just like your MacBook trackpad, **double-tap and hold** to drag files, select text, and move windows. No more holding down the physical button for drag operations!

### Core Tap-to-Click Features
- 🖱️ **Tap left side** for left-click - instant, responsive clicking
- 🖱️ **Hold right side (>0.1s)** for right-click (anti-false-trigger protection)
- ⚡ **Fast & responsive** - optimized for minimal latency
- 🚀 **Launch at Login** - auto-start with macOS
- 🎛️ **Easy toggle** on/off from the menu bar
- 🔒 **Privacy-focused** - runs entirely on your Mac, zero network access

**Keywords:** Magic Mouse tap to click, Magic Mouse drag and drop, Magic Mouse gestures, Apple Magic Mouse utility, macOS Magic Mouse app, trackpad-style mouse, Magic Mouse enhancement

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
   - **Double-tap and hold** = drag & drop
3. You can still click the mouse button normally - tapping is just an additional way to click

### Menu Bar Controls

Click the mouse icon in your menu bar to access:

- **Status** - Shows if running or disabled
- **Tap to Click** - Enable/disable the feature (checkmark shows when enabled)
- **Launch at Login** - Auto-start with macOS (checkmark when enabled)
- **Pointer Speed** - Adjust global macOS mouse pointer speed with a live slider
- **Accessibility Instructions** - Help with permissions
- **About** - Version info and features
- **Quit** - Exit the app

### Tips

- 💡 **Left-click**: Quick, light tap on the left side
- 💡 **Right-click**: Press and hold (>0.1s) on the right side before releasing
- 💡 **Drag & drop**: Double-tap quickly, keep finger down on second tap, then move
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

If taps are too sensitive or not sensitive enough, you can adjust the settings:

1. Open `MultitouchManager.swift` in a text editor
2. Find these lines near the top:
   ```swift
   tapTimeThreshold: 0.25,      // How long a tap can be (seconds)
   tapMovementThreshold: 0.08    // How much finger movement is allowed
   ```
3. Make the numbers **smaller** for stricter detection, **larger** for more lenient
4. Save and run `./build.sh` again

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
