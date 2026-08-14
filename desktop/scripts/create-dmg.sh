#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
output_dir="${project_dir}/build"
app_name="${1:-Addictive Mutator.app}"
dmg_name="${2:-Addictive Mutator.dmg}"
app_bundle="${output_dir}/${app_name}"
dmg_path="${output_dir}/${dmg_name}"

if [[ "${app_name}" == */* || "${app_name}" != *.app ]]; then
  print -u2 "Pass an app-bundle name ending in .app, without path separators."
  exit 1
fi

if [[ "${dmg_name}" == */* || "${dmg_name}" != *.dmg ]]; then
  print -u2 "Pass a DMG name ending in .dmg, without path separators."
  exit 1
fi

if [[ ! -d "${app_bundle}" ]]; then
  print -u2 "Build the app first: ./scripts/package-macos-app.sh '${app_name}'"
  exit 1
fi

if [[ -e "${dmg_path}" ]]; then
  print -u2 "Refusing to overwrite an existing disk image: ${dmg_path}"
  exit 1
fi

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/addictive-mutator-dmg.XXXXXX")"
trap 'rm -rf -- "${stage_dir}"' EXIT
ditto "${app_bundle}" "${stage_dir}/Addictive Mutator.app"
ln -s /Applications "${stage_dir}/Applications"

hdiutil create \
  -volname "Addictive Mutator" \
  -srcfolder "${stage_dir}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  "${dmg_path}"

print "Created ${dmg_path}"
