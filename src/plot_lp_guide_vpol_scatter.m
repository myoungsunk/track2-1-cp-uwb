function out = plot_lp_guide_vpol_scatter(cfg, guide_csv_path)
% PLOT_LP_GUIDE_VPOL_SCATTER Draws LP vpol guide inc_ang-RSSD scatter.
%
% INPUT
%   cfg            : struct from setup_config() (optional)
%   guide_csv_path : path to LP guide CSV (optional)
%
% OUTPUT
%   out : struct with saved file paths and key metadata

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end
if nargin < 2 || isempty(guide_csv_path)
    guide_csv_path = fullfile(cfg.data_dir, 'LP_guide_vpol.csv');
end
guide_csv_path = char(string(guide_csv_path));
if ~isfile(guide_csv_path)
    error('plot_lp_guide_vpol_scatter:fileNotFound', ...
        'Guide CSV not found: %s', guide_csv_path);
end

tbl = readtable(guide_csv_path, 'VariableNamingRule', 'preserve');
inc_col = find_column_name(tbl, {'inc_ang', 'inc ang', 'inc_ang_deg'}, true);

% vpol file layout:
%   mag(S(rx2_p1,rx1_p1)) and mag(S(tx_p1,rx1_p1))
% For consistency with RSSD := RSS1 - RSS2, we map:
%   RSS1 <-> mag(S(tx_p1,rx1_p1))
%   RSS2 <-> mag(S(rx2_p1,rx1_p1))
mag_tx_col = find_column_name(tbl, { ...
    'mag(S(tx_p1,rx1_p1))', 'mag(S(rx1_p1,tx_p1))', 'mag_s_rx1', 'rx1'}, true);
mag_rx2_col = find_column_name(tbl, { ...
    'mag(S(rx2_p1,rx1_p1))', 'mag(S(rx2_p1,tx_p1))', 'mag_s_rx2', 'rx2'}, true);

inc_ang = double(tbl.(inc_col));
mag_tx = double(tbl.(mag_tx_col));
mag_rx2 = double(tbl.(mag_rx2_col));

valid = isfinite(inc_ang) & isfinite(mag_tx) & isfinite(mag_rx2) & ...
    (mag_tx > 0) & (mag_rx2 > 0);
inc_ang = inc_ang(valid);
mag_tx = mag_tx(valid);
mag_rx2 = mag_rx2(valid);
if isempty(inc_ang)
    error('plot_lp_guide_vpol_scatter:emptyData', ...
        'No valid rows in %s', guide_csv_path);
end

rssd_dB = 20 .* log10(max(mag_tx, eps) ./ max(mag_rx2, eps));
[g, inc_unique] = findgroups(inc_ang);
rssd_mean = splitapply(@(x) mean(x, 'omitnan'), rssd_dB, g);
rssd_std = splitapply(@(x) std(x, 0, 'omitnan'), rssd_dB, g);
rssd_p10 = splitapply(@(x) prctile(x, 10), rssd_dB, g);
rssd_p90 = splitapply(@(x) prctile(x, 90), rssd_dB, g);

[inc_line, idx_sort] = sort(inc_unique, 'ascend');
rssd_line = rssd_mean(idx_sort);
rssd_std_line = rssd_std(idx_sort);
rssd_p10_line = rssd_p10(idx_sort);
rssd_p90_line = rssd_p90(idx_sort);

fig = figure('Visible', 'off', 'Color', 'w');
hold on;
scatter(inc_ang, rssd_dB, 11, ...
    'MarkerFaceColor', [0.12, 0.47, 0.71], ...
    'MarkerEdgeColor', 'none', ...
    'MarkerFaceAlpha', 0.18, ...
    'DisplayName', 'LP vpol guide samples');
plot(inc_line, rssd_line, 'k-', 'LineWidth', 2.1, ...
    'DisplayName', 'Mean RSSD by incidence angle');
plot(inc_line, rssd_p10_line, '--', 'LineWidth', 1.2, ...
    'Color', [0.85, 0.33, 0.10], 'DisplayName', 'P10');
plot(inc_line, rssd_p90_line, '--', 'LineWidth', 1.2, ...
    'Color', [0.47, 0.67, 0.19], 'DisplayName', 'P90');

grid on;
xlabel('Incidence angle (deg)');
ylabel('RSSD (dB) = 20log10(|S(tx,rx1)| / |S(rx2,rx1)|)');
title('LP vpol guide: incidence angle vs RSSD scatter');
legend('Location', 'best');
hold off;

png_path = fullfile(cfg.results_dir, 'lp_guide_vpol_scatter.png');
fig_path = fullfile(cfg.results_dir, 'lp_guide_vpol_scatter.fig');
savefig(fig, fig_path);
exportgraphics(fig, png_path, 'Resolution', 170);
close(fig);

summary_tbl = table(inc_line, rssd_line, rssd_std_line, rssd_p10_line, rssd_p90_line, ...
    'VariableNames', {'inc_ang_deg', 'rssd_mean_dB', 'rssd_std_dB', 'rssd_p10_dB', 'rssd_p90_dB'});
summary_csv = fullfile(cfg.results_dir, 'lp_guide_vpol_curve_summary.csv');
writetable(summary_tbl, summary_csv);

out = struct();
out.guide_csv = guide_csv_path;
out.png_path = png_path;
out.fig_path = fig_path;
out.summary_csv = summary_csv;
out.n_samples = numel(rssd_dB);
out.n_angles = numel(inc_line);
end

function col_name = find_column_name(tbl, patterns, required)
% FIND_COLUMN_NAME Robust column finder: exact-normalized first, then substring.
names = tbl.Properties.VariableNames;
norm_names = normalize_tokens(names);
norm_patterns = normalize_tokens(patterns);
col_name = '';

for p = 1:numel(norm_patterns)
    eq_hit = strcmp(norm_names, norm_patterns{p});
    if any(eq_hit)
        col_name = names{find(eq_hit, 1, 'first')};
        return;
    end
end
for p = 1:numel(norm_patterns)
    sub_hit = contains(norm_names, norm_patterns{p});
    if any(sub_hit)
        col_name = names{find(sub_hit, 1, 'first')};
        return;
    end
end

if required
    error('plot_lp_guide_vpol_scatter:columnNotFound', ...
        'Required column not found. Available columns: %s', strjoin(names, ', '));
end
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

