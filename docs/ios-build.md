# 使用 GitHub Actions 编译 iOS IPA

本项目使用 Xamarin.Forms 5 和旧版 Xamarin.iOS，不能直接使用 `dotnet publish` 或 MAUI 工作负载构建。

## 运行和下载

1. 将 `.github/workflows/ios-ipa.yml` 和 `scripts/ci/` 推送到自己的 GitHub 仓库。`master` 和 `ci/ios-ipa` 分支的相关代码变更会自动触发构建。
2. Fork 仓库如果尚未启用 Actions，在仓库 **Actions** 页面启用。手动运行按钮需要工作流先存在于默认分支，然后选择 **Build iOS IPA → Run workflow**。
3. 打开构建记录，完成后在 **Artifacts** 下载 `Mageki-iOS-unsigned-<运行编号>`，解压得到 `Mageki-iOS-unsigned.ipa`。
4. 如果失败，查看失败步骤和 `Mageki-iOS-logs-<运行编号>` 中的文本日志与 MSBuild binlog。

IPA 包含真机使用的 ARM64 程序，**未签名，不能直接安装，也不是 App Store 上传包**。需要使用自己的证书和 provisioning profile 签名，或交给支持重新签名的安装工具。工作流本身不需要任何签名 secrets。

应用的 NFC 读卡使用 `com.apple.developer.nfc.readersession.formats` entitlement。重新签名时，描述文件和签名工具必须支持 NFC Tag Reading capability；普通免费侧载签名可能无法保留该权限。仅生成 IPA 并不能保证 NFC 在设备上可用。

## 构建环境

- Intel runner：`macos-15-intel`，避免 `macos-latest` 的系统版本与 CPU 架构变动。
- Xcode：16.4，显式检查安装路径。
- Mono MDK：6.12.0.206，Xamarin.iOS：16.4.0.23；从官方归档下载安装包，并检查 SHA-256。
- .NET SDK：5.0.100，供 Mono MSBuild 加载 `netstandard2.1` 共享项目使用。新版 SDK 要求更高版本的 MSBuild，不能直接替换。
- 只构建 `Mageki/Mageki.iOS/Mageki.iOS.csproj` 和它引用的共享项目。
- 仅在 CI 的临时 Info.plist 中将最低系统设为 iOS 13.0，避免原有 iOS 8 目标与现代 Xcode 冲突，并符合现有 NFC tag API 的系统要求。
- 禁用签名和 Xamarin 的 IPA 导出，成功编译 `.app` 后手动打包 `Payload/*.app`。

Xamarin 已停止维护，这个工作流用于尝试构建现有项目。Xamarin 16.4 与 Xcode 16.4 不属于官方支持的组合，仍可能出现原生编译或链接兼容问题，应以实际 Actions 日志为准；长期维护需要迁移到受支持的 .NET iOS / MAUI 工具链。

参考：[Xamarin 官方归档](https://github.com/dotnet/macios/blob/main/DOWNLOADS.md)、[GitHub runner 列表](https://github.com/actions/runner-images)、[runner 的 Xcode 列表](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)。
