# Affine 기반 RSSD→DoA 변환 유효성 평가 보고서 (2026-04-07)

## 1) 목적
본 보고서는 다음 질문에 답하기 위해 작성하였다.

- "Affine(1차식) 적용이 기존 RSSD 가이드를 임의로 왜곡하는가?"
- "LP에서 affine 적용 결과를 물리적으로 타당한 모델로 볼 수 있는가?"

평가 기준은 `track 2-1` 파이프라인의 Stage 2(DoA) 구현이며, 코드 기준점은 아래 파일이다.

- `src/setup_config.m`
- `src/stage2_doa.m`

---

## 2) 현재 구현에서 affine의 정확한 의미

현재 affine은 아래 형태의 **역변환 보정식**이다.

- `angle = a * RSSD + b`

이때 계수 `(a, b)`는 외부 guide CSV의 `(RSSD, inc_ang)` 데이터에 대해 최소자승 1차 회귀로 계산된다.
즉, "아무 이유 없는 임의 변경"은 아니고, **guide를 전역 1차 근사한 캘리브레이션**이다.

다만, guide 곡선이 비단조/비선형이면 전역 1차 근사는 구조적으로 정보 손실을 만든다.

---

## 3) 평가 방법

### 3.1 Guide 선형성 검증
각 guide에 대해 다음을 계산:

- 선형 적합식: `inc_ang = a*RSSD + b`
- `corr`, `R^2`, RMSE/MAE/Max|err| (deg)
- 곡선 비단조 지표: slope sign-change count

### 3.2 시뮬레이션 성능 비교
동일 데이터에서 Stage2 inverse mode만 바꿔 비교:

- `branch_aware` vs `affine`
- 시나리오 A/B/C DoA RMSE
- Corr(DoA, GT), Corr(RSSD, GT)

---

## 4) 정량 결과

### 4.1 Guide 선형성

| Guide | a | b | corr | R^2 | RMSE (deg) | MAE (deg) | Max|err| (deg) | slope sign-change |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| CP (`inc_ang_RSSD_validation_patch.csv`) | -3.2933 | -0.4808 | -0.9962 | 0.9924 | 4.549 | 4.011 | 9.467 | 0 |
| LP (`step3_baseline_inc_ang.csv`) | -4.6871 | 3.3774 | -0.7422 | 0.5509 | 35.015 | 27.438 | 96.829 | 1 |
| LP (`step3_baseline_inc_ang_height=1m_23R1.csv`) | -10.1072 | -4.9467 | -0.6167 | 0.3803 | 41.356 | 32.154 | 108.701 | 3 |

해석:

- CP guide는 거의 선형(고R^2, sign-change 0)이라 affine 근사가 타당.
- LP guide는 강한 비선형/비단조(sign-change 1~3)라 전역 affine 근사 타당성이 낮음.

### 4.2 시뮬레이션 DoA 성능 (기본 LP guide: `step3_baseline_inc_ang.csv`)

#### CP
- branch_aware RMSE(A/B/C): `10.331 / 10.515 / 13.712` (mean `11.519`)
- affine RMSE(A/B/C): `9.178 / 9.537 / 12.720` (mean `10.478`)

#### LP
- branch_aware RMSE(A/B/C): `34.774 / 39.574 / 47.356` (mean `40.568`)
- affine RMSE(A/B/C): `17.180 / 17.321 / 22.280` (mean `18.927`)

해석:

- LP에서 affine이 수치상 크게 개선되지만, 이는 "물리 가이드 정확 복원"이 아니라
  **불안정한 비단조 역변환을 1차식으로 regularize한 효과**로 보는 것이 타당.

### 4.3 시뮬레이션 DoA 성능 (LP 23R1 guide 강제: `height=1m_23R1`)

#### LP only
- branch_aware RMSE(A/B/C): `28.121 / 27.194 / 35.108` (mean `30.141`)
- affine RMSE(A/B/C): `26.485 / 25.961 / 35.338` (mean `29.262`)

해석:

- LP 23R1에서는 affine 이득이 평균 `~0.88 deg`로 작다.
- 즉 affine의 효용이 guide 형태/조건에 따라 크게 달라져 일반 모델로 채택하기 어렵다.

### 4.4 LP 상관 저하의 직접 원인 해석 (raw RSSD vs inversion 결과)

LP의 핵심 이상점은 "측정이 완전히 무의미"한 것이 아니라, **inversion 단계에서 정보가 소실**된다는 점이다.

- raw `RSSD`와 `GT angle`의 상관 (A/B/C): `0.815 / 0.814 / 0.617`
- 최종 `DoA_est`와 `GT angle`의 상관 (A/B/C): `0.537 / 0.445 / 0.348` (기존 branch/LUT 체인)

이 패턴은 다음 원인과 정합적이다.

1. 실내 다중경로로 실제 RSSD-각도 관계가 baseline guide와 달라짐
2. 그 상태에서 단일 guide LUT 역변환을 적용하면 mismatch가 누적됨
3. 결과적으로 raw 측정에 남아 있던 angle 정보가 DoA_est 단계에서 약화됨

즉, LP 열화의 주원인은 "LP 물리 측정 자체 붕괴"보다는 **다중경로 유도 guide mismatch + inversion 구조 한계**로 해석하는 것이 타당하다.

---

## 5) 유효성 결론

### 5.1 기술적 결론

1. affine은 "무근거 변형"이 아니라 1차 캘리브레이션이다.
2. LP의 성능 저하는 raw RSSD 정보 부족보다는, 다중경로로 인한 guide mismatch와 inversion 단계 정보 손실 영향이 크다.
3. LP guide가 비단조/비선형이므로, 전역 affine을 **물리 모델**로 채택하는 것은 부적절하다.
4. 현재 LP에서 affine이 좋아 보이는 구간은 역변환 안정화 휴리스틱 효과가 크며, 물리적 해석력은 제한적이다.

### 5.2 보고/논문용 권고 문구

- LP 결과의 본선 모델은 `branch_aware`(또는 향후 piecewise/branch-conditioned LUT)로 유지.
- `affine`는 "sanity/ablation baseline"으로만 제시.
- 본문에는 "LP guide의 비단조성으로 인해 전역 1차식은 정보 손실을 유발"한다고 명시.

---

## 6) 즉시 적용 가능한 코드 운영 권고

1. `cfg.doa.inverse_mode_by_pol.LP` 기본값을 `branch_aware`로 두고,
2. `affine` 결과는 `doa_est_affine_deg` 보조 지표로만 리포트,
3. LP는 추후 `piecewise affine` 또는 `multi-branch inverse`로 확장.

---

## 7) 최종 한 줄 결론

**LP에 대한 전역 affine은 물리 가이드 대체 모델로는 유효하지 않고, 역변환 안정화용 보조 베이스라인으로만 제한적으로 유효하다.**
