# BALANCE LAB — 무인 QA 발견 사항

2026-10-27, Asia/Seoul(KST). [전체 평가](QA_REPORT.md) · [검사 기록](TEST_LOG.md)

최초 무인 QA 발견: **Critical 0 / High 0 / Medium 2 / Low 3**.
2026-10-27 사용자 수정 요청 후 **QA-001·QA-003 해결**. 현재 미해결은 **Medium 1 / Low 2**입니다.
최초 재현 내용은 이력으로 보존하며, 후속 검증은 [ICE 수정 보고서](../../reports/ice_mode/fixes.md)에 있습니다.
원시 로그와 화면은 `/tmp/balance-qa-2026-10-27/`에 있으며 임시 자료입니다.
하드웨어 미연결, 미검증 Windows 실행, 미끄러운 ICE의 의도된 난이도는 오류 수에 포함하지 않았습니다.

## QA-001 — ICE 바닥 셰이더 컴파일 실패

- **심각도:** Medium. ICE의 공통 시각 효과가 실패하지만 일반 모드·게임 실행·ICE 물리 진행은 유지됨.
- **발생 위치:** [ice_floor.gdshader](../../shaders/ice_floor.gdshader) 37행,
  [ice_mode.gd](../../scripts/modes/ice_mode.gd) 20행에서 재질 적용.
- **문제 설명:** 현재 Godot 4.7.2가 `CLEARCOAT_GLOSS`를 알 수 없는 식별자로 처리합니다.
  ICE 바닥은 실제 Metal 화면에서 의도한 푸른 얼음 광택 대신 흰색 기본/대체 표면으로 보입니다.
  같은 셰이더를 네 레벨이 공유하므로 네 레벨 모두 영향을 받습니다.
- **재현 절차:** 새로 게임 실행 → SETTINGS → ICE MODE ON → GAME START → 임의의 LEVEL 01~04 선택.
  Godot Output과 바닥을 확인합니다. 저장된 ICE가 ON인 다음 실행에서도 같은 적용 경로를 탑니다.
- **예상 결과:** 오류 없이 얼음 셰이더가 적용되고 차가운 바닥 무늬·광택이 보임.
- **실제 결과:** 셰이더 컴파일 오류. 물리·HUD는 계속 동작하므로 프로세스가 0으로 종료해도 이 검사는 실패입니다.
- **관련 오류 로그:** `ice-qa.log`, `render-qa.log`.

```text
E 37-> CLEARCOAT_GLOSS = 0.8;
SHADER ERROR: Unknown identifier in expression: 'CLEARCOAT_GLOSS'.
ERROR: Shader compilation failed.
apply (res://scripts/modes/ice_mode.gd:20)
_ready (res://scripts/main.gd:24)
```

- **실제 화면:** [LEVEL 01 ICE](</tmp/balance-qa-2026-10-27/ice-level1-native.png>),
  [LEVEL 04 ICE](</tmp/balance-qa-2026-10-27/ice-level4-native.png>).
- **추정 원인:** 작성한 셰이더의 clearcoat 출력 이름이 실행 엔진의 셰이더 API와 맞지 않습니다.
  해당 식별자 거부는 실제 실행으로 확인했습니다. 오래된 다른 버전의 예제를 참고했는지까지는 확정하지 않습니다.
- **권장 해결 방법:** Godot 4.7의 지원 출력 변수와 의미를 확인해 clearcoat 코드를 수정하거나
  불필요한 출력을 제거합니다. 예를 들어 현재 문서의 `CLEARCOAT_ROUGHNESS`는 광택과 의미가 다르므로
  이름만 바꾸고 0.8을 그대로 쓰지 말고 의도한 거칠기를 검토해야 합니다.
  수정 후 실제 Metal에서 네 레벨을 다시 렌더링하고 Console 오류가 없는지 확인하세요.
  참고: [공식 Spatial shader 출력 설명](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html).
- **수정 여부:** **수정·재검증 완료(2026-10-27)**. 무인 QA 당시에는 미수정으로 기록했고 이후 사용자 요청으로 수정했습니다.
  `CLEARCOAT_ROUGHNESS=0.2`로 바꿔 원래 gloss 0.8에 대응하는 거칠기를 사용합니다.
  실제 Metal에서 푸른 얼음 픽셀을 확인하고 4개 레벨 재렌더링에서 셰이더 오류가 없음을 확인했습니다.
  근거: [새 회귀 검사](../../tests/ice_mode_test.gd), [Metal 결과](../../reports/ice_mode/regression-native.log),
  [수정 후 화면](../../reports/ice_mode/level01-fixed.png).

## QA-002 — LEVEL 01 진단 패널과 최대 대각 기울기의 플랫폼 겹침

