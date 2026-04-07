function [T_case, T_agg, best] = sweep_fp_detection_params(cfg, threshold_list, search_start_list_m)
% SWEEP_FP_DETECTION_PARAMS Parametric study for first-path detector settings.
%
% INPUT
%   cfg                 : struct from setup_config()
%   threshold_list      : vector of fp_threshold_ratio candidates
%   search_start_list_m : vector of fp_search_start_m candidates [m]
%
% OUTPUT
%   T_case : per-case table (pol/scenario level metrics)
%   T_agg  : aggregate table (across all 6 cases)
%   best   : struct with best-by-bias and best-by-rmse rows
%
% SIDE EFFECTS
%   Writes:
%   - results/fp_detection_parametric_by_case.csv
%   - results/fp_detection_parametric_aggregate.csv
%   - results/fp_detection_parametric_summary.txt
%   - results/fp_detection_abs_bias_heatmap.{png,fig}
%   - results/fp_detection_rmse_heatmap.{png,fig}

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end
if nargin < 2 || isempty(threshold_list)
    threshold_list = [0.03 0.05 0.07 0.10 0.12 0.15 0.20];
end
if nargin < 3 || isempty(search_start_list_m)
    search_start_list_m = [0.00 0.10 0.20 0.30 0.40 0.50];
end

threshold_list = threshold_list(:);
search_start_list_m = search_start_list_m(:);

n_th = numel(threshold_list);
n_ss = numel(search_start_list_m);
n_cases = numel(cfg.pol_types) * numel(cfg.scenarios);
n_rows = n_th * n_ss * n_cases;

Threshold = nan(n_rows, 1);
SearchStart_m = nan(n_rows, 1);
Polarization = strings(n_rows, 1);
Scenario = strings(n_rows, 1);
Ranging_RMSE_m = nan(n_rows, 1);
Ranging_Bias_m = nan(n_rows, 1);
Ranging_MAE_m = nan(n_rows, 1);
Ranging_P90AbsErr_m = nan(n_rows, 1);

row = 0;
for ith = 1:n_th
    for iss = 1:n_ss
        cfg_run = cfg;
        cfg_run.fp_threshold_ratio = threshold_list(ith);
        cfg_run.fp_search_start_m = search_start_list_m(iss);

        for p = 1:numel(cfg.pol_types)
            pol = cfg.pol_types{p};
            for s = 1:numel(cfg.scenarios)
                scenario = cfg.scenarios{s};
                data = load_case_data(pol, scenario, cfg_run);
                s1 = stage1_ranging(data, cfg_run);

                abs_err = abs(s1.error_m(:));
                valid_abs = abs_err(isfinite(abs_err));
                if isempty(valid_abs)
                    p90_abs = NaN;
                else
                    p90_abs = prctile(valid_abs, 90);
                end

                row = row + 1;
                Threshold(row) = cfg_run.fp_threshold_ratio;
                SearchStart_m(row) = cfg_run.fp_search_start_m;
                Polarization(row) = string(pol);
                Scenario(row) = string(scenario);
                Ranging_RMSE_m(row) = s1.rmse_m;
                Ranging_Bias_m(row) = mean(s1.error_m, 'omitnan');
                Ranging_MAE_m(row) = mean(abs_err, 'omitnan');
                Ranging_P90AbsErr_m(row) = p90_abs;
            end
        end
    end
end

T_case = table(Threshold, SearchStart_m, Polarization, Scenario, ...
    Ranging_RMSE_m, Ranging_Bias_m, Ranging_MAE_m, Ranging_P90AbsErr_m);

comb = unique(T_case(:, {'Threshold', 'SearchStart_m'}), 'rows', 'stable');
n_comb = height(comb);

Mean_RMSE_m = nan(n_comb, 1);
Mean_Bias_m = nan(n_comb, 1);
AbsMean_Bias_m = nan(n_comb, 1);
Mean_MAE_m = nan(n_comb, 1);
Mean_P90AbsErr_m = nan(n_comb, 1);
LP_minus_CP_RMSE_m = nan(n_comb, 1);
LP_minus_CP_Bias_m = nan(n_comb, 1);

for i = 1:n_comb
    th = comb.Threshold(i);
    ss = comb.SearchStart_m(i);
    sel = T_case.Threshold == th & T_case.SearchStart_m == ss;
    sub = T_case(sel, :);

    Mean_RMSE_m(i) = mean(sub.Ranging_RMSE_m, 'omitnan');
    Mean_Bias_m(i) = mean(sub.Ranging_Bias_m, 'omitnan');
    AbsMean_Bias_m(i) = abs(Mean_Bias_m(i));
    Mean_MAE_m(i) = mean(sub.Ranging_MAE_m, 'omitnan');
    Mean_P90AbsErr_m(i) = mean(sub.Ranging_P90AbsErr_m, 'omitnan');

    % Scenario-wise LP-CP deltas.
    d_rmse = nan(numel(cfg.scenarios), 1);
    d_bias = nan(numel(cfg.scenarios), 1);
    for s = 1:numel(cfg.scenarios)
        sc = string(cfg.scenarios{s});
        cp_row = sub(sub.Polarization == "CP" & sub.Scenario == sc, :);
        lp_row = sub(sub.Polarization == "LP" & sub.Scenario == sc, :);
        if ~isempty(cp_row) && ~isempty(lp_row)
            d_rmse(s) = lp_row.Ranging_RMSE_m - cp_row.Ranging_RMSE_m;
            d_bias(s) = lp_row.Ranging_Bias_m - cp_row.Ranging_Bias_m;
        end
    end
    LP_minus_CP_RMSE_m(i) = mean(d_rmse, 'omitnan');
    LP_minus_CP_Bias_m(i) = mean(d_bias, 'omitnan');
