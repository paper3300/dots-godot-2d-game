#!/bin/sh
# Requires Godot 4.6.3 and matching official export templates.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
godot_bin=${GODOT_BIN:-godot}
case "$($godot_bin --version)" in 4.6.3.*) ;; *) echo 'Godot 4.6.3 is required.' >&2; exit 1;; esac
mkdir -p builds/windows builds/linux builds/web
"$godot_bin" --headless --path . --import
"$godot_bin" --headless --path . --script scripts/write-licenses.gd
"$godot_bin" --headless --path . --export-release Windows builds/windows/BriarAndBone.exe
"$godot_bin" --headless --path . --export-release Linux builds/linux/BriarAndBone.x86_64
"$godot_bin" --headless --path . --export-release Web builds/web/index.html
for target in windows linux web; do
    cp builds/ENGINE-LICENSES.txt "builds/$target/ENGINE-LICENSES.txt"
    cp assets/fonts/LICENSE-NOTO.txt "builds/$target/FONT-LICENSE.txt"
    cp THIRD_PARTY_NOTICES.md "builds/$target/THIRD_PARTY_NOTICES.md"
    cp README.md "builds/$target/README.md"
done
printf '%s\n' 'Exports prepared in builds/windows, builds/linux, builds/web.'
printf '%s\n' 'Run graphical/runtime QA for each target before publishing.'
