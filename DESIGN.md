# Design

## Source of truth
- Status: Active
- Last refreshed: 2026-09-27
- Primary product surfaces: macOS 메뉴 막대 팝오버, 목록 및 앱 설정 화면
- Evidence reviewed: `README.md`, `Sources/BarRemember/MenuBarContentView.swift`, `Sources/BarRemember/ReminderModels.swift`, `Sources/BarRemember/ReminderStore.swift`, 사용자가 제공한 리마인더 목록 스크린샷과 완료·복구·정렬·수정·목록 분리·사용자 정의 공간·공간 전환 UX 피드백, 2026-08-20 드롭다운 클릭 영역 스크린샷, 취소 시 메뉴 막대 앱이 종료되는 오류 제보, 목록 출처 문구 제거·새 항목 날짜 입력·기존 항목 날짜 수정·Apple 스타일 통일 요청, `CJ 지원서 마감 9/28`처럼 제목 끝 날짜를 자동으로 마감일로 지정해 달라는 요청, `docs/branding/logo-concept-v1.png`, 공개 배포와 한국어·영어 MVP 요구

## Brand
- Product name: `BarRemember`를 유지한다. 앱 설명에는 `Apple Reminders, one click away.`를 사용한다. `Bar Reminders`는 Apple의 제품명과 지나치게 가까우며 검색에서 구분력이 낮다. 상표 사용 가능 여부는 별도 법률 검토 대상이다.
- Personality: 가볍고 차분하며, 매일 열어도 부담 없는 생산성 도구. Apple Reminders보다 덜 복잡하고 더 가까운 동반자.
- Trust signals: 네이티브 macOS 동작, 로컬 EventKit 데이터, 계정·서버·분석 도구 없음, 명확한 선택 상태
- Avoid: 과도한 장식, 큰 설정 패널, 저대비 색상, 불필요한 네트워크 기능, Apple의 앱 아이콘·로고·브랜딩을 모사한 마크

## Product goals
- Goals: 메뉴 막대에서 사용자가 원하는 이름의 공간을 직접 추가해 Reminders 항목을 목적별로 분리하고, 각 공간에서 날짜를 포함해 확인·추가·수정·완료·복구한다. 첫 공개 버전은 한국어와 영어를 같은 수준으로 지원한다.
- Non-goals: Reminders 전체 기능 대체, 공간별 별도 클라우드 데이터베이스, 자유형 테마 편집기, 클라우드 계정 추가
- Success signals: 사용자가 공간 이름을 한 번만 클릭해 즉시 전환하고, 새 항목 제목 끝에 날짜를 입력하면 저장 전에 자동 감지 상태를 확인하며, 새 항목과 기존 항목에서 동일한 네이티브 날짜 UI로 날짜를 추가·변경·삭제한다. 취소는 현재 동작만 닫고 앱 종료는 별도의 명시적 확인 후에만 실행된다.

## Personas and jobs
- Primary personas: Apple Reminders를 쓰며 메뉴 막대에서 최소한의 조작을 원하는 Mac 사용자
- User jobs: 남은 항목 훑기, 지원 공고·공부·장보기 등 원하는 목적의 공간 만들기, 제목을 즉시 수정하기, 직접 줄 세우기, 완료 처리, 빠른 추가, 목록 배정과 아이콘 색상 설정
- Key contexts of use: 업무 중 짧게 메뉴 막대 팝오버를 열어 수초 안에 조작

## Information architecture
- Primary navigation: 메인 팝오버의 직접 선택 공간 탭과 `+` → 하단 `설정` → 공간 및 목록 배정 설정
- Core routes/screens: 선택한 사용자 정의 공간, 공간·목록 배정 및 앱 설정
- Content hierarchy: 오늘 요약 → 공간 전환·추가 → 빠른 추가 → 해당 공간의 항목 → 보조 동작; 설정에서는 공간 관리 → 목록 배정 → 아이콘 색상 → 앱 실행 옵션

