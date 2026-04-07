function T = generate_summary_table(all_results, cfg)
% GENERATE_SUMMARY_TABLE Builds and saves summary metrics across cases.
%
% INPUT
%   all_results : struct with all_results.(pol).(scenario).s1...s4
%   cfg         : struct from setup_config()
%
% OUTPUT
%   T : summary table with 6 rows in order:
%       CP-A, CP-B, CP-C, LP-A, LP-B, LP-C

n_rows = numel(cfg.pol_types) * numel(cfg.scenarios);

Polarization = strings(n_rows, 1);
Scenario = strings(n_rows, 1);
Ranging_RMSE_m = nan(n_rows, 1);
Ranging_RMSE_Debiased_m = nan(n_rows, 1);
Ranging_Bias_m = nan(n_rows, 1);
Ranging_RMSE_Rx2_m = nan(n_rows, 1);
Ranging_RMSE_Debiased_Rx2_m = nan(n_rows, 1);
DoA_RMSE_deg = nan(n_rows, 1);
DoA_Bias_deg = nan(n_rows, 1);
DoA_Corr_RSSD_vs_GT = nan(n_rows, 1);
DoA_Corr_Est_vs_GT = nan(n_rows, 1);
DoA_Selected_RMSE_deg = nan(n_rows, 1);
DoA_Selected_Bias_deg = nan(n_rows, 1);
DoA_Selected_Corr_vs_GT = nan(n_rows, 1);
DoA_Selected_Valid_Ratio = nan(n_rows, 1);
DoA_Selected_Improve_deg = nan(n_rows, 1);
MRR_mean_dB = nan(n_rows, 1);
FP_Sharpness_mean_dB = nan(n_rows, 1);
Pos_RMSE_m = nan(n_rows, 1);
Pos_P90_m = nan(n_rows, 1);
Pos_CEP67_m = nan(n_rows, 1);
Pos_CEP95_m = nan(n_rows, 1);
Pos_Approx_RMSE_m = nan(n_rows, 1);
LoS_Count = nan(n_rows, 1);
NLoS_Count = nan(n_rows, 1);

row = 0;
for p = 1:numel(cfg.pol_types)
    pol = cfg.pol_types{p};
    for s = 1:numel(cfg.scenarios)
        scenario = cfg.scenarios{s};
        row = row + 1;

        leaf = all_results.(pol).(scenario);
        Polarization(row) = string(pol);
        Scenario(row) = string(scenario);
        Ranging_RMSE_m(row) = leaf.s1.rmse_m;
        if isfield(leaf.s1, 'rmse_debiased_m')
            Ranging_RMSE_Debiased_m(row) = leaf.s1.rmse_debiased_m;
        end
        if isfield(leaf.s1, 'bias_m')
            Ranging_Bias_m(row) = leaf.s1.bias_m;
        else
            Ranging_Bias_m(row) = mean(leaf.s1.error_m, 'omitnan');
        end
        if isfield(leaf.s1, 'rmse_rx2_m')
            Ranging_RMSE_Rx2_m(row) = leaf.s1.rmse_rx2_m;
        end
        if isfield(leaf.s1, 'rmse_debiased_rx2_m')
            Ranging_RMSE_Debiased_Rx2_m(row) = leaf.s1.rmse_debiased_rx2_m;
        end
        DoA_RMSE_deg(row) = leaf.s2.rmse_deg;
        DoA_Bias_deg(row) = mean(leaf.s2.error_deg, 'omitnan');
        if isfield(leaf.s2, 'corr_rssd_vs_gt')
            DoA_Corr_RSSD_vs_GT(row) = leaf.s2.corr_rssd_vs_gt;
        end
        if isfield(leaf.s2, 'corr_coef')
            DoA_Corr_Est_vs_GT(row) = leaf.s2.corr_coef;
        end
        [rmse_sel, bias_sel, corr_sel, valid_ratio_sel] = ...
            local_selected_doa_metrics(leaf.s4, leaf.s2);
        DoA_Selected_RMSE_deg(row) = rmse_sel;
        DoA_Selected_Bias_deg(row) = bias_sel;
        DoA_Selected_Corr_vs_GT(row) = corr_sel;
        DoA_Selected_Valid_Ratio(row) = valid_ratio_sel;
        if isfinite(DoA_RMSE_deg(row)) && isfinite(DoA_Selected_RMSE_deg(row))
            DoA_Selected_Improve_deg(row) = DoA_RMSE_deg(row) - DoA_Selected_RMSE_deg(row);
        end
        MRR_mean_dB(row) = leaf.s3.mean_ratio_dB;
        if isfield(leaf.s3, 'mean_sharpness_dB')
            FP_Sharpness_mean_dB(row) = leaf.s3.mean_sharpness_dB;
        end
        Pos_RMSE_m(row) = leaf.s4.rmse_m;
        if isfield(leaf.s4, 'p90_m')
            Pos_P90_m(row) = leaf.s4.p90_m;
        else
            vals = leaf.s4.error_m(isfinite(leaf.s4.error_m));
            if isempty(vals)
                Pos_P90_m(row) = NaN;
            else
                Pos_P90_m(row) = prctile(vals, 90);
            end
        end
        Pos_CEP67_m(row) = leaf.s4.cep67_m;
        Pos_CEP95_m(row) = leaf.s4.cep95_m;
        if isfield(leaf.s4, 'approx_pos_rmse_m')
            Pos_Approx_RMSE_m(row) = leaf.s4.approx_pos_rmse_m;
        end
        if isfield(leaf.s1, 'n_los')
            LoS_Count(row) = leaf.s1.n_los;
        end
        if isfield(leaf.s1, 'n_nlos')
            NLoS_Count(row) = leaf.s1.n_nlos;
        end
    end
