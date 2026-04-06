# DESIGN.md ??CP vs LP Single-Anchor UWB Positioning System

> **Audience**: This document is the sole specification for the MATLAB implementer.
> Follow every signature, formula, and convention exactly.
> Mark anything ambiguous with `% TODO:` in the generated code.

---

## 1. Project Context

- **Frequency**: 6.5 GHz UWB (sweep 6.24??.74 GHz, BW = 500 MHz, ?f = 1 MHz, N_freq = 501)
- **Simulation**: HFSS SBR+ ray-tracing (indoor room)
- **System 1 (CP)**: 1 횞 RHCP anchor + tilted tag with 2 횞 RHCP antennas
- **System 2 (LP)**: 1 횞 LP anchor + tilted tag with 2 횞 LP antennas
- **Anchor position**: (x_a, y_a) = (0, 0) mm ??origin of the room coordinate system
- **Tag grid**: X ??{750, 1500, 2250, 3000, 3750, 4500, 5250} mm (7 cols),
  Y ??{??750, ??250, ??50, ??50, 250, 750, 1250, 1750} mm (8 rows) ??56 positions total
- **Speed of light**: c = 3 횞 10??m/s

---

## 2. Scenario Definitions

| Case file        | Scenario | LoS tags | NLoS tags | Total |
|------------------|----------|----------|-----------|-------|
| CP_caseA / LP_caseA | A     | 56       | 0         | 56    |
| CP_caseB / LP_caseB | B     | 34       | 22        | 56    |
| CP_caseC / LP_caseC | C     | 21       | 35        | 56    |

**LoS/NLoS label source**: `cfg.los_idx.A`, `cfg.los_idx.B`, `cfg.los_idx.C`
(integer arrays of 1-based tag indices that are LoS; set in `setup_config.m`).
Scenario A: all 1:56. Scenarios B and C: defined from simulation metadata ??
implementer must fill these arrays as `% TODO: insert LoS index list from simulation log`.

---

## 3. File Structure

```
track2-1-cp-uwb/
?쒋?? data/
??  ?쒋?? CP_caseA.csv
??  ?쒋?? CP_caseB.csv
??  ?쒋?? CP_caseC.csv
??  ?쒋?? LP_caseA.csv
??  ?쒋?? LP_caseB.csv
??  ?붴?? LP_caseC.csv
?쒋?? src/
??  ?쒋?? main_track2_1.m          % Top-level runner ??runs all stages for all 6 cases
??  ?쒋?? setup_config.m           % Returns cfg struct with all parameters
??  ?쒋?? load_case_data.m         % Reads one CSV ??structured data matrix
??  ?쒋?? compute_cir.m            % Complex S21 vector ??CIR via windowed IFFT
??  ?쒋?? stage1_ranging.m         % CIR ??ToA ??range error metrics
??  ?쒋?? stage2_doa.m             % RSS1/RSS2 ??RSSD ??DoA error metrics
??  ?쒋?? stage3_rejection.m       % CIR ??first-path energy ratio
??  ?쒋?? stage4_positioning.m     % (range, DoA) ??2D position error metrics
??  ?쒋?? compute_metrics.m        % Shared: RMSE, CDF arrays, CEP67, CEP95
??  ?쒋?? plot_comparison.m        % CP vs LP overlaid CDF / bar chart per scenario
??  ?붴?? generate_summary_table.m % All metrics ??summary_table.csv
?쒋?? results/                     % All .fig, .png, summary_table.csv written here
?쒋?? PLAN.md
?쒋?? IMPLEMENT.md
?붴?? DESIGN.md
```

---
## 4. Data File Loading Rules

### 4.1 Naming Convention ??Case Mapping

```
Filename pattern : data/<POL>_case<SCENARIO>.csv
  POL      : 'CP' | 'LP'
  SCENARIO : 'A'  | 'B' | 'C'
Example  : data/CP_caseB.csv  ?? pol='CP', scenario='B'
```

### 4.2 CSV Column Layout (verified from actual files)

