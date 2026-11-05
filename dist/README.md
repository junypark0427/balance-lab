# Windows 배포 파일

[BALANCE LAB Windows x64 다운로드 — BGM 포함](BALANCE_LAB_Windows_x64_2026-11-06.zip) · [SHA-256](SHA256SUMS.txt) · [상세 실행 안내](../docs/WINDOWS_RELEASE.md)

2026-11-06에 소스 커밋 `fd88487`로 새로 내보낸 Windows 10/11 x64 배포본입니다.
로비·일반 모드·ICE 모드 BGM과 Windows 센서 중계 `10054` 수정이 함께 포함됩니다.
ZIP에는 `BALANCE_LAB.exe`, 센서 중계 프로그램, 내장 Windows Python, 기본 컨트롤러 역할 설정,
사용 방법과 검사 결과, 라이선스가 포함되어 있습니다.

1. ZIP 파일 페이지의 **Download raw file**을 눌러 받고 압축을 모두 풉니다.
2. 키보드 플레이: `BALANCE_LAB.exe` 실행.
3. 센서 플레이: `START_BALANCE_LAB.cmd` 실행 → 중립 자세에서 C로 INIT → F8로 SENSOR 모드 선택.

이미 이전 배포본이 있다면 게임과 운영 콘솔을 모두 종료하고 최신 ZIP 전체를 새 폴더에 푸세요.
Windows 사용자 폴더에 저장된 역할·영점·게임 설정은 보존합니다.
이전 [작은 센서 패치](BALANCE_LAB_Sensor_Fix_2026-11-05.zip)는 BGM을 추가하지 않습니다.

Python이나 Godot를 별도로 설치할 필요는 없습니다. Windows의 실제 USB 센서 동작은
사용할 PC에서 확인해야 합니다. 이전 ZIP은 이력 보존용이며 새 다운로드에는 위 최신 링크를 사용하세요.
