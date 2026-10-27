# BALANCE LAB

Godot 4 / GDScript로 만든 로컬 2인 협동 물리 퍼즐의 핵심 프로토타입입니다.
기존 프로젝트의 내장 Jolt Physics 설정을 유지했고 Godot 4.7.2로 검증했습니다.
외부 에셋이나 추가 플러그인은 필요하지 않습니다.

**LEVEL 01~04가 포함되며 LEVEL 04가 마지막 단계입니다.** 두 사람이 플랫폼을 기울여 공을 초록색 목표로 이동시킵니다.
공의 중력·충돌·굴림은 내장 Jolt 물리 엔진이 처리합니다. LEVEL 02에는 외곽 벽과 수직 충돌 연장을 사용하며, LEVEL 03·04는 특수 장애물의 실제 형상을 따릅니다.

## 시작 화면과 메뉴

F5로 프로젝트를 실행하면 `scenes/menu.tscn`에서 시작합니다.
작업 폴더의 참고 PNG는 디자인 참고용으로만 확인했으며 실제 게임 배경이나 버튼 이미지로 사용하지 않습니다.
실험실, 유리 패널, 금속 미로 전시대, 조명과 네온 띠는 Godot 기본 Mesh와 Material로 구성했습니다.
메뉴의 공은 물리 게임과 별개인 전시용 애니메이션이며 실제 플레이는 `scenes/main.tscn`, `level_02.tscn`, `level_03.tscn`, `level_04.tscn`에서 실행됩니다.
외부 모델·이미지·폰트·사운드를 다운로드하지 않았고 폰트는 OS의 시스템 폰트 및 내장 대체 폰트를 사용합니다.

- **GAME START**: 레벨 선택 화면을 엽니다. CALIBRATION(01), THE LABYRINTH(02), NEW HORIZONS(03), FINAL ORBIT(04)를 선택합니다.
  기존처럼 네 레벨 모두 선택 가능하며, 별도의 진행도 저장/순차 잠금 해제는 구현하지 않았습니다.
- **SETTINGS**: ICE MODE, 입력 진단 표시, 모션 줄이기, 별도 게임 창의 전체 화면을 실제로 변경합니다.
  내장 게임 창에서는 전체 화면이 지원되지 않아 해당 스위치를 비활성화합니다.
  설정은 `user://settings.cfg`에 저장합니다. 음량 등 구현하지 않은 설정은 표시하지 않습니다.
- **ESC**: 레벨 선택/설정에서는 홈으로, 플레이 중에는 일시정지/재개로 동작합니다.

### 손목 센서와 ICE MODE

키보드 플레이는 Godot만으로 실행합니다. ESP32 + MPU6050 컨트롤러를 사용하려면
먼저 `hardware/start_sensors.command`로 Python/pySerial 중계를 실행해야 합니다.
Godot 실행만으로 중계 프로그램이 자동 시작되지는 않습니다.
최초 실행에는 Python 3와 pySerial 설치가 필요합니다.

- **F4**: 연결 상태·Player 등록·축·반전 설정. 패널을 열면 게임이 일시정지됩니다.
- **C**: 편한 정지 자세를 현재 중립으로 INIT. 실제 `INIT 완료` 표시를 확인합니다.
- **F8**: KEYBOARD/SENSOR 전환. 센서 모드에서도 해당 축의 키보드 입력이 우선합니다.
- 두 ESP32는 고유 ID로 역할을 저장해 USB 포트·연결 순서가 바뀌어도 P1 좌우/P2 앞뒤를 유지합니다.
  개인별 역할·영점 파일은 Git 제외이며 새 PC에서는 최초 등록과 C 보정이 필요합니다.
- **ICE MODE**: 기본 OFF. 설정을 저장하고 다음 레벨 시작/RESTART에 적용합니다.
  네 맵의 마찰·감쇠를 낮추며 일반 모드 재질·충돌 구조는 보존합니다.

[센서 운영 안내](hardware/SENSOR_CONTROLLERS.md) · [센서 실제 검증](reports/sensors/validation.md) ·
[ICE 수정·검사](reports/ice_mode/fixes.md) · [QA와 미해결 항목](docs/qa/QA_REPORT.md) · [개발 연혁](docs/devlog/README.md)

Windows용 개발 실행 `.bat`는 있지만 독립 EXE/Export 패키지는 아직 제작하지 않았고 Windows 실기기 검증도 남아 있습니다.

기본 디자인 해상도는 1920×1080, 16:9입니다. 최초 실행 창은 화면에 잘 맞는 1280×720이며
최소 960×540으로 설정했습니다. Anchor/Container와 canvas_items 스트레치를 사용하고
다른 종횡비에서는 레터박스로 비율을 유지해 UI가 잘리지 않도록 합니다.

## 플레이 인터페이스

상단에는 LEVEL 01, 경과 시간, 현재 상태와 PAUSE 버튼이 표시됩니다.
하단에는 PLAYER 1: A/D, PLAYER 2: ↑/↓ 및 실패 횟수와 단축키 안내가 있습니다.
목표에 도착하면 COMPLETE로 바뀌고 경과 시간이 멈춥니다. 플랫폼 조작과 공의 움직임을 잠그고
화면 중앙에 MISSION SUCCESS! 결과 화면을 표시합니다.
공 복귀 후에는 2초간 BALL RESET 상태를 보여주고 IN PROGRESS로 돌아옵니다.
R은 공만 재배치하며 경과 시간과 실패 횟수를 유지합니다.
클리어 후에는 R/ESC로 완료 상태를 해제하지 않으며 결과 화면의 RETRY 또는 LOBBY를 사용합니다.

ESC 또는 PAUSE 버튼은 SceneTree를 일시정지해 공·플랫폼·타이머를 함께 정지합니다.
일시정지 UI만 계속 처리하므로 다음 실제 버튼을 사용할 수 있습니다.

