#!/usr/bin/env bash
# Launch the app with fvm from a terminal, picking a platform/mode profile.
# Mirrors scripts/run_flutter.sh from joselicht90/flutter_ha, adapted: this
# app has no compile-time dart-define config (reader URL is set at runtime
# in Settings), so there is no defines file to pass.
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: scripts/run_flutter.sh [android-debug|android-profile|android-release|ios-debug|ios-profile|ios-release|macos-debug|macos-profile|macos-release|linux-debug|linux-profile|linux-release] [device-id]

Without arguments, choose a profile interactively. The script then lists the
available Flutter devices (`fvm flutter devices`) so you can pick a device ID.
EOF
}

profile="${1:-}"
if [[ "$profile" == "-h" || "$profile" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$profile" ]]; then
  profiles=(
    android-debug
    android-profile
    android-release
    ios-debug
    ios-profile
    ios-release
    macos-debug
    macos-profile
    macos-release
    linux-debug
    linux-profile
    linux-release
  )
  PS3='Elegí un perfil: '
  select profile in "${profiles[@]}"; do
    if [[ -n "$profile" ]]; then
      break
    fi
    printf 'Opción inválida.\n' >&2
  done
fi

case "$profile" in
  android-debug) platform=android; mode=debug ;;
  android-profile) platform=android; mode=profile ;;
  android-release) platform=android; mode=release ;;
  ios-debug) platform=ios; mode=debug ;;
  ios-profile) platform=ios; mode=profile ;;
  ios-release) platform=ios; mode=release ;;
  macos-debug) platform=macos; mode=debug ;;
  macos-profile) platform=macos; mode=profile ;;
  macos-release) platform=macos; mode=release ;;
  linux-debug) platform=linux; mode=debug ;;
  linux-profile) platform=linux; mode=profile ;;
  linux-release) platform=linux; mode=release ;;
  *)
    printf 'Perfil no válido: %s\n\n' "$profile" >&2
    usage >&2
    exit 2
    ;;
esac

device_id="${2:-}"
if [[ -z "$device_id" ]]; then
  fvm flutter devices
  default_device=''
  case "$platform" in
    linux) default_device=linux ;;
    macos) default_device=macos ;;
  esac
  read -r -p "ID del dispositivo${default_device:+ [$default_device]}: " device_id
  device_id="${device_id:-$default_device}"
fi

if [[ -z "$device_id" ]]; then
  printf 'Elegí un ID de dispositivo con fvm flutter devices.\n' >&2
  exit 2
fi

cd "$project_root"
fvm flutter run \
  --"$mode" \
  -d "$device_id"
