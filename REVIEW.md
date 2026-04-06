# DESIGN.md 검토 보고서

**검토 대상**: `DESIGN.md` (commit 304747b)  
**검토 기준**: 원본 요청 명세 + 실제 CSV 데이터 검증 결과  
**검토일**: 2026-04-06

---

## 요약

| 등급 | 건수 | 영향 |
|------|------|------|
| Critical | 2 | 실행 결과 오류 / DoA 추정 불가 |
| High | 2 | 코드 에러 / 수치 불일치 |
| Medium | 3 | 중복 구현 / 명세 누락 |
| Low | 2 | 가독성 / 완성도 |

---

## Critical 이슈

### C1 — RSSD LUT 범위 설정 오류 (§5.5, §7.6)

**문제**  
`cfg.doa_range_deg = [-90, 90]`으로 LUT를 생성하면 sin² 모델이 **단조 함수(monotone)가 아닌 구간**을 포함한다.

sin² 패턴 기반 RSSD:
```
RSSD(φ) = 10·log₁₀( sin²(φ − θ_tilt) / sin²(φ + θ_tilt) )
```
이 함수는 φ = ±θ_tilt 에서 G₁ 또는 G₂ = 0 이 되어 ±∞로 발산하고,
φ ∈ (−θ_tilt, +θ_tilt) 구간을 경계로 비단조 영역이 생긴다.

**실측 검증** (θ_tilt = 45°):
- LUT가 단조 감소하는 구간: φ ∈ (−44.9°, +44.9°)
- LUT 전체 범위 [-90°, +90°]로 build하면 RSSD가 다중값(multi-valued) → `interp1`이 잘못된 DoA를 반환함

**영향**  
- `cfg.doa_range_deg = [-90, 90]`을 그대로 구현하면 LUT의 절반 이상이 비단조 → DoA 추정 전체가 오염
- 실제 데이터에서 |DoA| > 45° 인 태그: **6개/56개**  
  `(750,−1750)`, `(750,−1250)`, `(1500,−1750)`, `(750,1250)`, `(750,1750)`, `(1500,1750)`  
  이들은 LUT 단조 범위 밖에 위치 → 외삽(extrapolation)으로 처리됨

**수정 지시**  
```matlab
% 기존 (오류)
% cfg.doa_range_deg = [-90, 90];

% 수정
cfg.doa_range_deg = [-(90 - cfg.theta_tilt_deg), (90 - cfg.theta_tilt_deg)];
% = [-45, 45] when theta_tilt_deg = 45
```
`build_rssd_lut()` 알고리즘 설명에 다음 문장 추가:
> "LUT는 monotone DECREASING이다. MATLAB interp1은 단조 감소 x를 지원하므로 flip 불필요. 단, LUT 범위는 반드시 `cfg.doa_range_deg`로 제한할 것."

---

### C2 — LoS/NLoS 인덱스 미정의 → Scenario B·C 분석 불가 (§2, §5.1)

**문제**  
```matlab
cfg.los_idx.B = [];   % TODO
cfg.los_idx.C = [];   % TODO
```
이 상태로 구현하면 `data.is_los` = all-false(B) 또는 상태 불명(C).  
모든 stage의 `rmse_los_*`, `rmse_nlos_*`, `mean_los_dB`, `mean_nlos_dB` 계산이 NaN 또는 에러.  
결과적으로 시나리오 B·C의 CP vs LP 비교 분석(전체 목적의 2/3)이 의미 없어짐.

**현황**  
이 정보는 HFSS 시뮬레이션 메타데이터에서 가져와야 하며, CSV 파일에 내재되어 있지 않음.  
데이터 제공자(연구자)가 LoS 태그 인덱스를 직접 입력해야 한다.

**수정 지시**  
DESIGN.md §2에 별도 박스 추가:

> ⚠️ **필수 입력 항목 (Implementer Action Required)**  
> `cfg.los_idx.B` 와 `cfg.los_idx.C` 는 HFSS 시뮬레이션 로그 또는 장애물 배치도에서  
> 확인한 후 `setup_config.m`에 직접 채워야 한다.  
> 태그 인덱스는 CSV에서의 위치 순서(1-based, X 오름차순 → Y 오름차순) 기준.  
> 채우기 전까지 B·C 시나리오의 LoS/NLoS 분리 지표는 모두 NaN으로 출력됨.

