# Track 2-1 구현 진행 상세 정리

- 작성일: 2026-04-06
- 브랜치: `track-2-1`
- 최신 커밋: `60ab36f`
- 저장소: `track2-1-cp-uwb`

## 1) 작업 목표

6.5 GHz UWB 실내 시뮬레이션(HFSS SBR+) 데이터 기반으로, 단일 Anchor 환경에서 CP vs LP 성능을 아래 4단계 파이프라인으로 비교하도록 MATLAB 코드를 구현했다.

1. Stage 1: Ranging Error
2. Stage 2: DoA Error (RSSD 기반)
3. Stage 3: Multipath Rejection Ratio
4. Stage 4: 2D Positioning Error

## 2) 구현 타임라인 (커밋 기준)

### 2.1 초기 구조/파이프라인 구축
- `234101f`: baseline 초기화
- `c647839`: 레포 구조 정리 (`data/`, `src/`, `results/`, `PLAN.md`, `IMPLEMENT.md`)
- `9d58eae`: 입력 CSV를 `data/`로 이동
- `9fdc32e`: Track 2-1 전체 파이프라인 1차 구현

### 2.2 설계 반영/LoS-NLoS 연동/안정화
- `d6bea28`: 외부 LoS/NLoS 라벨(`LOS_NLOS_EXPORT_20260405`) 연동, DoA/positioning 파이프라인 안정화
- `b1e4105`: LP sign alignment, positioning gate 비활성화 상태에서 전체 실행

### 2.3 최신 개선
- `60ab36f`: 
  - Stage4를 단순 Cartesian 변환에서 **measurement-space fusion (WLS)** 로 확장
  - Stage1에서 rx1만 primary로 사용하면서 rx2 ranging 결과를 보조 저장
  - summary_table에 bias/P90/근사오차 지표 추가

## 3) 최종 파일 구성

### 3.1 핵심 소스 (`src/`)
- `main_track2_1.m`: 전체 실행 엔트리
- `setup_config.m`: 전역 파라미터/경로/모드 설정
- `load_case_data.m`: 케이스 CSV 로드 + GT(range/doa) 계산 + LoS mask 로드
- `compute_cir.m`: windowed IFFT로 CIR 생성
- `extract_first_path.m`: first-path 탐지 공용 함수
- `stage1_ranging.m`
- `stage2_doa.m`
- `stage3_rejection.m`
- `stage4_positioning.m`
- `compute_metrics.m`
- `plot_comparison.m`
- `generate_summary_table.m`

### 3.2 입력/출력
- 입력: `data/CP_case[A-C].csv`, `data/LP_case[A-C].csv`
- LoS/NLoS 라벨: `LOS_NLOS_EXPORT_20260405/*.csv`
- 출력: `results/*.fig`, `results/*.png`, `results/summary_table.csv`, `results/all_results.mat`

## 4) Stage별 구현 상세

## 4.1 Stage 1 (Ranging)

### 알고리즘
- `S21 -> window -> zero-padding -> IFFT -> |CIR|`
- first-path 탐지:
  - `d_axis >= fp_search_start_m` 구간에서
  - `threshold = fp_threshold_ratio * max(cir_mag)` 이상 + local peak 조건
  - 미탐지 시 global max fallback

### 거리 축 정의
- 현재 구현은 **one-way 축**: `d_axis = c * t`
- 즉, round-trip(`c*t/2`)이 아님
- 본 파이프라인의 single-sided ranging chain 가정과 일치

### rx1/rx2 처리
- primary metric은 `rx1` 기준 (`result.range_est_m`)
- 동시에 `rx2`도 계산/저장:
  - `result.range_est_rx2_m`, `error_rx2_m`, `rmse_rx2_m` 등
- 목적: primary는 유지하면서 보조 분석 가능

## 4.2 Stage 2 (DoA, RSSD)

### RSS 계산식
- broadband RSS는 power-domain 평균 사용:
- `RSS_dB = 10*log10(mean(|S21|^2))`

### LUT 구축
- external guide CSV 우선 사용
  - CP: `inc_ang_RSSD_validation_patch.csv`
  - LP: `step3_baseline_inc_ang.csv`
- guide 미존재 시(설정 허용 시) theory LUT fallback

### 부호 규약 적용
- LUT 보간 결과 `doa_est_raw_deg`에
- `doa_est_deg = sign_applied * doa_est_raw_deg`
- 현재 설정:
  - `cfg.doa.sign_correction.CP = -1`
  - `cfg.doa.sign_correction.LP = -1`

### 품질 진단
- `corr(doa_est, doa_gt)` 저장
- `validity_corr_threshold` 기반 경고/게이트 로직 지원

## 4.3 Stage 3 (Multipath Rejection)