| Column index | Header                          | Unit  | Description                          |
|--------------|---------------------------------|-------|--------------------------------------|
| 1            | `x_coord [mm]`                  | mm    | Tag x-position                       |
| 2            | `y_coord [mm]`                  | mm    | Tag y-position                       |
| 3            | `Freq [GHz]`                    | GHz   | Frequency sample                     |
| 4            | `mag(S(rx1_p1,tx_p1)) []`       | ??    | |S21| magnitude, anchor?뭪ag antenna 1 |
| 5            | `ang_deg(S(rx1_p1,tx_p1)) [deg]`| deg   | ?쟔21 phase, anchor?뭪ag antenna 1    |
| 6            | `mag(S(rx2_p1,tx_p1)) []`       | ??    | |S21| magnitude, anchor?뭪ag antenna 2 |
| 7            | `ang_deg(S(rx2_p1,tx_p1)) [deg]`| deg   | ?쟔21 phase, anchor?뭪ag antenna 2    |

- `tx_p1` = anchor transmit port
- `rx1_p1` = antenna 1 of tilted tag (tilted at +罐_tilt from z-axis)
- `rx2_p1` = antenna 2 of tilted tag (tilted at ?믊?tilt from z-axis)

### 4.3 Data Layout in File

Rows are sorted **first by tag position, then by frequency**:
- 501 consecutive rows share the same (x, y)
- 56 횞 501 = 28,056 data rows + 1 header = 28,057 lines per file

`load_case_data.m` must reshape the flat rows into a (56 횞 501) matrix per antenna.

---
## 5. Function Signatures

### 5.1 `setup_config.m`

```matlab
function cfg = setup_config()
% Returns the global configuration struct.
%
% OUTPUT
%   cfg : struct with fields listed below
%
% ---- System parameters ----
% cfg.c            = 3e8;           % speed of light [m/s]
% cfg.f_start      = 6.24e9;        % start frequency [Hz]
% cfg.f_stop       = 6.74e9;        % stop frequency  [Hz]
% cfg.delta_f      = 1e6;           % frequency step  [Hz]
% cfg.N_freq       = 501;           % number of frequency points
% cfg.BW           = 500e6;         % bandwidth [Hz]
% cfg.fc           = 6.49e9;        % center frequency [Hz]
%
% ---- IFFT / CIR parameters ----
% cfg.N_fft        = 2^14;          % zero-pad length (16384) for IFFT
% cfg.window_type  = 'hann';        % window applied before IFFT ('hann'|'hamming'|'rect')
%
% ---- Geometry ----
% cfg.anchor_mm    = [0, 0];        % anchor position [mm]
%
% ---- First-path detection ----
% cfg.fp_threshold_ratio = 0.1;     % first peak must exceed ratio * max(|CIR|)
% cfg.fp_search_start_m  = 0.3;     % ignore CIR before this distance [m] (hardware guard)
%
% ---- Stage 3: multipath window ----
% cfg.fp_window_ns = 5;             % energy integration window after ToA [ns]
%
% ---- Stage 2: DoA / tilted tag ----
% cfg.theta_tilt_deg = 45;          % half-angle between the two tag antennas [deg]
% cfg.rssd_lut_step  = 0.1;         % DoA LUT resolution [deg]
% cfg.doa_range_deg  = [-90, 90];   % valid DoA search range [deg]
%
% ---- Scenario metadata ----
% cfg.scenarios    = {'A','B','C'};
% cfg.pol_types    = {'CP','LP'};
% cfg.n_tags       = 56;
%
% cfg.los_idx.A    = 1:56;          % all LoS
% cfg.los_idx.B    = [];            % TODO: insert 34 LoS tag indices from simulation log
% cfg.los_idx.C    = [];            % TODO: insert 21 LoS tag indices from simulation log
%
% ---- Paths ----
% cfg.data_dir     = fullfile(fileparts(mfilename('fullpath')), '..', 'data');
% cfg.results_dir  = fullfile(fileparts(mfilename('fullpath')), '..', 'results');
```

---

### 5.2 `load_case_data.m`