---

## High 이슈

### H1 — `extract_first_path_range` 스코프 충돌 (§5.4, §5.6)

**문제**  
DESIGN §5.4에서 `extract_first_path_range`를 `stage1_ranging.m`의 **내부 서브함수(sub-function)**로 설계:
```matlab
% stage1_ranging.m 하단에 private sub-function으로 정의
function d_fp = extract_first_path_range(cir_mag, d_axis, cfg)
  ...
```
MATLAB에서 .m 파일 내 sub-function은 **해당 파일 외부에서 호출 불가**.

§5.6 `stage3_rejection.m` 알고리즘:
> "Find first-path index: fp_idx via **same logic as stage1 extract_first_path**"

→ `stage3_rejection.m`에서 `stage1_ranging.m`의 서브함수를 직접 호출할 수 없음 → 런타임 에러.

**수정 지시**  
`extract_first_path_range`를 독립 파일로 분리:
```
src/extract_first_path.m    % stage1과 stage3가 공통 호출
```
파일 구조(§3)에 추가하고, stage1/stage3 알고리즘 설명에서 해당 파일 호출로 수정.

---

### H2 — RSS 계산 수식 비일관성: 진폭 평균 vs 전력 평균 (§5.5, §7.5)

**문제**  
설계 §7.5의 RSS 계산:
```matlab
rss1_dB = 20 * log10( mean(abs(S21_rx1(i,:))) )   % ← 진폭 평균
```
RSSD LUT는 전력 이득 비율로 구성:
```matlab
rssd_lut = 10 * log10(G1 ./ G2)    % G = sin² : 전력
```
`10·log₁₀(power ratio) = 20·log₁₀(amplitude ratio)`는 **단일 주파수에서만** 동일.  
주파수 다중 샘플에 대해 평균을 취하면 다음과 같이 달라진다:

```
20·log10(mean(|S21|))  ≠  10·log10(mean(|S21|²))
```

**실측 검증** (CP_caseA, 56개 태그):
- 두 수식 간 RSS 차이: 평균 **0.26 dB**, 최대 **0.94 dB**
- RSSD 오차로 전환 시 최대 ~1.9 dB 차이 → DoA 추정 오차 유발

**수정 지시**  
§7.5 수식을 전력 평균 방식으로 변경:
```matlab
% 수정
rss1_dB = 10 * log10( mean(abs(data.S21_rx1(i,:)).^2) )
rss2_dB = 10 * log10( mean(abs(data.S21_rx2(i,:)).^2) )
```
§5.5 알고리즘 설명도 동일하게 수정.

---

## Medium 이슈

### M1 — `compute_metrics.m` 미사용: 코드 중복 발생 (§5.4–5.7 vs §5.8)

**문제**  
stage1~4 각 함수의 알고리즘 설명에 RMSE/CDF 계산 로직이 인라인으로 기술되어 있음.  
동시에 `compute_metrics.m`을 공통 유틸로 설계함.  
IMPLEMENT.md 규칙: *"하드코딩 금지, 중복 금지"* — 그러나 각 stage가 독자적으로 RMSE를 계산하면 동일 로직이 4번 중복됨.

**수정 지시**  
각 stage 알고리즘 설명 마지막에 다음 줄 추가:
```matlab
% 5. m = compute_metrics(abs_error_vec, data.is_los)
%    result.rmse_m      = m.rmse;
%    result.rmse_los_m  = m.rmse_los;
%    result.rmse_nlos_m = m.rmse_nlos;
%    result.cdf_x       = m.cdf_x;
%    result.cdf_y       = m.cdf_y;
```
stage1/2 의 `rmse_m`, `cdf_*` 계산을 `compute_metrics.m` 위임으로 교체.

---

### M2 — `cdf_x / cdf_y` 필드의 소스 데이터 미명시 (§5.4, §5.9)