- 지표: `MRR = 10*log10(E_fp / E_total)`
- `fp_window_ns`를 샘플 수로 변환해 first-path 이후 에너지 적분
- 민감도 확인 결과:
  - `5 ns`에서는 CP/LP 분리가 상대적으로 작음
  - `2 ns`로 줄이면 분리 증가 (해석 시 창 폭 영향 주의)

## 4.4 Stage 4 (Positioning)

### 기존
- 단순 변환: `(r, theta) -> (x, y)`

### 현재
- **measurement-space WLS** 적용
- Anchor 위치 `p_a=[x_a, y_a]^T`, boresight `psi_a`를 사용
- 측정 `z=[r_hat, theta_hat]^T`
- 목적함수:

\[
\hat p = \arg\min_p \frac{(\|p-p_a\|-\hat r)^2}{\sigma_r^2} + \frac{(\operatorname{wrap}(\operatorname{atan2}(y-y_a,x-x_a)-\psi_a-\hat\theta))^2}{\sigma_\theta^2}
\]

- Gauss-Newton 반복해 각 태그별 위치 추정
- 동시에 direct Cartesian 추정도 보조 저장 (`pos_est_cart_mm`)

### 분해 지표 추가
- `range_residual_m`, `angle_residual_deg`
- `Pos_P90_m`
- small-angle 근사:

\[
\epsilon_p^2 \approx \epsilon_r^2 + r^2\epsilon_\theta^2
\]

- `approx_pos_error_m`, `approx_pos_rmse_m` 저장

## 5) LoS/NLoS 분류 반영 방식

- `load_case_data.m`에서 external CSV 우선 사용
- 기본 클래스 필드: `geometric_class`
- Scenario B 카운트 이슈:
  - 과업 설명: 34/22
  - 외부 라벨(실제 사용): **35/21**
- 현재 코드는 입력 라벨 파일(geometric_class)을 신뢰해 35/21로 동작

## 6) 리뷰/디버깅에서 반영한 주요 수정

1. `extract_first_path`를 독립 파일로 분리
- Stage1 내부 서브함수 스코프 문제를 해소하여 Stage3에서도 재사용

2. RSS 계산식 일관화
- magnitude 평균식과 power 평균식 혼용 문제 해소
- Stage2/guide LUT 모두 power-domain으로 통일

3. DoA sign 이슈 추적
- sign 적용 위치를 LUT 보간 직후로 명확화
- CP/LP 모두 현재 `-1` 적용

4. LoS/NLoS 외부 라벨 연결
- `cfg.los_idx` 빈 값에 의존하지 않고 CSV 기반으로 마스크 생성

5. Stage4 확장
- WLS fusion + p90 + 분해지표 추가

## 7) 최종 결과 요약 (latest run)

`results/summary_table.csv` 기준:

- CP
  - A: Range RMSE 0.216 m, DoA RMSE 10.33 deg, Pos RMSE 0.441 m, Pos P90 0.611 m
  - B: Range RMSE 0.226 m, DoA RMSE 10.51 deg, Pos RMSE 0.473 m, Pos P90 0.819 m
  - C: Range RMSE 0.289 m, DoA RMSE 13.71 deg, Pos RMSE 0.747 m, Pos P90 1.004 m

- LP
  - A: Range RMSE 0.362 m, DoA RMSE 61.05 deg, Pos RMSE 3.100 m, Pos P90 4.981 m
  - B: Range RMSE 0.342 m, DoA RMSE 67.62 deg, Pos RMSE 3.656 m, Pos P90 5.850 m
  - C: Range RMSE 0.457 m, DoA RMSE 62.43 deg, Pos RMSE 3.354 m, Pos P90 5.519 m

핵심 해석:
- CP가 LP 대비 전 시나리오에서 위치추정 성능 우수
- 성능 차이의 지배 항은 Stage2(DoA) 오차 및 bias

## 8) 재현 방법

프로젝트 루트에서:

```powershell
matlab -batch "cd('src'); main_track2_1"
```

생성물:
- `results/summary_table.csv`
- `results/all_results.mat`
- `results/cdf_*.fig`, `results/cdf_*.png`

## 9) 현재 남은 리스크 / TODO

1. LP DoA 상관계수 저하
- LP guide 적용 상태에서도 corr가 매우 낮음
- 안테나 패턴/guide 생성 체인 재검증 필요

2. Scenario B 라벨 기준 정합
- 문서(34/22)와 외부 라벨(35/21) 불일치
- 분석 보고 시 기준 명시 필요

3. Stage3 창 폭 민감도
- `fp_window_ns` 변화에 따라 CP/LP 분리도 변화 큼
- 보고서에는 민감도 분석 결과 병기 권장
