# Windows 배포 파일

[BALANCE LAB Windows x64 다운로드](BALANCE_LAB_Windows_x64_2026-10-27.zip) · [SHA-256](SHA256SUMS.txt) · [상세 실행 안내](../docs/WINDOWS_RELEASE.md)

2026-10-27에 소스 커밋 `7fd194e`로 만든 Windows 10/11 x64 배포본입니다.
ZIP에는 `BALANCE_LAB.exe`, 센서 중계 프로그램, 내장 Windows Python, 기본 컨트롤러 역할 설정,
사용 방법과 검사 결과, 라이선스가 포함되어 있습니다. 2026-11-05에 저장소에 추가했습니다.

1. ZIP 파일 페이지의 **Download raw file**을 눌러 받고 압축을 모두 풉니다.
2. 키보드 플레이: `BALANCE_LAB.exe` 실행.
3. 센서 플레이: `START_BALANCE_LAB.cmd` 실행 → 중립 자세에서 C로 INIT → F8로 SENSOR 모드 선택.

Python이나 Godot를 별도로 설치할 필요는 없습니다. Windows의 실제 그래픽 실행·USB 드라이버·
COM 인식은 사용할 Windows PC에서 확인해야 합니다. 이번 업로드는 기존 검증된 배포 파일을
그대로 추가한 것이며 게임 코드나 모델은 변경하지 않았습니다.
