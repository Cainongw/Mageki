#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != x86_64 ]]; then
  echo 'This legacy Xamarin toolchain requires an Intel macOS runner.' >&2
  exit 1
fi

# Official archived installers; Xamarin and Mono MDK are no longer preinstalled
# on hosted runners, and their old Homebrew casks have been removed.
install_package() {
  local url="$1" checksum="$2" package
  package="${RUNNER_TEMP:?}/${url##*/}"
  curl --fail --location --retry 3 --output "$package" "$url"
  printf '%s  %s\n' "$checksum" "$package" | shasum -a 256 -c -
  sudo installer -pkg "$package" -target /
}

install_package \
  'https://download.mono-project.com/archive/6.12.0/macos-10-universal/MonoFramework-MDK-6.12.0.206.macos10.xamarin.universal.pkg' \
  '80b0dbfa59ba9ed76dbf1393998e6a2ed2d1ccc8f5850c7a46fbe31a2aea88d8'
install_package \
  'https://download.visualstudio.microsoft.com/download/pr/ceb0ea3f-4db8-46b4-8dc3-8049d27c0107/3960868aa9b1946a6c77668c3f3334ee/xamarin.ios-16.4.0.23.pkg' \
  '3c3a2e3c5adebf7955934862b89c82e4771b0fd44dfcfebad0d160033a6e0a1a'

# Avoid macos-latest / Xcode-latest: they move independently of Xamarin.
xcode_root='/Applications/Xcode_16.4.app'
test -d "$xcode_root/Contents/Developer"
sudo xcode-select --switch "$xcode_root/Contents/Developer"
printf 'MD_APPLE_SDK_ROOT=%s\n' "$xcode_root" >> "${GITHUB_ENV:?}"
printf '%s\n' '/Library/Frameworks/Mono.framework/Versions/Current/Commands' >> "${GITHUB_PATH:?}"

# A newer SDK needs a newer MSBuild than the one bundled in Mono 6.12.
test -d "${DOTNET_ROOT:?}/sdk/5.0.100/Sdks"
printf 'MSBuildSDKsPath=%s/sdk/5.0.100/Sdks\n' "$DOTNET_ROOT" >> "$GITHUB_ENV"
printf '{"sdk":{"version":"5.0.100","rollForward":"disable"}}\n' > global.json

xcodebuild -version
/Library/Frameworks/Mono.framework/Versions/Current/Commands/mono --version
/Library/Frameworks/Mono.framework/Versions/Current/Commands/msbuild -version
/Library/Frameworks/Xamarin.iOS.framework/Versions/Current/bin/mtouch --version