## Design principles
- Principle 1: 자주 쓰는 작업은 메인 화면에, 드물게 바꾸는 개인화는 기존 설정 화면에 둔다.
- Principle 2: 색상만으로 선택을 알리지 않고 체크 표시, 테두리, 접근성 라벨을 함께 제공한다.
- Principle 3: 자주 발생하는 되돌릴 수 있는 작업에는 확인창을 띄우지 않고 짧은 실행 취소 기회를 제공한다.
- Principle 4: 완료와 순서 변경의 시작 영역을 분리하고, 드롭 위치를 색상 외 테두리로도 표시한다.
- Principle 5: 짧은 제목 수정은 현재 카드 안에서 끝내고 별도 모달이나 상세 화면을 열지 않는다.
- Principle 6: 하나의 Reminders 목록은 `숨김` 또는 한 사용자 정의 공간에만 배정하며 여러 공간에 중복 노출하지 않는다.
- Principle 7: 공간 추가는 앱 내부 분류만 만들고, Reminders 목록 생성은 빈 상태에서 사용자가 명시적으로 선택한다.
- Principle 8: 자주 쓰는 공간 전환은 메뉴를 한 번 더 열지 않고 한 번의 직접 클릭으로 끝낸다.
- Principle 9: 항목 카드는 사용자가 행동에 필요한 제목과 날짜만 보여주고 내부 Reminders 목록 이름은 숨긴다.
- Principle 10: `취소`와 `앱 종료`를 같은 시스템 취소 이벤트에 의존시키지 않는다. 종료는 팝오버 안에서 별도 확인 단계를 거친다.
- Principle 11: 제목·날짜 편집은 하나의 카드 안에서 함께 저장하거나 함께 취소해 부분 저장으로 인한 혼동을 막는다.
- Principle 12: 날짜 자동 감지는 제목 끝의 명확한 날짜 표현에만 적용해 일반 숫자를 날짜로 잘못 해석하지 않는다. 사용자가 날짜 컨트롤로 직접 고른 값은 자동 감지보다 우선한다.
- Principle 13: 앱의 시각적 계층은 macOS material, 시스템 서체, SF Symbols, 얇은 구분선으로 만들고, 할 일 카드의 큰 회색 면적과 장식적 효과를 늘리지 않는다.
- Principle 14: 로고는 메뉴 막대 16pt에서도 읽히는 하나의 인디고 완료 원 마크를 기반으로 하며, 목록의 의미는 앱 UI 안에서 보완한다. 복잡한 목록 카드·세부 묘사는 앱 아이콘에 넣지 않는다.
- Principle 15: 테마는 네 개의 검증된 프리셋만 제공한다. 투명 테마도 텍스트·선택 상태의 대비를 낮추지 않으며, 임의 색상 편집기처럼 설정 화면을 복잡하게 만들지 않는다.
- Tradeoffs: 공간 이름 변경은 BarRemember의 분류명만 바꾸며 연결된 Apple Reminders 목록 이름은 예기치 않게 변경하지 않는다.

## Visual language
- Color: 완료 원은 기본 인디고를 포함한 고대비 6색 프리셋. 전체 앱 테마는 네 가지다: `시스템`(기본 macOS material), `Glass`(투명한 팝오버 위에 색이 번지는 네이티브 popover material), `미드나이트`(반투명 네이비 글래스), `페이퍼`(따뜻하고 불투명한 표면). Glass는 투명한 팝오버 창, vibrant color field, `NSVisualEffectView(.popover, .withinWindow)` blur, 15% translucent white tint, 1px 하이라이트 테두리로 유리 깊이를 만들되 텍스트 대비를 우선한다. 각 프리셋은 밝은·어두운 모드 변형과 독립적인 텍스트·표면·강조색을 가진다.
- Typography: macOS 시스템 서체와 기존 headline/caption 위계를 유지한다.
- Spacing/layout rhythm: 4–16pt 기존 리듬, 설정 그룹 간 16pt 간격
- Shape/radius/elevation: 빠른 추가는 10pt 연속형 컨테이너, 항목은 배경색 카드 대신 넉넉한 행 간격과 1px 구분선 중심으로 구성한다. 색상 선택은 원형 스와치. 날짜 필드와 보조 버튼은 macOS 시스템 컨트롤 크기·모양을 유지한다.
- Motion: 행 제거와 실행 취소 배너는 짧은 기본 전환만 사용한다. 재정렬은 네이티브 드래그 미리보기와 짧은 위치 이동 애니메이션을 사용한다.
- Imagery/iconography: SF Symbols와 단색 원형 스와치. 날짜 추가·선택·삭제에는 `calendar.badge.plus`, `calendar`, `xmark.circle.fill`을 일관되게 사용하고, 입력에서 감지된 날짜에는 `wand.and.stars`를 사용한다. 공개 배포용 앱 아이콘은 독자적인 인디고 원형 체크 마크를 사용한다.

