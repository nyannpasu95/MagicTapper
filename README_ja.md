# MagicTapper

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="magictapper-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="magictapper-light.png">
  <img alt="MagicTapper Logo" src="magictapper-light.png">
</picture>

**Apple Magic Mouse にタップでクリック機能を！** (v1.1)

[English](README.md) | [中文](README_zh.md) | 日本語

MagicTapper は、Apple Magic Mouse にトラックパッドのようなタップでクリック機能を追加します。マウスの表面を軽くタップするだけでクリックできます。もうボタンを押し込む必要はありません。

## ✨ 機能

- 🖱️ **左側をタップ** → 左クリック
- 🖱️ **右側を長押し（0.1秒以上）** → 右クリック（誤操作防止）
- 🎯 **ダブルタップ＆ホールド** → ドラッグ＆ドロップ
- ⚡ **高速レスポンス** - 遅延を最小限に最適化
- 🚀 **ログイン時に起動** - macOS と一緒に自動起動
- 🎛️ **簡単切替** - メニューバーからオン/オフ
- 🔒 **プライバシー重視** - ネットワークアクセスなし、Mac 内で完結

## 📋 動作環境

- macOS 13.0（Ventura）以降
- Apple Magic Mouse（第1世代または第2世代）
- Bluetooth で接続されていること

## 🚀 インストール

### クイックインストール（推奨）

自動インストールスクリプトを使用：

```bash
# リポジトリに移動
cd /path/to/magictapper

# インストーラーを実行
bash install-final.sh
```

スクリプトが行うこと：
- 最適化版をビルド（必要な場合）
- 実行中のインスタンスを停止
- 旧バージョンをバックアップ
- /Applications にインストール
- 初回起動をガイド

### 手動インストール

```bash
# オプション1: ビルド済みバイナリを使用
cd /path/to/magictapper
cp -r build/MagicTapper.app /Applications/

# オプション2: ソースからビルド
bash build.sh
cp -r build/MagicTapper.app /Applications/
```

### アクセシビリティ権限の付与

1. Applications フォルダから **MagicTapper** を開く
2. 権限リクエストが表示されたら **「システム設定を開く」** をクリック
3. **プライバシーとセキュリティ → アクセシビリティ** で **MagicTapper** を有効に ✓
   - アプリがリストにない場合は **+** ボタンをクリックして `/Applications/MagicTapper.app` を追加
4. MagicTapper に戻る – トグルがオンになると自動的に動作開始（再起動不要）

完了！メニューバーにマウスアイコンが表示されます。

## 📖 使い方

### 基本操作

1. メニューバー（画面右上）の **マウスアイコン** 🖱️ を確認
2. **Magic Mouse の表面をタップ**：
   - **左側をクイックタップ** = 左クリック
   - **右側を長押し（0.1秒以上）** = 右クリック（コンテキストメニュー）
   - **ダブルタップ＆ホールド** = ドラッグ＆ドロップ
3. 通常通りマウスボタンを押すことも可能 – タップは追加のクリック方法です

### メニューバーの操作

マウスアイコンをクリックしてアクセス：

- **Status** - 動作状態を表示
- **Tap to Click** - 機能のオン/オフ（チェックマークで有効状態を表示）
- **Launch at Login** - macOS と一緒に自動起動（チェックマークで有効状態を表示）
- **Accessibility Instructions** - 権限設定のヘルプ
- **About** - バージョン情報と機能
- **Quit** - アプリを終了

### ヒント

- 💡 **左クリック**: 左側を軽く素早くタップ
- 💡 **右クリック**: 右側を0.1秒以上押してから離す
- 💡 **ドラッグ＆ドロップ**: 素早くダブルタップし、2回目のタップで指を離さずに移動
- 💡 左右の境界線は左から約60%の位置
- 💡 一時的に無効にするには、メニューバーで「Tap to Click」をオフに

## ⚠️ 重要な情報

### プライベートフレームワークについて

MagicTapper は、Magic Mouse のタッチを検出するために Apple のプライベートフレームワーク **MultitouchSupport** を使用しています。

**これが意味すること：**

- ✅ **安全に使用可能** - 多くのアプリがこのフレームワークを使用
- ✅ **現在の macOS で正常動作**
- ❌ **Mac App Store には非公開** - Apple は App Store でプライベートフレームワークを許可していない
- ⚠️ **将来のアップデート** - 大きな macOS アップデートで動作しなくなる可能性あり（過去の経緯から可能性は低い）

**プライバシー:** アプリは Magic Mouse のタッチのみを監視します。データの収集、インターネットへのアクセス、情報の送信は一切行いません。

## 🐛 トラブルシューティング

### タップが機能しない

**権限を確認：**
1. **システム設定 → プライバシーとセキュリティ → アクセシビリティ** に移動
2. **MagicTapper** がリストにあり、**チェック** ✓ されていることを確認
3. リストから消えている場合（再ビルド後など）、**+** をクリックして `/Applications/MagicTapper.app` を再追加
4. チェックボックスを一度オフ/オンに切り替える – アプリは変更を即座に検出

**Magic Mouse を確認：**
1. **システム設定 → Bluetooth** に移動
2. Magic Mouse が「接続済み」と表示されていることを確認
3. マウスを動かして動作確認

### アプリが起動しない

**「アプリが破損しています」エラー：**
- App Store 以外のアプリでは正常な動作
- MagicTapper を右クリック → **開く** → ダイアログで再度 **開く** をクリック
- または：**システム設定 → プライバシーとセキュリティ** で **このまま開く** をクリック

## 🗑️ アンインストール

```bash
# アプリを削除
rm -rf /Applications/MagicTapper.app

# ログイン項目から削除（追加した場合）
# システム設定 → 一般 → ログイン項目 → MagicTapper を削除

# 権限を取り消し（オプション）
# システム設定 → プライバシーとセキュリティ → アクセシビリティ → MagicTapper を削除
```

## 💖 サポート

このプロジェクトが役に立ったら、開発をサポートしてください：

- ⭐ GitHub でスターを付ける
- 🐛 バグを見つけたら Issue を開く
- 🔀 プルリクエストを送る
- 📢 Magic Mouse ユーザーにシェア

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://buymeacoffee.com/your_username)

## 🙏 クレジット

Claude Code（Sonnet 4.5）を使用して「バイブコーディング」で作成

macOS の不満を解決するために作られました – なぜトラックパッドにはタップでクリックがあるのに、Magic Mouse にはないのか？

MultitouchSupport フレームワークを解析してドキュメント化してくれたリバースエンジニアリングコミュニティに感謝します。

---

**新しいタップでクリック Magic Mouse をお楽しみください！** 🎉

*Magic Mouse を愛用しているが、タップでクリックが欲しい Mac ユーザーのために。*