```matlab
function data = load_case_data(pol_type, scenario, cfg)
% Loads one CSV file and returns a structured dataset.
%
% INPUT
%   pol_type : char   ??'CP' or 'LP'
%   scenario : char   ??'A', 'B', or 'C'
%   cfg      : struct ??from setup_config()
%
% OUTPUT
%   data.pol_type   : char          pol_type input (passed through)
%   data.scenario   : char          scenario input (passed through)
%   data.n_tags     : int           56
%   data.pos_mm     : [56횞2]        tag positions [x, y] in mm
%   data.freq_Hz    : [501횞1]       frequency axis in Hz
%   data.S21_rx1    : [56횞501]      complex S21 for antenna 1
%   data.S21_rx2    : [56횞501]      complex S21 for antenna 2
%   data.range_gt_m : [56횞1]        ground-truth range = norm(pos_mm - anchor_mm)/1000 [m]
%   data.doa_gt_deg : [56횞1]        ground-truth DoA   = atan2d(dy, dx) [deg]
%   data.is_los     : [56횞1 logical] true for LoS tags (from cfg.los_idx)
%
% NOTES
%   - Complex S21: mag * exp(1j * deg2rad(ang_deg))
%   - File path:   fullfile(cfg.data_dir, [pol_type '_case' scenario '.csv'])
%   - Error if file not found: error('load_case_data: file not found: %s', filepath)
%   - Rows are grouped as 501 consecutive freq rows per tag position.
%     Reshape: S21_rx1(i,:) = rows for tag i, all frequencies.
```

---

### 5.3 `compute_cir.m`

```matlab
function [cir_mag, t_axis_s, d_axis_m] = compute_cir(S21_vec, cfg)
% Converts a single-tag S21 frequency vector to a CIR via windowed IFFT.
%
% INPUT
%   S21_vec  : [N_freq횞1] complex  ??complex S21 at 501 frequency points
%   cfg      : struct               ??from setup_config()
%
% OUTPUT
%   cir_mag  : [N_fft횞1]  double   ??|CIR| magnitude (linear)
%   t_axis_s : [N_fft횞1]  double   ??time axis [s],  t_n = n/(N_fft * delta_f)
%   d_axis_m : [N_fft횞1]  double   ??range axis [m], d_n = c * t_n
%
% ALGORITHM
%   1. Build window w = hann(N_freq) (or per cfg.window_type)
%   2. H_win = S21_vec .* w          % apply window
%   3. H_pad = [H_win; zeros(N_fft - N_freq, 1)]   % zero-pad
%   4. h     = ifft(H_pad, N_fft)    % IFFT (no fftshift needed)
%   5. cir_mag = abs(h)
%   6. t_axis_s = (0:N_fft-1)' / (N_fft * cfg.delta_f)
%   7. d_axis_m = cfg.c * t_axis_s
```

---
### 5.4 `stage1_ranging.m`

```matlab
function result = stage1_ranging(data, cfg)
% Computes ranging error for all tags in one case.
%
% INPUT
%   data   : struct ??from load_case_data()
%   cfg    : struct ??from setup_config()
%
% OUTPUT  (all vectors are [56횞1] unless noted)
%   result.range_est_m   : [56횞1]  estimated range per tag [m] using antenna 1 (primary)
%   result.range_est_rx2_m : [56횞1] estimated range per tag [m] using antenna 2 (auxiliary log)
%   result.range_gt_m    : [56횞1]  ground-truth range [m]  (= data.range_gt_m)
%   result.error_m       : [56횞1]  signed ranging error = range_est - range_gt [m]
%   result.abs_error_m   : [56횞1]  |error_m|
%   result.rmse_m        : scalar  RMSE over all tags [m]
%   result.rmse_los_m    : scalar  RMSE over LoS tags only
%   result.rmse_nlos_m   : scalar  RMSE over NLoS tags only (NaN if scenario A)
%   result.error_rx2_m   : [56횞1]  signed ranging error from antenna 2 [m]
%   result.abs_error_rx2_m : [56횞1] absolute ranging error from antenna 2 [m]
%   result.rmse_rx2_m    : scalar  RMSE from antenna 2 over all tags [m]
%   result.rmse_los_rx2_m : scalar RMSE from antenna 2 over LoS tags [m]
%   result.rmse_nlos_rx2_m : scalar RMSE from antenna 2 over NLoS tags [m]
%   result.cdf_x         : [K횞1]  CDF x-axis (error values, sorted)
%   result.cdf_y         : [K횞1]  CDF y-axis (cumulative probability 0??)
%   result.pol_type      : char   passed through from data
%   result.scenario      : char   passed through from data
%
% ALGORITHM (per tag i = 1..56)
%   1. S21 = data.S21_rx1(i,:).'   % use antenna 1 for ranging metrics (primary path)
%   2. [cir, t_axis, d_axis] = compute_cir(S21, cfg)
%   3. range_est_m(i) = extract_first_path_range(cir, d_axis, cfg)
%   4. error_m(i) = range_est_m(i) - data.range_gt_m(i)
%   5. In parallel, compute and store the same first-path range/error from data.S21_rx2(i,:).'
%      for diagnostics, but do not use antenna 2 for primary Stage1 metrics.
%
% HELPER (inline or sub-function within file):
%   function d_fp = extract_first_path_range(cir_mag, d_axis, cfg)
%   % Returns estimated range from first-path peak in CIR.
%   % 1. Restrict search to d_axis >= cfg.fp_search_start_m
%   % 2. threshold = cfg.fp_threshold_ratio * max(cir_mag)
%   % 3. Find indices where cir_mag > threshold AND is local maximum
%   %    (local max: cir_mag(k) > cir_mag(k-1) AND cir_mag(k) > cir_mag(k+1))
%   % 4. d_fp = d_axis(first qualifying index)
%   % 5. If no peak found: d_fp = d_axis(argmax(cir_mag))  % fallback
```