- **RESUME**: 같은 상태에서 재개합니다.
- **RESTART**: 현재 레벨 Scene을 새로 불러와 공·플랫폼·시간·실패 횟수를 초기화합니다.
- **MAIN MENU**: 일시정지를 해제하고 시작 Scene으로 돌아갑니다.

기존 입력 진단 화면은 F3 또는 Settings의 INPUT DIAGNOSTICS로 표시/숨김할 수 있습니다.
디버그 로그와 키보드/센서 입력 어댑터는 유지했습니다.
모션 줄이기는 실험실 전시 공을 정지시키고 메뉴/Scene 전환 시간을 줄입니다.

## 미션 성공과 결과 화면

`MissionController`에 연결된 Goal `Area3D`가 **지정된 Ball 인스턴스**의 진입을 감지하면 한 번만 완료합니다.
다른 물체가 공과 같은 충돌 레이어를 사용하더라도 완료 처리하지 않습니다.
완료 플래그를 먼저 설정하고 Goal 모니터링을 끄므로 반복 접촉이나 중복 신호로 재실행되지 않습니다.

- 클리어 순간의 경과 시간을 별도로 보관하고 타이머를 정지합니다.
- 플랫폼의 물리 처리/회전 입력을 중단해 현재 기울기를 유지합니다. 입력 어댑터와 진단 기능은 유지합니다.
- 물리 질의 처리 이후 공을 Freeze하고 선형/각속도를 0으로 만들어 결과 화면 뒤에서 떨어지지 않게 합니다.
- 실제 Godot UI로 MISSION SUCCESS!, 클리어 시간, LOBBY/RETRY 버튼을 표시합니다.
  결과 패널은 페이드/확대 애니메이션으로 등장하고 Goal 위치에서 네이티브 3D 파티클이 한 번 발생합니다.
- 모션 줄이기가 켜져 있으면 등장 시간을 짧게 하고 파티클을 생략합니다.
- **LOBBY**는 기존 `Session.MENU_SCENE`인 `scenes/menu.tscn`으로 이동합니다. 별도 가상 로비는 만들지 않았습니다.
- **RETRY**는 현재 맵의 `scene_file_path`를 다시 불러와 시간·실패 횟수·물리·입력·클리어 상태를 초기화합니다.

다른 맵에서는 `MissionController`의 Inspector에 그 맵의 **Goal(Area3D), Ball(RigidBody3D), Platform**을 연결하세요.
Goal의 위치를 코드에서 가정하지 않으며 파티클도 실제 Goal의 월드 위치에서 생성됩니다.
Goal을 이동할 때 초록색 GoalMarker도 함께 이동하세요. 새 맵의 경로/잠금 상태는 기존 level_catalog에서 관리합니다.
공의 물리/충돌 설정과 플레이 중의 2인 입력 방식은 유지했습니다.

기울일 때 보이던 플레이 맵 아래 장식 지지대 4개는 `visible=false`로 숨겼습니다.
이 지지대는 원래 충돌 도형이 없는 표시용 Mesh이므로 플랫폼/공 충돌에는 영향을 주지 않습니다.
시작 화면 실험실의 구조 기둥은 유지했습니다.

플레이 화면의 장식 바닥·격자·외곽 조명은 더 아래(Y=-6 부근)에 배치했습니다.
16×16 플랫폼을 X/Z 각 축 ±15도로 동시에 기울여도 아래쪽 모서리가 배경 바닥에 묻히지 않습니다.
이 높이는 `scripts/ui/lab_backdrop.gd`의 `GAMEPLAY_FLOOR_Y`에서 조정하며, 시작 화면 배경에는 적용되지 않습니다.

## 실행

1. Godot 프로젝트 관리자에서 이 폴더의 `project.godot`를 가져오거나 엽니다.
2. **F5**로 시작 화면을 실행한 뒤 GAME START를 누릅니다.
   게임만 확인하려면 `scenes/main.tscn`을 열어 **F6**으로 직접 실행할 수 있습니다.
3. 실행 창을 클릭해 키보드 포커스를 준 뒤 두 사람이 같은 키보드로 조작합니다.

| 조작 | 기능 |
| --- | --- |
| Player 1: A / D | 왼쪽 / 오른쪽 가장자리를 낮춤 |
| Player 2: ↑ / ↓ | 앞쪽(-Z, 화면의 먼 쪽) / 뒤쪽(+Z, 화면의 가까운 쪽) 가장자리를 낮춤 |
| R | 공의 위치·회전·운동량 초기화. 실패 횟수는 유지 |
| ESC | 일시정지 / 재개 |
| F3 | 입력 진단 화면 표시 / 숨김 |

키를 놓으면 해당 축이 수평으로 부드럽게 복귀합니다. 반대 키를 함께 누르면 해당 축 입력은 0입니다.
각 회전축의 최대 각도는 ±15도입니다. 두 축을 동시에 조작하면 두 축에 각각 한도가 적용됩니다.

플랫폼은 원점에서 회전하며, 입력과 별도의 각도 상태를 사용해 AnimatableBody3D의 물리 동기화 중에도
보간을 계속합니다. 카메라는 `(0, 22, 18)`에서 플랫폼 중심을 `look_at()`으로 바라보는 고정 직교 시점입니다.
실행 시 `make_current()`로 활성화합니다. 일반 플레이의 직교 크기는 24, 수직 오프셋은 0입니다.
입력 진단 표시 중에는 직교 크기 30, 수직 오프셋 -3으로 바꿔 진단 패널과 겹치지 않도록 합니다.

## 첫 번째 기본 미로

공은 플랫폼 왼쪽 `(-5.6, 1.1, 3.4)`에서 출발합니다. 경로는
**오른쪽 → 앞쪽(-Z) → 오른쪽 → 뒤쪽(+Z)**으로 세 번 꺾이며, 오른쪽 `(5.6, 0.7, 1.2)`의 기존 Goal로 이어집니다.
시작점과 Goal 중심은 플랫폼 좌우 가장자리에서 각각 2.4m 떨어져 있습니다.
구멍·움직이는 장애물·갈림길 없이 두 방향의 협동 조작을 사용하는 단순한 통로입니다.

