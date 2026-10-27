# BALANCE LAB Windows 실행 안내

대상: **Windows 10/11 64비트, Intel/AMD x64 PC**. macOS에서 만드는 Windows 전용 배포본입니다.
Windows ARM 전용 빌드는 아닙니다. 기존 macOS Godot 개발·실행은 그대로 사용합니다.

## 옮기고 실행하기

1. 배포 ZIP 전체를 Windows PC로 복사한 뒤 **압축을 모두 풉니다**.
2. 키보드만 사용하려면 `BALANCE_LAB.exe`를 실행합니다.
3. 손목 컨트롤러를 사용하려면 `START_BALANCE_LAB.cmd`를 실행합니다.
   함께 들어 있는 Windows Python 런타임과 pySerial을 사용하므로 Python·Godot 설치나
   실행 중 인터넷 다운로드가 필요하지 않습니다. 동봉 파일과 폴더를 함께 유지하세요.
4. 게임을 닫으면 실행 스크립트가 시작한 중계 프로그램도 종료됩니다.
   센서 사용 중에는 함께 열린 운영 콘솔을 닫지 마세요.

`BALANCE_LAB.exe`는 게임 데이터가 포함된 EXE입니다. **센서 중계 프로그램까지 합쳐진 단일 EXE는 아닙니다.**
센서 플레이를 다른 컴퓨터로 옮길 때는 ZIP 전체를 옮깁니다.
Arduino IDE의 시리얼 모니터나 다른 중계 프로그램은 먼저 닫아 주세요.

## 손목 컨트롤러

| 역할 | 현재 등록된 ID | 입력 설정 |
| --- | --- | --- |
| Player 1 좌우 | `esp32-680947606060` | PITCH, INVERT ON |
| Player 2 앞뒤 | `esp32-08d1f9e7279c` | ROLL, INVERT ON |

위 역할·축·방향은 macOS에서 사용자가 실제로 확인한 설정을 기본 프로필로 제공합니다.
USB 포트 번호나 연결 순서는 기준으로 쓰지 않습니다. 다른 ESP32로 교체하면 게임의 F4 패널에서
기존 역할 등록을 해제한 다음 새 ID를 지정하고 축·방향을 확인할 수 있습니다.
하드웨어의 기존 펌웨어는 유지하며 이 실행 프로그램은 펌웨어를 업로드하지 않습니다.

1. 두 ESP32를 데이터 USB 케이블로 연결합니다.
2. `START_BALANCE_LAB.cmd`로 실행하고 원하는 레벨을 선택합니다.
3. F4 패널에서 두 장치가 연결되어 있는지 확인합니다.
4. 손목을 편한 중립 자세로 잠깐 멈추고 **C**를 누릅니다.
   **INIT 완료**를 확인합니다. 움직이는 중이면 멈춘 뒤 다시 누릅니다.
5. **F8**로 SENSOR 모드를 선택합니다. 새 실행은 항상 KEYBOARD/NEEDS ZERO로 시작합니다.
6. P1은 좌우, P2는 앞뒤로 조작합니다. 센서 모드에서도 A/D·↑/↓는 각 축에 우선 적용됩니다.

각 PC의 역할·축·영점 설정은 `%LOCALAPPDATA%\BALANCE_LAB\controllers.json`에 저장됩니다.
기본 프로필은 첫 실행에만 복사하며, 기존 사용자 설정을 덮어쓰지 않습니다.
배포본에 개발 PC의 착용 영점이나 COM 포트 경로는 포함하지 않습니다.
새 착용 자세에서는 C 보정이 필요합니다. 게임의 ICE MODE 등 설정은 Godot의 사용자 데이터
`%APPDATA%\Godot\app_userdata\balance_lab\settings.cfg`에 별도로 저장됩니다.

## 조작과 설정

- A/D: 좌우, ↑/↓: 앞뒤, 최대 기울기 각 축 ±15도.
- C: 현재 자세 INIT. F8: KEYBOARD/SENSOR 전환.
- F4: 센서 패널. F3: 게임 화면 진단 표시 켜기/끄기.
- ESC: 일시정지, 재시작, 메인 메뉴.
- GAME START: LEVEL 01~04 선택. LEVEL 04가 마지막 단계입니다.
- SETTINGS의 ICE MODE: 다음 레벨 시작/재시작부터 적용, 종료 후에도 저장.

## 연결·화면 문제 확인

