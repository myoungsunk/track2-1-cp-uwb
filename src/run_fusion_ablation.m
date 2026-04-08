function T = run_fusion_ablation(all_results, all_data, cfg)
% RUN_FUSION_ABLATION Compares Stage4 WLS vs direct Cartesian conversion.

n_rows = numel(cfg.pol_types) * numel(cfg.scenarios);
Polarization = strings(n_rows, 1);
Scenario = strings(n_rows, 1);
DoA_Corr = nan(n_rows, 1);
DoA_Valid = false(n_rows, 1);
WLS_RMSE_m = nan(n_rows, 1);
Direct_RMSE_m = nan(n_rows, 1);
Delta_RMSE_m = nan(n_rows, 1);
WLS_P90_m = nan(n_rows, 1);
Direct_P90_m = nan(n_rows, 1);
Delta_P90_m = nan(n_rows, 1);
WLS_CEP95_m = nan(n_rows, 1);
Direct_CEP95_m = nan(n_rows, 1);
Delta_CEP95_m = nan(n_rows, 1);

cfg_direct = cfg;
cfg_direct.fusion.method = 'cartesian_direct';

row = 0;
for p = 1:numel(cfg.pol_types)
    pol = cfg.pol_types{p};
    for s = 1:numel(cfg.scenarios)
        scn = cfg.scenarios{s};
        row = row + 1;

        leaf = all_results.(pol).(scn);
        data = all_data.(pol).(scn);
        s4_direct = stage4_positioning(leaf.s1, leaf.s2, data, cfg_direct);

        Polarization(row) = string(pol);
        Scenario(row) = string(scn);
        DoA_Corr(row) = leaf.s2.corr_coef;
        DoA_Valid(row) = logical(leaf.s2.is_valid_for_positioning);
        WLS_RMSE_m(row) = leaf.s4.rmse_m;
        Direct_RMSE_m(row) = s4_direct.rmse_m;
        Delta_RMSE_m(row) = leaf.s4.rmse_m - s4_direct.rmse_m;
        WLS_P90_m(row) = leaf.s4.p90_m;
        Direct_P90_m(row) = s4_direct.p90_m;
        Delta_P90_m(row) = leaf.s4.p90_m - s4_direct.p90_m;
        WLS_CEP95_m(row) = leaf.s4.cep95_m;
        Direct_CEP95_m(row) = s4_direct.cep95_m;
        Delta_CEP95_m(row) = leaf.s4.cep95_m - s4_direct.cep95_m;
    end
end

T = table(Polarization, Scenario, DoA_Corr, DoA_Valid, ...
    WLS_RMSE_m, Direct_RMSE_m, Delta_RMSE_m, ...
    WLS_P90_m, Direct_P90_m, Delta_P90_m, ...
    WLS_CEP95_m, Direct_CEP95_m, Delta_CEP95_m);

out_csv = fullfile(cfg.results_dir, 'fusion_ablation_table.csv');
writetable(T, out_csv);
end

