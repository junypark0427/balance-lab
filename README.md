# BALANCE LAB

Godot 4 / GDScript로 만든 로컬 2인 협동 물리 퍼즐의 핵심 프로토타입입니다.
기존 프로젝트의 내장 Jolt Physics 설정을 유지했고 Godot 4.7.2로 검증했습니다.
외부 에셋이나 추가 플러그인은 필요하지 않습니다.

**현재는 공 물리가 활성화된 16×16 기본 맵입니다.** 두 사람이 플랫폼을 기울여 공을 초록색 목표로 이동시킵니다.
공의 중력·충돌·굴림은 내장 Jolt 물리 엔진이 처리하며, 가장자리에는 벽이 없어 떨어질 수 있습니다.

## 실행

1. Godot 프로젝트 관리자에서 이 폴더의 `project.godot`를 가져오거나 엽니다.
2. `scenes/main.tscn`을 열어 **F6**으로 실행하거나 **F5**로 프로젝트를 실행합니다.
   메인 Scene은 이미 `Main`으로 지정되어 있습니다.
3. 실행 창을 클릭해 키보드 포커스를 준 뒤 두 사람이 같은 키보드로 조작합니다.

| 조작 | 기능 |
| --- | --- |
| Player 1: A / D | 왼쪽 / 오른쪽 가장자리를 낮춤 |
| Player 2: ↑ / ↓ | 앞쪽(-Z, 화면의 먼 쪽) / 뒤쪽(+Z, 화면의 가까운 쪽) 가장자리를 낮춤 |
| R | 공의 위치·회전·운동량 초기화. 실패 횟수는 유지 |

키를 놓으면 해당 축이 수평으로 부드럽게 복귀합니다. 반대 키를 함께 누르면 해당 축 입력은 0입니다.
각 회전축의 최대 각도는 ±15도입니다. 두 축을 동시에 조작하면 두 축에 각각 한도가 적용됩니다.

플랫폼은 원점에서 회전하며, 입력과 별도의 각도 상태를 사용해 AnimatableBody3D의 물리 동기화 중에도
보간을 계속합니다. 카메라는 `(0, 22, 18)`에서 플랫폼 중심을 `look_at()`으로 바라보는 고정 직교 시점입니다.
실행 시 `make_current()`로 활성화합니다. 기본 실행 크기는 1152×720입니다.
직교 크기는 30, 수직 오프셋은 -3으로 설정해 기본 ±15도 대각 기울기에서도 플랫폼 전체가 보이고
하단 진단 패널과 겹치지 않도록 화면 위쪽에 여백을 배분합니다.

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

실행을 완전히 중지한 뒤 상단 삼각형 버튼(F5)으로 다시 실행하고, 화면 하단의 **INPUT TRACE v1**을 확인합니다.
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

- `scenes/main.tscn`: Main 3D Scene. 16×0.4×16 플랫폼, 반지름 0.5의 공,
  충돌 도형, 목표 감지 영역, 고정 카메라, 조명 및 최소 안내 UI.
- `scripts/tilt_input.gd`: 키보드를 정규화된 Vector2 입력으로 변환하는 입력 어댑터.
- `scripts/platform_controller.gd`: 입력값만 받아 물리 프레임마다 지수 보간으로 플랫폼을 기울임.
  AnimatableBody3D를 사용해 움직이는 플랫폼의 충돌을 물리에 반영합니다.
- `scripts/ball.gd`: RigidBody3D 물리 공. 높이 감지 및 `fell` 신호, 물리 상태 콜백에서 복귀 및 운동량 초기화.
- `scripts/main.gd`: `fell` 신호를 받아 실패 횟수 증가·복귀 요청. 카메라 활성화, 목표 안내 및 R키 재시작 연결.
- `scripts/input_debug.gd`: 화면의 입력 진단 표시. 포커스, 실행 연결, 액션 등록, 이벤트 수신 및 플랫폼 전달을 관찰.
- `tests/tilt_smoke_test.gd`: Input Map을 통과하는 합성 키 이벤트로 카메라/입력/회전을 검증.
  기본 Scene의 공 물리 활성화 상태를 확인한 뒤 테스트 내부에서만 공을 고정해 플랫폼 조작을 독립적으로 검사.
- `tests/ball_physics_test.gd`: 공의 중력, 회전, 관성, 마찰/감쇠, CCD, 실제 가장자리 추락 및 복귀와 목표 도착 검사.

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
복귀 시 선형 속도·각속도는 0, 회전은 단위 회전으로 초기화하고 플랫폼 로컬 `(0, 1.1, 0)`에 배치합니다.
중력에 의해 플랫폼 위로 안착하며, 키를 계속 누르고 있으면 현재 플랫폼 기울기에 따라 다시 굴러갑니다.
16×16 맵의 기본 최대 기울기에서 플랫폼 아래로 충분히 떨어진 뒤 실패하도록 높이를 -6으로 낮췄습니다.
실패 횟수와 복귀 안내는 화면에 유지됩니다. R키로 직접 재시도하는 것은 실패 횟수에 더하지 않습니다.
목표 영역에 도착하면 GOAL 문구가 표시됩니다. R 또는 추락 복귀로 문구가 초기화됩니다.
목표는 폭/깊이 1.6, 위치 `(5.4, 0.215, -5.4)`이며 도착 표시 후에도 공의 물리는 계속 동작합니다.
현재는 단순 기본 맵이며 미로·벽·추가 스테이지는 만들지 않았습니다.

