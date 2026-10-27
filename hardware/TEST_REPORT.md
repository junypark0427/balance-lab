# 하드웨어 확인 결과 — 2026-10-26 (한국 시간)

## 후속 확인: USB 시리얼 실행 확인

사용자가 센서 SDA/SCL이 서로 뒤바뀌어 있었음을 보고했다. 실제 배선 수정 여부는 독립 확인하지 못했다.
제공된 구매 링크의 상품명은 ATmega32U4-MU Pro Micro USB-C 5V/16MHz 및 MPU6050 GY-521이다.
조회 가능한 상품 텍스트에서는 GY-521의 5V I²C 레벨 변환 유무를 확인하지 못했다.
이후 포트를 다시 읽었으며 센서 스케치는 여전히 START 대기 안내를 출력했다.
START는 전송하지 않았고 센서 통신 성공 여부는 아직 확인하지 않았다.

사용자의 재연결 및 IDE 작업 이후 `/dev/cu.usbmodem11101`을 115200 baud로 직접 열어
아래 출력을 실제로 수신했다. 센서 스케치가 현재 보드에서 실행되고 있으며 START 명령을 기다린다.
후속 확인에서는 업로드나 START 전송을 수행하지 않았다. 아래 기존 표는 최초 검사 당시의 기록이다.

```text
BALANCE LAB MPU6050 test / 115200 baud
Confirm electrical safety BEFORE powering sensor.
Send START + newline only after safety confirmation; STOP ends I2C.
```

따라서 USB 시리얼 출력 기능은 확인되었다. 가속도·자이로·I²C·기울기 측정은 여전히 미시험이다.
확인 후 포트를 닫아 IDE 시리얼 모니터에서 다시 사용할 수 있게 했다.

## 판정

USB 장치 인식과 Pro Micro 5V/16MHz용 두 스케치의 컴파일은 성공했다.
센서 배선의 전기적 안전과 보드 단독 분리가 확인되지 않아 업로드·센서 통신·실측은 수행하지 않았다.
따라서 손목형 컨트롤러의 실제 동작 및 사용 가능 여부는 아직 검증되지 않았다.

| 항목 | 실제 결과 |
|---|---|
| Arduino IDE | `/Applications/Arduino IDE.app`, 2.3.10 설치 확인 |
| Arduino CLI | PATH에는 없음. IDE 내장 CLI 1.5.1 실행 확인 |
| 보드 USB 인식 | Arduino Leonardo / VID 0x2341 / PID 0x8036로 열거됨 |
| 실제 관측 시리얼 포트 | `/dev/cu.usbmodem11101` (업로드·모니터에 사용하지 않음) |
| ATmega32U4 / 5V / 16MHz | 사용자 제시 사양과 USB 정보가 부합하나 실물·전압·클록을 독립 확인하지 못함 |
| SparkFun AVR Boards | 기존 사용자 환경에는 없음. 임시 환경에만 1.1.13 설치 성공 |
| 컴파일 설정 | `SparkFun:avr:promicro:cpu=16MHzatmega32U4` |
| 핀 매핑 | 설치한 Pro Micro 변형의 SDA=2, SCL=3 확인 |
| 보드 단독 스케치 컴파일 | 성공: flash 3984/28672 bytes, RAM 151/2560 bytes |
| 센서 스케치 컴파일 | 성공: flash 11770/28672 bytes, RAM 441/2560 bytes |
| 업로드 | 미수행 |
| I²C 0x68 / 0x69 인식 | 미시험 |
| WHO_AM_I 확인 | 미시험 |
| 가속도·자이로 출력 | 미시험 |
| Roll / Pitch | 계산 코드 컴파일 성공, 실측 미시험 |
| 수평 / 좌우 / 앞뒤 / 노이즈 | 미시험 |

## 발생한 오류 및 처리

1. PATH에서 `arduino-cli`를 찾지 못했으나 IDE 내장 실행 파일을 찾아 사용했다. 새 CLI 프로그램은 설치하지 않았다.
2. 제한된 네트워크 환경의 첫 보드 목록 다운로드에서 DNS 오류가 발생했다.
   네트워크 접근을 허용받은 실행으로 공식 Arduino·SparkFun 목록을 내려받고 임시 패키지 설치에 성공했다.
3. 최초 센서 컴파일의 `WIRE_HAS_TIMEOUT` 검사 매크로가 설치된 Wire 헤더에 없어 실패했다.
   해당 헤더에서 실제 timeout 메서드가 제공됨을 확인하고 잘못된 매크로 조건을 제거했다.
   실제 메서드 호출은 유지했으며 재컴파일에 성공했다.
4. `--warnings all`에서 Arduino 코어 `new.cpp`의 사용하지 않는 `tag` 인수 경고 4개가 있었다.
   작성한 스케치 오류는 없으며 두 컴파일은 종료 코드 0으로 성공했다.

## 작업 범위

- 추가한 프로젝트 파일: `hardware/.gdignore`, 보드 단독·센서 스케치, README, 이 보고서.
- Godot 코드·장면·프로젝트 설정은 변경하지 않았다.
- 작업 시작 전부터 있던 Git 변경과 삭제 파일을 유지했다. 커밋과 푸시는 하지 않았다.
- 기존 `~/.arduinoIDE/arduino-cli.yaml`의 additional_urls는 그대로 빈 목록이며 초기화하지 않았다.
- 기존 Arduino AVR 1.8.8과 Wire 1.0을 참조했다. 센서 라이브러리는 설치하지 않았다.
- 임시 설정/패키지: `/var/folders/s3/qx92dvqx07d4dwl7r5_lpbyr0000gn/T/balance-lab-arduino-6ldq6hjg/`
- 컴파일 산출물: `/tmp/balance-lab-build-pro_micro_smoke/`, `/tmp/balance-lab-build-mpu6050_test/`

## 남은 실물 확인 및 다음 단계

1. 전원을 뺀 상태에서 센서 배선을 전부 분리하고, Pro Micro만 연결했음을 확인한다.
   보드 실물의 ATmega32U4 및 16MHz/5V 표기도 확인한다.
2. 포트를 다시 검색해 단독 스케치를 업로드하고 115200 baud에서 BOARD OK 출력을 확인한다.
3. 센서 모듈의 정확한 회로 자료 또는 검증된 I²C 레벨 시프터 구성으로 전압 안전을 확인한다.
4. 안전한 센서 배선 후 센서 스케치 업로드 → START → WHO_AM_I / 가속도 / 자이로 출력을 기록한다.
5. 정지 및 ±30도 자세 시험으로 각도 변화·복귀·노이즈·지연을 측정한다.
6. 이 시험을 통과한 다음 Godot 연동 방식(USB Serial 또는 USB HID)을 정하고,
   축 방향, 영점 보정, 필터, 데드존, 입력 범위, 연결 해제 처리를 구현한다.
   USB Serial을 택하면 명확한 프레임/타임스탬프가 있는 출력과 Godot 수신 계층이 필요하다.
   이번 작업에는 실제 게임 연동을 포함하지 않았다.