## Components
- Existing components to reuse: `ListSelectionView`, `ReminderRow`, `BarRememberPalette`, 공통 `OptionalReminderDateControl`
- New/changed components: 동적 `ReminderSection`, 큰 직접 선택 탭형 `ReminderSectionPicker`, 공통 네이티브 날짜 컨트롤을 가진 빠른 추가 카드와 인라인 편집 카드, 빠른 추가의 자동 날짜 감지 행, 종료 확인 푸터, 공간 추가 alert, 공간 관리 행, 동적 목록 배정 메뉴, `ThemePicker`, 선택 공간용 Reminders 목록 생성 빈 상태, 낮은 표면 대비의 목록 행과 macOS 구분선 기반 레이아웃, 한국어·영어 현지화 문자열
- Variants and states: 기본 공간/사용자 공간, 공간 추가·이름 변경·삭제 확인, 새 항목의 날짜 없음/자동 감지/수동 선택, 기존 항목의 날짜 없음/날짜 선택/날짜 변경/날짜 삭제, 종료 대기/종료 확인, 연결 목록 없음/빈 목록/항목 있음, 편집/저장 중/저장 실패
- Token/component ownership: 색상 토큰과 프리셋 모델은 `BarRememberPalette.swift`, 선택 UI는 `MenuBarContentView.swift`

## Accessibility
- Target standard: macOS HIG 기반, 인접 배경 대비와 비색상 선택 표시 확보
- Keyboard/focus behavior: 각 공간 탭과 `+`는 표준 버튼 탐색을 따르고, 공간 이름 입력은 Enter로 저장·Esc로 취소한다. 빠른 추가의 Enter는 제목 끝 날짜를 감지해 제목과 마감일을 함께 저장한다. 자동 감지 행을 누르면 같은 날짜를 수동 날짜 컨트롤로 전환해 수정할 수 있다. 기존 항목 편집의 Enter는 제목과 날짜를 함께 저장하고 Esc는 두 초안을 모두 취소한다. 공간을 바꾸면 진행 중인 빠른 입력·선택 날짜·인라인 편집을 정리한다. 취소 버튼은 상태만 정리하고 앱 종료 함수를 호출하지 않는다.
- Contrast/readability: 모든 프리셋은 회색 행 카드에서 기존 연한 하늘색보다 높은 대비를 갖도록 짙은 라이트 모드 색을 사용한다.
- Screen-reader semantics: 각 공간 이름과 항목 수, 공간 추가·이름 변경·삭제, 목록의 현재 배정 공간에 결과 중심 라벨을 제공
- Reduced motion and sensory considerations: 필수 정보를 애니메이션이나 색상 하나에만 의존하지 않는다.

## Responsive behavior
- Supported breakpoints/devices: macOS 14+, 고정 380×520 메뉴 막대 팝오버
- Layout adaptations: 380pt 폭에서 공간 탭은 최소 34pt 높이와 충분한 좌우 패딩을 가지며, 공간이 많으면 탭 영역만 가로 스크롤한다. `+`는 오른쪽에 고정한다.
- Touch/hover differences: 연필 버튼과 제목 더블클릭 모두 편집을 시작하며 각 보조 아이콘에 포인터 도움말을 제공한다.