- 벽 10개: 밝은 회색 금속 BoxMesh, 높이 0.75m, 두께 0.32m, 은은한 청색 상단 테두리.
- 미로 위에는 Mesh가 없는 `EscapeCeiling` 충돌 덮개를 둡니다. 크기 16×0.2×16m,
  아랫면은 플랫폼 로컬 Y=1.7m로 공의 최초 위치/복귀 위치와 겹치지 않습니다.
  벽 상단(Y=0.95m)과 덮개 사이 간격은 0.75m로 공 지름 1m보다 작아 벽 위로 넘어갈 수 없습니다.
  플랫폼의 직접 자식이므로 바닥·미로와 함께 기울어지며 일반 화면에서는 보이지 않습니다.
- 벽 중심선 사이 간격 3m, 실제 통로 폭 약 2.68m. 지름 1m인 공 양옆에 충분한 여유를 둡니다.
- `scenes/maps/basic_maze.tscn`을 Main의 **Platform 자체로 인스턴스화**합니다.
  벽 CollisionShape3D와 기존 바닥 CollisionShape3D 모두 동일한 AnimatableBody3D의 직접 자식입니다.
  별도 움직이는 물리 몸체 사이의 지연 없이, 벽 표시와 충돌이 플랫폼 중심을 기준으로 함께 회전합니다.
- 기울기·입력 Script는 기존처럼 Main에서 Platform에 연결합니다. 맵 Scene에는 게임 로직이 없습니다.
  다음 맵은 같은 AnimatableBody3D 루트 아래에 벽 Mesh/충돌을 구성하고 인스턴스 경로를 교체하면 됩니다.
  원점·기존 바닥 크기·Goal/공 시작 위치를 새 맵에 맞추고, 충돌 도형은 물리 몸체의 직접 자식으로 유지하세요.
- 기존 플랫폼/공 재질, 카메라, 메뉴, 일시정지, 재시작, Mission Success 시스템을 유지합니다.

자동 기울기 주행으로 출발점부터 세 코너를 지나 Goal까지 물리 이동을 검사합니다.
이는 경로와 충돌 검증이며, 두 사람이 실제 키보드로 30초~1분에 클리어하는 난이도는 직접 플레이 후 조정해야 합니다.

## LEVEL 02 — Tinkercad 미로

F5 → LEVEL SELECT → THE LABYRINTH → ENTER LAB으로 실행합니다.
직접 실행은 `scenes/level_02.tscn`을 열고 F6입니다. LEVEL 01의 Scene·재질·고정 카메라는 변경하지 않았습니다.

### 원본과 배치

- 원본: `prototypes/tinkercad/2nd map/Grand Fulffy/tinker.obj`, 재질: 같은 폴더 `obj.mtl`.
  저장소의 `Grand Fulffy.zip` 안 OBJ와 작업 폴더의 OBJ가 동일함을 확인했습니다. 원본 이동/복사/수정 없음.
- `tinker_preview.png`는 참고만 했으며 게임 Scene에서는 참조하지 않습니다.
- OBJ 실제 범위: X=185.898, Y=388, Z(높이)=39. 균일 배율 0.1로 18.5898×38.8, 높이 3.9가 됩니다.
  X축 -90도 회전으로 Tinkercad Z-up을 Godot Y-up으로 바꾸고, 모델의 평면 중심을 플랫폼 원점에 맞춥니다.
- 바닥 20.6×0.4×40.8, 상면 Y=0.2. OBJ 하단과 모든 충돌 프록시의 하단이 이 상면에 맞닿습니다.
- 696개 원본 삼각형을 19개 연결된 구조별로 분리 렌더링합니다. 위치·형상·비율을 유지하며,
  분리 목적은 공을 가리는 구조물만 반투명하게 하기 위한 것입니다. 임의의 미로를 생성하지 않습니다.
- 시작점 `(-0.1562, 1.1, 18.4)`, Goal `(2.6438, 0.8, -18.4)`는 원본 양끝 표시판에 맞췄습니다.
  원본 표시판은 바닥 위 0.1m 두께이며 공은 시작 표시판 위에서 Y≈0.8로 안착합니다.

### 충돌과 공의 반발

기존 LEVEL 01은 10개의 벽 충돌과 한 개의 수평 덮개를 사용합니다. 벽 전체를 덮는 중복 수직 충돌벽은 없었습니다.
기존 공은 Bounce=0.05, Friction=0.6, 감쇠 0.05/0.1입니다. 수평 벽 충돌 비교에서
충돌 직전 속도 약 2.86에 대해 기존 반발 속도 약 0.14, 새 프로필 약 0.63을 측정했습니다.
이 비교는 공이 바닥에 붙어 있고 덮개에 닿지 않는 상태이므로 낮은 반발력 자체의 영향을 구분합니다.
수평 덮개는 위로 튀었을 때 별도 접촉을 만들 수 있지만, 모든 수평 충돌의 원인이라고 단정하지 않습니다.

LEVEL 02에는 다음을 적용합니다. LEVEL 01의 물리 재질과 덮개는 유지합니다.

- 원본의 19개 독립 솔리드당 ConvexPolygonShape3D 하나. Concave/Trimesh와 중복 원본 충돌은 없습니다.
- 14개 얇은 벽은 **같은 Convex의 위쪽을 연장**합니다. 기본 높이 3.5m, 최소 두께 0.12m.
  시각 메시의 원래 높이와 위치는 유지하며 수평 천장은 만들지 않습니다.
