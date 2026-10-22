BLOCKED

# 작업 C — 브랜치별 Web 미리보기 (2026-10-22)

요청한 구현과 로컬 검증은 완료했지만 **로컬 커밋 생성이 환경 권한으로 차단되었다**.
`git add -- .github/workflows/preview.yml docs/BUILD.md docs/WORK_SUMMARY_C.md`가
`.git/index.lock: Read-only file system`으로 실패했다. 이 작업실의 `.git`이 읽기 전용이다.
스테이징/커밋은 생성되지 않았다(**커밋 해시 없음**). 승인 요청이나 우회는 하지 않고 여기서 중단한다.
실제 Actions/Godot export/Pages 공개 실행은 **미검증**이다. 푸시와 저장소 설정 변경은 하지 않았다.
총괄은 Git 메타데이터 쓰기가 허용된 작업실에서 아래 세 파일을 검토하고 로컬 커밋한 뒤 푸시한다.
커밋 제목 예: `Add branch web preview deployment`, 본문 trailer: `Agent: codex`.

## 소스와 범위

- 작업 브랜치/인계 대상: `ci/preview-deploy-20261022`.
- 시작 소스: `b3570c650bd0fa285af94fd9136708b1df41bdc8` (v0.3.1).
- 변경 파일: `.github/workflows/preview.yml`, `docs/BUILD.md`, 이 문서뿐이다.
- `feat/**`, `ci/**` push와 해당 브랜치의 수동 실행만 허용한다. 워크플로가 각 브랜치에 있어야 동작한다.
- 기존 installer를 통해 Godot 4.7.2/templates를 설치하고 `build.py --platforms Web`을 호출한다.
  Web import/layout/PCK 감사/패키징은 재사용하며 다른 플랫폼 export와 브라우저 테스트는 호출하지 않는다.
- 액션 SHA/Python/cache는 기존 `ci.yml`과 같다. 기본 `GITHUB_TOKEN`에 `contents: write`,
  `pages: write`만 부여하고 새 비밀값·토큰·OIDC·유료 서비스를 추가하지 않는다.

## 배포 방식과 근거

1. `ci.yml`은 모든 빌드에서 Pages artifact를 만들지만 실제 `pages` job은
   `workflow_dispatch`와 `deploy=true`에만 동작한다. 이 사실만으로 현재 Pages 소스를 단정할 수 없다.
2. [ADR 0027](adr/0027-current-workshop-public-release.md),
   [BUILD의 기존 배포 설명](BUILD.md), [RELEASE_PLAN](RELEASE_PLAN.md),
   [v0.3.1 배포 기록](evidence/public_release_2026-10-11/README.md)은
   `gh-pages` 루트와 `.nojekyll`을 사용하는 배포를 명시한다. 위키 조회로 찾은 2026-09-30 공개 기록도 일치했다.
