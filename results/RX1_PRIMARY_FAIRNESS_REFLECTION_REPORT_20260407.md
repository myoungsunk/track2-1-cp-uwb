# RX1-Primary Fairness 반영 보고서 (2026-04-07)

## 1) 반영은 이렇게 진행됨

### 1.1 Stage1 반영
- 기존 `rx1` primary만 사용하던 구조를 확장하여 `rx2`를 동시 계산/저장
- 추가 출력 지표:
  - `rmse_rx2_m`
  - `rmse_best2_m`
  - `best_port_share_rx2`
- 구현 파일:
  - `src/stage1_ranging.m`

### 1.2 Stage4 반영
- 위치추정 목적함수를 `r_rx1 + r_rx2 + theta` 동시 사용 형태로 변경
- 목적함수:
  - `(||p-pa||-r1)^2/sigma_r1^2 + (||p-pa||-r2)^2/sigma_r2^2 + (atan2-psi_a-theta)^2/sigma_theta^2`
- 구현 파일:
  - `src/stage4_positioning.m`

### 1.3 요약 테이블 반영
- 요약표에 per-port/fairness 해석용 컬럼 추가
  - `Ranging_RMSE_Rx2_m`
  - `Ranging_RMSE_Debiased_Rx2_m`
- 구현 파일:
  - `src/generate_summary_table.m`

---

## 2) 실제 효과 (최신 `results/all_results.mat` 기준)

### 2.1 Range (Stage1) 포트별 성능

- CP: `rx1`이 더 좋음
  - rx1 RMSE (A/B/C): `0.330 / 0.329 / 0.397 m`
  - rx2 RMSE (A/B/C): `0.532 / 0.364 / 0.554 m`

- LP: `rx2`가 더 좋음
  - rx1 RMSE (A/B/C): `0.697 / 0.667 / 0.713 m`
  - rx2 RMSE (A/B/C): `0.457 / 0.525 / 0.571 m`

- LP에서 `best_port_share_rx2`:
  - A/B/C = `0.571 / 0.554 / 0.482`

해석:
- "rx1 고정"은 LP에 불리하다는 점이 데이터로 확인됨.

---

## 3) Stage4 fairness 완화 효과 (동일 데이터 비교)

비교 기준:
- `dual-range WLS` (r1+r2+theta 사용)
- `rx1-primary direct` (기존 단순 변환)

### 3.1 LP DoA = affine
- dual-range WLS Pos RMSE (A/B/C): `0.962 / 0.986 / 1.330 m`
- rx1-primary direct Pos RMSE (A/B/C): `1.125 / 1.108 / 1.415 m`
- 개선량 (direct - dual): `0.162 / 0.122 / 0.085 m`
- 평균 개선: `~0.123 m`

### 3.2 LP DoA = branch_aware
- dual-range WLS Pos RMSE (A/B/C): `2.180 / 2.457 / 3.200 m`
- rx1-primary direct Pos RMSE (A/B/C): `2.252 / 2.468 / 3.239 m`
- 개선량 (direct - dual): `0.072 / 0.011 / 0.039 m`
- 평균 개선: `~0.041 m`

### 3.3 CP (참고)
- dual-range WLS vs rx1-primary direct 개선폭: 평균 `~0.011 m`

해석:
- LP에서 dual-range 반영 이득이 CP보다 확실히 큼.
- 특히 LP=affine 조건에서 fairness 완화 효과가 가장 크게 나타남.

---

## 4) 결론

1. 지적된 `rx1-primary fairness issue`는 코드에 반영됨.
2. Stage1에서 per-port/best-of-two 분석이 가능해져 편향을 명시적으로 평가 가능.
3. Stage4에서 dual-range WLS 적용으로 LP 위치오차가 실제로 감소함.
4. 다만 Stage1 대표값(`rmse_m`)은 여전히 rx1 기준이므로, 논문 본문/표에서는 `rx2`/`best2`를 반드시 병기하는 것이 타당함.

---

## 5) 논문 문장 예시 (그대로 사용 가능)

"To address the potential fairness issue of fixing RX1 as the primary ranging channel, we extended Stage 1 to report per-port and best-of-two ranging metrics, and updated Stage 4 to fuse RX1 and RX2 ranges jointly with DoA in a measurement-space WLS objective. The impact is minor for CP but significant for LP, confirming that RX1-only evaluation can systematically disadvantage the LP configuration."
