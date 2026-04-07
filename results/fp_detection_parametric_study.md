# First-Path Detection Parametric Study (Re-run with updated data)

## Scope
- Parameters:
  - `fp_threshold_ratio`
  - `fp_search_start_m`
- Objective:
  - Reduce positive ranging bias (late first-path pick)
  - Check trade-off with RMSE/MAE/P90

## Baseline
- `fp_threshold_ratio = 0.10`
- `fp_search_start_m = 0.30`

Aggregate over 6 cases (CP/LP x A/B/C):
- Mean RMSE: `0.4451 m`
- Mean Bias: `+0.3330 m`
- Mean MAE: `0.3404 m`
- Mean P90(|error|): `0.7792 m`

## Main sweep result
Files:
- `fp_detection_parametric_by_case.csv`
- `fp_detection_parametric_aggregate.csv`
- `fp_detection_parametric_summary.txt`
- `fp_detection_abs_bias_heatmap.png`
- `fp_detection_rmse_heatmap.png`

### Best by minimum |mean bias|
- `threshold = 0.03`, `search_start = 0.00 m`
- Mean RMSE: `0.5223 m`
- Mean Bias: `+0.2743 m`
- Mean MAE: `0.3870 m`
- Mean P90: `0.8554 m`

Interpretation:
- Bias is reduced versus baseline (`+0.3330 -> +0.2743 m`).
- But RMSE/MAE/P90 degrade (more unstable early picks).

### Best by minimum mean RMSE
- `threshold = 0.05`, `search_start = 0.00 m`
- Mean RMSE: `0.4451 m`
- Mean Bias: `+0.3330 m`
- Mean MAE: `0.3404 m`
- Mean P90: `0.7792 m`

Interpretation:
- Practically same as current baseline (`0.10, 0.30`) in this dataset.

## Search-start sensitivity note
For the tested range (`0.0~0.5 m`), `fp_search_start_m` has negligible effect.
The selected peaks are beyond this guard region in current data.

## Recommendation
1. If bias minimization is priority: use `threshold=0.03` (accept tail/variance penalty).
2. If balanced robustness is priority: keep `threshold=0.05~0.10`.
3. Keep `fp_search_start_m` in low guard range (`<=0.5 m`) unless geometry changes.
