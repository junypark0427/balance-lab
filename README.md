# BALANCE LAB

Godot 4 / GDScript로 만든 로컬 2인 협동 물리 퍼즐의 핵심 프로토타입입니다.
기존 프로젝트의 내장 Jolt Physics 설정을 유지했고 Godot 4.7.2로 검증했습니다.
외부 에셋이나 추가 플러그인은 필요하지 않습니다.

**시작 메뉴와 플레이 HUD가 포함된 16×16 기본 미로 맵입니다.** 두 사람이 플랫폼을 기울여 공을 초록색 목표로 이동시킵니다.
공의 중력·충돌·굴림은 내장 Jolt 물리 엔진이 처리하며, 가장자리에는 벽이 없어 떨어질 수 있습니다.

## 시작 화면과 메뉴

F5로 프로젝트를 실행하면 `scenes/menu.tscn`에서 시작합니다.
작업 폴더의 참고 PNG는 디자인 참고용으로만 확인했으며 실제 게임 배경이나 버튼 이미지로 사용하지 않습니다.
실험실, 유리 패널, 금속 미로 전시대, 조명과 네온 띠는 Godot 기본 Mesh와 Material로 구성했습니다.
메뉴의 공은 물리 게임과 별개인 전시용 애니메이션이며 실제 플레이는 기존 `scenes/main.tscn`에서 실행됩니다.
외부 모델·이미지·폰트·사운드를 다운로드하지 않았고 폰트는 OS의 시스템 폰트 및 내장 대체 폰트를 사용합니다.

- **GAME START**: 기본 LEVEL 01을 시작합니다.
- **LEVEL SELECT**: CALIBRATION만 열려 있으며 미구현 두 맵은 비활성 잠금 버튼으로 표시합니다.
- **SETTINGS**: 입력 진단 표시, 모션 줄이기, 별도 게임 창의 전체 화면을 실제로 변경합니다.
  내장 게임 창에서는 전체 화면이 지원되지 않아 해당 스위치를 비활성화합니다.
  설정은 `user://settings.cfg`에 저장합니다. 음량 등 구현하지 않은 설정은 표시하지 않습니다.
- **ESC**: 레벨 선택/설정에서는 홈으로, 플레이 중에는 일시정지/재개로 동작합니다.

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

## 공 물리와 실패 처리

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
현재는 세 번 꺾이는 기본 미로 하나만 있으며 추가 스테이지는 없습니다.

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
시작 화면/UI 통합 검사 27개도 통과했습니다. 960×540, 1280×800, 1024×768 창 크기에서
홈 UI가 화면 안에 들어오는 것을 검사했고, 레벨 선택/설정/플레이 HUD/일시정지 메뉴도 확인했습니다.
이는 합성 GUI 이벤트를 이용한 검사이며 실제 사용자의 macOS 키보드/포커스 확인과 구분합니다.
미션 성공 검사 27개가 통과했습니다. 다른 물체 무시, 실제 공 진입, 중복 이벤트 방지, 조작/타이머 정지,
성공 애니메이션, 결과 시간, 재시작/기존 메뉴 복귀, Goal 위치 변경 및 모션 줄이기를 확인합니다.
물리 회귀 검사는 굴림/추락/초기화 동안 Goal 감지를 잠시 끄고, 마지막에 Goal을 켜 성공 후 잠금까지 검사합니다.
기본 물리 검사만 테스트 내부에서 미로 벽을 제거하고 중앙 시작점을 사용해 순수한 관성/마찰을 독립 검사합니다.
미로 검사 17개는 실제 배치 그대로 시작/복귀, 벽 충돌, 세 번의 방향 전환과 Goal 도달을 확인합니다.

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
```

그래픽 화면을 함께 저장하려면 아래 명령으로 검증을 실행합니다. 창이 열리고 자동 테스트 후 닫힙니다.

```sh
godot --path . --fixed-fps 60 --script res://tests/tilt_smoke_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/ball_physics_test.gd -- --capture
godot --path . --script res://tests/ui_flow_test.gd -- --capture
godot --path . --script res://tests/mission_success_test.gd -- --capture
godot --path . --fixed-fps 60 --max-fps 120 --script res://tests/basic_maze_test.gd -- --capture
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
