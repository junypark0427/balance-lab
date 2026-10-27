# BALANCE LAB 하드웨어 작동 테스트

Godot 게임과 분리한 Pro Micro + MPU6050 시험 코드. 외부 센서 라이브러리는 사용하지 않는다.
`.gdignore`로 Godot의 리소스 검색에서 이 폴더를 제외한다.

## 전원을 넣기 전

현재 사용자의 GY-521 회로 및 I²C 전압 호환성은 확인되지 않았다. USB 전원을 뺀 상태에서 배선을 변경한다.
단독 보드 시험은 센서의 VCC/GND/SDA/SCL 연결을 모두 분리하고 진행한다.

GY-521에 전압 레귤레이터가 있다고 해서 SDA/SCL이 5V 신호를 허용하는 것은 아니다.
MPU6050 칩의 VDD 동작 범위는 2.375–3.46V이며, VLOGIC은 VDD 이하이다.
모듈의 정확한 모델/회로도에서 전원 입력 허용 범위와 I²C 레벨 변환 회로를 각각 확인해야 한다.
단순히 판매 페이지에 적힌 `3–5V`만으로 신호 호환성을 판단하지 않는다.

검증된 양방향 I²C 레벨 시프터를 사용하는 경우, 보드 D2/D3는 HV 측,
센서 SDA/SCL은 LV 측에 연결한다. HV 기준은 보드 5V, LV 기준은 적절한 3.3V 전원으로 하고 GND를 공유한다.
센서 VCC에는 해당 모듈 사양에 맞는 전원을 사용한다. 5V Pro Micro의 VCC는 3.3V 출력이 아니다.
시프터·풀업 회로와 전원 구성이 확인된 후에만 전원을 연결한다.
실측으로 확인할 때도 센서를 미검증 5V 버스에 연결해 측정하지 말고, 분리한 전원/레벨 변환 회로부터 검증한다.

Arduino AVR의 `Wire.begin()`은 SDA/SCL의 내부 VCC 풀업을 켠다.
따라서 소프트웨어의 `START` 대기 기능이나 센서 전원선만 분리하는 조치는 전기적 안전을 보장하지 않는다.
SDA/SCL을 통한 역급전도 피해야 한다.

전압 호환성을 입증한 모듈에 직접 연결하는 경우의 논리적 핀 매핑은 다음과 같다.

| GY-521 | Pro Micro |
|---|---|
| VCC | 모듈의 허용 입력 전압에 맞는 전원 (5V 허용이 확인된 경우 VCC) |
| GND | GND |
| SDA | D2 (필요 시 레벨 시프터 경유) |
| SCL | D3 (필요 시 레벨 시프터 경유) |

## 도구와 보드 설정

이번 검사에서 Arduino IDE 2.3.10과 내장 Arduino CLI 1.5.1을 사용했다.
일반 PATH에는 CLI가 없지만 별도 CLI 설치는 필요하지 않았다.

```sh
ARDUINO_CLI='/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli'
FQBN='SparkFun:avr:promicro:cpu=16MHzatmega32U4'
```

- 보드: SparkFun Pro Micro
- 프로세서: ATmega32U4 (5V, 16 MHz)
- 패키지: SparkFun AVR Boards 1.1.13
- 기반 코어: Arduino AVR Boards 1.8.8
- 시리얼: 115200 baud, USB `Serial` 사용 (`Serial1` 아님)
- Arduino IDE의 현재 선택을 변경하지 않고 CLI의 FQBN으로 명시했다.

기존 Arduino 설정을 유지하기 위해 SparkFun 패키지는 아래 임시 환경에만 설치했다.
기존 Arduino AVR 및 내장 도구는 읽기 참조하며, 별도 라이브러리는 설치하지 않았다.

```sh
TEST_CONFIG='/var/folders/s3/qx92dvqx07d4dwl7r5_lpbyr0000gn/T/balance-lab-arduino-6ldq6hjg/arduino-cli.yaml'
"$ARDUINO_CLI" board details --config-file "$TEST_CONFIG" -b "$FQBN"
"$ARDUINO_CLI" board list --config-file "$TEST_CONFIG"
```

임시 폴더는 운영체제가 정리할 수 있다. 없어졌다면 기존 설정을 초기화하지 않고 IDE의 보드 매니저로 설치할 수 있다.
추가 보드 매니저 URL 목록에 아래 URL을 **추가**하고 SparkFun AVR Boards를 설치한다.
이 작업은 이번 검사에서는 사용자의 IDE 설정에 적용하지 않았다.

