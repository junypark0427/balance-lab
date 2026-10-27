# BALANCE LAB 손목 컨트롤러 운영 안내

이 문서는 게임용 센서 연동 안내입니다. 이전 Pro Micro 검사 기록인 [README](README.md),
[TEST_REPORT](TEST_REPORT.md)와 원래 테스트 스케치는 그대로 보존했습니다.
현재 연결한 장치의 확인 결과는 [검증 기록](../reports/sensors/validation.md)을 참조하세요.
Windows EXE/Export/PyInstaller는 이번 작업에 포함하지 않습니다.

## 구조와 보드 설정

`MPU6050 2개 → 각 ESP32 → USB Serial 115200 → Python → 127.0.0.1 UDP → TiltInput → 기존 Platform`

공의 좌표·속도·힘을 직접 조작하지 않습니다. LEVEL 01~04의 기존 RigidBody3D, 미로, 충돌,
카메라, Goal, 플랫폼 제어 코드를 공유합니다. 각 축 최대 기울기는 기존 ±15도입니다.

이번에 연결한 두 장치는 esptool에서 모두 `ESP32-D0WD-V3 revision 3.1`로 식별되었습니다.
이는 칩 정보이며, USB 이름만으로 제조사별 개발보드 모델이나 WROOM 실드의 정확한 품번까지
확정한 것은 아닙니다. ESP32-WROOM은 ESP32 계열 모듈 이름입니다.
예전 ATmega32U4 Pro Micro의 D2/D3 설정을 현재 ESP32에 적용하지 않습니다.

| 현재 장치의 MAC 기반 ID | 확인한 I²C | 근거 |
| --- | --- | --- |
| `esp32-680947606060` | SDA=GPIO21, SCL=GPIO22 | 기존 펌웨어 시작 로그, WHO_AM_I=0x68, 새 펌웨어 측정 |
| `esp32-08d1f9e7279c` | SDA=GPIO21, SCL=GPIO22 | 기존 펌웨어 시작 로그, WHO_AM_I=0x68, 새 펌웨어 측정 |

원래 요청의 D2/D3를 GPIO2/GPIO3으로 추정하지 않았습니다. 현재 실제로 실행되던
`ESP32 MPU6050 quick test | SDA=21 SCL=22` 안내와 센서 응답을 두 장치에서 각각 확인했습니다.
배선은 변경하지 않았습니다. ESP32/센서의 3.3V I²C 구성을 유지하세요.
다른 보드로 바꿀 경우 실제 보드와 핀·전압을 다시 확인하고 빌드해야 합니다.

## 행사에서 실행하기

1. 컨트롤러 두 개를 데이터 통신이 가능한 USB 케이블로 연결합니다.
2. Arduino IDE의 시리얼 모니터 등 포트를 사용하는 프로그램을 닫습니다.
3. macOS에서 `hardware/start_sensors.command`를 실행합니다.
   최초 실행은 Python 3와 인터넷이 필요하며 `hardware/.venv/`에 pySerial 3.5를 설치합니다.
   일반 Python/Arduino 설정은 변경하지 않습니다. 이미 설치됐다면 인터넷 없이 실행합니다.
4. Godot에서 평소처럼 F5/시작 버튼으로 게임을 실행합니다. 메인 화면의 `GAME START`는
   레벨 선택 화면을 엽니다. 원하는 레벨을 선택하세요. 중복된 홈 `LEVEL SELECT` 버튼은 제거했습니다.
   `F4` 또는 화면의 SENSORS 버튼으로 컨트롤러 패널을 엽니다. 플레이 중 패널을 열면 게임 물리가 일시정지됩니다.
5. Player 1/2 드롭다운에서 **서로 다른 ID**를 지정합니다. 역할은
   `hardware/bridge/controllers.local.json`에 저장되며 포트 번호·연결 순서와 무관합니다.
   처음 등록한 뒤에도 필요하면 SELECT DEVICE ID로 등록을 해제하고 재지정할 수 있습니다.
6. 편한 중립 자세에서 손목을 잠깐 멈추고 **C**를 누릅니다. 화면에 초록색 **INIT 완료**가
   표시된 뒤 자세를 풀어도 됩니다. 착용 자세가 달라졌으면 같은 방법으로 다시 보정하세요.
   정밀 보정이 필요할 때는 패널의 `ZERO BOTH`를 누르고 **3초 이상** 가만히 둔 뒤 READY를 확인합니다.
7. `SENSOR [F8]`를 선택하고 RETURN 버튼/F4로 돌아가 플레이합니다.
   `KEYBOARD [F8]`로 언제든 키보드 전용으로 돌아갈 수 있습니다.