3. 호스트의 로컬 `origin/gh-pages`는 과거 `ae501c5`였지만, 연결된 GitHub 읽기 도구로 확인한 실제
   [원격 HEAD `2237cca84d8235e6d72f804bfeb08fa42cf6c564`](https://github.com/Bum-Boo/ssok/commit/2237cca84d8235e6d72f804bfeb08fa42cf6c564)는
   메인 사이트의 링크 미리보기 수정이다. 캐시된 로컬 ref를 배포 근거 전체로 취급하지 않았다.
4. 따라서 실행 때 최신 `gh-pages`를 별도로 checkout하고 `preview/<slug>/`만 교체·커밋한다.
   root의 `index.html`, `.nojekyll`, `deploy.json`, 그 외 root 파일과 다른 preview는 수정하지 않는다.
   Pages 설정 API가 `legacy` + `gh-pages` + `/`를 반환하는지 먼저 검사하고 불일치하면 파일/설정을 건드리지 않고 실패한다.
   현재 설정 자체의 인증된 API 조회는 로컬 `gh` 미로그인/네트워크 제한 때문에 미검증이다.
5. [GitHub 공식 문서](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)는
   `GITHUB_TOKEN` push만으로 Pages 빌드가 시작되지 않는다고 명시한다.
   따라서 commit 이후 [Pages build API](https://docs.github.com/en/rest/pages/pages#request-a-github-pages-build)를
   `POST`하고 해당 gh-pages commit의 `built` 상태를 최대 10분 기다린 뒤 요약에 링크를 출력한다.
   API 문서는 installation token과 Pages write 권한을 지원한다고 명시한다. 실제 워크플로 토큰의 성공은 푸시 후 확인한다.

## 보존과 재실행

- 모든 브랜치가 `ssok-preview-gh-pages` concurrency 그룹과 `cancel-in-progress: false`를 사용한다.
  GitHub concurrency는 pending 실행을 교체할 수 있으므로 누락된 브랜치는 최신 실행을 재실행한다.
- 슬러그는 소문자 변환 → `[a-z0-9]` 이외의 연속 문자를 `-`로 변환 → 양끝 `-` 제거 → 80자 제한 후,
  원래 브랜치명의 UTF-8 SHA-256 앞 12자리 hex를 붙인다. 대소문자·구분자 정규화 충돌을 줄인다.
- `rsync -a --checksum --delete`는 해당 preview 안의 이전 파일을 제거하며 숨김 파일도 복사한다.
  크기·수정 시각이 같아도 내용이 다른 파일을 갱신한다.
- source branch HEAD가 실행 SHA보다 새로워졌다면 오래된 실행은 배포를 생략한다.
  gh-pages push는 force하지 않는다. 별도 릴리스와 경합하면 안전하게 실패하며 최신 실행을 다시 수행한다.
- 브랜치 삭제 시 자동 정리는 이번 범위에서 생략했다. 향후 릴리스가 gh-pages 전체를 교체하면
  preview 보존 여부는 해당 릴리스 작업에 달려 있으며, 필요하면 브랜치 최신 실행을 다시 수행한다.

## 실제 로컬 검증

검증 환경은 이 원격 작업실의 WSL/Linux, Python 3.14, PyYAML 6.0.3이다. Windows native 검증으로 표현하지 않는다.

| 입력 브랜치 | 실제 실행한 workflow 식의 출력 |
|---|---|
| `feat/ui-onboarding-20261022` | `feat-ui-onboarding-20261022-8ffd3a5a7a2a` |
| `feat/parts-freedom-20261022` | `feat-parts-freedom-20261022-5f6ff5bd2013` |
| `ci/preview-deploy-20261022` | `ci-preview-deploy-20261022-c538728c9209` |

- `PYTHONDONTWRITEBYTECODE=1 python3 /tmp/ssok-preview-check.py`: 통과.
  임시 검증 도구가 실제 YAML의 `run` 블록을 추출하여 실행했다. `yaml.BaseLoader`로 YAML을 파싱하여
  YAML 1.1의 `on` → boolean 해석을 피했고, 모든 action 40자리 SHA·트리거·권한·concurrency·Web 전용 호출,
  `bash -n`과 내장 Python `compile`을 검사했다. 위 세 이름 외에 대소문자/구분자 충돌·한글·긴 이름까지 9개 실행했다.
- 같은 임시 검증 도구에서 `/tmp`의 bare Git remote와 사이트를 만들고 실제 commit/push로
  첫 배포·재배포·오래된/숨김 파일 삭제·동일 payload 재실행·구버전 실행 생략·root/다른 preview 보존을 확인했다.
  임시 remote와의 push만 실행했으며 프로젝트 원격에는 푸시하지 않았다.
- 같은 도구에서 concurrent release를 먼저 push하여 non-fast-forward 실패와 remote release 보존을 확인했다.
  Pages API는 mock으로 정상 source/잘못된 source 3종, build 요청, commit 일치 성공/오류/시간초과,
  summary URL을 확인했다. mock 결과를 실제 GitHub 배포 성공으로 취급하지 않는다.
- 최초 슬러그 검사 시 이 Linux 호스트에 `python` 별칭이 없어 실패했다. `/tmp`에 Python 3 실행 별칭을
  만들어 동일 블록을 재실행했다. Actions에서는 `setup-python`이 해당 명령을 제공한다.
  첫 재배포 검사는 rsync의 크기/mtime 판정 문제를 찾아 `--checksum`으로 수정 후 전체 통과했다.
- `PYTHONDONTWRITEBYTECODE=1 python3 tools/docs/maintain.py --check`: 통과.
- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/docs -p 'test_*.py'`: **10 tests / OK**.
- `git diff --check`: 통과. BUILD의 Preview deployment 절은 제목/공백을 포함해 10줄 이내다.

## 미검증과 푸시 후 확인

- 실제 Actions 실행, Godot 다운로드/export, 실토큰 Pages build 요청/완료, 공개 URL과 브라우저 플레이는 **미검증**이다.
  앱 코드/asset 변경이 없는 tooling 작업이므로 Godot import/scene-load/앱·UI·브라우저 검사는 로컬에서 실행하지 않았다.
- 총괄이 검토 후 이 변경을 대상 브랜치에 반영하고 푸시한다. Actions의 해당 브랜치 실행과 summary 링크를 확인한다.
  URL 규칙은 `https://bum-boo.github.io/ssok/preview/<branch-slug>/`다.
  작업 C의 확인 대상은 `https://bum-boo.github.io/ssok/preview/ci-preview-deploy-20261022-c538728c9209/`다.
  익명 접속으로 로딩/플레이를 확인하고 메인 `https://bum-boo.github.io/ssok/`의 root payload가 유지되는지 비교한다.
- 재실행: Actions → **Preview ssok on the web** → 최신 해당 브랜치 run → **Re-run all jobs**.
  default branch에 이 workflow가 포함된 이후에는 **Run workflow**에서 대상 브랜치를 고를 수도 있다.

## 문서·소유권·기록 인계

BUILD/RELEASE_PLAN/ADR 0001·0013·0017·0024·0027과 문서 갱신 규칙을 검토했다.
기존 엔진/릴리스/앱 구조·데이터·실행 계약을 바꾸지 않으므로 ADR/ARCHITECTURE/STATUS/도식은 유지했다.
UI 문구/번역 키 변경이 없어 네 언어 catalog 수정이나 localization 검사는 필요하지 않다. 새 과금은 없다.

읽기 전용 소유권 조회에서 총괄 `ssok/quality-loop-20261022`가 live이며 C 대기 기록을 확인했다.
별도의 preview issue/PR은 검색되지 않았다. 총괄 작업을 claim하지 않았고 이 사용자 지정 브랜치/범위만 수행했다.
이 문서가 작업 C의 명시적 checkpoint이며 검토 대상 브랜치는 `ci/preview-deploy-20261022`다.
현재 변경은 미커밋 상태여서 통합 준비 완료로 표시하지 않는다. 다음은 쓰기 가능한 Git 작업실에서 세 파일을 커밋하는 일이다.
공통 위키 중요작업 기록 절차도 검토했으나, 이번 요청은 허용한 세 파일 외 쓰기를 금지하므로
공유 Wiki/Work Log/arch/agent-task/Now는 갱신하지 않았다(**공유 기록 미완료**).
총괄이 이 문서를 근거로 공유 기록과 기존 소유권 checkpoint를 갱신하면 된다.
