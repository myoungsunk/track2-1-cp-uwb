function out = plot_lp_guide_vs_sim_incang_rssd_curve(cfg)
% PLOT_LP_GUIDE_VS_SIM_INCANG_RSSD_CURVE Draws LP guide line vs simulation RSSD scatter.
%
% INPUT
%   cfg : struct from setup_config() (optional)
%
% OUTPUT
%   out : struct with saved file paths

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end

if ~isfield(cfg, 'guide') || ~isfield(cfg.guide, 'lp_csv') || ~isfile(cfg.guide.lp_csv)
    error('plot_lp_guide_vs_sim_incang_rssd_curve: guide CSV not found: %s', string(cfg.guide.lp_csv));
end

% Build LP guide line: inc_ang (x) -> mean RSSD (y)
tbl = readtable(cfg.guide.lp_csv, 'VariableNamingRule', 'preserve');
inc_col = find_column_name(tbl, {'inc_ang', 'inc ang'});
mag1_col = find_column_name(tbl, {'mag(S(rx1_p1,tx_p1))', 'mag_s_rx1', 'rx1'});
mag2_col = find_column_name(tbl, {'mag(S(rx2_p1,tx_p1))', 'mag_s_rx2', 'rx2'});

inc_ang = double(tbl.(inc_col));
mag1 = double(tbl.(mag1_col));
mag2 = double(tbl.(mag2_col));

valid = isfinite(inc_ang) & isfinite(mag1) & isfinite(mag2) & (mag1 > 0) & (mag2 > 0);
inc_ang = inc_ang(valid);
pow1 = mag1(valid).^2;
pow2 = mag2(valid).^2;

[g, inc_unique] = findgroups(inc_ang);
pow1_mean = splitapply(@(x) mean(x, 'omitnan'), pow1, g);
pow2_mean = splitapply(@(x) mean(x, 'omitnan'), pow2, g);
rssd_guide = 10 * log10(max(pow1_mean, eps)) - 10 * log10(max(pow2_mean, eps));

[inc_line, line_sort_idx] = sort(inc_unique, 'ascend');
rssd_line = rssd_guide(line_sort_idx);

fig = figure('Visible', 'off', 'Color', 'w');
hold on;
plot(inc_line, rssd_line, 'k-', 'LineWidth', 2.0, 'DisplayName', 'LP guide (line)');

colors = lines(numel(cfg.scenarios));
for s = 1:numel(cfg.scenarios)
    scenario = cfg.scenarios{s};
    data = load_case_data('LP', scenario, cfg);

    rss1_dB = 10 * log10(max(mean(abs(data.S21_rx1).^2, 2), eps));
    rss2_dB = 10 * log10(max(mean(abs(data.S21_rx2).^2, 2), eps));
    rssd_sim = rss1_dB - rss2_dB;

    % Guide inc_ang convention is opposite to GT azimuth in this pipeline.
    inc_sim = -data.doa_gt_deg(:);

    scatter(inc_sim, rssd_sim, 34, ...
        'MarkerFaceColor', colors(s, :), ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.9, ...
        'DisplayName', sprintf('LP sim case%s (scatter)', scenario));
end

grid on;
xlabel('Incidence angle (deg)');
ylabel('RSSD (dB)');
title('LP guide vs simulation inc\_ang-RSSD curve');
legend('Location', 'best');

png_path = fullfile(cfg.results_dir, 'lp_guide_vs_sim_incang_rssd_curve.png');
fig_path = fullfile(cfg.results_dir, 'lp_guide_vs_sim_incang_rssd_curve.fig');
savefig(fig, fig_path);
exportgraphics(fig, png_path, 'Resolution', 150);
close(fig);

out = struct();
out.png_path = png_path;
out.fig_path = fig_path;
end

function col_name = find_column_name(tbl, patterns)
% FIND_COLUMN_NAME Finds table column by normalized substring matching.
names = tbl.Properties.VariableNames;
norm_names = normalize_tokens(names);
norm_patterns = normalize_tokens(patterns);

for p = 1:numel(norm_patterns)
    hit = contains(norm_names, norm_patterns{p});
    if any(hit)
        col_name = names{find(hit, 1, 'first')};
        return;
    end
end

error('plot_lp_guide_vs_sim_incang_rssd_curve:columnNotFound', ...
    'Required guide column not found. Available columns: %s', strjoin(names, ', '));
end

function out = normalize_tokens(in)
% NORMALIZE_TOKENS Lowercases and strips non-alnum chars.
out = cell(size(in));
for i = 1:numel(in)
    s = lower(char(string(in{i})));
    s = regexprep(s, '[^a-z0-9]', '');
    out{i} = s;
end
end