## Interaction states
- Loading: EventKit에서 모든 공간에 배정된 목록의 합집합을 한 번 불러온 뒤 선택한 공간만 로컬 필터링한다.
- Empty: 선택 공간에 배정된 목록이 없으면 `이 이름으로 Reminders 목록 만들기`와 `기존 목록 연결`을 제시한다. 배정된 목록이 비어 있으면 빠른 입력을 안내한다.
- Error: 제목 또는 날짜 저장 실패 시 EventKit 상태를 다시 불러오고 편집을 유지하며 오류 메시지를 표시한다.
- Success: 새 공간은 즉시 선택된다. `M/D`, `M월 D일`, `YYYY-MM-DD`, `YYYY년 M월 D일`, `오늘`, `내일`, `모레`처럼 제목 끝에 쓴 날짜는 감지 행으로 미리 보이고, 저장 시 제목에서 제거되어 시간 없는 Reminders 마감일로 저장된다. 연도가 없는 이미 지난 날짜는 다음 해로 해석한다. 사용자가 직접 선택한 날짜는 자동 감지 날짜보다 우선한다. 변경된 기존 항목의 선택 날짜도 시간 없이 저장되며, 기존 날짜를 건드리지 않은 경우 기존 시간 정보도 보존한다. 목록 만들기 성공 시 같은 이름의 Reminders 목록을 만들고 자동 배정한다. 기존 선택 목록과 지원 공고 목록은 각각 기존 공간으로 마이그레이션한다.
- Cancel: 인라인 수정·날짜 선택·공간 관리·종료 확인의 취소는 해당 임시 상태만 초기화하고 앱이나 팝오버의 종료 경로를 실행하지 않는다.
- Disabled: 빈 제목과 저장 중에는 저장 버튼을 비활성화하고, 편집·저장 중에는 완료 및 드래그를 잠근다.
- Offline/slow network, if applicable: 네트워크와 무관

## Content voice
- Tone: 짧고 친근한 한국어와 간결한 영어. 두 언어 모두 기능명보다 행동 결과를 먼저 쓴다.
- Terminology: 사용자에게는 `공간`, `목록 연결`, `숨김`; 내부 구현에는 `ReminderSection`, `listSectionAssignments`, `activeAddListIDs`
- Microcopy rules: 편집 기능은 고정 설명문 대신 연필·체크·X 아이콘의 도움말과 명확한 접근성 라벨로 설명. 사용자 생성 공간명·할 일 제목은 번역하지 않는다.

## Implementation constraints
- Framework/styling system: SwiftUI, AppKit, EventKit; 새 의존성 금지. `Localizable.strings` 또는 동등한 Swift Package 호환 리소스로 `ko`와 `en`을 제공한다.
- Design-token constraints: 동적 `NSColor`를 통해 밝은·어두운 모드 쌍 제공
- Performance constraints: 메뉴 막대 앱 특성상 추가 서비스 없이 취소 가능한 단일 8초 `Task`와 작은 리마인더 ID 배열만 로컬 저장
- Compatibility constraints: macOS 14+, Swift 6.2
- Test/screenshot expectations: 공간 이름 정규화·중복 방지·추가·이름 변경·삭제, 목록 배정·기존 두 공간 마이그레이션, 날짜 미변경 시 기존 시간 보존·추가·변경·삭제 결정, 시간 없는 날짜 구성요소 저장, 지원 날짜 형식·윤년·잘못된 날짜·제목 중간 숫자·다음 해 이월·수동 날짜 우선, 목록 이름이 제거된 날짜 행, 종료 확인 푸터, 380pt에서 빠른 추가의 자동 날짜 감지·기존 항목 날짜 편집·직접 선택 탭 레이아웃을 검증

## Open questions
- [ ] Apple Reminders의 공개 EventKit API가 임의 수동 순서 동기화를 제공하면 BarRemember 로컬 순서와 iCloud 순서의 통합을 재검토한다.
- [ ] 독자 로고를 16pt 메뉴 막대, 32pt Dock, 128pt Finder, 밝은·어두운 배경에서 검증한 뒤 앱 아이콘으로 확정한다.