전원 LED만 켜지는 것은 USB 데이터 통신 성공을 뜻하지 않습니다. Windows 장치 관리자에서
두 USB Serial/COM 장치를 확인하세요. 현재 장치의 USB 어댑터는 CH340 계열입니다.
COM 장치가 없으면 제조사의 Windows 드라이버가 필요할 수 있습니다.
임의 드라이버를 배포본에 넣거나 자동 설치하지 않습니다.
공식 안내: [WCH CH340/CH341 드라이버](https://www.wch-ic.com/downloads/CH341SER_EXE.html).

- 값이 들어오는데 움직이지 않으면 INIT 완료와 SENSOR 모드를 확인합니다.
- 장치는 있지만 값이 없으면 시리얼 모니터 종료·데이터 케이블·재연결을 확인합니다.
  기존 macOS 검사에서는 한 장치가 EN/RST를 짧게 누른 뒤 복구된 사례가 있습니다.
- 여러 게임/중계를 동시에 실행하지 마세요. 로컬 UDP 6171/6172를 사용합니다.
  인터넷 서버에 센서 값을 보내지 않습니다.
- 실행 기록은 `%LOCALAPPDATA%\BALANCE_LAB\logs\game.log`, `bridge.log`에 남습니다.
  최근 실행 기록으로 덮어쓰며, 로그에는 장치 ID·포트·각도 등이 들어갈 수 있습니다.
- 기본 그래픽은 Forward+ / Vulkan입니다. 최신 그래픽 드라이버를 권장합니다.
  Vulkan에서 시작되지 않으면 `START_OPENGL_FALLBACK.cmd`로 대체 실행을 시도할 수 있습니다.
  대체 모드는 조명·그림자 표현이 달라질 수 있으며 실제 대상 PC에서 확인해야 합니다.
- 서명 인증서가 없는 배포본이므로 Windows 보안 경고가 나타날 수 있습니다.
  배포 출처와 동봉 `BUILD_MANIFEST.json`의 SHA-256을 확인하세요.

## 검증 범위

macOS에서 Godot 4.7.2를 사용해 소스 검사와 Windows 크로스 Export를 수행하는 구조입니다.
배포 전 소스 검사에서 중계 로직 15개, 센서 입력 45개, ICE 회귀 24개,
메뉴·레벨 흐름 52개가 통과했습니다. 합성 입력 검사와 실제 Windows 키보드/USB 검증은 다릅니다.

**Windows 네이티브 실행·그래픽 드라이버·CH340 COM 통신은 Windows PC에서 최종 확인해야 합니다.**
이 Mac에서 Windows의 실제 센서 동시 조작까지 검증했다고 주장하지 않습니다.
ICE MODE 네 레벨 전체의 사람 플레이 완주·체감 난이도도 별도 확인 대상입니다.
기존 QA의 화면 진단 겹침·일부 센서 라벨 겹침·콘솔 디버그 빈도는
게임 진행을 막지 않는 기존 문제로 남아 있습니다.

## 개발자가 다시 빌드하기

Godot **4.7.2 stable**, 빌드용 Python 3.10 이상이 필요합니다. 배포받는 Windows 사용자는
이 개발 도구를 설치할 필요가 없습니다. 공식 템플릿·Python·pySerial의 SHA-256을 고정해 검사합니다.

```sh
python3 tools/windows/package_windows.py --prepare-only
python3 tools/windows/package_windows.py --godot /path/to/Godot
```

출력 폴더는 `dist/BALANCE_LAB_Windows/`, 로그는 `build/validation/`입니다.
기존 출력이 있으면 자동 삭제하지 않고 중단합니다. 보존할 위치로 옮긴 다음 다시 빌드하세요.
`build/`, `dist/`는 Git과 Godot 리소스 검색에서 제외합니다.
원본 모델을 직접 읽는 LEVEL 03·04를 위해 `addons/raw_models/`의 **내보내기 전용 플러그인**이
필요한 OBJ·MTL의 원본 바이트를 PCK에 추가합니다. 원래 모델 위치나 형상은 바꾸지 않습니다.

배포물에는 Godot·내장 의존성, CPython, pySerial의 라이선스를 `licenses/`에 함께 제공합니다.
공식 참고: [Godot Windows Export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html),
[Python Windows 내장 배포](https://docs.python.org/3.13/using/windows.html#the-embeddable-package).
