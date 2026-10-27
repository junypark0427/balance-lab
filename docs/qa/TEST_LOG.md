# BALANCE LAB — 무인 QA 실제 테스트 기록

수행일: **2026-10-27, Asia/Seoul(KST, UTC+09:00)**

[종합 결과](QA_REPORT.md) · [문제 목록](ISSUES.md)

## 실행 원칙과 재현 환경

Godot 4.7.2 / Jolt, macOS headless 및 Apple M3 Metal Forward+에서 수행했습니다.
사용자에게 응답·키 조작·USB 연결을 요청하지 않았습니다. 실제 하드웨어 검사는 실행하지 않았습니다.
센서 미연결은 실패로 집계하지 않습니다.

임시 실행 파일·로그·설정·JSON·PNG는 모두 **`/tmp/balance-qa-2026-10-27/`**에 생성했습니다.
프로젝트에는 QA Markdown 3개만 추가했습니다. 기존 검사 스크립트는 수정하지 않고,
임시 상속 래퍼에서 일반 모드를 명시한 뒤 기존 검사 함수를 호출했습니다.
예를 들어 LEVEL 04 래퍼의 핵심은 다음과 같습니다.

```gdscript
extends "res://tests/level_04_test.gd"
func _run() -> void:
    root.get_node("Session").ice_mode_enabled = false
    await super._run()
```

일반적인 실행 형식은 아래와 같습니다. `GODOT`는 현재 PC의 공식 실행 파일 경로입니다.
실행 파일의 경로 자체는 게임 런타임 의존성이 아닙니다.

```sh
GODOT='/Users/parkjunhoo/Downloads/Godot.app/Contents/MacOS/Godot'
"$GODOT" --headless --path /Users/parkjunhoo/Documents/balance-lab \
  --fixed-fps 60 --script /tmp/balance-qa-2026-10-27/route04.gd -- \
  --sensor-port=6191 --sensor-command-port=6192 --keyboard --inner
```

검사는 6191~6200 사이의 별도 UDP 포트를 사용했습니다. 실제 중계에 보정·등록 명령을 보내지 않았습니다.
설정 저장 검사는 `Session.preferences_path`를 임시 파일로 바꾸어 기존 사용자 설정 파일을 보존했습니다.
기존 검사 일부는 원래 정해진 `/tmp/balance-level03/`, `/tmp/balance-level04/`에 CSV를 갱신합니다.
이 경로들도 프로젝트 외부이며 프로젝트의 기존 보고서·CSV는 덮어쓰지 않았습니다.

## 1. 기존 기능 회귀 — 일반 모드

실제 엔진에서 이번에 새로 실행한 결과입니다. 과거 보고서의 통과 수를 가져온 표가 아닙니다.

| ID | 기존 검사 / 방식 | 결과 | 핵심 확인 | 원시 로그 |
| --- | --- | --- | --- | --- |
| T01 | `tilt_smoke_test.gd` / 합성 물리 키 이벤트 | **27 통과, 1 실패** | Input Map, 두 축·상쇄·수평 복귀·물리 변환, 진단 투영 | `input-camera.log` |
| T02 | `ball_physics_test.gd` / 실제 Jolt fixture | 21 통과 | 중력·회전·마찰·CCD·낙하·초기화·성공 잠금 | `ball.log` |
| T03 | `basic_maze_test.gd` / 실제 충돌·기울기 주행 | 22 통과 | LEVEL 01 연결 경로·벽·세 코너·Goal | `maze01.log` |
| T04 | `mission_success_test.gd` / Goal·UI fixture | 27 통과 | 공만 완료, 중복 방지·타이머·결과·로비/재시도 | `mission.log` |
| T05 | `ui_flow_test.gd` / 합성 마우스·키 이벤트 | 52 통과 | GAME START→선택, 네 맵, pause/retry/lobby, 최종 단계 | `ui.log` |
| T06 | `level_02_test.gd` / 실제 충돌·주행·카메라 | 30 통과 | OBJ 비율·반발·수직 벽·카메라·반대편 Goal | `level02.log` |
| T07 | `level_03_obstacle_test.gd` / 독립 충돌 fixture | 30 통과 | 곡면·피라미드·통과구·고속 충돌·리셋 | `obstacles03.log` |
| T08 | `level_04_geometry_test.gd` / 점 점유·실제 충돌 | 14 통과 | 원형 통로·접합부·안팎 충돌·복귀 | `geometry04.log` |
| T09 | `level_03_test.gd --keyboard` / 연속 물리 주행 | 14 통과 | 조정된 사각뿔 구간 포함 Goal 도달 | `route03.log` |
| T10 | `level_04_test.gd --keyboard --inner` / 연속 물리 주행 | 9 통과 | ㄷ자·대각·안쪽 원형 경유·최종 Goal | `route04.log` |