- 기둥·곡면 장애물·양끝 표시판은 원본 꼭짓점으로 만든 Convex를 사용합니다.
- 네 외곽 벽: 표시 높이 1.1m, 두께 0.4m. 충돌은 동일한 수직 연장 높이까지 이어집니다.
- 바닥, 원본 프록시, 외곽 벽 모두 같은 Platform AnimatableBody3D의 직접 자식입니다.
- 공 Friction=0.24/Bounce=0.22, 플랫폼 Friction=0.32/Bounce=0. 기존 감쇠와 CCD는 유지합니다.
- 긴 판에 기존 회전 반응을 그대로 적용한 급반전 검사에서 공이 약 9.5m까지 튀고 탈출했습니다.
  LEVEL 02에만 각 축 **최대 회전 속도 8도/초**를 적용해 같은 검사에서 탈출을 막았습니다.
  공통 플랫폼 Script의 제한 기본값은 0(해제)이므로 LEVEL 01의 조작 반응은 그대로입니다.
- 최대 기울기 ±15도, 부드러운 보간과 키를 놓을 때 수평 복귀는 공유합니다.
  긴 판이 기울어져도 바닥에 있는 공을 실패 처리하지 않도록 LEVEL 02의 실패 높이는 -12 이하로 계산합니다.

### 추적 카메라

`Camera3D`는 플랫폼 밖 Main의 직접 자식으로, 월드 위쪽을 유지합니다.
공의 위치에 전방 오프셋을 더한 추적 중심을 지수 보간하며, 높이 변화는 더 천천히 따라갑니다.
직교 쿼터뷰이고 공은 화면 중앙보다 아래에 보입니다. 추적 중심은 바닥 범위 안에서 제한합니다.
공을 가리는 원본 구조물과 외곽 벽만 반투명하게 하며 충돌/형상은 바꾸지 않습니다.
재배치 후 카메라도 시작점을 향해 부드럽게 돌아옵니다. LEVEL 01 카메라는 기존 고정 방식입니다.

### Inspector 조정

값을 바꾼 뒤 게임을 다시 시작하면 새 설정으로 구성합니다. 원본 모델 파일은 수정하지 마세요.

| 위치 / 값 | 기본값 | 역할 |
| --- | --- | --- |
| Platform / Model Scale | 0.1 | 원본의 균일 배율. 변경 시 공 크기와 시작점/Goal도 다시 검증 |
| Platform / Floor Margin | 1.0 | 실제 원본 바깥에 확보하는 바닥 여유 |
| Platform / Outer Wall Height, Thickness | 1.1 / 0.4 | 외곽 벽 표시 높이와 두께 |
| Platform / Escape Wall Height | 3.5 | 벽/외곽 벽의 충돌 연장 높이 |
| Platform / Start Position, Goal Position | 위 좌표 | 맵별 시작/복귀와 Goal 위치 |
| Platform / Max Angular Speed Degrees | 8 | 긴 판의 급상승으로 공이 튀는 것을 줄이는 축별 회전 속도 |
| Camera3D / Height, Distance | 14 / 11 | 공에 대한 월드 기준 높이/거리 |
| Camera3D / Tracking Speed, Vertical Tracking Speed | 5 / 2 | 수평/높이 추적 반응 |
| Camera3D / Look Ahead | (0, -2.4) | 진행 경로를 더 보여주는 전방 오프셋 |
| Camera3D / Camera Offset, View Size | (0, 0, 0) / 14 | 추가 위치 오프셋과 직교 시야 크기 |
| Camera3D / Bounds Padding | (3, 0.5) | 맵 끝에서 추적 중심을 제한할 여유 |
| Camera3D / Occlusion Transparency | 0.8 | 공을 가리는 구조물의 투명도. 0이면 비활성 |

자동 주행은 실제 RigidBody에 기울기 입력만 주어 원본 통로를 따라 Goal까지 도달했습니다.
이는 경로/충돌 검증이며 사람의 플레이 난이도, 동시 키보드 입력, 반발감과 카메라 감각은 직접 확인해야 합니다.

## Input Map과 로그 확인

**프로젝트 → 프로젝트 설정 → Input Map**에서 다음 물리 키 연결을 확인할 수 있습니다.

| Action | 물리 키 | 입력값 / 회전 |
| --- | --- | --- |
| tilt_left | A | Player 1=-1 → Z축 +15도 |
| tilt_right | D | Player 1=+1 → Z축 -15도 |
| tilt_forward | ↑ | Player 2=-1 → X축 -15도 |
| tilt_backward | ↓ | Player 2=+1 → X축 +15도 |

두 축은 `Input.get_axis()`로 각각 읽습니다. 플랫폼 제어 코드는 키보드를 직접 읽지 않습니다.
키 위치를 사용하는 물리 키 설정이므로 한글 입력 상태에서도 같은 위치의 키로 조작합니다.

Godot 하단 **Output(출력)** 패널에서 아래와 같은 로그를 확인하세요.

```text
[Platform] input_source=/root/Main/TiltInput limit=+/-15.0 deg
[TiltInput] source=keyboard keys=[A, Up] Player 1=-1.00 Player 2=-1.00
[Platform] Player 1=-1.00 Player 2=-1.00 X=-7.91 deg Z=7.91 deg
```

`TiltInput`은 눌린 키 또는 입력 상태가 바뀔 때만 로그를 출력합니다. A+D처럼 상쇄되는 조합도 기록합니다.
`Platform`은 0.2초마다 현재 입력값과 실제 X/Z 회전값을 도 단위로 출력합니다.
로그가 필요 없으면 각 노드 Inspector에서 `Debug Logging`을 끄면 됩니다.
키 로그가 전혀 바뀌지 않으면 게임 실행 창을 클릭해 포커스를 확인하세요.

### macOS에서 키 입력이 반응하지 않을 때

이전 자동 검증은 `Input.parse_input_event()`로 만든 이벤트를 주입한 검사입니다.
사용자의 실제 키보드, macOS 이벤트 전달, 편집기 게임 입력 모드나 포커스까지 검증한 결과가 아닙니다.
이번 사용자 확인에서는 처음에 키를 눌러도 `Events=0`이었고, 내장 게임 화면에서 **Input** 모드를
선택하고 게임 화면을 클릭한 뒤 Events가 증가했습니다. 확인된 차이는 내장 게임의 입력 모드/포커스
단계에서의 키 전달이며, 이 문제를 이유로 키 매핑이나 플랫폼 회전 수식을 변경하지 않았습니다.
이어 사용자가 A와 ↑를 눌렀을 때 P1/P2 및 X/Z 값이 바뀌고 플랫폼도 기울어지는 것을 확인했습니다.
이 실제 키보드 확인은 합성 이벤트를 주입하는 자동 검사 결과와 별도로 기록합니다.

