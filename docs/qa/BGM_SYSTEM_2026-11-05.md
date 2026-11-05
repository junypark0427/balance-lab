# BALANCE LAB BGM 구현 및 검증

작업일: **2026-11-05, Asia/Seoul**. 엔진: **Godot 4.7.2.stable.official.ed1daf0bf**, GDScript.

후속 작업: **2026-11-06**에 사용자 요청으로 소스를 Push하고 Windows 배포본을 재생성했습니다.
현재 배포 상태는 [Windows 배포 검증](WINDOWS_RELEASE_2026-11-06.md)을 참조하세요.
아래 본문은 최초 BGM 구현 당시의 기록을 보존합니다.

## 확인한 기존 구조와 파일

- 시작 씬은 `scenes/menu.tscn`입니다. 홈·레벨 선택·SETTINGS는 같은 씬의 MenuUI 페이지입니다.
- 게임은 `main.tscn`, `level_02.tscn`, `level_03.tscn`, `level_04.tscn`으로 분리되어 있습니다.
- 일시정지는 GameplayUI의 오버레이이며 SceneTree를 정지합니다. 성공 화면도 게임 내 오버레이입니다.
- 기존 오디오 매니저, SFX/UI AudioStreamPlayer, 별도 음량 설정·버스 레이아웃은 발견되지 않았습니다.
- ICE 설정은 `Session.ice_mode_enabled`이며 `user://settings.cfg`의 기존 저장 형식을 유지합니다.
- 사용자 확인에 따라 **로비·설정에서는 로비 곡을 유지**하고, 게임에서만 모드별 곡을 사용합니다.

| 용도 | 실제 원본 경로 | 엔진에서 확인한 길이 |
| --- | --- | --- |
| 로비 | `bgm/lobby.mp3` | 약 212.41초 |
| 일반 게임 | `bgm/ingame_not_ice.mp3` | 약 149.93초 |
| ICE 게임 | `bgm/ice.mp3` | 약 228.01초 |

요청에 적힌 `bgm/not ice.mp3`는 실제 작업 폴더에 없었습니다. 파일을 변경하지 않고
`not ice.mp3`를 우선 확인한 뒤, 없으면 현재 존재하는 `ingame_not_ice.mp3`를 사용합니다.
공백 경로도 문자열 전체로 ResourceLoader에 전달합니다. 원본 MP3의 바이트·위치·이름은 보존했습니다.

## 생성·수정 파일

| 파일 | 변경 내용 |
| --- | --- |
| [scripts/bgm_manager.gd](../../scripts/bgm_manager.gd) | 새 Autoload용 BGM 관리자, 캐시·루프·페이드·누락 방어 |
| [project.godot](../../project.godot) | 기존 Autoload 뒤에 BGMManager 등록 |
| [scripts/session.gd](../../scripts/session.gd) | ICE 속성 변경 시 신호 발생. 기존 저장·로드 경로와 형식 보존 |
| [scripts/ui/menu.gd](../../scripts/ui/menu.gd) | 메뉴 씬 진입 시 로비 곡 요청 |
| [scripts/main.gd](../../scripts/main.gd) | 공통 게임 씬 진입 시 모드별 곡 요청 |
| [tests/bgm_test.gd](../../tests/bgm_test.gd) | 오디오 믹서·실제 씬·반복 재생 통합 검사 |
| 이 문서 | 설계·테스트·한계 기록 |

Godot이 세 MP3의 `.import` 파일과 새 GDScript의 `.uid` 메타데이터도 자동 생성했습니다.
씬, 미로, 충돌체, 공 물리, 입력 어댑터, 센서 펌웨어, Python USB/UDP 중계는 수정하지 않았습니다.

## 동작과 연결 방식

`BGMManager`는 씬과 별개로 유지되는 **AudioStreamPlayer 하나**를 소유합니다.
`BGM` 버스가 있으면 그대로 재사용하고, 없으면 Master로 보내는 BGM 버스만 추가합니다.
Master나 다른 버스의 음량·음소거·효과를 초기화하지 않습니다.
초기 BGM 플레이어 음량은 **-18 dB**이며 `music_volume_db`로 조정할 수 있습니다.

| 조건 | 음악 동작 |
| --- | --- |
| 첫 실행·로비 복귀 | `lobby.mp3` |
| 로비 내 레벨 선택·설정 이동·ICE 토글 | 로비 곡을 현재 위치에서 계속 재생 |
| 일반 모드 게임 진입 | 일반 곡 |
| ICE 모드 게임 진입 | ICE 곡 |
| 게임 중 `Session.ice_mode_enabled` 변경 | 신호를 받은 즉시 해당 곡의 페이드 전환 시작 |
| 같은 모드의 다음 스테이지·씬 재로드 | 기존 재생 객체와 위치 유지 |
| 공 초기화·일시정지·센서 패널·성공 오버레이 | 현재 게임 곡 유지 |

기존 게임 물리는 레벨 시작 때의 ICE 값을 복사하므로 실행 도중 설정값이 변해도 현재 맵의
물리를 바꾸지 않습니다. 음악은 설정 신호에 반응하고 물리는 기존 재시작 정책을 유지합니다.

기본 전환은 **0.25초 페이드 아웃 → 기존 재생 중단·곡 교체 → 0.25초 페이드 인**입니다.
총 0.5초이며 `transition_seconds`에서 0.4~0.7초로 조정합니다. 첫 곡은 페이드 인만 적용합니다.
두 곡을 동시에 틀지 않습니다. 전환 도중 요청이 바뀌면 이전 Tween을 취소하고 마지막 요청을 반영합니다.
바뀌기 전 원래 곡으로 돌아가는 빠른 요청도 재시작 없이 음량만 회복합니다.
완료된 Tween의 참조와 종료 시 플레이어·캐시를 정리합니다.

