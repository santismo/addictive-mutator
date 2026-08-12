#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
output_dir="${project_dir}/build"
app_bundle="${output_dir}/AD2 Kit Architect.app"
binary="${project_dir}/.build/release/AD2KitArchitect"

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
