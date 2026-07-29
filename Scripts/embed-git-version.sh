#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" = "Release" ]; then
    version_tag=$(
        /usr/bin/git -C "$SRCROOT" describe \
            --tags \
            --exact-match \
            --match 'v[0-9]*.[0-9]*.[0-9]*' \
            HEAD 2>/dev/null || true
    )

    if [ -z "$version_tag" ]; then
        echo "error: Release builds require HEAD to have a semantic version tag such as v0.11.0." >&2
        exit 1
    fi
else
    version_tag=$(
        /usr/bin/git -C "$SRCROOT" describe \
            --tags \
            --abbrev=0 \
            --match 'v[0-9]*.[0-9]*.[0-9]*' \
            HEAD 2>/dev/null || true
    )
fi

if ! /usr/bin/printf '%s\n' "$version_tag" |
    /usr/bin/grep -Eq '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
    echo "error: No reachable semantic version tag found. Create a tag such as v0.11.0 before building." >&2
    exit 1
fi

version=${version_tag#v}
build_number=$(/usr/bin/git -C "$SRCROOT" rev-list --count HEAD)
commit_hash=$(/usr/bin/git -C "$SRCROOT" rev-parse --short=7 HEAD)
source_info_plist="$SRCROOT/MintPlayer/App/Info.plist"
generated_info_plist="$DERIVED_FILE_DIR/MintPlayer-Info.plist"

if [ "${CONFIGURATION:-}" = "Release" ]; then
    display_version="$version"
else
    display_version="$version-$commit_hash-debug"
fi

if [ ! -f "$source_info_plist" ]; then
    echo "error: Info.plist template not found at $source_info_plist." >&2
    exit 1
fi

/bin/mkdir -p "$DERIVED_FILE_DIR"
/bin/cp "$source_info_plist" "$generated_info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$generated_info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$generated_info_plist"
/usr/libexec/PlistBuddy -c "Set :MintDisplayVersion $display_version" "$generated_info_plist"

echo "Embedded Git version $display_version (build $build_number) from $version_tag."
