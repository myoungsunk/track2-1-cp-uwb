function T = run_counterfactual_analysis(all_results, all_data, cfg)
% RUN_COUNTERFACTUAL_ANALYSIS Runs S1/S2 cross-polarization counterfactuals for S4.
%
% This isolates contribution pathways by mixing range estimator (S1) and
% DoA estimator (S2) across CP/LP while keeping geometry fixed.

scenarios = cfg.scenarios;
combos = { ...
    struct('name', 'CP_S1_CP_S2', 's1_pol', 'CP', 's2_pol', 'CP'), ...
    struct('name', 'LP_S1_LP_S2', 's1_pol', 'LP', 's2_pol', 'LP'), ...
    struct('name', 'CP_S1_LP_S2', 's1_pol', 'CP', 's2_pol', 'LP'), ...
    struct('name', 'LP_S1_CP_S2', 's1_pol', 'LP', 's2_pol', 'CP') ...
    };

cfg_cf = cfg;
if isfield(cfg_cf, 'analysis') && isfield(cfg_cf.analysis, 'counterfactual_disable_doa_gate') ...
        && cfg_cf.analysis.counterfactual_disable_doa_gate
    cfg_cf.doa.invalidate_positioning_if_low_corr = false;
end

n_rows = numel(scenarios) * numel(combos);
Scenario = strings(n_rows, 1);
Combo = strings(n_rows, 1);
S1_Polarization = strings(n_rows, 1);
S2_Polarization = strings(n_rows, 1);
S2_Corr = nan(n_rows, 1);
S2_Valid_For_Positioning = false(n_rows, 1);
DoA_Gate_Disabled = false(n_rows, 1);
S1_RMSE_m = nan(n_rows, 1);
S2_RMSE_deg = nan(n_rows, 1);
Pos_RMSE_m = nan(n_rows, 1);
Pos_P90_m = nan(n_rows, 1);
Pos_CEP95_m = nan(n_rows, 1);

row = 0;
for s = 1:numel(scenarios)
    scn = scenarios{s};
    data_cp = all_data.CP.(scn);
    data_lp = all_data.LP.(scn);
    if any(abs(data_cp.pos_mm(:) - data_lp.pos_mm(:)) > 1e-9)
        error('run_counterfactual_analysis:geometryMismatch', ...
            'CP and LP geometry mismatch in scenario %s.', scn);
    end

    ref_data = data_cp;
    for c = 1:numel(combos)
        row = row + 1;
        cb = combos{c};

        s1 = all_results.(cb.s1_pol).(scn).s1;
        s2 = all_results.(cb.s2_pol).(scn).s2;
        s4 = stage4_positioning(s1, s2, ref_data, cfg_cf);

        Scenario(row) = string(scn);
        Combo(row) = string(cb.name);
        S1_Polarization(row) = string(cb.s1_pol);
        S2_Polarization(row) = string(cb.s2_pol);
        S2_Corr(row) = s2.corr_coef;
        S2_Valid_For_Positioning(row) = logical(s2.is_valid_for_positioning);
        DoA_Gate_Disabled(row) = cfg_cf.doa.invalidate_positioning_if_low_corr == false;
        S1_RMSE_m(row) = s1.rmse_m;
        S2_RMSE_deg(row) = s2.rmse_deg;
        Pos_RMSE_m(row) = s4.rmse_m;
        Pos_P90_m(row) = s4.p90_m;
        Pos_CEP95_m(row) = s4.cep95_m;
    end
end

T = table(Scenario, Combo, S1_Polarization, S2_Polarization, ...
    S2_Corr, S2_Valid_For_Positioning, DoA_Gate_Disabled, ...
    S1_RMSE_m, S2_RMSE_deg, Pos_RMSE_m, Pos_P90_m, Pos_CEP95_m);
T.Delta_vs_LP_S1_LP_S2_m = nan(height(T), 1);
T.Delta_vs_CP_S1_CP_S2_m = nan(height(T), 1);

for s = 1:numel(scenarios)
    scn = string(scenarios{s});
    idx = T.Scenario == scn;
    idx_lp_lp = idx & (T.Combo == "LP_S1_LP_S2");
    idx_cp_cp = idx & (T.Combo == "CP_S1_CP_S2");
    base_lp_lp = NaN;
    base_cp_cp = NaN;
    if any(idx_lp_lp), base_lp_lp = T.Pos_RMSE_m(find(idx_lp_lp, 1, 'first')); end
    if any(idx_cp_cp), base_cp_cp = T.Pos_RMSE_m(find(idx_cp_cp, 1, 'first')); end
    T.Delta_vs_LP_S1_LP_S2_m(idx) = T.Pos_RMSE_m(idx) - base_lp_lp;
    T.Delta_vs_CP_S1_CP_S2_m(idx) = T.Pos_RMSE_m(idx) - base_cp_cp;
end

out_csv = fullfile(cfg.results_dir, 'counterfactual_table.csv');
writetable(T, out_csv);
end