---

### 5.5 `stage2_doa.m`

```matlab
function result = stage2_doa(data, cfg)
% Computes DoA error using RSSD between the two tilted tag antennas.
%
% INPUT
%   data   : struct ??from load_case_data()
%   cfg    : struct ??from setup_config()
%
% OUTPUT  (all vectors [56횞1] unless noted)
%   result.rss1_dB       : [56횞1]  broadband RSS antenna 1 [dB]
%   result.rss2_dB       : [56횞1]  broadband RSS antenna 2 [dB]
%   result.rssd_dB       : [56횞1]  RSSD = RSS1 - RSS2 [dB]
%   result.doa_est_deg   : [56횞1]  estimated DoA [deg]
%   result.doa_gt_deg    : [56횞1]  ground-truth DoA [deg]  (= data.doa_gt_deg)
%   result.error_deg     : [56횞1]  signed DoA error = doa_est - doa_gt [deg]
%   result.abs_error_deg : [56횞1]  |error_deg|
%   result.rmse_deg      : scalar  RMSE [deg]
%   result.rmse_los_deg  : scalar  RMSE over LoS tags
%   result.rmse_nlos_deg : scalar  RMSE over NLoS tags (NaN if scenario A)
%   result.cdf_x         : [K횞1]
%   result.cdf_y         : [K횞1]
%   result.pol_type      : char
%   result.scenario      : char
%
% ALGORITHM
%   Step A ??Compute broadband RSS per tag
%     rss1_dB(i) = 10*log10( mean(abs(data.S21_rx1(i,:)).^2) )
%     rss2_dB(i) = 10*log10( mean(abs(data.S21_rx2(i,:)).^2) )
%     rssd_dB(i) = rss1_dB(i) - rss2_dB(i)
%
%   Step B ??Build RSSD?묭oA lookup table (call once per cfg)
%     [rssd_lut, doa_lut] = build_rssd_lut(cfg)
%
%   Step C ??Map each RSSD to DoA
%     doa_est_deg(i) = interp1(rssd_lut, doa_lut, rssd_dB(i), 'linear', 'extrap')
%
% HELPER (sub-function within file):
%   function [rssd_lut, doa_lut] = build_rssd_lut(cfg)
%   % Returns monotone RSSD-vs-DoA lookup table.
%   % doa_lut  = (cfg.doa_range_deg(1) : cfg.rssd_lut_step : cfg.doa_range_deg(2)).'
%   % For each doa angle phi [deg]:
%   %   G1 = sin^2(phi_rad - theta_rad)   % antenna 1 at +theta_tilt
%   %   G2 = sin^2(phi_rad + theta_rad)   % antenna 2 at -theta_tilt
%   %   rssd_lut = 10*log10(G1 ./ G2)     % [dB], element-wise
%   % where phi_rad = deg2rad(doa_lut), theta_rad = deg2rad(cfg.theta_tilt_deg)
%   % Clip G1, G2 to eps before log to avoid -Inf.
%   % NOTE: valid monotone range is phi in (-90+theta, 90-theta) deg.
%   %       Outside this range interp1 will extrapolate ??flag a warning.
```

---

### 5.6 `stage3_rejection.m`

