# CHAT-070 접근성 검증 체크리스트

CHAT-070은 REL-001, REL-002, CHAT-053, CHAT-062에 의해 전체 완료가 차단되어 있다. 이 문서는 현재 저장소에서 실행 가능한 로컬 자동 검증과 실제 기기 수동 검증을 구분한다.

## 로컬 자동 검증 완료

- [x] 320/390/430dp × 글자 100/150/200% × light/dark 18개 조합에서 대화 목록 행, 메시지 실패·재시도, composer, 첨부 미리보기 진입 UI를 render smoke로 확인한다. 18개 조합은 18개 golden 증거가 아니다.
- [x] 320dp, 글자 200%, dark, 키보드 inset 280dp, 하단 safe area 16dp, 첨부 4개 조건에서 overflow 없이 입력과 action을 유지한다.
- [x] 위 통합 조건의 golden을 저장하고 재비교한다.
- [x] macOS와 Linux의 bundled font rasterization 차이를 각각 strict golden으로 비교한다. Linux baseline은 GitHub Actions run `39717160127`, head `9e2dfb822c6e6d4c0de3b2cc0ed3fb61a36965ab`, Ubuntu 24.04.5/Flutter 3.38.5에서 생성된 `testImage`를 시각 검토한 결과이며 SHA-256은 `8b8b9274f5c5e81a52e2adc289c3f6486ab312eede020977124023a9993f9e39`이다. 두 baseline 모두 동일한 번들 Nanum Gothic 및 Material Icons fixture를 사용한다.
- [x] 빈 대화에서 320dp, 글자 200%, 키보드, 좌·우·하단 safe area, 실패 첨부 5개 조건을 overflow 없이 처리한다.
- [x] 실패 첨부 제거 후 초점이 화면 FocusScope에 유실되지 않고 입력으로 이동하는지 확인한다.
- [x] 메시지 실패 상태를 한 개의 live semantics 상태로 노출하고 재시도 action을 별도 button node로 유지한다.
- [x] 첨부 queued/uploading/failed/ready 상태를 색상 외 icon과 text로 표시한다.
- [x] 첨부 상태를 한 개의 live semantics 상태로 노출하고 실패 첨부 제거를 별도 button node로 유지한다.
- [x] 업로드 byte 진행률이 연속 변경되어도 상태 semantics node와 label이 불필요하게 변경되지 않는지 구조적으로 확인한다.
- [x] 실패 첨부 제거와 메시지 보내기 조작 영역이 최소 44×44dp인지 확인한다.
- [x] 기존 목록·채팅 light/dark 및 text-scale golden 회귀를 실행한다.
- [x] PR #31 이후 추가된 dev-local PDF preview를 320/390/430dp × 글자 100/150/200% × light/dark 18개 조합에서 render smoke로 확인한다. 이 행렬은 golden 18개가 아니다.
- [x] 긴 한글 파일명의 PDF preview를 320dp, 글자 200%, safe area 조건에서 표시하고, 닫기 조작을 44×44dp 이상으로 유지한다.
- [x] 로컬 preview에서 서버 미업로드 상태와 image/PDF 확대·이동 힌트를 semantics로 구분한다.
- [x] 미리보기 실패를 text·error icon·단일 live-region으로 표시하고, 320dp·200% 글자에서 44dp 이상의 `다시 시도` 조작을 유지한다.
- [x] 열 수 있는 attachment chip은 상태 live-region과 분리된 `미리보기 열기` semantics hint를 제공하고, 제거 action은 별도 button node로 유지한다.

## 실제 기기 수동 검증 필요

- [ ] iOS 실제 기기에서 VoiceOver를 켜고 목록 → 대화 → 작성 → 실패 재시도 → 첨부 제거·미리보기 순서의 focus 이동과 낭독을 녹화한다.
- [ ] Android 실제 기기에서 TalkBack을 켜고 동일 시나리오의 focus 이동과 낭독을 녹화한다.
- [ ] 업로드 진행이 자주 바뀔 때 VoiceOver/TalkBack이 중복 또는 과도하게 낭독하지 않는지 청취한다.
- [ ] 실패 상태가 나타난 뒤 재시도 action으로 예측 가능하게 이동하고, 실행 후 focus가 유실되지 않는지 확인한다.
- [ ] 실제 소프트 키보드, 제스처 내비게이션 영역, 노치·홈 인디케이터에서 composer와 첨부 제거 action이 가려지지 않는지 확인한다.
- [ ] image/PDF 실제 renderer의 확대·스크롤·닫기 focus 순서를 확인한다.
- [ ] iOS Files picker와 Android document picker에서 선택·취소·재선택 후 focus가 attachment chip 또는 composer로 예측 가능하게 복귀하는지 확인한다.
- [ ] PDF의 현재 페이지, 확대·이동 가능 상태와 preview 닫기가 VoiceOver/TalkBack에서 중복 없이 낭독되는지 확인한다.
- [ ] iOS와 Android의 light/dark 고대비 설정에서 상태 label과 icon이 식별 가능한지 확인한다.

자동 widget/semantics/golden 테스트는 VoiceOver 또는 TalkBack의 실제 음성 출력, 플랫폼별 focus 이동, 실제 키보드·safe-area 동작을 대체하지 않는다. 양 플랫폼 영상과 수동 결과가 없으므로 CHAT-070 전체 완료 증거는 아직 충족되지 않았다.
