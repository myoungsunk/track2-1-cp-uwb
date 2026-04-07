function out = analyze_rssd_variation_same_incidence(cfg)
% ANALYZE_RSSD_VARIATION_SAME_INCIDENCE
% Quantifies scenario-dependent RSSD variation at identical incidence angles.
%
% For each polarization (CP/LP):
%   - Loads A/B/C data on identical tag grid
%   - Computes broadband RSSD per tag:
%       RSSD = 10log10(mean(|S21_rx1|^2)) - 10log10(mean(|S21_rx2|^2))
%   - Builds per-tag variation across scenarios:
%       std_tag = std([RSSD_A, RSSD_B, RSSD_C])
%   - Aggregates variation by identical incidence angle
%
% OUTPUT FILES
%   results/rssd_variation_tagwise_CP.csv
%   results/rssd_variation_tagwise_LP.csv
%   results/rssd_variation_by_angle_CP.csv
%   results/rssd_variation_by_angle_LP.csv
%   results/rssd_variation_summary.csv
%   results/rssd_variation_same_incidence_cp_lp.png
%
% OUTPUT
%   out.summary_table : table
%   out.figure_png    : char

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end

scenarios = {'A', 'B', 'C'};
pols = {'CP', 'LP'};

summary_pol = strings(numel(pols), 1);
summary_mean_std = nan(numel(pols), 1);
summary_median_std = nan(numel(pols), 1);
summary_p90_std = nan(numel(pols), 1);
summary_mean_span = nan(numel(pols), 1);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1500, 620]);
t = tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

for p = 1:numel(pols)
    pol = pols{p};

    dataA = load_case_data(pol, scenarios{1}, cfg);
    dataB = load_case_data(pol, scenarios{2}, cfg);
    dataC = load_case_data(pol, scenarios{3}, cfg);

    local_assert_same_grid(dataA, dataB, dataC, pol);

    rssdA = local_compute_rssd(dataA);
    rssdB = local_compute_rssd(dataB);
    rssdC = local_compute_rssd(dataC);
    rssd_mat = [rssdA, rssdB, rssdC];

    inc_ang_deg = -dataA.doa_gt_deg(:);  % guide-aligned incidence convention
    range_m = dataA.range_gt_m(:);
    x_m = dataA.pos_mm(:, 1) / 1000;
    y_m = dataA.pos_mm(:, 2) / 1000;

    std_tag = std(rssd_mat, 0, 2, 'omitnan');
    span_tag = max(rssd_mat, [], 2) - min(rssd_mat, [], 2);

    tag_idx = (1:dataA.n_tags).';
    T_tag = table(tag_idx, x_m, y_m, range_m, inc_ang_deg, ...
        rssdA, rssdB, rssdC, std_tag, span_tag, ...
        'VariableNames', {'tag_idx', 'x_m', 'y_m', 'range_m', 'inc_ang_deg', ...
        'rssd_A_dB', 'rssd_B_dB', 'rssd_C_dB', 'std_across_scenarios_dB', 'span_across_scenarios_dB'});
    writetable(T_tag, fullfile(cfg.results_dir, sprintf('rssd_variation_tagwise_%s.csv', pol)));

    [inc_unique, ~, g] = unique(round(inc_ang_deg, 6), 'stable');
    std_mean = splitapply(@(v) mean(v, 'omitnan'), std_tag, g);
    std_med = splitapply(@(v) median(v, 'omitnan'), std_tag, g);
    span_mean = splitapply(@(v) mean(v, 'omitnan'), span_tag, g);
    n_tags = splitapply(@numel, std_tag, g);

    T_angle = table(inc_unique, n_tags, std_mean, std_med, span_mean, ...
        'VariableNames', {'inc_ang_deg', 'n_tags', 'std_mean_dB', 'std_median_dB', 'span_mean_dB'});
    writetable(T_angle, fullfile(cfg.results_dir, sprintf('rssd_variation_by_angle_%s.csv', pol)));

    summary_pol(p) = string(pol);
    summary_mean_std(p) = mean(std_tag, 'omitnan');
    summary_median_std(p) = median(std_tag, 'omitnan');
    summary_p90_std(p) = prctile(std_tag, 90);
    summary_mean_span(p) = mean(span_tag, 'omitnan');

    nexttile;
    scatter(inc_ang_deg, std_tag, 28, 'filled', ...
        'MarkerFaceAlpha', 0.55, ...
        'DisplayName', sprintf('%s tag-wise std', pol));
    hold on;
    [x_line, idx] = sort(inc_unique);
    y_line = std_mean(idx);
    plot(x_line, y_line, 'k-', 'LineWidth', 2.0, 'DisplayName', 'angle-wise mean std');
    grid on;
    xlabel('Incidence angle (deg)');
    ylabel('RSSD variation across scenarios (std, dB)');
    title(sprintf('%s: same-incidence RSSD variation', pol));
    legend('Location', 'best');
end

title(t, 'Scenario-dependent RSSD variation at identical incidence angle');

fig_png = fullfile(cfg.results_dir, 'rssd_variation_same_incidence_cp_lp.png');
fig_fig = fullfile(cfg.results_dir, 'rssd_variation_same_incidence_cp_lp.fig');
savefig(fig, fig_fig);
exportgraphics(fig, fig_png, 'Resolution', 160);
close(fig);

T_summary = table(summary_pol, summary_mean_std, summary_median_std, summary_p90_std, summary_mean_span, ...
    'VariableNames', {'polarization', 'mean_std_dB', 'median_std_dB', 'p90_std_dB', 'mean_span_dB'});
writetable(T_summary, fullfile(cfg.results_dir, 'rssd_variation_summary.csv'));

out = struct();
out.summary_table = T_summary;
out.figure_png = fig_png;
out.figure_fig = fig_fig;
end

function rssd = local_compute_rssd(data)
% LOCAL_COMPUTE_RSSD Broadband RSSD from per-tag S21 spectra.
rss1 = 10 .* log10(max(mean(abs(data.S21_rx1).^2, 2), eps));
rss2 = 10 .* log10(max(mean(abs(data.S21_rx2).^2, 2), eps));
rssd = rss1 - rss2;
end

function local_assert_same_grid(a, b, c, pol)
% LOCAL_ASSERT_SAME_GRID Ensures scenarios share same tag coordinates.
tol = 1e-9;
ok_ab = isequal(size(a.pos_mm), size(b.pos_mm)) && all(abs(a.pos_mm(:) - b.pos_mm(:)) <= tol);
ok_ac = isequal(size(a.pos_mm), size(c.pos_mm)) && all(abs(a.pos_mm(:) - c.pos_mm(:)) <= tol);
if ~(ok_ab && ok_ac)
    error('analyze_rssd_variation_same_incidence:gridMismatch', ...
        '%s scenarios do not share identical tag grid.', pol);
end
end