MP3는 관리자가 복제한 AudioStreamMP3에 `loop=true`, `loop_offset=0.0`을 적용합니다.
타이머로 곡을 다시 시작하지 않고 엔진의 반복 재생을 사용합니다.
파일이 없거나 디코딩할 수 없으면 이전 유효 곡을 유지하며 한 번만 경고합니다.
플레이어가 없거나 재생을 초기화할 수 없어도 게임을 종료하지 않습니다.

API 근거: [AudioStreamMP3.loop](https://docs.godotengine.org/en/stable/classes/class_audiostreammp3.html),
[AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html).

## 실제 수행한 검증

| 검사 | 결과 |
| --- | --- |
| 프로젝트 import·GDScript 검사 | 통과 |
| BGM 통합 검사, headless/Dummy | **54 통과 / 0 실패** |
| BGM 통합 검사, 실제 macOS CoreAudio | **54 통과 / 0 실패** |
| 내보낸 임시 게임 데이터 팩만 사용한 BGM 검사 | **54 통과 / 0 실패** |
| 기존 메뉴·네 레벨·재시작·성공 흐름 | **52 통과 / 0 실패** |
| 기존 ICE 회귀 | **24 통과 / 0 실패** |
| 기존 센서 합성 UDP·키보드·INIT 회귀 | **45 통과 / 0 실패** |
| 세 필수 음악 파일이 실제로 없는 별도 임시 프로젝트 | 3개 누락 경고 후에도 엔진 루프 유지, 충돌 없이 통과 |
| MP3·Scene·하드웨어 원본 보호 | 기준 해시 30개 모두 동일 |

BGM 검사는 실제 AudioStreamPlayer의 재생 객체 ID와 위치를 비교하고, AudioEffectCapture로
**세 곡의 실제 디코딩 샘플이 0이 아님**을 확인했습니다. 끝부분으로 seek한 다음 커서가
처음으로 돌아오며 동일한 재생 객체가 유지되는 것도 각 곡에서 확인했습니다.
`seek()` 자체는 엔진 재생 객체를 교체할 수 있으므로 그 동작과 루프를 구분했습니다.

일반/ICE 각각 LEVEL 01~04, 로비·설정 토글, 게임 중 설정 변경, 일시정지 중 페이드,
성공·RETRY·로비 복귀, 빠른 전환 취소, 중복 플레이어 방지를 검사했습니다.
성공 화면은 Goal 핸들러를 호출하는 fixture로 검사했으며 맵을 실제 완주한 결과가 아닙니다.
SFX 노드가 원래 없으므로 별도 SFX 테스트 플레이어·버스를 메모리에 만들고,
BGM 전환 후에도 재생·버스·음량·음소거 상태가 유지되는지 검사했습니다.
추가 음악이나 효과음 파일을 만들지는 않았습니다.

공백 파일명은 원본 MP3를 이동·복사하지 않고 임시 PCK의 import 메타데이터 별칭으로 검사했습니다.
시험용 설정·별칭 PCK·음악 누락 프로젝트는 `/tmp`에 만들었습니다.
영구 원본 파일을 숨기거나 이름을 변경해서 누락을 재현하지 않았습니다.

로그: [headless](../../build/validation/bgm/regression-headless.log),
[CoreAudio](../../build/validation/bgm/regression-native.log),
[게임 데이터 팩](../../build/validation/bgm/regression-packed.log),
[음악 누락](../../build/validation/bgm/missing-files.log).
이 실행 로그는 Git에서 제외되는 로컬 `build/validation/bgm/`에 있습니다.

## 남은 확인 사항과 경고

- **직접 청음한 결과는 아닙니다.** 실제 믹서 샘플은 검사했으나 사람의 청감상 음량·곡 끝 연결감은
  확인해야 합니다. MP3 원곡에 들어 있는 시작·끝 여백과 페이드는 편집하지 않았습니다.
- CoreAudio 일반 시작·종료와 최종 BGM 검사에서는 오디오 객체 정리 경고가 없었습니다.
  일부 headless/Dummy 실행의 종료 시 `ObjectDB instances were leaked at exit` 경고가 남았습니다.
  일반 시작·종료에서는 MP3/Playback 2개, SFX fixture가 있는 통합 검사에서는 추가 객체가 표시됐습니다.
  재생·전환 실패나 크래시는 없었으나 경고의 원인은 확정하지 않았습니다.
  비슷한 엔진 보고 [Godot #95484](https://github.com/godotengine/godot/issues/95484)가 있지만 동일 원인이라고 단정하지 않습니다.
- 실제 오디오 장치를 분리하거나 장치 초기화 고장을 강제하는 검사는 하지 않았습니다.
  Dummy 드라이버, 파일 누락, 플레이어 참조 누락은 검사했습니다.
- 실제 ESP32를 사용한 재플레이와 Windows BGM 출력은 이번 작업에서 검증하지 않았습니다.
  센서·중계 코드는 해시가 동일하며 기존 합성 입력 회귀는 통과했습니다.
- 기존 Windows ZIP/EXE는 다시 만들지 않았습니다. 임시 PCK로 리소스 포함·실행만 검사했습니다.
- Git Commit·Push는 진행하지 않았습니다.
