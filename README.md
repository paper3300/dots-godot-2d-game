# Briar & Bone · 가시나무 속의 종

**독자 제작 Godot 2D 픽셀 아트 턴제 RPG의 작은 완성형 플레이어블입니다.**
마을에서 의뢰와 보급품을 준비하고, 숲길과 여섯 방의 수도원을 탐험한 뒤, 종을 되찾아 살아서 귀환하세요.

Stoneshard의 준비·턴제 전투·치료·귀환이라는 장르적 흐름에서 영감을 받았습니다. 원작의 에셋, 지도, 문구, 코드, 캐릭터를 사용하지 않았습니다. 제목과 세계관은 이 프로젝트를 위해 만든 임시 오리지널 설정입니다.

## 실행

- **Godot 4.6.3 stable, 일반판 (GDScript)**에서 검증했습니다. Compatibility 렌더러를 사용합니다.
- Godot 프로젝트 관리자에서 `project.godot`를 가져온 다음 **F5**를 누르세요.
- 명령행: `godot --path .`
- 기본 언어는 한국어입니다. 시작 화면의 **한국어 / English** 또는 상단 EN 버튼으로 전환할 수 있습니다.
- 한국어 글꼴을 포함하므로 시스템 글꼴 설치가 필요하지 않습니다.
- 기준 화면은 **1280×800**이며 창 크기를 조절할 수 있습니다. 매우 작은 화면이나 모바일은 검증 대상이 아닙니다.

완성된 배포 파일이 제공되는 경우 Windows는 `BriarAndBone.exe`, Linux는 `BriarAndBone.x86_64`를 실행합니다. Web 빌드는 HTTP(S) 서버를 통해 제공해야 합니다. 내보내기 프리셋이 있다는 사실만으로 해당 빌드가 실제 검증되었다는 뜻은 아닙니다. 최신 검증 범위는 `docs/TESTING.md`를 확인하세요.

## 조작

| 조작 | 기능 |
|---|---|
| WASD / 방향키 | 네 방향 한 칸 이동. 적 방향으로 이동하면 기본 공격 |
| 왼쪽 클릭 | 이동·공격·상호작용. 안전한 길에서는 연속 이동 |
| 1 | 내려베기 선택: 피해 +7, 적 행동 1회 저지, 기력 7 |
| 2 | 방어 자세: 적 행동 2회 동안 받는 피해 -6, 기력 4 |
| 3 | 빠른 발걸음 선택: 직선으로 빈 공간 두 칸 이동, 기력 5 |
| 방향키 / 대상 클릭 | 선택한 기술 사용 |
| Space / . | 대기, 기력 회복. 적도 행동 |
| E | 옆의 게시판·NPC·상자·우물과 상호작용 |
| G | 현재 칸 또는 인접한 전리품 줍기 |
| I | 배낭. 물품 클릭으로 정보 확인 후 사용·장착·내려놓기 |
| B / T | 붕대 / 회복 물약 사용 |
| K / L | 저장 / 저장 불러오기 확인 |
| F1 | 여행 안내서 |
| Esc / 오른쪽 클릭 | 기술·이동 취소. Esc는 메뉴 열기·닫기 |

데스크톱에서 F5도 저장할 수 있지만, Web에서는 새로고침 키이므로 **K 또는 메뉴의 저장 버튼**을 사용하세요. 터치 입력은 마우스 클릭으로 연결되며 휴대폰은 가로 화면을 권장합니다. 모바일 전용 레이아웃은 아직 없습니다.

Godot 내장 실행 창의 F9는 에디터 일시정지 키와 충돌하므로, 불러오기는 **L**을 사용합니다.

키를 길게 누르는 반복 입력은 의도적으로 무시합니다. 전투에서 한 번의 입력이 한 번의 행동이 되도록 했습니다. 적이 보이면 자동 이동은 멈추고 클릭 한 번에 한 칸만 이동합니다. 메뉴·가방 열기·유효하지 않은 행동은 턴을 쓰지 않습니다.

## 첫 여정

1. 시작 위치 바로 위 **의뢰 게시판**에서 E를 누르고 의뢰를 수락합니다.
2. 마을 동쪽 **길손 상점**에서 보급품을 구매합니다. 우물은 물을 최대 3개까지 보충하며, 여관은 치료·숙박·저장을 제공합니다.
3. 동쪽 화살표를 밟아 숲길로 떠납니다. 길의 북동쪽 계단이 수도원 입구입니다.
4. 수도원 북서쪽 보급함에는 검, 남동쪽 보급함에는 갑옷이 있습니다. 문을 여는 데에도 한 턴이 듭니다.
5. 북동쪽 방의 **공허의 파수꾼**을 처치하고 종을 회수합니다. 적 위의 **!** 표시는 강한 공격 예고입니다.
6. 왔던 길로 마을에 돌아가 게시판에서 보수 **90 크라운**을 받습니다. 이후 여관은 무료입니다.

## 전투와 보급

