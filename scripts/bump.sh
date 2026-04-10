#!/usr/bin/env bash
# piKeyboard version bumper. Updates every place a version string lives.
#
# Usage:
#   scripts/bump.sh patch     # 0.2.0 -> 0.2.1
#   scripts/bump.sh minor     # 0.2.0 -> 0.3.0  (default: feature added)
#   scripts/bump.sh major     # 0.2.0 -> 1.0.0  (breaking change)
#   scripts/bump.sh 0.5.0     # explicit version
#
# After bumping it stages the changed files but does NOT commit. Caller commits.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$ROOT/app/project.yml"
DAEMON_PY="$ROOT/pid/pikeyboard_daemon.py"

current=$(grep -E '^\s*MARKETING_VERSION:' "$PROJECT_YML" | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$current" ]]; then
  echo "could not read MARKETING_VERSION from $PROJECT_YML" >&2
  exit 1
fi

bump_kind="${1:-minor}"
case "$bump_kind" in
  patch|minor|major)
    IFS='.' read -r maj min pat <<<"$current"
    case "$bump_kind" in
      patch) new="${maj}.${min}.$((pat+1))" ;;
      minor) new="${maj}.$((min+1)).0" ;;
      major) new="$((maj+1)).0.0" ;;
    esac
    ;;
  *.*.*)
    new="$bump_kind"
    ;;
  *)
    echo "usage: $0 {patch|minor|major|X.Y.Z}" >&2
    exit 2
    ;;
esac

# Project build number = total bumps so far. Increment by 1.
build=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | sed -E 's/.*"([^"]+)".*/\1/')
new_build=$((build + 1))

echo "==> $current -> $new (build $build -> $new_build)"

# Update Xcode marketing + build versions
sed -i.bak -E "s/(MARKETING_VERSION:\s*)\"[^\"]+\"/\1\"$new\"/" "$PROJECT_YML"
sed -i.bak -E "s/(CURRENT_PROJECT_VERSION:\s*)\"[^\"]+\"/\1\"$new_build\"/" "$PROJECT_YML"
rm -f "$PROJECT_YML.bak"

# Update daemon Bonjour TXT version
sed -i.bak -E "s/(\"version\":\s*)\"[^\"]+\"/\1\"$new\"/" "$DAEMON_PY"
rm -f "$DAEMON_PY.bak"

# Stage changes
git -C "$ROOT" add "$PROJECT_YML" "$DAEMON_PY"

echo "==> Done. Files staged. Now run:"
echo "    git commit -m \"...\""
echo "    git tag v$new"
echo "    git push && git push --tags"