<https://raw.githubusercontent.com/sparkfun/Arduino_Boards/main/IDE_Board_Manager/package_sparkfun_index.json>

별도 CLI가 필요한 다른 환경의 공식 설치 방법은 `brew install arduino-cli`이며,
이번에는 이미 내장 도구가 있어 실행하지 않았다.

## 1. 보드 단독 시험

센서 배선을 모두 분리한 상태에서 보드만 USB에 연결한다.
보드에 실제로 ATmega32U4 및 16MHz 표기가 있는지 확인한다.
현재 USB 디스크립터는 Arduino Leonardo / VID 2341 / PID 8036이다.
이는 펌웨어가 제공하는 이름이며, 물리적인 모델·전압·클록의 증명은 아니다.

프로젝트 루트에서 컴파일:

```sh
"$ARDUINO_CLI" compile --config-file "$TEST_CONFIG" -b "$FQBN" \
  --build-path /tmp/balance-lab-build-pro_micro_smoke hardware/pro_micro_smoke
```

다음 업로드 명령은 이번에 실행하지 않았다. 센서 완전 분리와 보드/포트를 재확인한 후에만 사용한다.
기존 사용자 스케치는 업로드로 교체된다.

```sh
"$ARDUINO_CLI" board list --config-file "$TEST_CONFIG"
# 아래 포트는 당시 관측값이다. 재연결 후 바뀌면 실제 포트로 수정한다.
BOARD_PORT='/dev/cu.usbmodem11101'
"$ARDUINO_CLI" upload --config-file "$TEST_CONFIG" -b "$FQBN" \
  -p "$BOARD_PORT" --input-dir /tmp/balance-lab-build-pro_micro_smoke
"$ARDUINO_CLI" monitor --config-file "$TEST_CONFIG" \
  -p "$BOARD_PORT" --config baudrate=115200
```

성공 시 `BALANCE LAB BOARD OK | ATmega32U4 | F_CPU=16000000 | uptime_ms=...`가 매초 출력된다.
이는 예상 출력이며 이번에 실측하지 않았다.

## 2. 센서 시험

전원/신호 호환성과 배선 안전이 확인된 후에 진행한다.
전원을 끄고 안전한 센서 회로를 연결한 다음 전원을 켠다.

```sh
"$ARDUINO_CLI" compile --config-file "$TEST_CONFIG" -b "$FQBN" \
  --build-path /tmp/balance-lab-build-mpu6050_test hardware/mpu6050_test
# 업로드 전 위의 board list로 보드와 포트를 다시 확인한다.
"$ARDUINO_CLI" upload --config-file "$TEST_CONFIG" -b "$FQBN" \
  -p "$BOARD_PORT" --input-dir /tmp/balance-lab-build-mpu6050_test
"$ARDUINO_CLI" monitor --config-file "$TEST_CONFIG" \
  -p "$BOARD_PORT" --config baudrate=115200
```

모니터에서 `START`와 줄바꿈을 보내야 I²C를 초기화한다. 종료 명령은 `STOP`과 줄바꿈이다.
START는 전기적 안전을 확인하는 기능이 아니라 사용자가 확인한 뒤 시험을 시작하는 명령이다.
0x68, 0x69에 ACK를 확인하고 WHO_AM_I(0x75)가 0x68인 장치만 채택한다.
AD0 때문에 주소가 0x69가 되더라도 WHO_AM_I는 0x68이다.
절전 해제 및 범위 설정 후 레지스터를 읽어 검증한다.

가속도 ±2g / 16384 LSB/g, 자이로 ±250 deg/s / 131 LSB/(deg/s),
I²C 100kHz, 25ms 통신 제한, 측정 약 50Hz, 텍스트 출력 최대 약 5Hz로 설정했다.
0x3B부터 14바이트를 연속 읽고 온도 바이트 두 개를 건너뛰어 자이로 데이터를 해석한다.
통신 오류 시 이전 측정값을 정상값처럼 출력하지 않고 시험을 중단한다.

다음은 **출력 형식 예시이며 실제 측정 결과가 아니다**.