- **심각도:** Medium. 진단 UI를 켠 특정 상황에서 플레이 영역 일부를 가리는 표시 문제.
- **발생 위치:** [game_hud.gd](../../scripts/ui/game_hud.gd)의 진단 배치·고정 카메라 조정,
  [tilt_smoke_test.gd](../../tests/tilt_smoke_test.gd)의 화면 투영 검사.
- **문제 설명:** LEVEL 01의 양축 최대 기울기에서 진단 패널이 플랫폼의 투영 영역과 분리되지 않습니다.
  이전 LEVEL 03·04 보고서에도 남아 있는 실패이며 이번 ICE 변경이 원인이라고 확정하지 않습니다.
- **재현 절차:** LEVEL 01 → F3으로 INPUT TRACE 표시 → A+↑ 또는 대응하는 대각 입력을 충분히 유지.
  자동 재현은 `input-camera.gd` 임시 래퍼에서 기존 `tilt_smoke_test.gd`를 일반 모드로 실행합니다.
- **예상 결과:** 진단 패널과 플랫폼 투영 영역이 최대 기울기에서도 겹치지 않음.
- **실제 결과:** 기존 자동 검사 28항목 중 27개 통과, 해당 항목 1개 실패. 키 입력과 ±15도 회전 검사는 통과합니다.
- **관련 오류 로그:** `input-camera.log` 152행.

```text
[TEST] FAIL Visible diagnostic panel stays clear of platform at diagonal extremes
```

- **추정 원인:** 고정 카메라의 화면 범위·오프셋과 진단 패널 위치의 조합이 대각 최대 투영 범위를 충분히 분리하지 못함.
  정확한 조정값은 별도 수정 작업에서 실화면을 보며 결정해야 합니다.
- **권장 해결 방법:** 진단 전용 카메라 여유 또는 패널 위치·크기를 검토하고 해상도·양축 극값에서 재검사합니다.
  임시 운영에서는 F3으로 패널을 숨길 수 있으나 해결된 것으로 간주하지 않습니다.
- **수정 여부:** **미수정**.

## QA-003 — ICE 안내 문구가 일시정지 가림막 위에 남음

- **심각도:** Low. 조작을 막지 않는 표시 순서 문제.
- **발생 위치:** [ice_mode.gd](../../scripts/modes/ice_mode.gd)의 `_add_indicator()`,
  [game_hud.gd](../../scripts/ui/game_hud.gd)의 PauseMenu.
- **문제 설명:** 화면 중앙 위쪽의 `ICE MODE / EXTREME CHALLENGE`가 일시정지 시 다른 HUD와 함께 어두워지지 않습니다.
- **재현 절차:** ICE MODE ON으로 레벨 시작 → PAUSE/ESC → 상단 모드 안내와 주변 HUD 밝기 비교.
- **예상 결과:** 일반 HUD 표시가 가림막 아래에 놓이거나, 일시정지 화면 정책에 맞춰 함께 숨겨짐/어두워짐.
- **실제 결과:** 다른 헤더는 어두워지지만 ICE 문구는 밝게 남습니다. PAUSE 메뉴의 클릭·재개 기능은 정상입니다.
- **관련 화면:** [LEVEL 04 ICE 일시정지](</tmp/balance-qa-2026-10-27/ice-level4-paused.png>).
- **추정 원인:** `Main._ready()`의 ICE 적용이 HUD 자식들의 구성 이후 실행되고,
  ICE Label을 PauseMenu 뒤의 형제로 추가해 나중에 그려집니다.
- **권장 해결 방법:** 일반 HUD 표시를 일시정지·성공 패널보다 먼저 그리도록 순서/레이어를 정하거나
  해당 상태에서 표시 정책을 명시하세요. 게임 기믹이나 충돌체를 바꿀 필요는 없습니다.
- **수정 여부:** **수정·재검증 완료(2026-10-27)**. ICE Label을 HUD의 첫 번째 자식으로 옮겨
  PauseMenu·성공 패널의 가림막 뒤에 그리도록 했습니다. 네 레벨의 두 오버레이보다 앞선 자식 순서를 검사하고
  실제 Metal의 일시정지 화면에서 문구가 함께 어두워지는 것을 확인했습니다.
  근거: [표시 순서 검사](../../reports/ice_mode/regression-headless.log),
  [수정 후 일시정지 화면](../../reports/ice_mode/level04-paused-fixed.png).

## QA-004 — 센서 바로가기와 PLAYER 1 카드 영역 겹침

- **심각도:** Low. 카드 경계가 겹치는 시각 문제이며 현재 키 조작을 막는 증거는 없음.
- **발생 위치:** [sensor_hub.gd](../../scripts/sensor_hub.gd) `_build_ui()`의 하단 Badge,
  [game_hud.gd](../../scripts/ui/game_hud.gd)의 하단 Player 1 카드.
