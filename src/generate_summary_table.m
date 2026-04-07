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
Ranging_Bias_m = nan(n_rows, 1);
DoA_RMSE_deg = nan(n_rows, 1);
DoA_Bias_deg = nan(n_rows, 1);
MRR_mean_dB = nan(n_rows, 1);
FP_Sharpness_mean_dB = nan(n_rows, 1);
Pos_RMSE_m = nan(n_rows, 1);
Pos_P90_m = nan(n_rows, 1);
Pos_CEP67_m = nan(n_rows, 1);
Pos_CEP95_m = nan(n_rows, 1);
Pos_Approx_RMSE_m = nan(n_rows, 1);

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
        Ranging_Bias_m(row) = mean(leaf.s1.error_m, 'omitnan');
        DoA_RMSE_deg(row) = leaf.s2.rmse_deg;
        DoA_Bias_deg(row) = mean(leaf.s2.error_deg, 'omitnan');
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
    end
end

T = table(Polarization, Scenario, ...
    Ranging_RMSE_m, Ranging_Bias_m, ...
    DoA_RMSE_deg, DoA_Bias_deg, ...
    MRR_mean_dB, FP_Sharpness_mean_dB, ...
    Pos_RMSE_m, Pos_P90_m, Pos_CEP67_m, Pos_CEP95_m, Pos_Approx_RMSE_m);

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
end
