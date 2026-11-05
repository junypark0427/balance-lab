# BGM 포함 Windows 배포 검증 — 2026-11-06

기준 시간대: **Asia/Seoul**. 소스 커밋: **`fd88487`**.
요청 순서대로 BGM 소스·세 MP3를 먼저 GitHub main에 Push한 다음 해당 소스로 EXE를 생성했습니다.

## 결과물

- [전체 Windows ZIP](../../dist/BALANCE_LAB_Windows_x64_2026-11-06.zip)
- [다운로드 체크섬](../../dist/SHA256SUMS.txt)
- [실행 안내](../WINDOWS_RELEASE.md)

Windows 10/11 x64용 Godot 4.7.2 Release EXE입니다. 게임 데이터와 BGM은 EXE에 내장됩니다.
센서용 Windows Python·pySerial·실행기·기본 ID/축 설정과 라이선스도 전체 ZIP에 포함합니다.
센서의 착용 영점·로컬 COM 포트·개발 PC 인증 정보는 배포하지 않습니다.
현재 사용자 설정은 기존과 같은 Windows 사용자 폴더에서 읽습니다.

기존 `dist/BALANCE_LAB_Windows/`, 사용자가 만든 다른 배포 폴더와 이전 ZIP은 보존했습니다.
새 빌드는 `build/releases/2026-11-06/BALANCE_LAB_Windows/`에서 별도로 생성했습니다.

## 실제 검사

| 항목 | 결과 |
| --- | --- |
| 소스 BGM, 실제 macOS CoreAudio | 54 통과 / 0 실패 |
| Python 센서 중계, Windows 10054 주입·실제 로컬 UDP 포함 | 22 통과 / 0 실패 |
| Windows Release 내보내기 | 성공, Export 오류·경고 없음 |
| 새 EXE 내부 데이터만 사용한 BGM | 54 통과 / 0 실패 |
| 새 EXE 내부 데이터만 사용한 메뉴·LEVEL 01~04·성공·RETRY·로비 복귀 | 52 통과 / 0 실패 |
| 새 EXE 내부 데이터만 사용한 센서 합성 UDP·키보드 병행·INIT | 45 통과 / 0 실패 |
| 세 MP3의 포함·디코딩·실제 루프·페이드·같은 곡 유지 | 통과 |
| LEVEL 03·04의 런타임 OBJ/MTL 원본 해시 | 4개 모두 원본과 일치 |
| 게임 팩에 하드웨어 로컬 설정·테스트·보고서가 섞이지 않음 | 통과 |
| 동봉 bridge.py | Windows 10054 수정이 있는 현재 소스와 동일 |
| 컨트롤러 기본 프로필 | 기존 P1/P2 ID·축·반전 유지, 영점 0·미보정 |
| EXE 헤더·내장 PCK·전체 배포 파일 manifest·ZIP CRC | 통과 |

동일 버전 macOS Godot에서 Windows EXE의 내장 PCK를 읽는 방식으로 검사했습니다.
원본 프로젝트 폴더 대신 별도 임시 폴더에서 실행하여 빠진 파일을 소스에서 대신 읽지 않도록 했습니다.
추가 검사는 실제 BGM 디코딩 샘플과 재생 객체·커서를 확인합니다.
성공 화면 검사는 Goal 판정 fixture를 포함하며 각 맵을 시작점부터 완주한 증거는 아닙니다.

관련 코드: [BGM 검사](../../tests/bgm_test.gd), [UI 검사](../../tests/ui_flow_test.gd),
[센서 입력 검사](../../tests/sensor_input_test.gd), [중계 검사](../../hardware/bridge/test_udp_transport.py).
실행 로그와 팩 파일 목록은 로컬 `build/validation/windows-2026-11-06/`에 있습니다.

## 한계와 남은 확인

- **새 EXE를 Windows에서 네이티브 실행한 결과는 아닙니다.** 갤럭시 북에서 BGM 출력·음량·
  반복 연결감과 두 컨트롤러 동시 플레이를 최종 확인해야 합니다.
- 이전 Windows 센서 10054 패치는 사용자가 두 장치 인식과 정상 작동을 확인했습니다.
  이번 배포에도 동일한 중계 소스를 포함했지만 새 배포본의 실제 하드웨어 테스트를 대신하지 않습니다.
- 일부 자동 검사 종료 시 `ObjectDB instances were leaked at exit` 경고가 간헐적으로 남았습니다.
  이번 소스 CoreAudio BGM 검사에서 4개, 내장 데이터 UI 검사에서 2개가 표시됐습니다.
  재생·씬 전환·검사 실패나 크래시는 없었으며, 원인을 확정하거나 해결됐다고 주장하지 않습니다.
- 파일 누락과 플레이어 누락을 일부러 주입한 BGM 검사에서는 의도된 경고도 출력됩니다.
- 기존의 진단 UI 겹침, 일부 센서 라벨 겹침, 디버그 출력 빈도는 이번 배포에서 변경하지 않았습니다.
- ICE 전체 맵 사람 플레이 완주·체감 난이도, 오디오 장치 고장·분리 상황은 이번 검사에 포함하지 않았습니다.

이전 상세 기록: [BGM 구현](BGM_SYSTEM_2026-11-05.md),
[Windows 센서 수정](WINDOWS_SENSOR_HOTFIX_2026-11-05.md).