- **문제 설명:** SensorHub 버튼의 실제 최소 높이가 지정 offset 높이보다 커져 하단 HUD 카드와 겹칩니다.
- **재현 절차:** 일반 또는 ICE 레벨 실행 → 좌하단 `[C] INIT / [F4] SENSORS` 버튼과 PLAYER 1 카드 경계 관찰.
- **예상 결과:** 두 컨트롤 영역이 서로 겹치지 않고 여유를 둠.
- **실제 결과:** 현재 1920×1080 논리 좌표에서 아래 사각형을 확인했습니다.
  글자 자체가 가려진다고 과장하지 않고 패널 영역의 교차로 기록합니다.

```text
sensor_rect = position (48, 922), size (512, 58)
player_card = position (48, 964), size (416, 101)
intersection = position (48, 964), size (416, 16)
```

- **관련 로그/화면:** `debug-probe.log`, [일반 LEVEL 01 화면](</tmp/balance-qa-2026-10-27/normal-level1-native.png>).
- **추정 원인:** 버튼의 글꼴·스타일 최소 크기와 offset 범위의 불일치.
  서로 다른 CanvasLayer에서 하단 공간을 독립 배치하여 공통 여백을 예약하지 않습니다.
- **권장 해결 방법:** 실제 최소 크기를 반영해 버튼 위치/하단 카드의 여유를 검토하고 작은 화면에서도 교차 여부를 검사하세요.
- **수정 여부:** **미수정**.

## QA-005 — 진단 UI OFF와 관계없는 반복 플랫폼 콘솔 출력

- **심각도:** Low. 현재 프레임마다 출력되는 것은 아니지만 행사 장시간 운영에서 불필요한 로그가 쌓일 수 있음.
- **발생 위치:** [platform_controller.gd](../../scripts/platform_controller.gd) `debug_logging=true`, `debug_interval=0.2`와
  `_physics_process()`의 출력. [game_hud.gd](../../scripts/ui/game_hud.gd)의 F3는 화면 진단 표시를 제어합니다.
- **문제 설명:** INPUT DIAGNOSTICS OFF/F3 숨김은 콘솔 출력까지 끄지 않습니다.
- **재현 절차:** 일반 레벨에서 INPUT DIAGNOSTICS OFF → 아무 키도 누르지 않고 약 2.5 게임 초 대기 → Output 확인.
- **예상 결과:** 운영용 로그 억제 수단이 있거나 화면 진단과 콘솔 로그 설정이 분명히 구분되어 있음.
- **실제 결과:** 진단 UI `visible=false`, 149 physics tick 동안 동일한 Platform 로그 12줄.
  기본 간격으로 게임 시간 기준 약 5Hz, 대략 분당 300줄입니다.
  센서 장치가 없어도 재현되므로 센서 오류로 기록하지 않습니다.
- **관련 로그:** `debug-probe.log`.

```text
[Platform] Player 1=0.00 Player 2=0.00 X=-0.00 deg Z=0.00 deg
[DEBUG QA] diagnostics visible=false physics ticks=149
```

- **추정 원인:** 화면 표시 설정과 플랫폼의 export된 로그 설정이 서로 독립되어 있으며,
  정지 상태에서도 주기마다 출력하는 현재 동작입니다. F3 자체가 오작동한다는 뜻은 아닙니다.
- **권장 해결 방법:** 사용자 승인 후 배포용 로그 정책을 정하고 로그 비활성화 또는 상태 변경 때만 출력하는 방식을 검토하세요.
  이번에는 출력 코드를 삭제하거나 빈도를 바꾸지 않았습니다.
- **수정 여부:** **미수정**.

## 오류와 구분한 미검증·정적 위험

아래는 재현된 결함 수에 포함하지 않습니다.

- 분리된 ESP32 두 대: 이번 QA의 명시적 범위 제외. 연결 요청·통신·보정·업로드 없음.
- Windows COM/드라이버/실행: macOS만 사용했으므로 미검증.
- OBJ/MTL 원본의 Export 포함: 런타임 텍스트 파싱 의존성과 Export 설정 부재를 정적으로 확인했습니다.
  Export를 만들지 않아 실제 누락을 재현한 것은 아닙니다. 배포 전에 반드시 확인해야 합니다.
- ICE 초고난도·미끄러움: 의도된 설계이며 자체로 오류가 아닙니다. 모든 맵 연속 완주는 미검증입니다.
- 첫 임시 검사에서 일반 재질 보존 4개가 실패한 것: 정확한 float 동등 비교의 검사 준비 오류였습니다.
  **외부 임시 검사만** 근사 비교로 바꾼 뒤 통과했습니다. 게임 수정이나 공유 재질 손상으로 집계하지 않습니다.