**문제**  
stage1 결과에 `error_m`(부호 있음)과 `abs_error_m`(절댓값) 두 필드가 있는데,  
`cdf_x / cdf_y`가 어느 것 기반인지 명시되지 않음.  
`plot_comparison`은 `abs_error_m`을 직접 사용하므로 `cdf_x/cdf_y` 필드가 중복·불일치 위험 있음.

**수정 지시**  
§5.4에 다음 주석 추가:
```
%   result.cdf_x  : abs_error_m 기반 (= m.cdf_x from compute_metrics(abs_error_m, ...))
%   result.cdf_y  : 동일 기반
```
Stage 2: `abs_error_deg`, Stage 3: `ratio_dB`, Stage 4: `error_m` 으로 명시.

---

### M3 — `fp_window_ns` 변환 수식 복잡 (§5.6)

**문제**  
```matlab
T_win_samples = round(cfg.fp_window_ns * 1e-9 / (1/(cfg.N_fft*cfg.delta_f)))
```
수식이 분수의 역수라 가독성 낮음.

**수정 지시**  
동일한 의미의 단순한 형태로 교체:
```matlab
T_win_samples = round(cfg.fp_window_ns * 1e-9 * cfg.N_fft * cfg.delta_f)
% = round(5e-9 * 16384 * 1e6) = 82 samples
```

---

## Low 이슈

### L1 — §3과 §4 사이 구분선 누락

§3 코드 블록 종료 후 `---` 구분선 없이 §4가 시작됨.  
렌더링 시 섹션 구분이 불명확. `---` 한 줄 삽입.

---

### L2 — Summary Table에 LoS/NLoS 서브지표 부재

**현황**  
`summary_table.csv` 컬럼: `Ranging_RMSE_m`, `DoA_RMSE_deg`, `MRR_mean_dB`, `Pos_RMSE_m`, `Pos_CEP67_m`, `Pos_CEP95_m`  
LoS/NLoS 분리 RMSE가 없음.

**권고**  
Scenario B·C 분석에서 CP의 NLoS 성능 우위가 핵심 가설임.  
다음 컬럼 추가 고려:
```
Pos_RMSE_LoS_m | Pos_RMSE_NLoS_m | MRR_mean_LoS_dB | MRR_mean_NLoS_dB
```

---

## 확인된 정상 항목

| 항목 | 검증 결과 |
|------|-----------|
| CSV 컬럼 순서·헤더 | 완전 일치 (실제 파일 검증) |
| 태그 수 56개 · 7×8 그리드 | 완전 일치 |
| 주파수 축 6.24–6.74 GHz, 501점 | 완전 일치 |
| 행 정렬: 위치 우선, 주파수 오름차순 | 검증됨 |
| CIR 범위 축 최대 300m (N_fft=16384) | 태그 최대거리 5.53m 충분히 커버 |
| fp_search_start_m = 0.3m | 최소 GT 거리 0.79m > 0.3m ✓ |
| IFFT → 절대 ToA 수식 | S21(f) IFFT의 피크 위치가 실제 전파지연 τ와 정확히 대응됨 ✓ |
| MATLAB interp1 단조감소 지원 | MATLAB 지원 확인 (flip 불필요) ✓ |
| 파일 구조 11개 .m 파일 | IMPLEMENT.md 요구사항 충족 |

---

## 조치 우선순위

| 우선순위 | 이슈 | 수정 위치 |
|---------|------|-----------|
| 즉시 | C1 — LUT 범위 수정 | §5.1 cfg, §5.5 helper, §7.6 수식 |
| 즉시 | C2 — LoS 인덱스 경고 강화 | §2 주의사항 박스 |
| 구현 전 | H1 — extract_first_path 독립 파일화 | §3 파일구조, §5.4, §5.6 |
| 구현 전 | H2 — RSS 수식 전력 평균으로 교체 | §5.5, §7.5 |
| 구현 중 | M1 — compute_metrics 호출 명시 | §5.4–5.7 |
| 구현 중 | M2 — cdf_x/cdf_y 소스 명시 | §5.4–5.7 |
| 선택 | M3, L1, L2 | 해당 섹션 |
