#!/usr/bin/env bash
# Final optional step after importing the approved master ZIP into a local checkout.
# Commits only the three immutable image masters; never pushes generated JTX caches.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/check_assets.py --sources-only
test "$(git branch --show-current)" = "main" || { echo "Switch to main first."; exit 1; }
test "$(git remote get-url origin)" != "" || { echo "Missing origin remote."; exit 1; }
echo "Publishing approved binary art masters to $(git remote get-url origin)"
echo "Ensure you have rights to publish the supplied vehicle photograph in this PUBLIC repository."
if [[ "${1:-}" != "--push" ]]; then
  echo "Dry run: supply --push to commit/push exactly the three binary masters."
  git status --short -- Source/Vehicle/car_master.png Source/Vehicle/rear_original.png Reference/APPROVED.png
  exit 0
fi
git add -- Source/Vehicle/car_master.png Source/Vehicle/rear_original.png Reference/APPROVED.png
if git diff --cached --quiet -- Source/Vehicle/car_master.png Source/Vehicle/rear_original.png Reference/APPROVED.png; then
  echo "Binary art masters already committed; no changes."
  exit 0
fi
git commit -m "assets: add approved production artwork masters" -- Source/Vehicle/car_master.png Source/Vehicle/rear_original.png Reference/APPROVED.png
git push origin main
echo "Master artwork pushed. Verify on GitHub and run CI."
