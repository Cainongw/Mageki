#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
project='Mageki/Mageki.iOS/Mageki.iOS.csproj'
output="$repo_root/artifacts"
mkdir -p "$output/logs"

# Raise only the CI manifest's deployment target. NFC tag reading already
# requires iOS 13, and modern Xcode no longer ships libarclite for iOS 8.
manifest="${RUNNER_TEMP:?}/Mageki-Info.plist"
cp Mageki/Mageki.iOS/Info.plist "$manifest"
/usr/libexec/PlistBuddy -c 'Set :MinimumOSVersion 13.0' "$manifest"

# Build only the iOS project and its shared library, not Android/UWP from the
# solution. Global properties override the project's local signing defaults.
msbuild "$project" \
  /restore /t:Build /m \
  /p:Configuration=Release \
  /p:Platform=iPhone \
  /p:MtouchArch=ARM64 \
  /p:MtouchLink=SdkOnly \
  /p:MtouchUseLlvm=false \
  "/p:AppBundleManifest=$manifest" \
  /p:EnableCodeSigning=false \
  /p:CodesignRequireProvisioningProfile=false \
  /p:_RequireCodeSigning=false \
  /p:BuildIpa=false \
  /p:ArchiveOnBuild=false \
  /p:RestoreIgnoreFailedSources=false \
  /verbosity:minimal \
  "/bl:$output/logs/ios-build.binlog" \
  2>&1 | tee "$output/logs/ios-build.log"

# Xamarin's IPA exporter expects signing assets, so package the device .app
# directly. Preserve bundle symlinks and executable permissions with ditto/zip.
app="$repo_root/Mageki/Mageki.iOS/bin/iPhone/Release/Mageki.iOS.app"
test -d "$app"
executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist")"
test -x "$app/$executable"
lipo -verify_arch arm64 "$app/$executable"
file "$app/$executable" | tee "$output/logs/executable.txt"
staging="$(mktemp -d "${RUNNER_TEMP}/mageki-ipa.XXXXXX")"
mkdir -p "$staging/Payload"
ditto "$app" "$staging/Payload/Mageki.iOS.app"
ipa="$output/Mageki-iOS-unsigned.ipa"
(cd "$staging" && zip -qry "$ipa" Payload)
unzip -t "$ipa"
shasum -a 256 "$ipa" | tee "$output/logs/ipa-sha256.txt"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '### Mageki iOS IPA'
    echo '- Architecture: ARM64 (physical iPhone/iPad), minimum iOS 13.0.'
    echo '- Download the unsigned IPA from this run’s Artifacts section.'
    echo '- Sign with your own certificate/profile before installing.'
    echo '- NFC requires a provisioning profile with the NFC Tag Reading capability.'
  } >> "$GITHUB_STEP_SUMMARY"
fi
