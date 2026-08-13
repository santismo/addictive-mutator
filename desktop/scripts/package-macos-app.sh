#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
output_dir="${project_dir}/build"
app_name="${1:-AD2 Kit Architect.app}"
app_bundle="${output_dir}/${app_name}"
binary="${project_dir}/.build/release/AD2KitArchitect"

if [[ "${app_name}" == */* || "${app_name}" != *.app ]]; then
  print -u2 "Pass an app-bundle name ending in .app, without path separators."
  exit 1
fi

if [[ -e "${app_bundle}" ]]; then
  print -u2 "Refusing to overwrite an existing app bundle: ${app_bundle}"
  exit 1
fi

cd "${project_dir}"
swift build -c release
mkdir -p "${app_bundle}/Contents/MacOS"
cp "${binary}" "${app_bundle}/Contents/MacOS/AD2KitArchitect"
cp "${project_dir}/Info.plist" "${app_bundle}/Contents/Info.plist"
print "Created ${app_bundle}"
