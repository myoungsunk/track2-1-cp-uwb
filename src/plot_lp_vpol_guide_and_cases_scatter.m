function out = plot_lp_vpol_guide_and_cases_scatter(cfg, guide_csv, case_csv_list)
% PLOT_LP_VPOL_GUIDE_AND_CASES_SCATTER
%   Draw LP vpol guide as a line and LP case A/B/C as scatter.
%
% INPUT
%   cfg          : struct from setup_config() (optional)
%   guide_csv    : path to LP_guide_vpol.csv (optional)
%   case_csv_list: cellstr paths for LP_case*_new_vpol.csv (optional)
%
% OUTPUT
%   out: struct with output file paths and summary

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end
if nargin < 2 || isempty(guide_csv)
    guide_csv = fullfile(cfg.data_dir, 'LP_guide_vpol.csv');
end
if nargin < 3 || isempty(case_csv_list)
    case_csv_list = { ...
        fullfile(cfg.data_dir, 'LP_caseA_new_vpol.csv'), ...
        fullfile(cfg.data_dir, 'LP_caseB_new_vpol.csv'), ...
        fullfile(cfg.data_dir, 'LP_caseC_new_vpol.csv') ...
        };
end

guide_csv = char(string(guide_csv));
if ~isfile(guide_csv)
    error('plot_lp_vpol_guide_and_cases_scatter:guideMissing', ...
        'Guide CSV not found: %s', guide_csv);
end

for i = 1:numel(case_csv_list)
    if ~isfile(case_csv_list{i})
        error('plot_lp_vpol_guide_and_cases_scatter:caseMissing', ...
            'Case CSV not found: %s', case_csv_list{i});
    end
end

% ---------------- Guide line ----------------
tg = readtable(guide_csv, 'VariableNamingRule', 'preserve');
inc_col = local_find_col(tg, {'inc_ang', 'inc ang', 'inc_ang_deg'});
mag_tx_col = local_find_col(tg, {'mag(S(tx_p1,rx1_p1))', 'mag(S(rx1_p1,tx_p1))', 'rx1'});
mag_rx2_col = local_find_col(tg, {'mag(S(rx2_p1,rx1_p1))', 'mag(S(rx2_p1,tx_p1))', 'rx2'});

inc_g = double(tg.(inc_col));
mag_tx_g = double(tg.(mag_tx_col));
mag_rx2_g = double(tg.(mag_rx2_col));
valid_g = isfinite(inc_g) & isfinite(mag_tx_g) & isfinite(mag_rx2_g) & ...
    (mag_tx_g > 0) & (mag_rx2_g > 0);
inc_g = inc_g(valid_g);
mag_tx_g = mag_tx_g(valid_g);
mag_rx2_g = mag_rx2_g(valid_g);

rssd_g = 20 .* log10(max(mag_tx_g, eps) ./ max(mag_rx2_g, eps));
[gg, inc_u] = findgroups(inc_g);
rssd_u = splitapply(@(x) mean(x, 'omitnan'), rssd_g, gg);
[inc_line, idx_sort] = sort(inc_u, 'ascend');
rssd_line = rssd_u(idx_sort);

% ---------------- Case scatters ----------------
case_names = {'A', 'B', 'C'};
colors = lines(numel(case_csv_list));
all_case = struct('scenario', {}, 'inc_ang_deg', {}, 'rssd_dB', {}, 'zero_rx2_rows', {}, 'n_tags', {});

for i = 1:numel(case_csv_list)
    tc = readtable(case_csv_list{i}, 'VariableNamingRule', 'preserve');
    x_col = local_find_col(tc, {'x_coord', 'xcoord'});
    y_col = local_find_col(tc, {'y_coord', 'ycoord'});
    m1_col = local_find_col(tc, {'mag(S(rx1_p1,tx_p1))', 'rx1'});
    m2_col = local_find_col(tc, {'mag(S(rx2_p1,tx_p1))', 'rx2'});

    x = double(tc.(x_col));
    y = double(tc.(y_col));
    m1 = double(tc.(m1_col));
    m2 = double(tc.(m2_col));
    valid = isfinite(x) & isfinite(y) & isfinite(m1) & isfinite(m2) & (m1 >= 0) & (m2 >= 0);
    x = x(valid);
    y = y(valid);
    m1 = m1(valid);
    m2 = m2(valid);

    zero_rows = sum(m2 == 0);
    key = string(round(x, 6)) + "_" + string(round(y, 6));
    [gk, key_u] = findgroups(key);
    p1_mean = splitapply(@(z) mean(z.^2, 'omitnan'), m1, gk);
    p2_mean = splitapply(@(z) mean(z.^2, 'omitnan'), m2, gk);
    x_u = splitapply(@(z) z(1), x, gk);
    y_u = splitapply(@(z) z(1), y, gk);

    rss1 = 10 .* log10(max(p1_mean, eps));
    rss2 = 10 .* log10(max(p2_mean, eps));
    rssd = rss1 - rss2;
    inc = -atan2d(y_u, x_u);

    scn = sprintf('case%s', case_names{min(i, numel(case_names))});
    all_case(i).scenario = scn; %#ok<AGROW>
    all_case(i).inc_ang_deg = inc(:); %#ok<AGROW>
    all_case(i).rssd_dB = rssd(:); %#ok<AGROW>
    all_case(i).zero_rx2_rows = zero_rows; %#ok<AGROW>
    all_case(i).n_tags = numel(key_u); %#ok<AGROW>