```matlab
function result = stage3_rejection(data, cfg)
% Computes first-path multipath rejection ratio for each tag.
%
% INPUT
%   data   : struct ??from load_case_data()
%   cfg    : struct ??from setup_config()
%
% OUTPUT
%   result.ratio_dB      : [56횞1]  MRR = 10*log10(E_fp / E_total) [dB] per tag
%   result.mean_ratio_dB : scalar  mean MRR over all tags
%   result.mean_los_dB   : scalar  mean MRR over LoS tags
%   result.mean_nlos_dB  : scalar  mean MRR over NLoS tags (NaN if scenario A)
%   result.cdf_x         : [K횞1]
%   result.cdf_y         : [K횞1]
%   result.pol_type      : char
%   result.scenario      : char
%
% ALGORITHM (per tag i, using antenna 1 CIR)
%   1. [cir, t_axis, d_axis] = compute_cir(data.S21_rx1(i,:).', cfg)
%   2. Find first-path index: fp_idx via same logic as stage1 extract_first_path
%   3. T_win_samples = round(cfg.fp_window_ns * 1e-9 / (1/(cfg.N_fft*cfg.delta_f)))
%   4. fp_end_idx = min(fp_idx + T_win_samples - 1, cfg.N_fft)
%   5. E_fp    = sum(cir(fp_idx : fp_end_idx).^2)
%   6. E_total = sum(cir.^2)
%   7. ratio_dB(i) = 10*log10(E_fp / E_total)
```

---

### 5.7 `stage4_positioning.m`

```matlab
function result = stage4_positioning(s1_result, s2_result, data, cfg)
% Computes 2D positioning error from range + DoA estimates.
%
% INPUT
%   s1_result : struct ??output of stage1_ranging()
%   s2_result : struct ??output of stage2_doa()
%   data      : struct ??from load_case_data()  (for ground-truth positions)
%   cfg       : struct ??from setup_config()
%
% OUTPUT
%   result.pos_est_mm    : [56횞2]  estimated 2D position [mm]
%   result.pos_gt_mm     : [56횞2]  ground-truth position [mm]  (= data.pos_mm)
%   result.error_m       : [56횞1]  2D Euclidean error [m]
%   result.rmse_m        : scalar  RMSE [m]
%   result.rmse_los_m    : scalar  RMSE over LoS tags
%   result.rmse_nlos_m   : scalar  RMSE over NLoS tags (NaN if scenario A)
%   result.cep67_m       : scalar  67th-percentile circular error probable [m]
%   result.cep95_m       : scalar  95th-percentile CEP [m]
%   result.cdf_x         : [K횞1]
%   result.cdf_y         : [K횞1]
%   result.pol_type      : char
%   result.scenario      : char
%
% ALGORITHM (per tag i)
%   1. d   = s1_result.range_est_m(i)       % estimated range [m]
%   2. phi = deg2rad(s2_result.doa_est_deg(i))  % estimated DoA [rad]
%   3. x_est = cfg.anchor_mm(1) + d * cos(phi) * 1000   % [mm]
%   4. y_est = cfg.anchor_mm(2) + d * sin(phi) * 1000   % [mm]
%   5. pos_est_mm(i,:) = [x_est, y_est]
%   6. dx = pos_est_mm(i,1) - data.pos_mm(i,1)          % [mm]
%   7. dy = pos_est_mm(i,2) - data.pos_mm(i,2)          % [mm]
%   8. error_m(i) = sqrt(dx^2 + dy^2) / 1000            % [m]
```

---
### 5.8 `compute_metrics.m`

```matlab
function m = compute_metrics(err_vec, is_los)
% Computes standard scalar metrics from an error vector.
%
% INPUT
%   err_vec : [N횞1] double  ??non-negative error values
%   is_los  : [N횞1] logical ??LoS mask
%
% OUTPUT
%   m.rmse       : scalar  sqrt(mean(err_vec.^2))
%   m.rmse_los   : scalar  RMSE over err_vec(is_los)
%   m.rmse_nlos  : scalar  RMSE over err_vec(~is_los);  NaN if none
%   m.cep67      : scalar  prctile(err_vec, 67)
%   m.cep95      : scalar  prctile(err_vec, 95)
%   m.cdf_x      : [N횞1]  sorted err_vec
%   m.cdf_y      : [N횞1]  (1:N)'/N
```

