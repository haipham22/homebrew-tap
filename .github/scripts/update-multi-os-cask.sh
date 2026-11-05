#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --cask CASK [--force]" >&2
  exit 2
}

cask=
force=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cask)
      cask="${2:?}"
      shift 2
      ;;
    --force)
      force=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done
[[ -n "$cask" ]] || usage

full="haipham22/tap/$cask"
state="$(brew livecheck --cask "$full" --json 2>/dev/null | jq -r '.[0].version // "{}"')"
current="$(jq -r '.current // ""' <<<"$state")"
latest="$(jq -r '.latest // ""' <<<"$state")"
[[ -n "$latest" ]] || { echo "::error::$cask: livecheck found no version"; exit 1; }

if [[ "$latest" == "$current" && "$force" != true ]]; then
  echo "$cask: up to date ($current)"
  exit 0
fi

case "$cask" in
  saint)
    repository="Locotine/saint-hyper-agent"
    tag="v${latest}"
    mac_arm_asset="Saint-${latest}-arm64.dmg"
    mac_intel_asset="Saint-${latest}-x64.dmg"
    linux_asset="Saint-${latest}-x86_64.AppImage"
    ;;
  orca)
    repository="stablyai/orca"
    tag="v${latest}"
    mac_arm_asset="orca-macos-arm64.dmg"
    mac_intel_asset="orca-macos-x64.dmg"
    linux_asset="orca-linux.AppImage"
    ;;
  *)
    echo "::error::$cask is not a known multi-OS cask"
    exit 1
    ;;
esac

base_url="https://github.com/${repository}/releases/download/${tag}"
mac_arm_url="${base_url}/${mac_arm_asset}"
mac_intel_url="${base_url}/${mac_intel_asset}"
linux_url="${base_url}/${linux_asset}"

hash_url() {
  local url="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    curl -fsSL "$url" | sha256sum | awk '{print $1}'
  else
    curl -fsSL "$url" | shasum -a 256 | awk '{print $1}'
  fi
}

echo "$cask: downloading and hashing $latest"
mac_arm_sha256="$(hash_url "$mac_arm_url")"
mac_intel_sha256="$(hash_url "$mac_intel_url")"
linux_sha256="$(hash_url "$linux_url")"

cask_path="Casks/${cask}.rb"
python3 - "$cask_path" "$latest" \
  "$mac_arm_sha256" "$mac_intel_sha256" "$linux_sha256" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version, arm_sha, intel_sha, linux_sha = sys.argv[2:]
text = path.read_text()
text, version_count = re.subn(
    r'^  version "[^"]+"$', f'  version "{version}"', text, count=1, flags=re.M
)
for arch, digest in (("arm", arm_sha), ("intel", intel_sha), ("x86_64_linux", linux_sha)):
    pattern = rf'(?m)^(\s*{arch}:\s*)"[0-9a-f]{{64}}"'
    text, count = re.subn(pattern, rf'\1"{digest}"', text, count=1)
    if count != 1:
        raise SystemExit(f"could not update {arch} checksum in {path}")
if version_count != 1:
    raise SystemExit(f"could not update version in {path}")
path.write_text(text)
PY

if git diff --exit-code -- "$cask_path" >/dev/null; then
  echo "::error::$cask: no cask changes were generated"
  exit 1
fi

brew style --cask "$full"

branch="bump-${cask}-${latest}"
if gh pr list --head "$branch" --state open --json number --jq 'length' | grep -qv '^0$'; then
  git fetch origin "$branch"
fi
git checkout -B "$branch" origin/main
git add "$cask_path"
git commit -m "$cask $latest"
git push --force origin "HEAD:refs/heads/$branch"

pr_number="$(gh pr list --head "$branch" --state open --json number --jq 'first(.[].number // empty)' || true)"
if [[ -z "$pr_number" ]]; then
  gh pr create \
    --head "$branch" \
    --base main \
    --title "$cask $latest" \
    --body "Created by the multi-OS cask updater. It updates checksums for every supported platform."
else
  gh pr edit "$pr_number" --title "$cask $latest"
fi