브리지는 매번 Keyboard 모드와 NEEDS ZERO 상태로 시작합니다. 역할과 이전 숫자 영점은 보존하지만
새 실행에서는 착용한 중립 자세를 다시 보정해야 센서 조작이 활성화됩니다.
센서 모드에서도 A/D 및 ↑/↓를 누르면 **해당 축에 키보드 입력이 우선**합니다.
센서가 없거나 브리지가 종료되면 키보드는 계속 사용할 수 있습니다.
Godot 내장 게임 창에서 키가 들어오지 않으면 게임 화면의 Input 모드를 선택하고 화면을 클릭하세요.

### C: 현재 자세로 빠르게 INIT

`C` 또는 패널의 `INIT CURRENT POSE [C]`는 연결되고 역할이 지정된 컨트롤러의 현재 자세를
중립으로 저장합니다. 최근 최대 0.4초 표본에서 정지 상태를 확인하며, 보정되는 플레이어는
완료 안내의 `P1`, `P2`로 구분합니다. 연결된 두 기기 중 하나라도 움직이면 둘 다 변경하지 않고
실패를 표시합니다. 한 기기만 연결되어 있으면 그 기기만 보정합니다.

화면에는 `INIT 중` → 실제 중계 응답을 받은 뒤 `INIT 완료` 또는 `INIT 실패`가 약 4초 표시됩니다.
키를 누른 사실만으로 성공을 표시하지 않습니다. 실패하면 잠깐 멈춘 뒤 C를 다시 누르세요.
이 기능은 손목 영점만 바꾸며 공의 위치·속도, 플랫폼 최대 각도, 입력 모드는 바꾸지 않습니다.
센서 모드는 F8로 선택합니다. C는 Godot 실행 단축키 F5와 겹치지 않도록 정했습니다.

Windows 개발 환경용 `start_sensors.bat`도 제공하지만 현재 PC에서는 실행 검증하지 않았습니다.
이 파일은 Python 3 설치가 필요한 개발 실행 스크립트이며 독립 실행형 EXE가 아닙니다.
추후 배포 시 브리지 패키징과 Godot Windows Export를 별도 검증해야 합니다.

## 영점·축·방향·반응 조정

- Player 1은 실제 손목 좌우 동작이 크게 측정되는 ROLL/PITCH 축을 선택합니다.
- Player 2는 실제 손목 앞뒤 동작이 크게 측정되는 축을 선택합니다. 이름과 손목 방향이 항상 일치하지는 않습니다.
- 방향이 반대면 INVERT를 켭니다. 왼쪽/앞쪽으로 움직였을 때 원하는 플랫폼 방향인지 실제로 확인하세요.
- DEADZONE 기본 2.5°: 작은 손 떨림을 무시합니다.
- FULL TILT 기본 25°: 중립 기준 이 각도에서 플랫폼의 최대 ±15도 입력이 됩니다.
- 데드존 밖은 각도에 비례해 연속적으로 조작됩니다. 큰 값은 ±1로 제한됩니다.
- 중계 필터 시정수 기본 0.04초는 로컬 설정 파일의 `smoothing`에서 조정할 수 있습니다(변경 후 재실행).

패널의 ZERO는 먼저 정지 자세에서 자이로 편향을 약 1.2초 측정하고, 이어서 안정된 60개 각도 표본으로
중립을 구합니다. 움직임/진동/통신 중단이 있으면 보정을 완료하지 않고 중립 출력을 유지합니다.
10초 안에 정지 조건을 만족하지 못하면 실패 안내를 표시하므로 다시 시도하세요.
Roll은 ±180° 경계를 처리하고 Pitch는 ±90° 이내입니다. Pitch가 ±90°에 가까운 장착은
Roll이 불안정해질 수 있으므로 센서 자세/축을 조정해야 합니다.

두 ID를 바꾸려면 먼저 두 드롭다운을 모두 미지정 상태로 만들고 각각 지정한 뒤 다시 ZERO 합니다.
중복된 ID로 두 플레이어를 등록할 수 없습니다.

## 연결 해제와 오류

각 포트는 독립 스레드가 읽으므로 한쪽의 통신 지연이 다른 쪽을 막지 않습니다.
USB 장치 검색은 운영체제에 맞춰 수행하며 COM 번호나 `/dev/cu.*` 경로를 하드코딩하지 않습니다.
기본적으로 ESP32에 흔히 쓰는 USB VID를 대상으로 하며, 다른 어댑터는 `--port`로 명시할 수 있습니다.