실행을 완전히 중지한 뒤 상단 삼각형 버튼(F5)으로 다시 실행해 GAME START를 누릅니다.
F3 또는 Settings의 INPUT DIAGNOSTICS를 켜고 화면 하단의 **INPUT TRACE v1**을 확인합니다.
표시가 없다면 아직 예전 실행 인스턴스이거나 다른 Scene/프로젝트를 보고 있는지 확인하세요.
시작 로그 `[InputDebug READY]`에는 실행 프로젝트 경로와 Scene 경로도 표시됩니다.

1. 편집기 상단 **게임(Game)** 화면을 엽니다. 편집용 **3D** 작업 공간과 실행 중인 게임 화면을 구분하세요.
2. 게임 화면 위의 **Input / 2D / 3D** 상호작용 모드에서 **Input**을 선택한 뒤 게임 화면 안을 클릭합니다.
   **2D/3D 모드는 게임 입력을 차단**합니다. 편집기 Pause(F9)를 해제하고 게임 속도는 1×로 둡니다.
3. A/D와 ↑/↓를 각각 1초간 눌러 `Events`, `Last press`, `Keys`, `P1/P2`, `Platform`, `X/Z` 순으로 확인합니다.
4. 비교하려면 실행을 중지하고 게임 화면 우측 메뉴에서 **Embed Game on Next Play**를 끈 뒤 다시 실행합니다.
   Game bar가 없는 별도 실행 창을 클릭하고 동일하게 검사합니다. 단순히 Floating 창으로 바꾸는 것과 구분하세요.
5. 영문 ABC 입력 소스와 한글 입력 소스에서 비교합니다. 매핑은 QWERTY 물리 키 위치를 기준으로 유지하며,
   `_input` 로그에 물리 코드·논리 코드·Unicode·일치한 액션을 남겨 실제 전달 차이를 확인합니다.
   게임 안의 텍스트 입력칸이 없으므로 전역 키보드 감시 권한이나 시스템 보안 설정 변경은 필요하지 않습니다.

| 화면의 관찰 | 다음 확인 |
| --- | --- |
| Map에 MISSING | 프로젝트 설정의 해당 액션과 물리 키 연결 |
| TiltInput ready 또는 _input이 false / Link가 false | 실행 Scene의 스크립트, 노드 처리 상태, Platform.input_source 연결 |
| Events=0, Window focus=false | 게임 창 클릭, 다른 편집기/Output/인스펙터에 포커스가 있는지 확인 |
| Events=0, Window focus=true | 내장 게임 Input 모드 확인. 포커스 true만으로 편집기의 입력 전달을 보장하지 않음. 별도 창과 비교 |
| Events 증가, matches가 비어 있음 | 마지막 이벤트의 physical/keycode와 Input Map을 비교 |
| P1/P2는 변하는데 Platform이 0 | 센서 모드 여부, 플랫폼 입력 연결 및 물리 처리 상태 확인 |
| 입력은 오지만 Physics ticks가 멈춤 | 편집기 Pause/브레이크포인트/게임 속도, Tree paused 및 노드 처리 상태 확인 |
| X/Z 또는 Peak는 변하는데 화면이 그대로임 | 실행 게임을 보고 있는지, 편집기 카메라 오버라이드 상태 확인 |

`Events`는 `_input()`이 받은 non-echo 키 이벤트 수이고, `Last press`는 키를 놓아도 마지막 누름을 유지합니다.
`Keys/P1/P2`는 현재 폴링 값, `Platform`은 플랫폼이 마지막 물리 프레임에 실제 받은 입력입니다.
`Peak`는 실행 이후 관찰한 최대 X/Z 회전 크기이며 짧은 키 누름도 확인할 수 있습니다.
`Tree paused`는 SceneTree 상태입니다. 편집기 디버거의 Pause는 별개이므로 `false`여도 Physics ticks가
계속 증가하는지 확인해야 합니다. 진단 UI는 키를 소비하거나 포커스를 강제로 빼앗지 않습니다.

입력 모드 설명: [Godot Game embedding](https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html),
키 코드 설명: [Godot InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html).

## 파일 구성과 역할

- `scenes/menu.tscn`: 별도 시작 Scene. 실제 3D 실험실 배경과 네이티브 메뉴 UI.
- `scenes/ui/lab_backdrop.tscn`, `scripts/ui/lab_backdrop.gd`: 기본 도형으로 만든 실험실/미로 전시 환경.
- `scripts/ui/menu.gd`: 홈/레벨 선택/설정의 실제 Button, CheckButton 및 Container 구성.
- `scripts/ui/lab_ui.gd`, `menu_button.gd`: 공통 색상·시스템 폰트·네온 테두리 및 호버/클릭 애니메이션.
- `scripts/ui/game_hud.gd`: 상하단 플레이 HUD, 일시정지 메뉴와 진단 표시.
- `scripts/session.gd`: 작은 Autoload. 설정 저장, 선택 레벨, 화면 전환과 일시정지 해제 관리.
- `scripts/level_catalog.gd`: 레벨 목록. Tinkercad 맵을 연결할 때 이 파일에 실제 Scene 경로와 잠금 해제를 등록.
- `scripts/mission_controller.gd`: Goal/공 식별, 중복 완료 방지, 완료 후 물리/조작 잠금과 일회성 파티클.
- `scenes/ui/mission_success.tscn`, `scripts/ui/mission_success.gd`: 재사용 가능한 성공 결과 UI와 등장 연출.
- `scenes/main.tscn`: Main 3D Scene. 16×0.4×16 플랫폼, 반지름 0.5의 공,
  충돌 도형, 목표 감지 영역, 고정 카메라, 조명 및 최소 안내 UI.