---

### 5.9 `plot_comparison.m`

```matlab
function plot_comparison(results_cp, results_lp, metric_field, stage_label, scenario, cfg)
% Plots CP vs LP CDF on a single figure for one metric and saves to results/.
%
% INPUT
%   results_cp   : struct ??stage result for CP (from stage1/2/3/4)
%   results_lp   : struct ??stage result for LP (same stage, same scenario)
%   metric_field : char   ??field name in result to plot, e.g. 'abs_error_m'
%   stage_label  : char   ??axis label, e.g. 'Ranging Error (m)'
%   scenario     : char   ??'A', 'B', or 'C' (used in title + filename)
%   cfg          : struct
%
% BEHAVIOR
%   - Plot CDF: x = sorted metric, y = cumulative probability
%   - CP: solid blue line; LP: dashed red line
%   - Legend: 'CP', 'LP'
%   - Title: sprintf('Scenario %s ??%s', scenario, stage_label)
%   - xlabel: stage_label,  ylabel: 'CDF'
%   - Save as: results/cdf_<stage_label_sanitized>_scenario<scenario>.fig
%              results/cdf_<stage_label_sanitized>_scenario<scenario>.png
%   - Use sanitize_filename() (local helper) to replace spaces/() with underscores
%
% FIGURES GENERATED (called from main_track2_1.m for each combination)
%   Stage 1 : abs_error_m          label 'Ranging Error (m)'
%   Stage 2 : abs_error_deg        label 'DoA Error (deg)'
%   Stage 3 : ratio_dB             label 'Multipath Rejection Ratio (dB)'
%   Stage 4 : error_m              label '2D Positioning Error (m)'
%   ??4 stages 횞 3 scenarios = 12 figures
```

---

### 5.10 `generate_summary_table.m`

```matlab
function T = generate_summary_table(all_results, cfg)
% Builds and saves a summary table of all metrics.
%
% INPUT
%   all_results : struct  ??nested as all_results.(pol).(scenario)
%                           where pol ??{'CP','LP'}, scenario ??{'A','B','C'}
%                           each leaf contains fields: s1, s2, s3, s4
%                           (outputs of the four stage functions)
%   cfg         : struct
%
% OUTPUT
%   T : MATLAB table with columns:
%       Polarization | Scenario | Ranging_RMSE_m | DoA_RMSE_deg |
%       MRR_mean_dB  | Pos_RMSE_m | Pos_CEP67_m | Pos_CEP95_m
%   Saved to: results/summary_table.csv  via writetable(T, ...)
%
% ROW ORDER: CP-A, CP-B, CP-C, LP-A, LP-B, LP-C  (6 rows total)
```

---

### 5.11 `main_track2_1.m`

```matlab
% main_track2_1.m ??Top-level script. Run this to execute the full pipeline.
%
% EXECUTION ORDER:
%   1. cfg = setup_config()
%   2. For each pol in {'CP','LP'}, for each scenario in {'A','B','C'}:
%       a. data = load_case_data(pol, scenario, cfg)
%       b. s1   = stage1_ranging(data, cfg)
%       c. s2   = stage2_doa(data, cfg)
%       d. s3   = stage3_rejection(data, cfg)
%       e. s4   = stage4_positioning(s1, s2, data, cfg)
%       f. Store in all_results.(pol).(scenario).s1 ... .s4
%   3. For each scenario, call plot_comparison for each stage metric
%   4. T = generate_summary_table(all_results, cfg)
%   5. Print summary table to console via disp(T)
```

---
## 6. Data Flow Diagram

