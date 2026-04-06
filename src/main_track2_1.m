% MAIN_TRACK2_1 Top-level pipeline runner for Track 2-1 CP vs LP comparison.
%
% EXECUTION ORDER
%   1) cfg = setup_config()
%   2) loop over polarization/scenario and run stages 1..4
%   3) generate CP vs LP comparison plots for each scenario/stage
%   4) generate and save summary table

clear; clc;

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

cfg = setup_config();

all_results = struct();

for p = 1:numel(cfg.pol_types)
    pol = cfg.pol_types{p};
    for s = 1:numel(cfg.scenarios)
        scenario = cfg.scenarios{s};
        fprintf('[RUN] %s case %s\n', pol, scenario);

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

for s = 1:numel(cfg.scenarios)
    scenario = cfg.scenarios{s};
    cp = all_results.CP.(scenario);
    lp = all_results.LP.(scenario);

    plot_comparison(cp.s1, lp.s1, 'abs_error_m', ...
        'Ranging Error (m)', scenario, cfg);
    plot_comparison(cp.s2, lp.s2, 'abs_error_deg', ...
        'DoA Error (deg)', scenario, cfg);
    plot_comparison(cp.s3, lp.s3, 'ratio_dB', ...
        'Multipath Rejection Ratio (dB)', scenario, cfg);
    plot_comparison(cp.s4, lp.s4, 'error_m', ...
        '2D Positioning Error (m)', scenario, cfg);
end

T = generate_summary_table(all_results, cfg);
disp(T);

save(fullfile(cfg.results_dir, 'all_results.mat'), 'all_results', 'cfg', 'T');
fprintf('[DONE] Results saved to %s\n', cfg.results_dir);