- `scenes/maps/basic_maze.tscn`: Platform으로 사용하는 기본 미로의 벽 Mesh/Collision Scene. 별도 제어 Script 없음.
- `scripts/tilt_input.gd`: 키보드를 정규화된 Vector2 입력으로 변환하는 입력 어댑터.
- `scripts/platform_controller.gd`: 입력값만 받아 물리 프레임마다 지수 보간으로 플랫폼을 기울임.
  AnimatableBody3D를 사용해 움직이는 플랫폼의 충돌을 물리에 반영합니다.
- `scripts/ball.gd`: RigidBody3D 물리 공. 높이 감지 및 `fell` 신호, 물리 상태 콜백에서 복귀 및 운동량 초기화.
- `scripts/maps/tinkercad_platform.gd`: LEVEL 02 원본 삼각형과 Convex 프록시, 바닥/외곽 벽, 맵별 시작/Goal 설정.
- `scripts/follow_camera.gd`: LEVEL 02의 추적 보간, 범위 제한과 가림 구조물 투명 처리.
- `scenes/level_02.tscn`, `tests/level_02_test.gd`: 별도 LEVEL 02 Scene과 물리/카메라 통합 검사.
- `scripts/main.gd`: `fell` 신호를 받아 실패 횟수 증가·복귀 요청. 카메라 활성화, 목표 안내 및 R키 재시작 연결.
- `scripts/input_debug.gd`: 화면의 입력 진단 표시. 포커스, 실행 연결, 액션 등록, 이벤트 수신 및 플랫폼 전달을 관찰.
- `tests/tilt_smoke_test.gd`: Input Map을 통과하는 합성 키 이벤트로 카메라/입력/회전을 검증.
  기본 Scene의 공 물리 활성화 상태를 확인한 뒤 테스트 내부에서만 공을 고정해 플랫폼 조작을 독립적으로 검사.
- `tests/ball_physics_test.gd`: 공의 중력, 회전, 관성, 마찰/감쇠, CCD, 실제 가장자리 추락 및 복귀와 목표 도착 검사.
- `tests/ui_flow_test.gd`: 실제 GUI 노드에 마우스/키 이벤트를 전달해 메뉴 전환, 설정 저장, 일시정지,
  물리·타이머 정지, 재개, 전체 재시작, 메인 메뉴 복귀 및 여러 창 크기의 UI 영역을 검사.
- `tests/mission_success_test.gd`: 실제 Area3D 겹침을 사용해 공만 판정, 중복 방지, 완료 시간/조작 잠금,
  결과 UI, RETRY/LOBBY, 이동한 Goal, 모션 줄이기와 장식 지지대 숨김을 검사.
- `tests/basic_maze_test.gd`: 왼쪽 시작점, 벽 충돌/회전, 공 크기의 경로 탐색, 카메라 시야와 공 가림,
  실제 벽 접촉, 추락 후 새 시작점 복귀, 기울기 입력만으로 세 코너를 통과하는 물리 주행과 성공 화면을 검사.

플랫폼/공의 충돌 레이어는 각각 1/2이며, 목표 Area3D는 공만 감지합니다.
목표 표시에는 물리 장벽이 없으며, 플랫폼 가장자리에도 벽을 두지 않아 밖으로 떨어질 수 있습니다.

## 추후 기울기 센서 연결

`TiltInput`의 `use_sensor_input`을 켜고, 센서 어댑터에서
`set_sensor_axes(Vector2(left_right, front_back))`를 호출하면 됩니다.
각 입력은 -1~1로 제한됩니다. X의 양수는 오른쪽, Y의 양수는 가까운 쪽을 낮춥니다.
입력은 다음 값이 도착할 때까지 유지되므로 센서 연결이 끊기면 어댑터에서 0을 전달해야 합니다.
센서의 통신, 영점 보정, 각도 정규화는 어댑터에서 처리하면 플랫폼 제어 코드를 유지할 수 있습니다.
현재 실제 센서 통신은 구현하지 않았습니다.

## LEVEL 01 공 물리와 실패 처리

공은 `freeze=false`, 질량 1kg, 중력 배율 1로 동작하며 별도의 이동 힘을 가하지 않습니다.
공/플랫폼의 마찰 계수는 각각 0.6, 공의 반발 계수는 0.05입니다.
선형 감쇠 0.05와 각 감쇠 0.1로 관성을 유지하면서 속도가 서서히 줄어들게 설정했습니다.
구형 충돌 반지름과 표시 반지름은 모두 0.5이며, 연속 충돌 감지(CCD)를 유지합니다.
공에는 Godot 내장 GradientTexture2D로 만든 단순한 띠를 표시해 실제 회전이 눈에 보이도록 했습니다.
추가 충돌 도형이나 외부 이미지 없이 표시 재질에만 적용됩니다.

공이 월드 Y=-6 아래로 떨어지면 `ball.gd`가 `fell` 신호를 보내고 `main.gd`가 실패 횟수를
한 번 증가시킨 뒤 `request_reset()`을 호출합니다. 게임 규칙은 메인에, 물리 상태 변경은 공에 둡니다.
복귀 시 선형 속도·각속도는 0, 회전은 단위 회전으로 초기화하고 플랫폼 로컬 `(-5.6, 1.1, 3.4)`에 배치합니다.
중력에 의해 플랫폼 위로 안착하며, 키를 계속 누르고 있으면 현재 플랫폼 기울기에 따라 다시 굴러갑니다.
16×16 맵의 기본 최대 기울기에서 플랫폼 아래로 충분히 떨어진 뒤 실패하도록 높이를 -6으로 낮췄습니다.
실패 횟수와 복귀 안내는 화면에 유지됩니다. R키로 직접 재시도하는 것은 실패 횟수에 더하지 않습니다.
목표 영역에 도착하면 미션 성공 화면을 표시하고 공과 플랫폼을 멈춥니다. 결과 화면 RETRY로 새로 시작합니다.
목표 표시는 폭/깊이 1.6, 위치 `(5.6, 0.215, 1.2)`이며 성공 판정은 별도의 Area3D를 사용합니다.
LEVEL 01은 세 번 꺾이는 기본 미로이며, LEVEL 02는 별도의 OBJ 기반 Scene을 사용합니다.

