function out = run_cp_vs_lp_with_lp_vpol()
% RUN_CP_VS_LP_WITH_LP_VPOL
% Runs CP vs LP comparison with LP guide forced to LP_guide_vpol.csv.
%
% OUTPUT
%   out.summary_table_path
%   out.comparison_table_path
%   out.guide_path

cfg = setup_config();
guide_vpol = fullfile(cfg.data_dir, 'LP_guide_vpol.csv');
if ~isfile(guide_vpol)
    error('run_cp_vs_lp_with_lp_vpol:missingGuide', ...
        'LP vpol guide not found: %s', guide_vpol);
end

% Force LP guide priority to vpol file.
cfg.guide.lp_csv_candidates = [{guide_vpol}, cfg.guide.lp_csv_candidates];
cfg.guide.lp_csv = guide_vpol;

all_results = struct();
for p = 1:numel(cfg.pol_types)
    pol = cfg.pol_types{p};
    for s = 1:numel(cfg.scenarios)
        scenario = cfg.scenarios{s};
        fprintf('[RUN-vpol] %s case %s\n', pol, scenario);
        data = load_case_data(pol, scenario, cfg);
        s1 = stage1_ranging(data, cfg);
        s2 = stage2_doa(data, cfg);
        s3 = stage3_rejection(data, cfg);
        s4 = stage4_positioning(s1, s2, data, cfg);
        all_results.(pol).(scenario).s1 = s1;
        all_results.(pol).(scenario).s2 = s2;
        all_results.(pol).(scenario).s3 = s3;
        all_results.(pol).(scenario).s4 = s4;
    end
end

T = generate_summary_table(all_results, cfg);
summary_path = fullfile(cfg.results_dir, 'summary_table_lp_vpol.csv');
writetable(T, summary_path);

cmp = build_cp_lp_comparison(T);
cmp_path = fullfile(cfg.results_dir, 'cp_vs_lp_comparison_lp_vpol.csv');
writetable(cmp, cmp_path);

fprintf('[DONE-vpol] summary=%s\n', summary_path);
fprintf('[DONE-vpol] compare=%s\n', cmp_path);

out = struct();
out.summary_table_path = summary_path;
out.comparison_table_path = cmp_path;
out.guide_path = guide_vpol;
out.table = T;
out.compare = cmp;
end

function cmp = build_cp_lp_comparison(T)
% BUILD_CP_LP_COMPARISON Builds per-scenario CP-LP delta table.
scenarios = unique(string(T.Scenario), 'stable');
n = numel(scenarios);

Scenario = strings(n, 1);
CP_S1_RMSE_m = nan(n, 1);
LP_S1_RMSE_m = nan(n, 1);
Delta_S1_m = nan(n, 1);

CP_S2_RMSE_deg = nan(n, 1);
LP_S2_RMSE_deg = nan(n, 1);
Delta_S2_deg = nan(n, 1);

CP_S4_RMSE_m = nan(n, 1);
LP_S4_RMSE_m = nan(n, 1);
Delta_S4_m = nan(n, 1);

CP_DoA_Corr = nan(n, 1);
LP_DoA_Corr = nan(n, 1);

for i = 1:n
    scn = scenarios(i);
    Scenario(i) = scn;
    cp_idx = string(T.Polarization) == "CP" & string(T.Scenario) == scn;
    lp_idx = string(T.Polarization) == "LP" & string(T.Scenario) == scn;
    if any(cp_idx)
        cp = T(find(cp_idx, 1, 'first'), :);
        CP_S1_RMSE_m(i) = cp.Ranging_RMSE_m;
        CP_S2_RMSE_deg(i) = cp.DoA_RMSE_deg;
        CP_S4_RMSE_m(i) = cp.Pos_RMSE_m;
        CP_DoA_Corr(i) = cp.DoA_Corr_Est_vs_GT;
    end
    if any(lp_idx)
        lp = T(find(lp_idx, 1, 'first'), :);
        LP_S1_RMSE_m(i) = lp.Ranging_RMSE_m;
        LP_S2_RMSE_deg(i) = lp.DoA_RMSE_deg;
        LP_S4_RMSE_m(i) = lp.Pos_RMSE_m;
        LP_DoA_Corr(i) = lp.DoA_Corr_Est_vs_GT;
    end

    Delta_S1_m(i) = LP_S1_RMSE_m(i) - CP_S1_RMSE_m(i);
    Delta_S2_deg(i) = LP_S2_RMSE_deg(i) - CP_S2_RMSE_deg(i);
    Delta_S4_m(i) = LP_S4_RMSE_m(i) - CP_S4_RMSE_m(i);
end

cmp = table(Scenario, ...
    CP_S1_RMSE_m, LP_S1_RMSE_m, Delta_S1_m, ...
    CP_S2_RMSE_deg, LP_S2_RMSE_deg, Delta_S2_deg, ...
    CP_S4_RMSE_m, LP_S4_RMSE_m, Delta_S4_m, ...
    CP_DoA_Corr, LP_DoA_Corr);
end