end

% ---------------- Plot (single unified y-scale) ----------------
fig = figure('Visible', 'off', 'Color', 'w');

plot(inc_line, rssd_line, 'k-', 'LineWidth', 2.2, 'DisplayName', 'LP guide vpol (line)');
xlabel('Incidence angle (deg)');
ylabel('RSSD (dB)');
grid on; hold on;

for i = 1:numel(all_case)
    scatter(all_case(i).inc_ang_deg, all_case(i).rssd_dB, 36, ...
        'MarkerFaceColor', colors(i, :), ...
        'MarkerEdgeColor', 'k', ...
        'LineWidth', 0.3, ...
        'DisplayName', sprintf('LP %s (scatter)', all_case(i).scenario));
end

all_y = rssd_line(:);
for i = 1:numel(all_case)
    all_y = [all_y; all_case(i).rssd_dB(:)]; %#ok<AGROW>
end
all_y = all_y(isfinite(all_y));
if ~isempty(all_y)
    y_min = min(all_y);
    y_max = max(all_y);
    pad = max(1.0, 0.08 * (y_max - y_min));
    ylim([y_min - pad, y_max + pad]);
end

title('LP vpol guide (line) vs LP case A/B/C (scatter) - unified y-scale');
legend('Location', 'best');

png_path = fullfile(cfg.results_dir, 'lp_vpol_guide_vs_cases_scatter.png');
fig_path = fullfile(cfg.results_dir, 'lp_vpol_guide_vs_cases_scatter.fig');
savefig(fig, fig_path);
exportgraphics(fig, png_path, 'Resolution', 170);
close(fig);

% Save numeric summary
sum_scn = strings(numel(all_case), 1);
sum_n_tags = nan(numel(all_case), 1);
sum_zero_rows = nan(numel(all_case), 1);
sum_rssd_min = nan(numel(all_case), 1);
sum_rssd_max = nan(numel(all_case), 1);
sum_rssd_mean = nan(numel(all_case), 1);
for i = 1:numel(all_case)
    sum_scn(i) = string(all_case(i).scenario);
    sum_n_tags(i) = all_case(i).n_tags;
    sum_zero_rows(i) = all_case(i).zero_rx2_rows;
    v = all_case(i).rssd_dB;
    sum_rssd_min(i) = min(v);
    sum_rssd_max(i) = max(v);
    sum_rssd_mean(i) = mean(v, 'omitnan');
end
summary_table = table(sum_scn, sum_n_tags, sum_zero_rows, sum_rssd_min, sum_rssd_max, sum_rssd_mean, ...
    'VariableNames', {'scenario', 'n_tags', 'zero_rx2_rows', 'rssd_min_dB', 'rssd_max_dB', 'rssd_mean_dB'});
summary_csv = fullfile(cfg.results_dir, 'lp_vpol_guide_vs_cases_scatter_summary.csv');
writetable(summary_table, summary_csv);

out = struct();
out.guide_csv = guide_csv;
out.case_csv_list = case_csv_list;
out.png_path = png_path;
out.fig_path = fig_path;
out.summary_csv = summary_csv;
end

function col = local_find_col(tbl, patterns)
names = tbl.Properties.VariableNames;
norm_names = local_norm(names);
norm_patterns = local_norm(patterns);
for p = 1:numel(norm_patterns)
    eq_hit = strcmp(norm_names, norm_patterns{p});
    if any(eq_hit)
        col = names{find(eq_hit, 1, 'first')};
        return;
    end
end
for p = 1:numel(norm_patterns)
    sub_hit = contains(norm_names, norm_patterns{p});
    if any(sub_hit)
        col = names{find(sub_hit, 1, 'first')};
        return;
    end
end
error('plot_lp_vpol_guide_and_cases_scatter:columnNotFound', ...
    'Column not found. Candidates=%s | Available=%s', ...
    strjoin(patterns, '/'), strjoin(names, ', '));
end

function out = local_norm(in)
out = cell(size(in));
for i = 1:numel(in)
    s = lower(char(string(in{i})));
    s = regexprep(s, '[^a-z0-9]', '');
    out{i} = s;
end
end