### Inspector에서 조정

| 노드/속성 | 기본값 | 용도 |
| --- | --- | --- |
| Platform / Max Tilt Degrees | 15 | 축별 최대 기울기. 현재 0~30도 편집 가능 |
| Platform / Tilt Response | 5 | 기울기와 수평 복귀 반응 속도 |
| Ball / Spawn Local Position | (-5.6, 1.1, 3.4) | 플랫폼 기준 복귀 위치. 최초 Ball 위치도 함께 변경 |
| Ball / Fall Height | -6 | 월드 기준 실패 높이 |
| Ball / Linear Damp, Angular Damp | 0.05, 0.1 | 관성 감쇠 |
| Ball / Physics Material Override | 마찰 0.6, 반발 0.05 | 표면 반응 |

기울기를 15도보다 크게 바꾸면 카메라 시야와 실패 높이도 함께 확인하세요.
이후 미로 모델 교체 시에도 Platform의 원점과 충돌 도형, Ball의 복귀 높이를 맞추면 제어/물리 로직을 유지할 수 있습니다.
표시 Mesh만 교체하면 충돌은 기존 박스로 남으므로 새 모델에 맞는 충돌 도형을 별도로 준비해야 합니다.

## 검증과 직접 확인할 항목

Godot 4.7.2 / Jolt에서 입력·카메라 회귀 검사와 공 물리 검사를 실행합니다.
합성 입력 검사와 실제 사용자의 키보드/조작감 확인은 별개입니다.
현재 버전은 입력·카메라 회귀 28개, 공 물리 21개 검사를 통과했습니다.
Metal Forward+ 렌더링으로 회전 표시와 플랫폼/목표/공의 크기 및 화면 여백을 확인했습니다.
시작 화면/UI 통합 검사 34개도 통과했습니다. 960×540, 1280×800, 1024×768 창 크기에서
홈 UI가 화면 안에 들어오는 것을 검사했고, 레벨 선택/설정/플레이 HUD/일시정지 메뉴도 확인했습니다.
이는 합성 GUI 이벤트를 이용한 검사이며 실제 사용자의 macOS 키보드/포커스 확인과 구분합니다.
미션 성공 검사 27개가 통과했습니다. 다른 물체 무시, 실제 공 진입, 중복 이벤트 방지, 조작/타이머 정지,
성공 애니메이션, 결과 시간, 재시작/기존 메뉴 복귀, Goal 위치 변경 및 모션 줄이기를 확인합니다.
물리 회귀 검사는 굴림/추락/초기화 동안 Goal 감지를 잠시 끄고, 마지막에 Goal을 켜 성공 후 잠금까지 검사합니다.
기본 물리 검사만 테스트 내부에서 미로 벽을 제거하고 중앙 시작점을 사용해 순수한 관성/마찰을 독립 검사합니다.
미로 검사 22개는 실제 배치 그대로 시작/복귀, 벽 충돌, 세 번의 방향 전환과 Goal 도달을 확인합니다.
공을 위쪽·벽 쪽으로 빠르게 날리는 경우와 두 축을 빠르게 반전하는 경우에도 덮개가 벽 넘기/통로 이탈을 막는지 검사합니다.
카메라 가림 검사의 물리 Ray에서는 화면에 보이지 않는 덮개만 테스트 내부에서 잠시 제외합니다.
LEVEL 02 검사 30개는 원본 삼각형/비율 보존, 19개 Convex, 네 외곽 벽, 반발력 비교, 얇은 사선 벽의 CCD,
회전 속도 제한, 카메라 추적/가림/범위/복귀, 새 시작점의 실패 복귀와 실제 물리 완주를 확인합니다.

검증 스크립트는 물리 키 코드를 가진 합성 이벤트를 Godot에 주입해 Input Map → TiltInput → Platform 연결을 검사합니다.
각 플레이어의 독립 축 제어, 두 축 동시 입력, 반대 키 상쇄, 양방향 회전, 부드러운 수평 복귀, 축별 ±15도 제한,
플랫폼의 물리/표시 회전 일치, 카메라의 중심 방향과 고정 상태,
최대 대각 기울기에서 플랫폼 전체/공/목표의 카메라 시야 포함, 공의 위치/회전 고정을 확인합니다.

**직접 확인 필요:** 실제 키보드로 A/D와 ↑/↓를 동시에 누르고 놓는 조작감,
실행 창의 포커스와 키보드 하드웨어의 동시 키 인식. 자동 키 이벤트 주입은 실제 키보드 조작을 대신하지 않습니다.
직접 확인할 내용은 두 사람이 동시에 조작할 때의 난이도, 공의 속도와 관성/마찰 감각,
화면에서 공·목표의 크기, 가장자리 추락 후 실패 표시와 복귀, R키 재시도입니다.
현재 버전에서의 실제 키보드 플레이는 자동 검사로 확인했다고 간주하지 않습니다.
추가 직접 확인 항목은 마우스 호버·클릭 감각, 실제 ESC 키, 화면 배율과 글자 선명도,
별도 실행 창에서의 전체 화면 전환, 편집기 Input 모드와 포커스입니다.
미션 성공 기능은 실제 조작으로 공을 Goal에 보내는 과정, 등장/파티클 느낌, 결과 버튼의 클릭 감각도 직접 확인하세요.