합계는 **246개 통과, 1개 실패**입니다. T01만 종료 코드 1이고 다른 아홉 실행은 0입니다.
유일한 실패는 [QA-002](ISSUES.md#qa-002--level-01-진단-패널과-최대-대각-기울기의-플랫폼-겹침)입니다.
이는 이전 검증 보고서에서도 재현된 문제이며, 기존 실패를 삭제하거나 수정하여 통과시키지 않았습니다.

### 연속 주행의 핵심 결과

```text
[MAZE TEST] PASS Real ball traverses all three turns and reaches Goal using tilt alone, without falls or teleports
[MAZE TEST] Automated traversal simulation time: 21.0 seconds (not a human difficulty estimate)
[LEVEL02] PASS Real ball reaches the opposite Goal through the OBJ using tilt only
[LEVEL03] ... elapsed=156.416666666685
[LEVEL03] PASS Continuous real RigidBody traversal reaches Goal using tilt inputs only, without reset/teleport/velocity edits
[LEVEL04] ... min radius=1.73873591423035 ... elapsed=95.1333333333291
[LEVEL04] PASS Actual RigidBody reaches Goal continuously using tilt inputs only
```

연속 주행에는 실제 플랫폼과 충돌체·RigidBody3D를 사용했습니다. 경로 탐색 결과만으로 성공 처리하지 않고
Goal/Mission Success를 확인했습니다. 테스트 준비에서 공 배치·초기 속도를 쓰는 독립 충돌 검사는 이 결과와 구분합니다.
실제 사람이 키보드를 누르는 OS 입력·장시간 협동 플레이는 이 검사로 입증하지 않습니다.

## 2. ICE 모드·저장·반복 실행

프로젝트 밖에 `ice_qa.gd`를 만들어 현재 구현을 호출했습니다.
게임 코드나 물리 상수는 변경하지 않았습니다. 다음 기능 단언은 **84개 통과, 0개 실패**입니다.
다만 같은 실행에서 셰이더 오류가 별도로 발생했으므로 전체 ICE 검증 성공으로 표기하지 않습니다.

| ID | 검사 항목 | 결과 | 한계/로그 |
| --- | --- | --- | --- |
| T11 | SETTINGS의 ICE ON/OFF·표시 텍스트·저장 파일 | 통과 | `ice-qa.log`, 사용자 설정과 분리 |
| T12 | 960×540 / 1280×800 / 1024×768 설정 컨트롤 화면 안 배치 | 통과 | 같은 로그, 실제 모든 GPU/비율 보장은 아님 |
| T13 | 네 맵의 일반 프로필과 ICE 프로필 비교 | 통과 | 공·플랫폼 마찰/감쇠·Bounce·CCD·중력 비교 |
| T14 | 네 맵 일반/ICE 충돌체 형태·치수·로컬 변환 비교 | 통과 | 충돌체를 추가·삭제하지 않음 |
| T15 | ICE에서 합성 키보드 동시 입력·실제 공 이동 | 통과 | OS 키보드·실제 센서 검증과 구분 |
| T16 | 기존 정규화 아날로그 어댑터·각도 제한 | 통과 | USB·UDP 실측·영점 보정 아님 |
| T17 | ICE pause/resume, 타이머·공 정지 | 통과 | 임시 실행에서 각 레벨 확인 |
| T18 | ICE 공 초기화와 선속도·각속도 0 | 통과 | 실제 `respawned` 시점의 물리 상태를 관찰 |
| T19 | ICE Goal·성공 UI·플랫폼 잠금 | 통과 | 공을 Goal에 배치한 기능 fixture, 완주 아님 |
| T20 | 설정 OFF를 실제 RETRY에서 다음 실행에 적용 | 통과 | 4개 맵의 같은 Scene 재시작 확인 |
| T21 | 네 맵×4순환, 일반/ICE 반복 생성·해제 | 통과 | 16회 추가 로딩, `load-metrics.json` |
| T22 | 실제 셰이더 컴파일 | **실패** | `ice-qa.log`, QA-001 |
| T23 | 모든 ICE 맵의 시작→Goal 연속 주행·사람 체감 | **미검증** | T19의 배치를 완주로 계산하지 않음 |

### 저장 후 프로세스 재실행

`preferences_probe.gd`를 각각 별도 Godot 프로세스에서 실행했습니다.
공통 임시 파일 `persistent-settings.cfg`와 실제 `Session.save_preferences()`/`load_preferences()`를 사용했습니다.

| ID | 순서 | 결과 | 로그 |
| --- | --- | --- | --- |
| T24 | ICE ON 저장 | 통과 | `preferences-on.log` |
| T25 | 새 프로세스에서 ON 읽기 | 통과 | `preferences-reopen-on.log` |
| T26 | ICE OFF 저장 | 통과 | `preferences-off.log` |
| T27 | 새 프로세스에서 OFF 읽기 | 통과 | `preferences-reopen-off.log` |

네 프로세스 모두 종료 코드 0이며, 이전 프로세스의 메모리 변수만 읽은 검사가 아닙니다.
실제 배포 PC의 파일 권한과 Export된 실행 파일의 설정 저장은 미검증입니다.

### 첫 임시 검사의 오판 처리

초기 `ice-qa-initial.log`에는 공유 일반 재질 보존 4개가 실패했습니다.
임시 검사에서 float를 `==`로 비교한 것이 원인이었고, 근사 비교를 사용한 **임시 검사만** 고쳤습니다.
재실행에서는 해당 네 항목 모두 통과했습니다. 초기 로그도 `/tmp`에 보존했습니다.
프로젝트 코드·재질 수정은 없으며 이를 실제 게임 버그나 조용히 해결한 오류로 집계하지 않았습니다.

## 3. 통제된 물리 감속·제동

게임에서 읽은 일반/ICE 재질과 감쇠 프로필을 복제한, 동일한 넓은 평면·구체를 사용했습니다.
고정 60Hz 물리 프레임을 진행하고 초기 충격량을 한 번 준 뒤 속도를 관찰합니다.
이후 반대 기울기 이외에 속도·좌표·외력을 직접 변경하지 않습니다.

| ID | 항목 | 결과 | 수치/로그 |
| --- | --- | --- | --- |
| T28 | 일반 속도 유지·유한한 물리 계산 | 통과 | 2.37094→1.28254, 유지 54.1%, `coast-normal.json` |
| T29 | ICE 속도 유지·유한한 물리 계산 | 통과 | 2.97681→2.29396, 유지 77.1%, `coast-ice.json` |
| T30 | 일반 반대 기울기 제동·방향 전환 | 통과 | 약 1.35 게임 초 |
| T31 | ICE 반대 기울기 제동·방향 전환 | 통과 | 약 2.00 게임 초 |

모두 ±15도 범위의 기존 플랫폼 제어기를 사용했습니다. 프로필 차이로 초기 측정 속도도 다르며,
이 실험은 순수 마찰 하나만의 기여를 분리한 연구나 미로별 완주 증거가 아닙니다.
초고난도 설계의 체감 평가는 이번에 수행하지 않았습니다.

## 4. 실제 Metal 렌더링과 UI

`render_qa.gd`를 그래픽 실행으로 사용했습니다. `--max-fps 120 --fixed-fps 60`이며
일반/ICE 4개 맵, ICE pause 4개, 설정 화면 1개로 **PNG 13개**를 `/tmp`에 저장했습니다.

| ID | 항목 | 결과 | 근거 |
| --- | --- | --- | --- |
| T32 | 일반 4개 레벨·메뉴 렌더링 | 통과 | `normal-level1..4-native.png`, `settings-native.png` |
| T33 | ICE 바닥 렌더링 | **실패** | 컴파일 오류와 흰색 대체 바닥, `render-qa.log` |
| T34 | ICE pause 표시 순서 | 경미한 문제 | ICE 문구가 가림막 위에 남음, QA-003 |
| T35 | 센서 버튼/Player 1 카드 교차 | 경미한 문제 | 논리 높이 16 교차, QA-004 |

PNG 저장 성공만으로 디자인 검증에 성공했다고 처리하지 않았습니다.
실제 렌더링에서 셰이더 오류를 다시 확인했습니다. GUI 창을 렌더링한 것이며 사람이 플레이한 검사는 아닙니다.

## 5. 반복 로딩·로그·성능·종료

T21의 순환 마지막 표본은 다음과 같습니다. 캐시가 따뜻해진 뒤의 짧은 관측입니다.

| 순환 | 노드 | Object | orphan | 고정 메모리 bytes |
| --- | --- | --- | --- | --- |
| 0 | 110 | 1891 | 0 | 169425430 |
| 1 | 110 | 1891 | 0 | 169456946 |
| 2 | 110 | 1891 | 0 | 169457670 |
| 3 | 110 | 1891 | 0 | 169458418 |

노드 누적이나 큰 메모리 증가를 관찰하지 않았습니다. 이 짧은 실행만으로 장시간 누수를 부정하지 않습니다.

`performance_probe.gd`는 고정 물리 빠른 실행과 달리 **실제 시간으로** Metal 화면을 약 7.239초 실행했습니다.
첫 180 process frame을 제외하고 240개 표본을 수집했습니다.

| ID | 항목 | 결과/한계 |
| --- | --- | --- |
| T36 | LEVEL 04 일반 모드 성능 표본 | 관측 FPS 60, 물리 0.716~1.983ms, 중앙값 1.0015ms |
| T37 | 실제 렌더링 부하 | 캡처 3024×1701, draw call 222, `performance-native.json` |
| T38 | 관측 고정 메모리 | 332524535~332705155 bytes, 약 0.18MB 범위 변화 |
| T39 | 반복 콘솔 출력 | 진단 UI OFF에도 약 2.5 게임 초에 12줄, `debug-probe.log`, QA-005 |
| T40 | 종료 로그 | ObjectDB/RID 누수·GDScript 오류 발견 없음. ICE 셰이더 오류는 별도 존재 |

60FPS 제한에서 시작 구간을 본 결과이므로 최고 성능이나 전체 맵 평균 FPS가 아닙니다.
headless에서 일부 Performance 값이 0 또는 의미 없는 FPS였던 결과는 판단에서 제외했습니다.
GPU 장기 스트레스, 반복 낙하를 포함한 수시간 운영은 미검증입니다.

## 6. 정적 점검·Windows 준비

| ID | 항목 | 결과 | 한계 |
| --- | --- | --- | --- |
| T41 | 런타임 코드·Scene의 명시적 res 경로 | 63개 참조, 로컬 파일 누락 0 | 동적 경로와 Export 팩 내부까지 보증하지 않음 |
| T42 | macOS 고정 경로 의존성 | 런타임에는 하드코딩 USB 경로 없음 | 하드웨어 과거 설명·검사 임시 경로는 별도 |
| T43 | Python 플랫폼별 포트 탐색 | `list_ports`, Windows에서 exclusive 옵션 생략 확인 | 코드 정적 검토, 실물 통신 아님 |
| T44 | 외부 의존성 | Python·pySerial 3.5, Windows `.bat`의 `py -3` 전제 확인 | 실제 Windows 설치·실행 미검증 |
| T45 | OBJ/MTL 텍스트 사용과 Export 설정 | raw FileAccess 의존, `export_presets.cfg` 없음 | 원본 포함 정책 추후 필요. 실제 누락 결함으로 집계 안 함 |
| T46 | 보호 파일 해시 | 115개 모두 QA 시작 스냅샷과 일치 | 기존 미커밋 변경을 HEAD로 되돌리지 않음 |

Windows Export·배포 폴더·실행 파일을 만들지 않았습니다.
센서 통신·전원·펌웨어·USB 재연결·영점 보정·사람의 손목 방향은 이번 QA에서 모두 제외했습니다.

## 로그 보존과 재검사

원시 자료 목록은 다음과 같습니다.

```text
/tmp/balance-qa-2026-10-27/
  baseline.json, initial-status.txt
  run_existing.py, 기존 검사 임시 래퍼 *.gd
  existing-results.json, 각 기존 검사 *.log
  ice_qa.gd, ice-qa.log, ice-results.json
  ice-qa-initial.log, ice-results-initial.json
  load-metrics.json, coast-normal.json, coast-ice.json
  preferences_probe.gd, preferences-*.log, probe-results.json
  render_qa.gd, render-qa.log, PNG 13개
  debug_probe.gd, debug-probe.log
  performance_probe.gd, performance-native.log, performance-native.json
  resource-check.json
```

임시 폴더는 영구 보관물이 아니므로 중요한 결과·오류 원문은 이 문서와 ISSUES에 함께 적었습니다.
이번 QA에서 `.godot/` 캐시를 임의 삭제·초기화하지 않았고, 기존 미추적 `.import`/translation 파일도 지우지 않았습니다.
Commit·Push·Windows Export·EXE 생성과 게임 오류 수정은 수행하지 않았습니다.

## 7. 사용자 요청에 따른 ICE 오류 수정 후 재검증 — 2026-10-27

위 무인 QA 기록은 수정 전 이력으로 보존합니다. 이후 별도 사용자 요청으로 ICE 관련 두 항목을 수정했습니다.
이번 후속 작업은 무인 QA의 읽기 전용 검사와 구분하며, 게임 파일 중 기존 변경은
`scripts/modes/ice_mode.gd`와 `shaders/ice_floor.gdshader` 두 개뿐입니다.

| 검사 | 결과 | 보존한 근거 |
| --- | --- | --- |
| 새 ICE 회귀 검사 / headless | 24 통과, 0 실패. 픽셀 검사는 명시적 SKIP | [로그](../../reports/ice_mode/regression-headless.log) |
| 새 ICE 회귀 검사 / 실제 Metal | 25 통과, 0 실패. 푸른 픽셀 포함 | [로그](../../reports/ice_mode/regression-native.log) |
| 기존 ICE 설정·물리·충돌·재시작 검사 | 84 통과, 0 실패 | [로그](../../reports/ice_mode/physics-settings.log) |
| 실제 네 레벨의 일반/ICE·pause 재렌더링 | 오류 없음 | [렌더링 로그](../../reports/ice_mode/render-fixed.log) |
| 편집기 프로젝트 로드·가져오기 | Script/Shader/Resource 오류 없음 | [로그](../../reports/ice_mode/project-load.log) |

셰이더 적용 여부만 검사하지 않고 별도 SubViewport의 실제 색을 읽습니다.
중앙 픽셀 `(0.451, 0.6784, 0.7804, 1)`의 푸른색 우세를 확인하여 이전 흰색 대체 재질의 재발을 검사합니다.
네 레벨에서 ICE 안내 Label이 PauseMenu와 성공 화면보다 먼저 그려지는 순서도 검사합니다.
일반 모드에서 ICE 재질·Label이 남지 않고 기존 감쇠를 사용하는지도 확인했습니다.

재실행 가능한 [검사 스크립트](../../tests/ice_mode_test.gd)를 추가했습니다.
이 후속 작업에서도 실제 ESP32, 사람의 전체 맵 플레이, Windows Export/EXE, Git Commit/Push는 수행하지 않았습니다.
