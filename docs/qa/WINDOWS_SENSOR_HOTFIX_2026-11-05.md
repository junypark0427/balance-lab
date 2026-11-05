# Windows 센서 중계 종료 수정

기록일: **2026-11-05, Asia/Seoul**.

후속 사용자 확인: 갤럭시 북에서 패치 적용 후 **두 장치가 나타나고 정상 작동한다**는 답변을 받았습니다.
아래 구현·검사 본문은 해당 사용자 확인 전의 기록입니다. 이후 [BGM 포함 배포본](WINDOWS_RELEASE_2026-11-06.md)에도 같은 중계 수정을 포함했습니다.

## 확인된 증상과 원인

사용자가 갤럭시 북에서 기존 Windows ZIP을 풀고 `START_BALANCE_LAB.cmd`를 실행했습니다.
게임은 열리지만 F4에 장치 ID가 없었습니다. 장치 관리자에는 COM 장치가 **2개** 보인다고 확인했습니다.
사용자가 제공한 `bridge.log`는 첫 센서 상태 패킷(seq=0)을 출력한 다음,
`udp.recvfrom(4096)`에서 아래 오류로 종료된 기록입니다.

```text
ConnectionResetError: [WinError 10054]
```

실행기는 중계를 먼저 시작하고 0.6초 후 게임을 실행합니다. 그동안 게임의 UDP 수신 포트가
열려 있지 않을 수 있습니다. Windows는 이전 UDP 송신에 대한 ICMP Port Unreachable을
다음 수신 호출의 10054 오류로 알릴 수 있습니다.
기존 코드는 수신 큐가 비었을 때의 `BlockingIOError`만 처리했으므로 중계 프로세스가 종료됐습니다.
이는 사용자 로그의 실제 종료 원인입니다. COM 장치가 2개 있다는 것만으로 센서 측정까지
정상이라고 단정하지는 않지만, 이번 종료를 드라이버 설치 문제로 처리하지는 않았습니다.

근거: [Microsoft recvfrom 공식 문서](https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-recvfrom)의
UDP `WSAECONNRESET` 설명과 사용자 제공 로그, [실행기](../../tools/windows/launch.py)의 시작 순서.

## 수정 범위

- [bridge.py](../../hardware/bridge/bridge.py): 수신 경로에서 **`ConnectionResetError`이면서
  `winerror == 10054`인 경우만** 건너뛰고 다음 명령·센서 프레임을 처리합니다.
- 송신과 마지막 중립 패킷도 동일 오류가 전체 중계를 종료하지 않도록 처리합니다.
  해당 패킷을 보냈다고 주장하지 않고, 이후의 새로운 상태 패킷을 다시 보냅니다.
- 권한 오류·다른 통신 오류는 숨기지 않습니다. 64회 수신 상한, loopback 전용 주소,
  잘못된 JSON·크기 필터도 유지합니다.
- 로그 첫 줄에 수정 식별자 `UDP reset fix 2026-11-05`를 넣었습니다.
- 게임 EXE·Godot 소스·Scene·물리·펌웨어·컨트롤러 역할·축·방향·영점 데이터는 수정하지 않습니다.

## 실제 검증

[UDP 회귀 검사](../../hardware/bridge/test_udp_transport.py) 7개와 기존 중계 검사 15개,
**총 22개가 통과**했습니다.

1. 관찰된 Windows 10054 예외를 주입한 뒤 명령을 계속 수신.
2. 예외가 반복돼도 수신 상한에서 벗어나 센서 루프가 멈추지 않음.
3. 다른 수신 오류가 삼켜지지 않음.
4. 비로컬 주소·과대 패킷·잘못된 JSON 필터 유지.
5. 송신 중 10054 이후 다음 상태 패킷 송신 가능.
6. 다른 송신 오류가 삼켜지지 않음.
7. **실제 중계 main 루프와 실제 UDP 소켓**을 실행하고 첫 송신 후 Windows 예외를 주입.
   게임 수신 포트를 뒤늦게 연 뒤 모드 명령과 상태 패킷이 왕복하는지 검사.

```sh
hardware/.venv/bin/python -m unittest discover -s hardware/bridge -v
```

검사는 macOS에서 수행했습니다. Windows 예외는 주입했으며 USB 포트 목록은 비워 실제
하드웨어를 열지 않았습니다. **수정된 파일로 갤럭시 북 센서가 실제 인식됐다는 결과는 아직 없습니다.**
Windows 실제 사용자 확인과 자동 검사 결과를 구분합니다.

## 배포와 다음 확인

기존 검증된 ZIP의 게임 EXE·런타임·모델은 그대로 보존하고 센서 중계 파일과 안내·manifest만 갱신합니다.
전체 수정 ZIP과 기존 폴더에 덮어쓸 작은 패치를 제공합니다.
패치에는 `controllers.json`이나 `controllers.local.json`이 들어가지 않으며 사용자 설정을 초기화하지 않습니다.

게임·운영 콘솔을 모두 종료하고 패치를 적용한 뒤 `START_BALANCE_LAB.cmd`를 다시 실행하세요.
F4에서 두 장치 ID가 보이는지 확인하고, 중립 자세에서 C → INIT 완료 → F8 SENSOR로 진행합니다.
장치가 여전히 없으면 새 로그에서 수정 식별자와 이후 USB/센서 상태를 확인해야 합니다.
