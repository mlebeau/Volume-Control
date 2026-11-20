#!/bin/bash
# Link the native tests to the app objects produced by xcodebuild. This tests
# the actual event tap implementation without a second app target or test hooks.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <DerivedData directory from a Release build>" >&2
    exit 2
fi

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
derived_dir=$(cd "$1" && pwd)
test_arch=$(uname -m)
object_dir="$derived_dir/Build/Intermediates.noindex/Volume Control.build/Release/Volume Control.build/Objects-normal/$test_arch"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

objects=()
for object in "$object_dir"/*.o; do
    [[ -f "$object" ]] || { echo "Missing Release build objects: $object_dir" >&2; exit 1; }
    [[ $(basename "$object") == main.o ]] || objects+=("$object")
done

sdk_path=$(xcrun --sdk macosx --show-sdk-path)
xcrun clang -fobjc-arc -fmodules -isysroot "$sdk_path" -mmacosx-version-min=13.5 \
    -I "$repo_dir/Sources/Controllers" \
    -I "$repo_dir/Sources/Supporting files" \
    -I "$repo_dir/User interface/HUD" \
    -F "$repo_dir/Frameworks" \
    -c "$repo_dir/Tests/VolumeKeyEventTests.m" -o "$test_dir/events.o"

xcrun swiftc -sdk "$sdk_path" -target "$test_arch-apple-macosx13.5" \
    "$test_dir/events.o" "${objects[@]}" \
    -F "$repo_dir/Frameworks" \
    -framework Cocoa -framework QuartzCore -framework IOKit \
    -framework ScriptingBridge -framework CoreAudio -framework ServiceManagement \
    -framework CoreServices -framework UniformTypeIdentifiers -framework Sparkle \
    -Xlinker -rpath -Xlinker "$repo_dir/Frameworks" \
    -o "$test_dir/volume-events"

"$test_dir/volume-events"
