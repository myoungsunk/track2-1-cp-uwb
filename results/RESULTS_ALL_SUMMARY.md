# Results All Summary

- Updated: 2026-04-07
- Data used:
  - `data/CP_caseA_2rx.csv`
  - `data/CP_caseB_2rx.csv`
  - `data/CP_caseC_2rx.csv`
  - `data/LP_caseA_new.csv`
  - `data/LP_caseB_new.csv`
  - `data/LP_caseC_new.csv`
- Main output table: `results/summary_table.csv`
- Full bundle: `results/all_results.mat`

## 1) Core Performance (CP vs LP)
(Mean over scenarios A/B/C)

- Range RMSE: CP `0.2439 m` vs LP `0.6463 m`
- DoA RMSE: CP `11.5190 deg` vs LP `45.6177 deg`
- Position RMSE: CP `0.5537 m` vs LP `3.1165 m`
- Position P90: CP `0.8111 m` vs LP `5.7895 m`
- Stage3 MRR delta (CP-LP): `+0.7281 dB`
- FP sharpness delta (CP-LP): `+3.2937 dB`

## 2) Scenario-wise Snapshot

### Scenario A
- CP: Range `0.2164 m`, DoA `10.33 deg`, Pos RMSE `0.4412 m`, Pos P90 `0.6105 m`
- LP: Range `0.6529 m`, DoA `43.69 deg`, Pos RMSE `2.9503 m`, Pos P90 `5.5063 m`

### Scenario B
- CP: Range `0.2261 m`, DoA `10.51 deg`, Pos RMSE `0.4725 m`, Pos P90 `0.8188 m`
- LP: Range `0.6018 m`, DoA `42.92 deg`, Pos RMSE `3.0084 m`, Pos P90 `6.1088 m`

### Scenario C
- CP: Range `0.2892 m`, DoA `13.71 deg`, Pos RMSE `0.7472 m`, Pos P90 `1.0040 m`
- LP: Range `0.6842 m`, DoA `50.25 deg`, Pos RMSE `3.3907 m`, Pos P90 `5.7535 m`

## 3) Sensitivity Studies

### 3.1 `fp_window_ns` sweep
- Summary file: `results/fp_window_sensitivity_aggregate.csv`
- Key trend:
  - `1~2 ns`: CP-LP MRR separation ~`+2.07 dB`
  - `5 ns`: ~`+0.73 dB`
  - `10 ns`: ~`-0.33 dB` (reversal)

### 3.2 first-path detector param sweep
- Summary files:
  - `results/fp_detection_parametric_aggregate.csv`
  - `results/fp_detection_parametric_summary.txt`
- Best by minimum |bias|:
  - `threshold=0.03`, `search_start=0.0 m`
- Best by minimum RMSE:
  - `threshold=0.05`, `search_start=0.0 m`
- Current baseline (`0.10`, `0.30 m`) is RMSE-equivalent to `0.05` in this dataset.

## 4) Plot Inventory (results folder)

- Total files: `132`
- By extension:
  - `.png`: `61`
  - `.fig`: `56`
  - `.csv`: `10`
  - `.mat`: `1`
  - `.md`: `1`
  - `.txt`: `2`

Grouped counts:
- `cdf_*`: `30`
- `heatmap_*`: `72`
- `fp_window_*`: `4`
- `fp_detection_*`: `8`
- `*guide*sim*`: `12`
- `summary_table*`: `4`

## 5) Key Figure Sets

- CDF comparisons: `cdf_*`
- Guide-vs-sim plots:
  - `cp_guide_vs_sim_incang_rssd_curve.*`
  - `lp_guide_vs_sim_incang_rssd_curve.*`
- Spatial error heatmaps (CP/LP, A/B/C, rx1/rx2): `heatmap_*`
- Sensitivity plots:
  - `fp_window_sensitivity_delta_cp_lp.*`
  - `fp_detection_*_heatmap.*`

## 6) Repro Commands

```powershell
matlab -batch "cd('src'); main_track2_1"
matlab -batch "addpath('src'); cfg=setup_config(); sweep_fp_window_sensitivity(cfg,[1 1.5 2 3 5 7 10]);"
matlab -batch "addpath('src'); cfg=setup_config(); sweep_fp_detection_params(cfg,[0.03 0.05 0.07 0.10 0.12 0.15 0.20],[0.0 0.1 0.2 0.3 0.4 0.5]);"
matlab -batch "addpath('src'); cfg=setup_config(); plot_cp_guide_vs_sim_incang_rssd_curve(cfg); plot_lp_guide_vs_sim_incang_rssd_curve(cfg);"
matlab -batch "addpath('src'); cfg=setup_config(); plot_spatial_heatmaps_by_antenna(cfg);"
```
