function [T_scenario, T_aggregate] = sweep_fp_window_sensitivity(cfg, window_list_ns)
% SWEEP_FP_WINDOW_SENSITIVITY Sweeps Stage3 fp_window_ns and summarizes sensitivity.
%
% INPUT
%   cfg            : struct from setup_config()
%   window_list_ns : [K x 1] window values in ns (default: [1 1.5 2 3 5 7 10])
%
% OUTPUT
%   T_scenario  : per-window, per-scenario table
%   T_aggregate : per-window aggregate summary table
%
% SIDE EFFECTS
%   Writes:
%   - results/fp_window_sensitivity_by_scenario.csv
%   - results/fp_window_sensitivity_aggregate.csv
%   - results/fp_window_sensitivity_delta_cp_lp.png
%   - results/fp_window_sensitivity_delta_cp_lp.fig

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end
if nargin < 2 || isempty(window_list_ns)
    window_list_ns = [1 1.5 2 3 5 7 10];
end
window_list_ns = window_list_ns(:);

scenarios = cfg.scenarios(:);
n_w = numel(window_list_ns);
n_s = numel(scenarios);

rows = n_w * n_s;
Window_ns = nan(rows, 1);
Scenario = strings(rows, 1);
CP_MRR_dB = nan(rows, 1);
LP_MRR_dB = nan(rows, 1);
Delta_CP_minus_LP_MRR_dB = nan(rows, 1);
CP_MRR_LoS_dB = nan(rows, 1);
CP_MRR_NLoS_dB = nan(rows, 1);
LP_MRR_LoS_dB = nan(rows, 1);
LP_MRR_NLoS_dB = nan(rows, 1);
CP_Sharpness_dB = nan(rows, 1);
LP_Sharpness_dB = nan(rows, 1);
Delta_CP_minus_LP_Sharpness_dB = nan(rows, 1);

row = 0;
for wi = 1:n_w
    cfg_win = cfg;
    cfg_win.fp_window_ns = window_list_ns(wi);
    for si = 1:n_s
        sc = scenarios{si};
        d_cp = load_case_data('CP', sc, cfg_win);
        d_lp = load_case_data('LP', sc, cfg_win);
        s3_cp = stage3_rejection(d_cp, cfg_win);
        s3_lp = stage3_rejection(d_lp, cfg_win);

        row = row + 1;
        Window_ns(row) = window_list_ns(wi);
        Scenario(row) = string(sc);
        CP_MRR_dB(row) = s3_cp.mean_ratio_dB;
        LP_MRR_dB(row) = s3_lp.mean_ratio_dB;
        Delta_CP_minus_LP_MRR_dB(row) = s3_cp.mean_ratio_dB - s3_lp.mean_ratio_dB;
        CP_MRR_LoS_dB(row) = s3_cp.mean_los_dB;
        CP_MRR_NLoS_dB(row) = s3_cp.mean_nlos_dB;
        LP_MRR_LoS_dB(row) = s3_lp.mean_los_dB;
        LP_MRR_NLoS_dB(row) = s3_lp.mean_nlos_dB;
        CP_Sharpness_dB(row) = s3_cp.mean_sharpness_dB;
        LP_Sharpness_dB(row) = s3_lp.mean_sharpness_dB;
        Delta_CP_minus_LP_Sharpness_dB(row) = s3_cp.mean_sharpness_dB - s3_lp.mean_sharpness_dB;
    end
end

T_scenario = table(Window_ns, Scenario, ...
    CP_MRR_dB, LP_MRR_dB, Delta_CP_minus_LP_MRR_dB, ...
    CP_MRR_LoS_dB, CP_MRR_NLoS_dB, LP_MRR_LoS_dB, LP_MRR_NLoS_dB, ...
    CP_Sharpness_dB, LP_Sharpness_dB, Delta_CP_minus_LP_Sharpness_dB);

u_w = unique(Window_ns, 'stable');
n_u = numel(u_w);
Agg_Window_ns = nan(n_u, 1);
Delta_MRR_Avg_dB = nan(n_u, 1);
Delta_MRR_Min_dB = nan(n_u, 1);
Delta_MRR_Max_dB = nan(n_u, 1);
Delta_Sharpness_Avg_dB = nan(n_u, 1);

for i = 1:n_u
    sel = Window_ns == u_w(i);
    dm = Delta_CP_minus_LP_MRR_dB(sel);
    ds = Delta_CP_minus_LP_Sharpness_dB(sel);
    Agg_Window_ns(i) = u_w(i);
    Delta_MRR_Avg_dB(i) = mean(dm, 'omitnan');
    Delta_MRR_Min_dB(i) = min(dm);
    Delta_MRR_Max_dB(i) = max(dm);
    Delta_Sharpness_Avg_dB(i) = mean(ds, 'omitnan');
end

T_aggregate = table(Agg_Window_ns, Delta_MRR_Avg_dB, Delta_MRR_Min_dB, ...
    Delta_MRR_Max_dB, Delta_Sharpness_Avg_dB);

writetable(T_scenario, fullfile(cfg.results_dir, 'fp_window_sensitivity_by_scenario.csv'));
writetable(T_aggregate, fullfile(cfg.results_dir, 'fp_window_sensitivity_aggregate.csv'));

fig = figure('Visible', 'off', 'Color', 'w');
plot(T_aggregate.Agg_Window_ns, T_aggregate.Delta_MRR_Avg_dB, 'k-o', 'LineWidth', 1.8);
hold on;
plot(T_aggregate.Agg_Window_ns, T_aggregate.Delta_MRR_Min_dB, 'b--s', 'LineWidth', 1.2);
plot(T_aggregate.Agg_Window_ns, T_aggregate.Delta_MRR_Max_dB, 'r--^', 'LineWidth', 1.2);
grid on;
xlabel('fp\_window\_ns');
ylabel('\Delta MRR = CP - LP (dB)');
title('Stage3 fp\_window sensitivity');
legend({'Avg across scenarios', 'Min across scenarios', 'Max across scenarios'}, 'Location', 'best');
savefig(fig, fullfile(cfg.results_dir, 'fp_window_sensitivity_delta_cp_lp.fig'));
exportgraphics(fig, fullfile(cfg.results_dir, 'fp_window_sensitivity_delta_cp_lp.png'), 'Resolution', 150);
close(fig);
end

