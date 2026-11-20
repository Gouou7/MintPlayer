#!/bin/sh

set -eu

project_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
script="$project_dir/Scripts/embed-git-version.sh"
test_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mintplayer-version-test.XXXXXXXX")
trap '/bin/rm -rf "$test_dir"' EXIT
trap 'exit 1' HUP INT TERM

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
unset MINTPLAYER_RELEASE_TAG
repo="$test_dir/source repo"
derived_dir="$test_dir/derived files"

git_fixture() {
    /usr/bin/git -C "$repo" "$@"
}

commit_fixture() {
    git_fixture commit --quiet --allow-empty -m "$1"
}

assert_plist_value() {
    actual=$(/usr/libexec/PlistBuddy -c "Print :$1" "$derived_dir/MintPlayer-Info.plist")
    if [ "$actual" != "$2" ]; then
        printf 'FAIL %s: expected %s, got %s\n' "$1" "$2" "$actual" >&2
        exit 1
    fi
}

check_version() {
    SRCROOT="$1" DERIVED_FILE_DIR="$derived_dir" CONFIGURATION="$2" /bin/sh "$script"
    /usr/bin/plutil -lint -s "$derived_dir/MintPlayer-Info.plist"
    assert_plist_value MintDisplayVersion "$3"
    assert_plist_value CFBundleShortVersionString "$4"
    assert_plist_value CFBundleVersion "$5"
}

check_failure() {
    if output=$(SRCROOT="$1" DERIVED_FILE_DIR="$derived_dir" /bin/sh "$script" 2>&1); then
        echo 'FAIL version generation unexpectedly succeeded' >&2
        exit 1
    fi
    case "$output" in
        *"$2"*) ;;
        *) printf 'FAIL unexpected version generation error: %s\n' "$output" >&2; exit 1 ;;
    esac
}

/usr/bin/git init --quiet -b main "$repo"
git_fixture config user.name 'Mint Player version test'
git_fixture config user.email 'version-test@example.invalid'
/bin/mkdir -p "$repo/MintPlayer/App"
/bin/cp "$project_dir/MintPlayer/App/Info.plist" "$repo/MintPlayer/App/Info.plist"
git_fixture add MintPlayer/App/Info.plist
commit_fixture 'Initial commit'

# An untagged history and refs that are invalid versions or point to a blob.
initial_hash=$(git_fixture rev-parse HEAD | /usr/bin/cut -c 1-8)
check_version "$repo" Debug "0.0.0+g$initial_hash" 0.0.0 1
git_fixture tag v9.0.0-rc.1
git_fixture tag v9foo.0.0
git_fixture tag v09.0.0
git_fixture tag 9.0.0
git_fixture tag v99.0.0 "$(git_fixture rev-parse HEAD:MintPlayer/App/Info.plist)"
check_version "$repo" Debug "0.0.0+g$initial_hash" 0.0.0 1

git_fixture tag v10.0.0
commit_fixture 'Release commit'
git_fixture tag -a v1.2.3 -m 'Annotated version tag'
check_version "$repo" Release v1.2.3 1.2.3 2
git_fixture tag v1.10.0
git_fixture config column.tag always
git_fixture config versionsort.suffix .10.0
check_version "$repo" Debug v1.10.0 1.10.0 2
(
    export MINTPLAYER_RELEASE_TAG=v1.2.3
    check_version "$repo" Release v1.2.3 1.2.3 2
)

# A larger older tag, an unmerged tag, and an invalid exact tag must lose.
git_fixture switch --quiet -c side
commit_fixture 'Side branch commit'
git_fixture tag v1.11.0
git_fixture switch --quiet main
commit_fixture 'Development commit'
git_fixture tag v99.0.0-rc.1
development_hash=$(git_fixture rev-parse HEAD | /usr/bin/cut -c 1-8)
check_version "$repo" Release "v1.10.0+g$development_hash" 1.10.0 3
(
    export MINTPLAYER_RELEASE_TAG=v1.2.3
    check_failure "$repo" 'must be a valid version tag on HEAD'
)

# Both sides are now reachable at the same distance.
git_fixture tag v1.9.0
git_fixture merge --quiet --no-ff -m 'Merge side branch' side
merge_hash=$(git_fixture rev-parse HEAD | /usr/bin/cut -c 1-8)
check_version "$repo" Debug "v1.11.0+g$merge_hash" 1.11.0 5

# A local file URL creates a real shallow clone and requires no network.
shallow_repo="$test_dir/shallow repo"
/usr/bin/git clone --quiet --depth=1 "file://$repo" "$shallow_repo"
check_failure "$shallow_repo" 'git fetch --unshallow --tags'
/usr/bin/git -C "$shallow_repo" fetch --quiet --unshallow --tags
check_version "$shallow_repo" Debug "v1.11.0+g$merge_hash" 1.11.0 5

shallow_release="$test_dir/shallow release"
/usr/bin/git -c advice.detachedHead=false clone --quiet --depth=1 --branch v1.10.0 "file://$repo" "$shallow_release"
check_version "$shallow_release" Release v1.10.0 1.10.0 1

echo 'Git version tests passed.'
