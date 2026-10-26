# Tinkercad 미로 시제품

팀원이 Tinkercad에서 제작한 초기 미로 시제품과 실험용 3D 모델을 보관하는 폴더입니다.

- 크기, 구조, 충돌 등을 검토하기 위한 시제품을 보관합니다.
- 이 폴더의 모델은 실제 게임 Scene에 자동으로 연결되지 않습니다.
- 실제 게임에 사용할 완성된 모델은 추후 `assets/maps/`에서 별도로 관리합니다.

LEVEL 02는 현재 `2nd map/Grand Fulffy/tinker.obj`와 `obj.mtl`을 원본 위치에서 명시적으로 참조합니다.
원본을 이동하거나 `assets/maps/`로 복사하지 않습니다. 작업 폴더의 OBJ는 저장소의 `Grand Fulffy.zip` 안 OBJ와 동일합니다.
팀에 LEVEL 02를 공유할 때는 이 경로의 OBJ/MTL 및 Godot 가져오기 설정도 함께 포함해야 합니다.

이 README는 모델이 없는 상태에서도 Git에 폴더를 유지하기 위한 파일입니다.

LEVEL 03은 `3rd map/Amazing Densor-Uusam/tinker.obj`와 같은 폴더의 `obj.mtl`을 명시적으로 참조합니다.
실제 파일 이름은 `tinker(1).obj`가 아니라 `tinker.obj`입니다. 원본은 이동·복사·수정하지 않습니다.
통과구와 곡면을 보존하는 충돌 구성을 별도 맵 Script에서 관리합니다.

LEVEL 04의 GitHub 원본은 `Grand Duup.zip`(커밋 `381252f`)입니다. 압축에는 상위 폴더 없이
`tinker.obj`와 `obj.mtl`이 들어 있으므로 실행에 필요한 파일을 이 README와 같은 폴더에서 참조합니다.
`tinker(3).obj`/`obj(2).mtl`이 아니라 위 이름이며, OBJ의 `mtllib obj.mtl`과 일치합니다.
원본 ZIP·OBJ·MTL의 내용은 수정하지 않았으며 LEVEL 02·03 경로와 별개입니다.
