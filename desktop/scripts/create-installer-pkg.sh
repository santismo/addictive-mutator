#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
output_dir="${project_dir}/build"
app_name="${1:-Addictive Mutator.app}"
pkg_name="${2:-Addictive Mutator.pkg}"
app_bundle="${output_dir}/${app_name}"
pkg_path="${output_dir}/${pkg_name}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${project_dir}/Info.plist")"

if [[ "${app_name}" == */* || "${app_name}" != *.app ]]; then
  print -u2 "Pass an app-bundle name ending in .app, without path separators."
  exit 1
fi

if [[ "${pkg_name}" == */* || "${pkg_name}" != *.pkg ]]; then
  print -u2 "Pass a package name ending in .pkg, without path separators."
  exit 1
fi

if [[ ! -d "${app_bundle}" ]]; then
  print -u2 "Build the app first: ./scripts/package-macos-app.sh '${app_name}'"
  exit 1
fi

if [[ -e "${pkg_path}" ]]; then
  print -u2 "Refusing to overwrite an existing installer package: ${pkg_path}"
  exit 1
fi

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/addictive-mutator-pkg.XXXXXX")"
trap 'rm -rf -- "${stage_dir}"' EXIT
mkdir -p "${stage_dir}/Applications"
ditto "${app_bundle}" "${stage_dir}/Applications/Addictive Mutator.app"

pkgbuild \
  --root "${stage_dir}" \
  --identifier "com.santismo.addictive-mutator" \
  --version "${version}" \
  --install-location / \
  --ownership recommended \
  "${pkg_path}"

print "Created ${pkg_path}"