end

T_agg = table(comb.Threshold, comb.SearchStart_m, ...
    Mean_RMSE_m, Mean_Bias_m, AbsMean_Bias_m, Mean_MAE_m, Mean_P90AbsErr_m, ...
    LP_minus_CP_RMSE_m, LP_minus_CP_Bias_m, ...
    'VariableNames', {'Threshold', 'SearchStart_m', ...
    'Mean_RMSE_m', 'Mean_Bias_m', 'AbsMean_Bias_m', 'Mean_MAE_m', 'Mean_P90AbsErr_m', ...
    'LP_minus_CP_RMSE_m', 'LP_minus_CP_Bias_m'});

% Best points by two objectives.
idx_bias = local_argmin_two_keys(T_agg.AbsMean_Bias_m, T_agg.Mean_RMSE_m);
idx_rmse = local_argmin_two_keys(T_agg.Mean_RMSE_m, T_agg.AbsMean_Bias_m);
best = struct();
best.by_abs_bias = T_agg(idx_bias, :);
best.by_rmse = T_agg(idx_rmse, :);

% Baseline row for current default values.
baseline_sel = abs(T_agg.Threshold - cfg.fp_threshold_ratio) < 1e-12 & ...
    abs(T_agg.SearchStart_m - cfg.fp_search_start_m) < 1e-12;
if any(baseline_sel)
    best.baseline = T_agg(find(baseline_sel, 1, 'first'), :);
else
    best.baseline = table();
end

% Save CSV outputs.
writetable(T_case, fullfile(cfg.results_dir, 'fp_detection_parametric_by_case.csv'));
writetable(T_agg, fullfile(cfg.results_dir, 'fp_detection_parametric_aggregate.csv'));

% Save summary text.
summary_txt = local_build_summary_text(best);
summary_path = fullfile(cfg.results_dir, 'fp_detection_parametric_summary.txt');
fid = fopen(summary_path, 'w');
if fid >= 0
    fprintf(fid, '%s\n', summary_txt);
    fclose(fid);
end

% Heatmaps.
local_save_heatmap(T_agg, threshold_list, search_start_list_m, ...
    'AbsMean_Bias_m', ...
    'Mean |Bias| across 6 cases (m)', ...
    cfg, 'fp_detection_abs_bias_heatmap');
local_save_heatmap(T_agg, threshold_list, search_start_list_m, ...
    'Mean_RMSE_m', ...
    'Mean RMSE across 6 cases (m)', ...
    cfg, 'fp_detection_rmse_heatmap');
end

function idx = local_argmin_two_keys(key1, key2)
% LOCAL_ARGMIN_TWO_KEYS Argmin on key1, tie-break by key2.
[~, order] = sortrows([key1(:), key2(:)], [1, 2]);
idx = order(1);
end

function txt = local_build_summary_text(best)
% LOCAL_BUILD_SUMMARY_TEXT Builds human-readable summary lines.
lines = strings(0, 1);
lines(end+1) = "First-path detection parametric study summary";
lines(end+1) = "";
lines(end+1) = "Best by minimum |mean bias| (tie: mean RMSE):";
lines(end+1) = local_format_row(best.by_abs_bias);
lines(end+1) = "";
lines(end+1) = "Best by minimum mean RMSE (tie: |mean bias|):";
lines(end+1) = local_format_row(best.by_rmse);
if isfield(best, 'baseline') && ~isempty(best.baseline)
    lines(end+1) = "";
    lines(end+1) = "Baseline (current cfg):";
    lines(end+1) = local_format_row(best.baseline);
end
txt = strjoin(cellstr(lines), newline);
end

function line = local_format_row(T)
% LOCAL_FORMAT_ROW Formats one-row table for text output.
line = sprintf(['threshold=%.3f, search_start=%.3f m, mean_rmse=%.4f m, ', ...
    'mean_bias=%.4f m, abs_mean_bias=%.4f m, mean_mae=%.4f m, mean_p90=%.4f m'], ...
    T.Threshold, T.SearchStart_m, T.Mean_RMSE_m, T.Mean_Bias_m, ...
    T.AbsMean_Bias_m, T.Mean_MAE_m, T.Mean_P90AbsErr_m);
end

function local_save_heatmap(T_agg, threshold_list, search_start_list_m, field_name, title_str, cfg, file_stem)
% LOCAL_SAVE_HEATMAP Saves one heatmap for aggregate metric.
n_th = numel(threshold_list);
n_ss = numel(search_start_list_m);
M = nan(n_ss, n_th);

for ith = 1:n_th
    for iss = 1:n_ss
        sel = abs(T_agg.Threshold - threshold_list(ith)) < 1e-12 & ...
            abs(T_agg.SearchStart_m - search_start_list_m(iss)) < 1e-12;
        if any(sel)
            M(iss, ith) = T_agg.(field_name)(find(sel, 1, 'first'));
        end
    end
end

fig = figure('Visible', 'off', 'Color', 'w');
imagesc(threshold_list, search_start_list_m, M);
axis xy;
colormap(parula);
colorbar;
xlabel('fp\_threshold\_ratio');
ylabel('fp\_search\_start\_m');
title(title_str);

savefig(fig, fullfile(cfg.results_dir, [file_stem '.fig']));
exportgraphics(fig, fullfile(cfg.results_dir, [file_stem '.png']), 'Resolution', 150);
close(fig);
end

