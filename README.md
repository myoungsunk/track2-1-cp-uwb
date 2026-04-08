# Track 2-1 CP vs LP (Measurement-Level Validation)

MATLAB pipeline for HFSS SBR+ frequency-domain S21 processing and CP/LP comparison.

## 1) Requirements
- MATLAB R2021b or later
- Base MATLAB functions only (no mandatory external toolbox usage in core pipeline)
- Data files under:
  - `data/`
  - `LOS_NLOS_EXPORT_20260405/`

## 2) Input Data Layout
- Case data (required):
  - `data/CP_caseA_2rx.csv`, `CP_caseB_2rx.csv`, `CP_caseC_2rx.csv`
  - `data/LP_caseA_new*.csv`, `LP_caseB_new*.csv`, `LP_caseC_new*.csv`
- DoA guide CSV (required):
  - CP: `data/inc_ang_RSSD_validation_patch_height=1m_23R1.csv` (or configured fallback in `setup_config.m`)
  - LP: `data/step3_baseline_inc_ang_height=1m_23R1.csv` (or configured fallback)
- LoS/NLoS labels (required by default):
  - `LOS_NLOS_EXPORT_20260405/track23_all_scenarios_los_nlos.csv`
  - scenario-wise CSVs in the same directory

## 3) Run
From MATLAB:

```matlab
cd('src');
main_track2_1;
```

## 4) Outputs
Generated under `results/`:
- `summary_table.csv` (+ bootstrap CI columns)
- `counterfactual_table.csv` (S1/S2 cross-polarization decomposition)
- `fusion_ablation_table.csv` (WLS vs direct Cartesian)
- `label_summary_by_scenario.csv`
- `all_results.mat`
- `run_manifest.json`
- CDF figures (`.fig`, `.png`)

## 5) Tests
From MATLAB:

```matlab
cd('tests');
run_all_tests;
```

## 6) Known Limitations
- DoA method is RSSD-LUT based; LP fairness vs alternative LP DoA methods is a separate study axis.
- Results are deterministic per dataset unless noise/Monte-Carlo extensions are added.
- Range calibration behavior is controlled by `cfg.range_calibration` and should be reported with outputs.