- 출혈은 행동마다 체력 1을 깎습니다. **붕대**로 멈출 수 있습니다.
- 깊은 부상은 한 곳당 최대 체력 6을 줄입니다. **약초 찜질약**은 부상 한 곳과 통증을 치료합니다.
- 회복 물약은 체력 25를 회복하지만 부상은 치료하지 않습니다.
- 허기·갈증은 원정 중 천천히 증가합니다. 심해지면 체력을 잃습니다.
- 배낭은 **8개의 종류별 스택 공간**과 별도의 의뢰 주머니를 사용합니다. 모든 물품이 같은 크기인 간소화 모델입니다.
- 물품을 클릭하면 효과와 수량을 읽고 **사용 / 장착 / 1개 내려놓기 / 모두 내려놓기**를 선택할 수 있습니다. 정보창 열기·닫기는 턴을 쓰지 않습니다. 내려놓기는 한 턴을 쓰고 물품은 현재 칸에 남습니다.
- 줍기는 새로 발견한 전리품을 일부러 내려놓은 물건보다 먼저 챙깁니다. 의뢰 물품은 버릴 수 없습니다.
- 장착은 한 턴을 쓰며 이전 장비를 배낭에 보존합니다. 판매는 상점에서만 가능합니다. 무료로 보충하는 물은 판매할 수 없습니다.
- 3개 기술의 재사용 대기시간은 사용 이후 4턴입니다. 경험치로 최대 4등급까지 성장합니다.

## 저장과 죽음

- 새 여정 시작, 숙박, 의뢰 완료 시 자동 저장합니다. **K로 어디서든 수동 저장**할 수 있습니다.
- 저장 슬롯은 하나입니다. 새 여정을 시작하면 확인 후 기존 저장을 교체합니다.
- 죽음 상태는 저장하지 않습니다. 죽으면 L 또는 죽음 화면의 불러오기로 마지막 저장 지점으로 돌아갑니다.
- 저장은 임시 파일에 기록한 뒤 교체하며 스키마 검증 후 불러옵니다. 잘못된 파일은 현재 여정을 바꾸지 않습니다.
- 데스크톱 저장 위치: Godot의 `user://briar_and_bone_save.json` (운영체제별 사용자 앱 데이터 폴더). Web 저장은 해당 브라우저/사이트 저장소에 종속됩니다.
- 저장 파일을 지우거나 브라우저 사이트 데이터를 지우면 복구할 수 없습니다. 마지막 저장 이후 진행은 불러오기 시 사라집니다.

## 개발과 테스트

```sh
sh scripts/smoke-test.sh
# 더 긴 저장/재생 무작위 검증 포함
FULL_TESTS=1 sh scripts/smoke-test.sh
# binary 이름이 다른 경우
GODOT_BIN=godot4 sh scripts/smoke-test.sh
```

테스트는 사용자의 실제 저장을 건드리지 않는 임시 디렉터리에서 실행됩니다. 규칙, 거래, 치료, 전투, 저장 검증, 시야 대칭성, 입구 점유, 그리고 의뢰부터 귀환까지 실제 명령을 수행하는 전체 모험을 확인합니다.

- `game/run_state.gd`: UI와 독립적인 턴·전투·세계·물품·저장 규칙
- `scenes/main.gd`: 입력, 화면, 모달, 간단한 오디오 효과
- `assets/sprites/`: 독자 제작 스프라이트
- `scripts/generate-art.py`: 스프라이트 생성 원본. 수정 시 Python + Pillow 필요
- `tests/test_rules.gd`: 결정론적 회귀 테스트와 전체 모험
- `tests/test_ui.gd`: 정보창, 저장/불러오기, 취소, 연속 클릭 회귀 검증
- `tests/fuzz_*.gd`: 저장/재생 및 물품 보존에 대한 고정 시드 반복 검증
- `docs/DESIGN.md`: 범위, 결정, 제한 사항
- `docs/TESTING.md`: 검증 내역
- `export_presets.cfg`: Linux, Windows, Web 내보내기 프리셋
- `scripts/build-release.sh`: 일치하는 템플릿으로 세 플랫폼 빌드 및 라이선스 포함
- `scripts/subset-font.py`: 로컬 원본 Noto TTC에서 필요한 글꼴을 재생성

배포용 내보내기에는 정확히 일치하는 Godot 4.6.3 템플릿이 필요합니다. Godot의 **Editor → Manage Export Templates**에서 설치한 후 예를 들어 `godot --headless --path . --export-release "Windows" builds/windows/BriarAndBone.exe`를 실행합니다. 생성 폴더는 Git에서 제외됩니다.

## 현재 범위

마을 1개, 숲길 1개, 손으로 설계한 던전 1개, 의뢰 1개, 적 4종, 기술 3개로 구성된 수직 슬라이스입니다. 절차 생성 던전, 대륙 지도, 멀티플레이, 여러 저장 슬롯, 캐릭터 생성, 내구도, 세부 신체 부위 시뮬레이션, 복잡한 기술 트리는 구현하지 않았습니다. 플레이 시간 15~25분은 설계 목표이며 실제 사용자 측정치가 아닙니다.

## English quick start

An original small tactical RPG. Open `project.godot` in Godot 4.6.3 and press F5. Switch to English on the title screen. Accept the board's contract, prepare supplies, follow the east road, recover the bell from the ruin's northeast chamber, and return for payment.

WASD/arrows move and attack; 1/2/3 select skills, Space waits, E interacts, G loots, I opens the pack (click an item for Use/Equip/Drop), B bandages, T uses a tonic, K saves, L restores, and F1 opens the field guide. Each valid world action advances enemies once. Invalid actions and UI browsing never advance combat. Mouse auto-walking stops at visible danger.

This is a handcrafted three-area vertical slice, not a clone or a full-scale commercial RPG. See the Korean sections and `docs/DESIGN.md` for implementation scope. Third-party font licensing is recorded in `THIRD_PARTY_NOTICES.md`.
