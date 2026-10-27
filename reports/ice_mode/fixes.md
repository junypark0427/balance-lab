# ICE MODE 오류 수정·재검증

기록일: **2026-10-27, Asia/Seoul(KST)**. Godot 4.7.2 / Jolt / macOS Metal.

무인 QA에서는 오류를 기록만 했고, 이후 사용자의 별도 수정 요청에 따라 ICE 관련 **QA-001·QA-003**을 수정했습니다.
일반 모드의 기존 진단 겹침(QA-002), 센서 버튼 배치(QA-004), 콘솔 출력(QA-005)은 변경하지 않았습니다.

## 변경 내용

- [얼음 셰이더](../../shaders/ice_floor.gdshader): 실행 엔진이 지원하지 않는 `CLEARCOAT_GLOSS`를
  `CLEARCOAT_ROUGHNESS`로 변경했습니다. 광택 0.8에 대응하도록 거칠기 0.2를 사용합니다.
- [ICE 적용 스크립트](../../scripts/modes/ice_mode.gd): 나중에 추가하는 ICE Label을 HUD의 첫 자식으로 옮겨
  일시정지·성공 가림막 뒤에서 그려지도록 했습니다.
- [새 회귀 검사](../../tests/ice_mode_test.gd)와 Godot UID를 추가했습니다.
  실제 셰이더 픽셀, 네 맵의 표시 순서·일시정지·일반 모드 복귀를 확인합니다.
- [QA 문제 목록](../../docs/qa/ISSUES.md), [종합 보고서](../../docs/qa/QA_REPORT.md),
  [테스트 기록](../../docs/qa/TEST_LOG.md)에 후속 결과를 추가하고 최초 실패 기록은 보존했습니다.

공·플랫폼 마찰, 감쇠, Bounce, 최대 기울기, 미로·충돌체, 키보드·센서 입력과 로컬 컨트롤러 설정은 바꾸지 않았습니다.
작업 전 113개 기존 코드·리소스의 해시와 비교하여 변경된 기존 파일은 위 셰이더와 ICE 적용 스크립트 두 개뿐임을 확인했습니다.

## 검사 결과

| 검사 | 결과 |
| --- | --- |
| ICE 회귀 / headless | 24개 통과, 0개 실패. 렌더링 픽셀은 SKIP |
| ICE 회귀 / 실제 Metal | 25개 통과, 0개 실패. 실제 푸른 픽셀 확인 |
| 기존 ICE 설정·물리 검사 | 84개 통과, 0개 실패 |
| 네 레벨 일반/ICE 및 ICE pause 렌더링 | 셰이더 오류 없이 완료 |
| Godot 편집기 로드·가져오기 | Script/Shader/Resource 오류 없음 |

새 픽셀 검사는 실제 셰이더를 별도 SubViewport의 평면에 적용합니다.
중앙 픽셀은 `(0.451, 0.6784, 0.7804, 1.0)`로 이전 흰색 대체 표면과 구분됐습니다.
실제 LEVEL 01 화면에도 얼음 무늬·푸른 광택이 표시됩니다.
일시정지에서는 ICE 문구가 주변 HUD와 함께 어두워집니다.

기존 84개 단언에서 설정 저장·4개 맵 적용·충돌 형태 유지·키보드/정규화 입력·공 초기화·Goal fixture·재시작과
반대 기울기 제동을 확인했습니다. 별도 넓은 평면의 ICE 제동 실험은 약 2초에 방향이 반전됐습니다.
이 수치는 실제 미로의 전체 완주 시간이나 사람의 난이도 평가가 아닙니다.

## 화면과 실행 근거

- [수정 후 LEVEL 01](level01-fixed.png)
- [수정 후 LEVEL 04 일시정지](level04-paused-fixed.png)
- [headless 회귀](regression-headless.log), [Metal 회귀](regression-native.log)
- [설정·물리 검사](physics-settings.log), [렌더링](render-fixed.log), [프로젝트 로드](project-load.log)

프로젝트 폴더에서 Godot 실행 파일을 이용해 다음과 같이 재실행할 수 있습니다.

```sh
Godot --headless --path . --script tests/ice_mode_test.gd -- --sensor-port=6231 --sensor-command-port=6232
Godot --path . --script tests/ice_mode_test.gd -- --sensor-port=6233 --sensor-command-port=6234
```

실제 ESP32를 연결한 재시험, ICE의 네 맵 연속 완주, 사람의 체감 난이도, Windows 실행은 이번 수정에서 확인하지 않았습니다.
Git Commit/Push, Windows Export/EXE 제작은 하지 않았습니다. 실행 중인 게임은 중지 후 다시 시작해야 새 UI 순서가 적용됩니다.
