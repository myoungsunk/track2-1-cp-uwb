# Range Bias 및 Stage3 증거력 개선 보고서 (2026-04-07)

## 1) 보고 목적
본 보고서는 아래 두 이슈에 대해 현재 코드 기준 개선 상태를 정리한다.

1. Stage1에서 모든 케이스의 range bias가 양수로 나타나는 문제
2. Stage3에서 MRR 단독으로는 인과 증거력이 약한 문제

기준 저장소/파이프라인: `track 2-1` (`track3-cp-uwb-reliability_tilted2rx_project_20260406`)

---

## 2) 코드 레벨 개선 사항

### 2.1 Stage1 first-path detector 개선

적용 파일:
- `src/extract_first_path.m`
- `src/setup_config.m`
- `src/stage1_ranging.m`

핵심 변경:
- 기존 단순 peak-ratio 기반 탐지에서 `noise-aware hybrid threshold`로 확장
- threshold 구성: peak-ratio, noise-sigma, floor를 조합
- first-threshold run + local peak after crossing 규칙 추가
- fallback 사용 여부/threshold/노이즈 통계 진단값(info) 출력
- 결과 지표에 `bias_m`, `rmse_debiased_m`(rx1/rx2 포함) 추가

요약: "편향을 줄이기 위한 탐지 로직" + "편향을 분리 보고하는 평가 체계"를 동시에 적용함.

### 2.2 Stage3 증거 체계 보강

적용 파일:
- `src/stage3_rejection.m`
- `src/sweep_fp_window_sensitivity.m`

핵심 변경:
- 기존 MRR(`10*log10(E_fp/E_total)`) 외에 `FP sharpness` 추가
  - 정의: FP peak 대비 background RMS contrast (dB)
- `fp_window_ns` 민감도 스윕 추가
  - window 크기에 따른 CP-LP 분리도(ΔMRR) 추적 가능

요약: MRR 단일지표에서 "MRR + sharpness + sensitivity" 다중 증거 구조로 확장.

---

## 3) 정량 결과 요약 (최신 `results/summary_table.csv` 기준)

### 3.1 Range bias / RMSE (평균, A/B/C 평균)

- CP bias 평균: `+0.1557 m`
- LP bias 평균: `+0.3930 m`
- CP RMSE: `0.3523 m` → debiased `0.3158 m`
- LP RMSE: `0.6923 m` → debiased `0.5688 m`

해석:
- 양의 bias는 여전히 존재함(완전 해소 아님).
- 다만 debiased RMSE를 별도 제공함으로써 detector bias와 propagation 효과를 분리 해석 가능해짐.
- "CP가 LP보다 우세"라는 방향성은 debias 후에도 유지됨.

### 3.2 Stage3 (5 ns 기준, 시나리오별 CP-LP 차이)

- ΔMRR (CP-LP)
  - A: `+0.9345 dB`
  - B: `+1.1944 dB`
  - C: `+0.1523 dB`

- ΔFP sharpness (CP-LP)
  - A: `+3.4899 dB`
  - B: `+4.2588 dB`
  - C: `+2.5119 dB`

해석:
- C 시나리오에서 MRR 격차가 작아 MRR 단독 인과 주장은 약함.
- 반면 FP sharpness는 세 시나리오 모두에서 비교적 안정적으로 CP 우세를 보임.

### 3.3 Stage3 window 민감도 (`fp_window_sensitivity_aggregate.csv`)

- ΔMRR 평균 (CP-LP)
  - `1 ns`: `+2.1772 dB`
  - `2 ns`: `+2.0672 dB`
  - `5 ns`: `+0.7281 dB`
  - `10 ns`: `-0.3345 dB`

- ΔSharpness 평균 (CP-LP): `+3.2937 dB` (window sweep에서 안정적)

해석:
- MRR는 window 정의에 민감하며, large window에서 분리력이 약화/역전될 수 있음.
- 따라서 Stage3 해석은 단일 window/단일 지표가 아닌 sensitivity 결과와 함께 제시해야 함.

---

## 4) 이슈별 개선 상태 평가

### 이슈 A: "모든 range bias 양수"

- 상태: `부분 개선`
- 개선된 점:
  - detector가 noise-aware로 강화됨
  - debiased RMSE 공식 출력으로 절대치 해석의 왜곡 완화
- 남은 한계:
  - 양의 bias 자체는 남아 있음
  - earliest weak path 대신 delayed dominant peak 선택 경향이 아직 존재

### 이슈 B: "Stage3 인과 증거 약함"

- 상태: `해석 가능성 개선`
- 개선된 점:
  - MRR + FP sharpness + window sensitivity로 증거 체계 강화
- 남은 한계:
  - MRR 단독으로 odd-bounce rejection을 강하게 입증하기는 여전히 어려움

---

## 5) 논문/보고용 권장 기술 방식

1. Range는 `RMSE + bias + debiased RMSE`를 함께 보고
2. Stage3는 `MRR 단독 주장` 대신 `MRR + FP sharpness + window sensitivity` 묶음으로 제시
3. MRR 음수는 이상치가 아니라 정의상 정상임을 명시
   - `MRR = 10*log10(E_fp/E_total)`
4. 결론 문구는 "CP 우세 방향은 일관되나, 절대 크기는 detector 및 window 정의에 민감"으로 보수적으로 기술

---

## 6) 최종 결론

현재 구현은 두 문제를 "완전 해결"한 단계는 아니지만,

- Stage1: 편향 원인을 숨기지 않고 정량 분리하는 체계로 고도화되었고,
- Stage3: 단일 지표 취약점을 다중 보조지표 체계로 보완했다.

따라서 리뷰 지적에 대해 "개선 조치가 코드/결과에 반영되었다"고 설명 가능한 상태다.