### Inspector에서 조정

| 노드/속성 | 기본값 | 용도 |
| --- | --- | --- |
| Platform / Max Tilt Degrees | 15 | 축별 최대 기울기. 현재 0~30도 편집 가능 |
| Platform / Tilt Response | 5 | 기울기와 수평 복귀 반응 속도 |
| Ball / Spawn Local Position | (0, 1.1, 0) | 플랫폼 기준 복귀 위치 |
| Ball / Fall Height | -6 | 월드 기준 실패 높이 |
| Ball / Linear Damp, Angular Damp | 0.05, 0.1 | 관성 감쇠 |
| Ball / Physics Material Override | 마찰 0.6, 반발 0.05 | 표면 반응 |

기울기를 15도보다 크게 바꾸면 카메라 시야와 실패 높이도 함께 확인하세요.
이후 미로 모델 교체 시에도 Platform의 원점과 충돌 도형, Ball의 복귀 높이를 맞추면 제어/물리 로직을 유지할 수 있습니다.
표시 Mesh만 교체하면 충돌은 기존 박스로 남으므로 새 모델에 맞는 충돌 도형을 별도로 준비해야 합니다.

## 검증과 직접 확인할 항목

Godot 4.7.2 / Jolt에서 입력·카메라 회귀 검사와 공 물리 검사를 실행합니다.
합성 입력 검사와 실제 사용자의 키보드/조작감 확인은 별개입니다.
현재 버전은 입력·카메라 회귀 27개, 공 물리 21개 검사를 통과했습니다.
Metal Forward+ 렌더링으로 회전 표시와 플랫폼/목표/공의 크기 및 화면 여백을 확인했습니다.

검증 스크립트는 물리 키 코드를 가진 합성 이벤트를 Godot에 주입해 Input Map → TiltInput → Platform 연결을 검사합니다.
각 플레이어의 독립 축 제어, 두 축 동시 입력, 반대 키 상쇄, 양방향 회전, 부드러운 수평 복귀, 축별 ±15도 제한,
플랫폼의 물리/표시 회전 일치, 카메라의 중심 방향과 고정 상태,
최대 대각 기울기에서 플랫폼 전체/공/목표의 카메라 시야 포함, 공의 위치/회전 고정을 확인합니다.

**직접 확인 필요:** 실제 키보드로 A/D와 ↑/↓를 동시에 누르고 놓는 조작감,
실행 창의 포커스와 키보드 하드웨어의 동시 키 인식. 자동 키 이벤트 주입은 실제 키보드 조작을 대신하지 않습니다.
직접 확인할 내용은 두 사람이 동시에 조작할 때의 난이도, 공의 속도와 관성/마찰 감각,
화면에서 공·목표의 크기, 가장자리 추락 후 실패 표시와 복귀, R키 재시도입니다.
현재 버전에서의 실제 키보드 플레이는 자동 검사로 확인했다고 간주하지 않습니다.

명령줄로 다시 검사하려면 Godot 실행 파일을 사용해 다음을 실행합니다.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 180
godot --headless --path . --script res://tests/tilt_smoke_test.gd
godot --headless --path . --script res://tests/ball_physics_test.gd
```

그래픽 화면을 함께 저장하려면 아래 명령으로 검증을 실행합니다. 창이 열리고 자동 테스트 후 닫힙니다.

```sh
godot --path . --fixed-fps 60 --script res://tests/tilt_smoke_test.gd -- --capture
godot --path . --fixed-fps 60 --script res://tests/ball_physics_test.gd -- --capture
```

수평 화면은 `/tmp/balance-lab-tilt-preview.png`, A+↑로 기울인 화면은
`/tmp/balance-lab-tilt-diagonal.png`에 저장됩니다. 공이 굴러가는 화면은
`/tmp/balance-lab-physics-preview.png`에 저장됩니다. 저장 경로는 macOS의 임시 폴더입니다.

`godot`이 PATH에 없으면 설치된 Godot 실행 파일의 경로로 대체하세요.
현재 컴퓨터에서는 `/Users/parkjunhoo/Downloads/Godot.app/Contents/MacOS/Godot`를 사용했습니다.
제한된 실행 환경에서는 별도로 macOS 인증서 조회나 편집기 전역 설정 저장 권한 오류가 출력될 수 있습니다.