- 센서 표본이 250ms 이상 없으면 해당 플레이어 입력을 즉시 0으로 만듭니다.
- Godot가 중계 패킷을 300ms 이상 못 받으면 센서 전체 입력을 0으로 만듭니다.
- 플랫폼의 실제 복귀는 기존 부드러운 회전/각속도 제한을 따르며 순간 회전하지 않습니다.
- NaN/Infinity, 비정상 범위, 센서 오류, 잘못된 프로토콜과 중복 순번은 정상 표본으로 쓰지 않습니다.
- 재연결하면 ID를 다시 읽어 저장된 플레이어 역할을 유지합니다. 새 장치는 자동으로 다른 역할을 차지하지 않습니다.
- 포트 점유/동일 브리지 중복 실행 오류는 콘솔에서 확인합니다. 동시에 게임 두 개를 실행하면
  한쪽에서 센서 수신 포트를 사용할 수 없으며 키보드로 유지됩니다.
- I²C 초기화/읽기 오류는 유효 값으로 포장하지 않고 오류 프레임을 보냅니다. 재시도는 빌드에 지정한
  GPIO에서만 하며 다른 GPIO를 무작위로 스캔하지 않습니다.

프로그램은 시리얼 포트를 열 때 DTR/RTS를 비활성화합니다. 다만 일부 USB 드라이버는 열 때
보드를 재부팅할 수 있으므로 연결 초기에는 유효 측정이 들어오기까지 기다립니다.

## 펌웨어 빌드·업로드

현재 두 장치에서 확인한 보드 설정: `esp32:esp32:esp32`, 코어 3.3.12.
외부 MPU6050 라이브러리는 필요하지 않습니다. `Wire`, 기본 수학 함수, ESP32 MAC API만 사용합니다.

```sh
arduino-cli compile --fqbn esp32:esp32:esp32 \
  --build-path /tmp/balance-controller-build \
  --build-property 'compiler.cpp.extra_flags=-DBALANCE_SDA=21 -DBALANCE_SCL=22' \
  hardware/controller_firmware
# 브리지를 종료하고 실제 포트를 다시 확인한 다음, 한 대씩 실행합니다.
arduino-cli board list
arduino-cli upload --fqbn esp32:esp32:esp32 --port ACTUAL_PORT \
  --input-dir /tmp/balance-controller-build --upload-property upload.speed=115200 --verify
```

macOS에 PATH의 CLI가 없다면 Arduino IDE에 포함된 CLI 경로를 사용하세요.
빌드 시 핀 플래그를 생략하거나 ESP32 이외 보드를 고르면 컴파일을 중단합니다.
장치 ID는 읽기 전용 MAC 값에서 생성하며 eFuse/보안 설정을 쓰거나 변경하지 않습니다.
115200으로 업로드와 데이터 해시 검증을 두 장치에서 완료했습니다.
업로드하면 실행 펌웨어는 바뀌지만 기존 테스트 스케치 파일은 보존됩니다.

MPU6050 설정: ±2g, ±250°/s, 약 44Hz DLPF, 50Hz 표본/송신, I²C 100kHz/25ms timeout.
0x68/0x69에서 WHO_AM_I=0x68 및 설정 readback을 확인합니다.
상보 필터로 자이로 적분과 가속도 기울기를 결합합니다. 장시간 드리프트·빠른 손목 가속도의
영향까지 완전히 제거하는 절대 자세 계측기는 아닙니다.

## 운영 콘솔과 검증

브리지 콘솔에서도 아래 명령을 사용할 수 있습니다.

```text
assign 1 esp32-680947606060
assign 2 esp32-08d1f9e7279c
axis 1 roll
invert 1 on
init
calibrate all
sensor
keyboard
quit
```

위 ID/축은 명령 형식 예시입니다. 실제 착용자의 역할/방향과 일치하는지 확인해서 지정하세요.

```sh
python -m unittest discover -s hardware/bridge -v
godot --headless --path . --script tests/sensor_input_test.gd
# 실제 사람/센서 플레이의 관찰 기록. 자동 입력을 생성하지 않습니다.
godot --path . --script tests/sensor_live_test.gd
# 평소 메뉴부터 시작하는 관찰 기록
godot --path . --script tests/sensor_live_test.gd -- --menu
```

첫 번째는 중계 로직 검사, 두 번째는 합성 UDP 입력을 실제 Godot 물리에 적용하는 검사입니다.
이 두 검사만으로 손목 방향·착용감·두 사람의 실제 클리어를 검증했다고 보지 않습니다.
세 번째 실행에서는 실제 센서를 사용자가 움직여야 하며, 화면 종료 시 기록을 마칩니다.

참조: [Espressif I²C 공식 문서](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/i2c.html),
[pySerial 포트/타임아웃 API](https://pyserial.readthedocs.io/en/latest/pyserial_api.html).