end

T = table(Polarization, Scenario, ...
    Ranging_RMSE_m, Ranging_RMSE_Debiased_m, Ranging_Bias_m, ...
    Ranging_RMSE_Rx2_m, Ranging_RMSE_Debiased_Rx2_m, ...
    DoA_RMSE_deg, DoA_Bias_deg, DoA_Corr_RSSD_vs_GT, DoA_Corr_Est_vs_GT, ...
    DoA_Selected_RMSE_deg, DoA_Selected_Bias_deg, DoA_Selected_Corr_vs_GT, ...
    DoA_Selected_Valid_Ratio, DoA_Selected_Improve_deg, ...
    MRR_mean_dB, FP_Sharpness_mean_dB, ...
    Pos_RMSE_m, Pos_P90_m, Pos_CEP67_m, Pos_CEP95_m, Pos_Approx_RMSE_m, ...
    LoS_Count, NLoS_Count);

out_csv = fullfile(cfg.results_dir, 'summary_table.csv');
try
    writetable(T, out_csv);
catch ME
    fallback_csv = fullfile(cfg.results_dir, ...
        ['summary_table_' datestr(now, 'yyyymmdd_HHMMSS') '.csv']);
    warning('generate_summary_table:writeFallback', ...
        'Failed to write %s (%s). Writing fallback file: %s', ...
        out_csv, ME.message, fallback_csv);
    writetable(T, fallback_csv);
end

function [rmse_sel, bias_sel, corr_sel, valid_ratio] = local_selected_doa_metrics(s4, s2)
% LOCAL_SELECTED_DOA_METRICS Computes DoA metrics for Stage4-selected angle.
rmse_sel = NaN;
bias_sel = NaN;
corr_sel = NaN;
valid_ratio = NaN;

if ~isfield(s2, 'doa_gt_deg') || isempty(s2.doa_gt_deg)
    return;
end
theta_gt = s2.doa_gt_deg(:);

if isfield(s4, 'selected_theta_deg') && ~isempty(s4.selected_theta_deg)
    theta_sel = s4.selected_theta_deg(:);
else
    % Fallback to Stage2 DoA when Stage4 selection is unavailable.
    if isfield(s2, 'doa_est_deg') && ~isempty(s2.doa_est_deg)
        theta_sel = s2.doa_est_deg(:);
    else
        return;
    end
end

valid = isfinite(theta_sel) & isfinite(theta_gt);
if isempty(valid) || ~any(valid)
    valid_ratio = 0;
    return;
end
valid_ratio = mean(valid);

err = mod((theta_sel(valid) - theta_gt(valid)) + 180, 360) - 180;
rmse_sel = sqrt(mean(err.^2, 'omitnan'));
bias_sel = mean(err, 'omitnan');

if numel(err) >= 2
    C = corrcoef(theta_sel(valid), theta_gt(valid));
    if numel(C) >= 4
        corr_sel = C(1, 2);
    end
end
end
end
