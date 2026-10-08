# F2A

面向 **HarmonyOS NEXT（API 12+）** 的原生二次验证器，用于生成 Google / Microsoft / GitHub 等站点的 TOTP / HOTP 动态验证码。密钥只保存在本机，不会上传云端。

## 功能

- RFC 6238 TOTP、RFC 4226 HOTP（SHA1 / SHA256 / SHA512，6 或 8 位）
- 手动录入、解析 `otpauth://` 链接、扫描二维码
- 点击复制验证码，长按进入详情（删除 / 导出链接 / HOTP 递增）
- PIN 应用锁
- 通过剪贴板导入、导出 JSON 备份

## 环境

- DevEco Studio 5.0 或更高版本
- HarmonyOS SDK 5.0.0(12)
- 真机或模拟器：HarmonyOS 5.0+ 手机 / 平板 / 2in1

纯血鸿蒙无法直接运行 Android APK，因此本项目使用 ArkTS Stage 模型原生工程，而不是套壳 Android 应用。

## 打开与运行

1. 用 DevEco Studio 打开本仓库根目录。
2. 等待 `ohpm` 同步完成。
3. **File → Project Structure → Signing Configs** 完成自动签名。
4. 连接已开启开发者模式的鸿蒙设备，或启动模拟器。
5. 运行 `entry` 模块。

首次安装若提示相机权限，仅在扫描二维码时使用。不扫码也可以手动粘贴密钥。

## 打包安装包

鸿蒙安装包是 `.hap`（调试安装）或 `.app`（上架），必须用官方工具链编译。

1. 安装 [DevEco Studio 5.0+](https://developer.huawei.com/consumer/cn/download/deveco-studio)（需华为账号）。
2. 打开本工程，完成 **Signing Configs → Automatically generate signature**。
3. 菜单 **Build → Build Hap(s)/APP(s) → Build Hap(s)**。
4. 安装包路径：`entry\build\default\outputs\default\entry-default-signed.hap`

本机若已装好工具链，也可执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pack.ps1
```

成功后文件会复制到 `dist\`。当前这台电脑没有 DevEco Studio / Command Line Tools，无法在这里直接打出 hap。

## 添加令牌

在网站开启两步验证后，一般会给出：

- 二维码：在 F2A 中点「扫描二维码」
- 或一串密钥：填入「密钥（Base32）」
- 或 `otpauth://totp/...` 链接：粘贴后点「解析链接」

常见测试密钥 `JBSWY3DPEHPK3PXP`（Hello!）可用来确认界面与刷新倒计时是否正常。

## 工程结构

```
AppScope/                 应用包名与图标
entry/src/main/ets/
  common/                 Base32、otpauth、OTP 算法
  model/                  令牌与 PIN 本地存储
  pages/                  首页、添加、详情、设置
  components/             令牌卡片
```

令牌使用 `preferences` 本地存储。系统备份扩展未开启，避免密钥被未加密同步到云空间。

## 安全说明

- 所有 HMAC 计算走 `@kit.CryptoArchitectureKit`，在设备本地完成。
- 导出 JSON / otpauth 链接包含明文密钥，请只保存在离线可信位置。
- 卸载应用会删除本机令牌，请先导出备份。