```
data/<POL>_case<X>.csv
        |
        v
  load_case_data(pol, scenario, cfg)
        |
        +---- data.S21_rx1  [56횞501 complex]
        +---- data.S21_rx2  [56횞501 complex]
        +---- data.range_gt_m  [56횞1]
        +---- data.doa_gt_deg  [56횞1]
        +---- data.is_los      [56횞1]
        |
        +=========================> Stage 1: stage1_ranging()
        |   per tag: S21_rx1(i,:) --> compute_cir() --> extract_first_path_range()
        |   --> range_est_m, error_m, rmse, cdf
        |
        +=========================> Stage 2: stage2_doa()
        |   per tag: mean(|S21_rx1|^2), mean(|S21_rx2|^2) --> rssd_dB
        |            build_rssd_lut(cfg) --> interp1 --> doa_est_deg
        |   --> doa_est_deg, error_deg, rmse, cdf
        |
        +=========================> Stage 3: stage3_rejection()
        |   per tag: S21_rx1(i,:) --> compute_cir() --> E_fp/E_total
        |   --> ratio_dB, mean_ratio, cdf
        |
        +-- Stage 1 output --+
        |   Stage 2 output --+====> Stage 4: stage4_positioning()
        |                          per tag: (range_est, doa_est) --> (x_est, y_est)
        |                          --> error_m, rmse, cep67, cep95, cdf
        |
        v
  All 4 stage results stored in all_results.(pol).(scenario)
        |
        +-----> plot_comparison()        --> results/*.fig + *.png  (12 plots)
        +-----> generate_summary_table() --> results/summary_table.csv
```

---

## 7. Core Formulas

### 7.1 Complex S21 Reconstruction

```
H_k = mag_k 횞 exp(j 횞 ang_k 횞 ?/180)     for k = 1..501
```
where `mag_k = mag(S(rx,tx))` and `ang_k = ang_deg(S(rx,tx))` from CSV.

---

### 7.2 Windowed IFFT ??CIR

```
w_k    = 0.5 횞 (1 ??cos(2?(k??)/(N_freq??)))     k = 1..N_freq   [Hann window]

H_win  = H .횞 w                                    [element-wise, N_freq횞1]

H_pad  = [ H_win ]                                 [N_fft횞1, N_fft = 16384]
         [ zeros ]

h(t)   = IFFT(H_pad, N_fft)                        [complex, N_fft횞1]

CIR(t) = |h(t)|                                    [real, N_fft횞1]

t_n    = n / (N_fft 횞 ?f)                          n = 0,1,...,N_fft??
d_n    = c 횞 t_n                                   [range axis, meters]
```

- **Range resolution** (without zero-padding): c/BW = 3횞10??5횞10??= **0.60 m**
- **Range resolution** (with N_fft=16384):      c/(N_fft횞?f) = 3횞10??16.384횞10????**18.3 mm per bin**

---

### 7.3 First-Path ToA Detection

```
threshold  = fp_threshold_ratio 횞 max(CIR)

search_idx = find(d_axis >= fp_search_start_m)      [restrict far end of guard zone]

For each candidate index k in search_idx:
  if CIR(k) > threshold
  AND CIR(k) > CIR(k??)         [local max condition ??left]
  AND CIR(k) > CIR(k+1)         [local max condition ??right]
    fp_idx = k                   [first qualifying peak ??STOP]

range_est = d_axis(fp_idx)       [meters]
```

---

### 7.4 Ground-Truth Range and DoA

```
Anchor:  (x_a, y_a)   [mm]     default (0, 0)
Tag i:   (x_i, y_i)   [mm]

range_gt_m(i) = sqrt((x_i ??x_a)짼 + (y_i ??y_a)짼) / 1000     [m]

doa_gt_deg(i) = atan2d(y_i ??y_a,  x_i ??x_a)                 [deg, ??80..180]
```

---

### 7.5 RSSD Computation

```
RSS1_dB(i) = 10 * log10( mean_f( |S21_rx1(i, :)|^2 ) )
RSS2_dB(i) = 10 * log10( mean_f( |S21_rx2(i, :)|^2 ) )

RSSD(i)    = RSS1_dB(i) ??RSS2_dB(i)                          [dB]
```

where the mean is taken over all 501 frequency samples.

---

### 7.6 RSSD ??DoA Mapping (IoT-J 2025 Tilted-Tag Model)

```
罐_tilt = cfg.theta_tilt_deg    [deg]  (e.g. 45째)

For LUT angle ? ??[??0째, 90째] at step cfg.rssd_lut_step:

  ?_rad  = ? 횞 ?/180
  罐_rad  = 罐_tilt 횞 ?/180

  G1(?)  = sin짼(?_rad ??罐_rad)      [gain pattern antenna 1 at +罐_tilt]
  G2(?)  = sin짼(?_rad + 罐_rad)      [gain pattern antenna 2 at ?믊?tilt]

  RSSD_lut(?) = 10 횞 log10( max(G1(?), 琯) / max(G2(?), 琯) )   [dB]

Inverse mapping (per-tag):
  ?_est(i) = interp1(RSSD_lut, ?_lut, RSSD(i), 'linear', 'extrap')   [deg]
```