```text
WHO_AM_I: 0x68
MPU6050 FOUND: 0x68
Time ms: ...
Accel X: ... g
Accel Y: ... g
Accel Z: ... g
Gyro X: ... deg/s
Gyro Y: ... deg/s
Gyro Z: ... deg/s
Roll raw: ... deg
Pitch raw: ... deg
Roll filtered: ... deg
Pitch filtered: ... deg
Accel norm: ... g
```

## 3. 수평·기울기·노이즈 확인

1. 센서의 +Z가 위를 향하도록 평평하게 놓고 10초간 기록한다.
   이상적인 값은 X/Y 약 0g, Z 약 +1g, 자이로 약 0deg/s, Roll/Pitch 약 0도이다.
   장착 방향·오프셋에 따라 다르므로 이를 보장값이나 자동 합격 기준으로 보지 않는다.
2. 센서 X축을 중심으로 좌우 약 ±30도로 천천히 기울여 Roll 변화·복귀를 확인한다.
3. 센서 Y축을 중심으로 앞뒤 약 ±30도로 천천히 기울여 Pitch 변화·복귀를 확인한다.
4. 각 자세에서 5–10초 멈추고 원시 각도와 필터 각도의 최대–최소 폭 및 표준편차를 비교한다.
   이번에는 실측 데이터가 없어 노이즈 수치를 계산하지 않았다.
5. 정지 상태의 자이로 평균을 추후 영점 보정값으로 사용한다. 이번 스케치는 자동 보정하지 않는다.

계산식: `Roll = atan2(ay, az)`, `Pitch = atan2(-ax, sqrt(ay² + az²))`를 도로 변환한다.
센서 축 기준의 부호이며 손목 장착 방향에 따라 게임 입력 축을 바꿔야 한다.
각도 필터는 계수 0.2의 지수평활이며 Roll의 ±180도 경계를 처리한다.
가속도 크기가 1g에서 0.15g 넘게 벗어나면 동적 가속도 경고를 출력한다.
이 경고가 없더라도 움직이는 손목에서 가속도만으로 구한 각도가 정확하다는 뜻은 아니다.
Pitch ±90도 근방의 Roll은 불안정하고, 중력만으로 Yaw를 구할 수 없다.
실사용에는 가속도·자이로 결합 필터, 영점 보정, 데드존 및 지연 검증이 필요하다.

## 오류 대응

- 포트 없음: 센서를 분리한 뒤 데이터 전송 가능한 케이블, USB 포트, 허브 우회를 확인한다.
- Leonardo로 표시됨: USB 펌웨어 식별 이름일 수 있다. 실물 표기 확인 후 지정 FQBN을 사용한다.
- 업로드 실패/포트 사용 중: 다른 시리얼 모니터를 닫고 재검색한다.
  ATmega32U4는 부트로더 진입 시 포트가 바뀔 수 있다.
  필요한 경우 센서 분리 상태에서 RST–GND를 짧게 두 번 연결해 부트로더 진입을 시도하고 포트를 다시 확인한다.
  VCC를 단락하거나 보드 퓨즈·부트로더를 임의로 변경하지 않는다.
- I²C status=2: 보통 주소 NACK. 전원을 끄고 VCC/GND/SDA/SCL, AD0 및 접촉을 확인한다.
- 시간 초과: 전원을 끄고 SDA/SCL 고착, 뒤바뀐 배선, 풀업, 시프터 방향을 확인한다.
- WHO_AM_I 다름: 다른 MPU 계열이나 호환 칩일 수 있다. 검사를 우회하지 말고 부품을 확인한다.
- 값이 전부 0 또는 고정: 구성 readback/읽기 오류와 실제 움직임을 확인한다. ACK만으로 측정 정상 판정을 하지 않는다.

## 자료

- [SparkFun Pro Micro 보드 정의](https://github.com/sparkfun/Arduino_Boards/blob/main/sparkfun/avr/boards.txt)
- [SparkFun Pro Micro 가이드](https://learn.sparkfun.com/tutorials/pro-micro--fio-v3-hookup-guide)
- [MPU6050 전기 사양](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Datasheet.pdf)
- [MPU6050 레지스터 맵](https://invensense.tdk.com/wp-content/uploads/2015/02/MPU-6000-Register-Map1.pdf)
- [Arduino AVR Wire 내부 풀업 구현](https://github.com/arduino/ArduinoCore-avr/blob/master/libraries/Wire/src/utility/twi.c)
- [Arduino CLI 설치](https://docs.arduino.cc/arduino-cli/installation/)