명령줄로 다시 검사하려면 Godot 실행 파일을 사용해 다음을 실행합니다.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 180
godot --headless --path . --script res://tests/tilt_smoke_test.gd
godot --headless --path . --script res://tests/ball_physics_test.gd
godot --headless --path . --script res://tests/ui_flow_test.gd
godot --headless --path . --script res://tests/mission_success_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/basic_maze_test.gd
godot --headless --path . --fixed-fps 60 --script res://tests/level_02_test.gd
```

그래픽 화면을 함께 저장하려면 아래 명령으로 검증을 실행합니다. 창이 열리고 자동 테스트 후 닫힙니다.

```sh
godot --path . --fixed-fps 60 --script res://tests/tilt_smoke_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/ball_physics_test.gd -- --capture
godot --path . --script res://tests/ui_flow_test.gd -- --capture
godot --path . --script res://tests/mission_success_test.gd -- --capture
godot --path . --fixed-fps 60 --max-fps 120 --script res://tests/basic_maze_test.gd -- --capture
godot --path . --fixed-fps 60 --max-fps 120 --script res://tests/level_02_test.gd -- --capture
```

수평 화면은 `/tmp/balance-lab-tilt-preview.png`, A+↑로 기울인 화면은
`/tmp/balance-lab-tilt-diagonal.png`에 저장됩니다. 공이 굴러가는 화면은
`/tmp/balance-lab-physics-preview.png`에 저장됩니다. 저장 경로는 macOS의 임시 폴더입니다.
UI 검사에서는 `/tmp/balance-lab-menu.png`, `balance-lab-levels.png`, `balance-lab-settings.png`,
`balance-lab-gameplay.png`, `balance-lab-pause.png`를 저장합니다.
UI 검사는 실제 사용자 설정을 덮어쓰지 않도록 별도의 `/tmp/balance-lab-ui-test-settings.cfg`를 사용합니다.
미션 결과 화면 캡처는 `/tmp/balance-lab-mission-success.png`에 저장합니다.
미로 전체와 네 방향 최대 기울기 캡처는 `/tmp/balance-lab-maze-overview.png`, `balance-lab-maze-tilt-*.png`에 저장합니다.

`godot`이 PATH에 없으면 설치된 Godot 실행 파일의 경로로 대체하세요.
현재 컴퓨터에서는 `/Users/parkjunhoo/Downloads/Godot.app/Contents/MacOS/Godot`를 사용했습니다.
제한된 실행 환경에서는 별도로 macOS 인증서 조회나 편집기 전역 설정 저장 권한 오류가 출력될 수 있습니다.


## LEVEL 03 — NEW HORIZONS

F5 → LEVEL SELECT → LEVEL 03 → ENTER LAB, 또는 `scenes/level_03.tscn`에서 F6.
`prototypes/tinkercad/3rd map/Amazing Densor-Uusam/tinker.obj`와 같은 폴더의 MTL을 원본 위치에서 사용합니다.
21개 원본 구조물의 색/형상/비율을 유지하며, 22.1×81.1 바닥과 기존 협동 조작/물리/추적 카메라/Goal을 연결합니다.
통과구 벽은 세 충돌체로 나누어 빈 공간을 보존하고, 돔과 피라미드는 원래 곡면·경사면의 Convex를 사용합니다.
±15도 제한은 유지하고 LEVEL 03만 긴 판의 회전 속도를 4도/초로 설정했습니다.
실제 물리 자동 플레이로 약 169초에 Goal 도달을 확인했습니다. 사람의 전체 키보드 플레이 검증은 별도입니다.
원본 분석, 장애물별 물리 실험, 남아 있는 기존 표시 검사 실패 및 재실행 방법은
[LEVEL 03 검증 보고서](reports/level_03/validation.md)에 기록했습니다.


## LEVEL 04 — FINAL ORBIT (최종 맵)

F5 → LEVEL SELECT → FINAL ORBIT → ENTER LAB. 직접 실행은 `scenes/level_04.tscn`에서 F6입니다.
원격 커밋 `381252f`(2026-10-23 KST)의 `prototypes/tinkercad/Grand Duup.zip` 안
`tinker.obj`와 `obj.mtl`을 원래 압축 경로대로 `prototypes/tinkercad/`에서 사용합니다.
원본 파일의 내용과 좌표·비율·장애물 배치는 변경하지 않았습니다.

- 실제 OBJ 크기 183.2609×280×24.5, 균일 배율 0.1. 바닥은 18.4×29.2, 두께 0.4입니다.
- 공은 이 맵에서만 반지름 0.55이며, 원본 단위의 5.5에 해당합니다. LEVEL 01~03의 공은 그대로입니다.
- 중앙 8개 분리 솔리드 중 원호 7개는 원래 윗면 삼각형을 볼록 조각으로 병합해 68개 프록시로 만듭니다.
  중앙 원기둥은 자체 Convex 하나이고, 모든 모델 프록시는 78개입니다. 빈 원형 통로를 메우는 큰 충돌체는 없습니다.
- 전체가 같은 AnimatableBody3D로 기울어지며 원형 구조의 자동 회전은 없습니다.
- ±15도, 기존 키보드 입력/공 물리/카메라/성공 판정은 공유합니다. LEVEL 04 회전 속도는 축별 5도/초입니다.
- 원형 초록 Goal은 원본 표시를 그대로 사용합니다. LEVEL 03에서처럼 표시를 바닥에 겹치지 않습니다.
- LEVEL 04 성공 시 `FINAL EXPERIMENT COMPLETE`를 표시하고 기존 RETRY/LOBBY를 제공합니다. LEVEL 05는 없습니다.

실제 물리 프레임과 네 키 이벤트를 사용해 안쪽 원형 통로까지 거쳐 약 95초에 추가 낙하 없이 Goal에 도달했습니다.
OS 키 전달 검사와 전체 자동 주행은 별도이며, 사람이 두 명 협력하여 끝까지 플레이한 결과는 아닙니다.
원본 위치, 충돌 분해·통로 폭, 전체 회귀 검사와 남아 있는 LEVEL 01 진단 표시 실패는
[LEVEL 04 검증 보고서](reports/level_04/validation.md)에 기록했습니다.