The LUT must be sorted monotonically in RSSD before calling `interp1`.
Issue a `warning(...)` if any RSSD(i) falls outside the monotone region
(approximately |?| < 90째 ??罐_tilt).

---

### 7.7 2D Position Estimation

```
?_est  = doa_est_deg(i) 횞 ?/180      [rad]
d_est  = range_est_m(i)              [m]

x_est  = x_a  +  d_est 횞 cos(?_est) 횞 1000    [mm]
y_est  = y_a  +  d_est 횞 sin(?_est) 횞 1000    [mm]

error_m(i) = sqrt( (x_est ??x_gt(i))짼  +  (y_est ??y_gt(i))짼 ) / 1000   [m]
```

---

### 7.8 Summary Metrics

```
RMSE        = sqrt( mean( error짼 ) )
CEP67       = prctile(error, 67)
CEP95       = prctile(error, 95)
CDF x-axis  = sort(error)             [ascending]
CDF y-axis  = (1 : N)' / N
```

---

## 8. Output Specification

### 8.1 Figures Saved to `results/`

| Filename pattern                                | Content                              |
|-------------------------------------------------|--------------------------------------|
| `cdf_Ranging_Error_m_scenarioA.png/.fig`        | Stage 1 CDF, Scenario A              |
| `cdf_Ranging_Error_m_scenarioB.png/.fig`        | Stage 1 CDF, Scenario B              |
| `cdf_Ranging_Error_m_scenarioC.png/.fig`        | Stage 1 CDF, Scenario C              |
| `cdf_DoA_Error_deg_scenarioA.png/.fig`          | Stage 2 CDF, Scenario A              |
| `cdf_DoA_Error_deg_scenarioB.png/.fig`          | Stage 2 CDF, Scenario B              |
| `cdf_DoA_Error_deg_scenarioC.png/.fig`          | Stage 2 CDF, Scenario C              |
| `cdf_MRR_dB_scenarioA.png/.fig`                 | Stage 3 CDF, Scenario A              |
| `cdf_MRR_dB_scenarioB.png/.fig`                 | Stage 3 CDF, Scenario B              |
| `cdf_MRR_dB_scenarioC.png/.fig`                 | Stage 3 CDF, Scenario C              |
| `cdf_2D_Pos_Error_m_scenarioA.png/.fig`         | Stage 4 CDF, Scenario A              |
| `cdf_2D_Pos_Error_m_scenarioB.png/.fig`         | Stage 4 CDF, Scenario B              |
| `cdf_2D_Pos_Error_m_scenarioC.png/.fig`         | Stage 4 CDF, Scenario C              |

All figures: CP = solid blue, LP = dashed red.

### 8.2 `results/summary_table.csv`

```
Polarization,Scenario,Ranging_RMSE_m,DoA_RMSE_deg,MRR_mean_dB,Pos_RMSE_m,Pos_CEP67_m,Pos_CEP95_m
CP,A,...,...,...,...,...,...
CP,B,...,...,...,...,...,...
CP,C,...,...,...,...,...,...
LP,A,...,...,...,...,...,...
LP,B,...,...,...,...,...,...
LP,C,...,...,...,...,...,...
```

---

## 9. Implementation Constraints

1. **No hardcoded paths** ??all file paths derived from `cfg.data_dir` / `cfg.results_dir`.
2. **File-existence check** in `load_case_data.m`: use `assert(isfile(filepath), ...)`.
3. **Function files**: each `.m` file defines exactly one primary function of the same name.
4. **Code directory**: all `.m` files in `src/`; no subdirectories.
5. **Results directory**: create with `mkdir(cfg.results_dir)` if absent (no error if exists).
6. **Figure saving**:
   ```matlab
   savefig(fig_handle, fullfile(cfg.results_dir, fname_fig));
   exportgraphics(fig_handle, fullfile(cfg.results_dir, fname_png), 'Resolution', 150);
   ```
7. **Comment header**: every function begins with input/output description matching this DESIGN.
8. **TODO comments**: mark unresolved configuration items as `% TODO: <description>`.

