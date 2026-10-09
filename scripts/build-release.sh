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
    cp docs/TESTING.md "builds/$target/TESTING.md"
    case "$target" in
        windows) launch='BriarAndBone.exe를 실행하세요. / Run BriarAndBone.exe.'
            limits='The Windows binary is unsigned. Native Windows playback is not yet verified.' ;;
        linux) launch='BriarAndBone.x86_64를 실행하세요. / Run BriarAndBone.x86_64.'
            limits='Native Linux gameplay and the complete contract were tested. Audible output remains unverified.' ;;
        web) launch='HTTP(S) 서버에서 index.html을 여세요. / Serve over HTTP(S), then open index.html. Direct file:// launch is unsupported.'
            limits='Browser and Android playback remain unverified. This is a single-threaded Web export.' ;;
    esac
    cat > "builds/$target/PLAY-README.txt" <<EOF
BRIAR & BONE / 가시나무 속의 종

$launch

WASD / 방향키: 이동 및 공격, E: 상호작용, G: 줍기, I: 배낭
1/2/3: 기술, Space: 대기, B: 붕대, T: 물약, K: 저장, L: 불러오기
물품 클릭: 정보 · 사용 · 장착 · 내려놓기 / Click items for details, Use, Equip, and Drop.
F1: 도움말, Esc: 메뉴 / 취소. 주요 행동은 화면 버튼으로도 가능합니다.

한국어 / English 버튼으로 언어를 바꿀 수 있습니다.
Touch maps to mouse clicks. Landscape is recommended on phones; a mobile-specific layout is not provided.
$limits
Read TESTING.md for exact verification coverage. Source is provided in the separate source package.
EOF
done
printf '%s\n' 'Exports prepared in builds/windows, builds/linux, builds/web.'
printf '%s\n' 'Run graphical/runtime QA for each target before publishing.'
