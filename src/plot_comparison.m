function plot_comparison(results_cp, results_lp, metric_field, stage_label, scenario, cfg)
% PLOT_COMPARISON Plots CP vs LP CDF for one metric and saves figure files.
%
% INPUT
%   results_cp   : struct stage result for CP
%   results_lp   : struct stage result for LP
%   metric_field : char   field name to plot from each result struct
%   stage_label  : char   axis/title label
%   scenario     : char   scenario ID ('A'|'B'|'C')
%   cfg          : struct from setup_config()

scenario = upper(char(string(scenario)));

if ~isfield(results_cp, metric_field)
    error('plot_comparison: metric field "%s" not found in CP result.', metric_field);
end
if ~isfield(results_lp, metric_field)
    error('plot_comparison: metric field "%s" not found in LP result.', metric_field);
end

metric_cp = double(results_cp.(metric_field)(:));
metric_lp = double(results_lp.(metric_field)(:));
[x_cp, y_cp] = local_cdf(metric_cp);
[x_lp, y_lp] = local_cdf(metric_lp);

fig = figure('Visible', 'off', 'Color', 'w');
plot(x_cp, y_cp, 'b-', 'LineWidth', 1.8); hold on;
plot(x_lp, y_lp, 'r--', 'LineWidth', 1.8);
grid on;
legend({'CP', 'LP'}, 'Location', 'best');
title(sprintf('Scenario %s - %s', scenario, stage_label));
xlabel(stage_label);
ylabel('CDF');

safe_label = sanitize_filename(stage_label);
base_name = sprintf('cdf_%s_scenario%s', safe_label, scenario);
fname_fig = fullfile(cfg.results_dir, [base_name '.fig']);
fname_png = fullfile(cfg.results_dir, [base_name '.png']);

savefig(fig, fname_fig);
exportgraphics(fig, fname_png, 'Resolution', 150);
close(fig);
end

function [x, y] = local_cdf(v)
% LOCAL_CDF Returns empirical CDF axes from vector data.
v = v(:);
v = v(isfinite(v));
x = sort(v, 'ascend');
if isempty(x)
    y = [];
else
    y = (1:numel(x)).' ./ numel(x);
end
end

function out = sanitize_filename(stage_label)
% SANITIZE_FILENAME Maps stage labels to stable file-name tokens.
label = strtrim(char(stage_label));

switch label
    case 'Ranging Error (m)'
        out = 'Ranging_Error_m';
    case 'DoA Error (deg)'
        out = 'DoA_Error_deg';
    case 'Multipath Rejection Ratio (dB)'
        out = 'MRR_dB';
    case '2D Positioning Error (m)'
        out = '2D_Pos_Error_m';
    otherwise
        out = regexprep(label, '[\s\(\)/\\\-]+', '_');
        out = regexprep(out, '[^a-zA-Z0-9_]', '');
        out = regexprep(out, '_+', '_');
        out = regexprep(out, '^_|_$', '');
end
end

