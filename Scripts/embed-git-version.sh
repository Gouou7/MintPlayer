#!/bin/sh

set -eu

git_in_source() {
    /usr/bin/git -C "$SRCROOT" "$@"
}

if ! head=$(git_in_source rev-parse --verify 'HEAD^{commit}' 2>/dev/null); then
    echo "error: Cannot resolve HEAD. Build from a Git checkout with a commit." >&2
    exit 1
fi

build_number=$(git_in_source rev-list --count "$head" --)
is_shallow=$(git_in_source rev-parse --is-shallow-repository)
reachable_tags=$(git_in_source for-each-ref --merged="$head" --format='%(refname:lstrip=2)' 'refs/tags/v*')
version_tags=$(
    /usr/bin/printf '%s\n' "$reachable_tags" |
        LC_ALL=C /usr/bin/awk '/^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/' |
        LC_ALL=C /usr/bin/sort -nr -t . -k1.2,1 -k2,2 -k3,3
)

version_tag=
closest_distance=$build_number
# Count commits since each candidate as git describe does. Version order breaks ties.
for tag in $version_tags; do
    distance=$(git_in_source rev-list --count "refs/tags/$tag..$head" --)
    if [ "$distance" -lt "$closest_distance" ]; then
        version_tag=$tag
        closest_distance=$distance
    fi
    if [ "$distance" -eq 0 ]; then
        break
    fi
done

if [ "$closest_distance" -eq 0 ]; then
    display_version=$version_tag
    if [ "$is_shallow" = true ]; then
        echo "warning: CFBundleVersion uses the visible commit count in this shallow checkout. Fetch full history for the complete count." >&2
    fi
elif [ "$is_shallow" = true ]; then
    echo "error: Cannot resolve an ancestor version tag from shallow Git history. Fetch full history and tags before building (git fetch --unshallow --tags)." >&2
    exit 1
else
    commit_hash=$(git_in_source rev-parse --short=8 "$head")
    display_version="${version_tag:-0.0.0}+g$commit_hash"
fi

version=${version_tag#v}
version=${version:-0.0.0}
source_info_plist="$SRCROOT/MintPlayer/App/Info.plist"
generated_info_plist="$DERIVED_FILE_DIR/MintPlayer-Info.plist"

if [ ! -f "$source_info_plist" ]; then
    echo "error: Info.plist template not found at $source_info_plist." >&2
    exit 1
fi

/bin/mkdir -p "$DERIVED_FILE_DIR"
/bin/cp "$source_info_plist" "$generated_info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$generated_info_plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$generated_info_plist"
/usr/libexec/PlistBuddy -c "Set :MintDisplayVersion $display_version" "$generated_info_plist"

echo "Embedded Git version $display_version (build $build_number)."
