#!/usr/bin/env bash
set -euo pipefail
mujoco_repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$mujoco_repo_root"
flutter pub get
dart analyze --fatal-infos
(cd packages/mujoco && dart test --reporter expanded)
(cd packages/mujoco_flutter && flutter test --reporter expanded)
(cd packages/mujoco_viewer && flutter test --reporter expanded)
(cd examples/viewer && flutter test --reporter expanded)
