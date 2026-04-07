function out = plot_guide_vs_affine_line(cfg)
% PLOT_GUIDE_VS_AFFINE_LINE Plot guide RSSD curve vs affine fitted line for CP/LP.
%
% INPUT
%   cfg : struct from setup_config() (optional)
%
% OUTPUT
%   out : struct with saved image paths

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end

out = struct();
out.CP = '';
out.LP = '';

for i = 1:numel(cfg.pol_types)
    pol = upper(char(string(cfg.pol_types{i})));
    guide_path = resolve_guide_path(pol, cfg);
    if isempty(guide_path)
        warning('plot_guide_vs_affine_line:noGuide', 'Guide CSV not found for %s.', pol);
        continue;
    end

    tbl = readtable(guide_path, 'VariableNamingRule', 'preserve');
    cc = cfg.guide.column_candidates;
    inc_col = find_column_name(tbl, cc.inc_ang, true);
    mag1_col = find_column_name(tbl, cc.mag_rx1, true);
    mag2_col = find_column_name(tbl, cc.mag_rx2, true);

    inc_ang = double(tbl.(inc_col));
    mag1 = double(tbl.(mag1_col));
    mag2 = double(tbl.(mag2_col));

    valid = isfinite(inc_ang) & isfinite(mag1) & isfinite(mag2) & (mag1 > 0) & (mag2 > 0);
    inc_ang = inc_ang(valid);
    mag1 = mag1(valid);
    mag2 = mag2(valid);
    if isempty(inc_ang)
        warning('plot_guide_vs_affine_line:empty', 'No valid rows for %s guide.', pol);
        continue;
    end

    pow1 = mag1.^2;
    pow2 = mag2.^2;
    [g, inc_unique] = findgroups(inc_ang);
    pow1_mean = splitapply(@(x) mean(x, 'omitnan'), pow1, g);
    pow2_mean = splitapply(@(x) mean(x, 'omitnan'), pow2, g);
    rssd_mean = 10 .* log10(max(pow1_mean, eps)) - 10 .* log10(max(pow2_mean, eps));

    [inc_sorted, idx_sort] = sort(inc_unique, 'ascend');
    rssd_sorted = rssd_mean(idx_sort);

    p = polyfit(rssd_sorted, inc_sorted, 1); % angle ~= a*rssd + b
    ang_grid = linspace(min(inc_sorted), max(inc_sorted), 400).';
    if abs(p(1)) < 1e-12
        rssd_affine = nan(size(ang_grid));
    else
        rssd_affine = (ang_grid - p(2)) ./ p(1); % rssd ~= (angle-b)/a
    end

    fig = figure('Visible', 'off', 'Color', 'w');
    hold on;
    plot(inc_sorted, rssd_sorted, 'k-', 'LineWidth', 2.0, 'DisplayName', sprintf('%s guide (actual)', pol));
    scatter(inc_sorted, rssd_sorted, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.45, ...
        'DisplayName', sprintf('%s guide samples', pol));
    plot(ang_grid, rssd_affine, 'r--', 'LineWidth', 2.0, ...
        'DisplayName', sprintf('%s affine line', pol));
    grid on;
    xlabel('Incidence angle (deg)');
    ylabel('RSSD (dB)');
    title(sprintf('%s: Guide curve vs affine line', pol));
    legend('Location', 'best');
    hold off;

    out_png = fullfile(cfg.results_dir, sprintf('%s_guide_vs_affine_line.png', lower(pol)));
    out_fig = fullfile(cfg.results_dir, sprintf('%s_guide_vs_affine_line.fig', lower(pol)));
    savefig(fig, out_fig);
    exportgraphics(fig, out_png, 'Resolution', 180);
    close(fig);

    out.(pol) = out_png;
    fprintf('[plot_guide_vs_affine_line] %s -> %s\n', pol, out_png);
end
end

function guide_path = resolve_guide_path(pol, cfg)
guide_path = '';
if strcmp(pol, 'CP')
    candidates = local_collect_candidates(cfg.guide, 'cp_csv_candidates', 'cp_csv');
elseif strcmp(pol, 'LP')
    candidates = local_collect_candidates(cfg.guide, 'lp_csv_candidates', 'lp_csv');
else
    candidates = {};
end

for i = 1:numel(candidates)
    p = char(string(candidates{i}));
    if isfile(p)
        guide_path = p;
        return;
    end
end
end

function candidates = local_collect_candidates(guide_struct, list_field, single_field)
candidates = {};
if isfield(guide_struct, list_field) && ~isempty(guide_struct.(list_field))
    candidates = [candidates, guide_struct.(list_field)]; %#ok<AGROW>
end
if isfield(guide_struct, single_field) && ~isempty(guide_struct.(single_field))
    candidates{end+1} = guide_struct.(single_field); %#ok<AGROW>
end
end

function col_name = find_column_name(tbl, patterns, required)
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
    error('plot_guide_vs_affine_line:columnNotFound', ...
        'Column not found. Available: %s', strjoin(names, ', '));
end
end

function out = normalize_tokens(in)
out = cell(size(in));
for i = 1:numel(in)
    s = lower(char(string(in{i})));
    s = regexprep(s, '[^a-z0-9]', '');
    out{i} = s;
end
end
