function result = stage2_doa(data, cfg)
% STAGE2_DOA Computes DoA error using RSSD and guide-derived LUT.
%
% INPUT
%   data : struct from load_case_data()
%   cfg  : struct from setup_config()
%
% OUTPUT
%   result.rss1_dB       : [N x 1] broadband RSS of antenna 1 [dB]
%   result.rss2_dB       : [N x 1] broadband RSS of antenna 2 [dB]
%   result.rssd_dB       : [N x 1] RSSD = RSS1 - RSS2 [dB]
%   result.doa_est_deg   : [N x 1] estimated DoA [deg] (selected inverse mode)
%   result.doa_est_affine_deg : [N x 1] affine sanity DoA [deg]
%   result.doa_gt_deg    : [N x 1] ground-truth DoA [deg]
%   result.error_deg     : [N x 1] signed error [deg]
%   result.abs_error_deg : [N x 1] absolute error [deg]
%   result.rmse_deg      : scalar RMSE over all tags
%   result.rmse_los_deg  : scalar RMSE over LoS tags
%   result.rmse_nlos_deg : scalar RMSE over NLoS tags
%   result.corr_rssd_vs_gt : scalar Pearson corr(RSSD, GT angle)
%   result.corr_coef     : scalar Pearson corr(DoA_est, GT angle)
%   result.guide_source  : char guide source path ('theory' if fallback)
%   result.inverse_mode  : char selected inverse mode

% Broadband RSS per tag from case data (power-domain average).
rss1_dB = 10 .* log10(max(mean(abs(data.S21_rx1).^2, 2), eps));
rss2_dB = 10 .* log10(max(mean(abs(data.S21_rx2).^2, 2), eps));
rssd_dB = rss1_dB - rss2_dB;

[lut, guide_source] = build_rssd_lut(data.pol_type, cfg);

inverse_mode = resolve_inverse_mode(data.pol_type, cfg);
[doa_est_raw_deg, inv_info] = invert_rssd_to_doa(rssd_dB, lut, cfg, inverse_mode, data.pol_type);
doa_est_affine_raw_deg = invert_rssd_affine(rssd_dB, lut);
[doa_est_raw_deg, slope_info] = apply_slope_conditioning(doa_est_raw_deg, lut, data.pol_type, cfg);

sign_applied = get_doa_sign(data.pol_type, cfg);
doa_est_deg = sign_applied .* doa_est_raw_deg;
doa_est_affine_deg = sign_applied .* doa_est_affine_raw_deg;
if isfield(inv_info, 'candidate_angle_deg')
    doa_candidate_deg = sign_applied .* inv_info.candidate_angle_deg;
else
    doa_candidate_deg = doa_est_deg;
end

doa_corr = compute_linear_corr(doa_est_deg, data.doa_gt_deg);
rssd_corr = compute_linear_corr(rssd_dB, data.doa_gt_deg);
doa_affine_corr = compute_linear_corr(doa_est_affine_deg, data.doa_gt_deg);
is_valid_for_positioning = abs(doa_corr) >= cfg.doa.validity_corr_threshold;
if ~is_valid_for_positioning
    warning('stage2_doa:lowDoACorrelation', ...
        ['Low DoA correlation for %s-%s (corr=%.3f < %.3f). ', ...
         'Positioning can be invalid.'], ...
        data.pol_type, data.scenario, doa_corr, cfg.doa.validity_corr_threshold);
end

error_deg = wrap_to_180(doa_est_deg - data.doa_gt_deg);
abs_error_deg = abs(error_deg);
m = compute_metrics(abs_error_deg, data.is_los);

error_affine_deg = wrap_to_180(doa_est_affine_deg - data.doa_gt_deg);
rmse_affine_deg = sqrt(mean(error_affine_deg.^2, 'omitnan'));

result = struct();
result.rss1_dB = rss1_dB;
result.rss2_dB = rss2_dB;
result.rssd_dB = rssd_dB;
result.doa_est_deg = doa_est_deg;
result.doa_est_affine_deg = doa_est_affine_deg;
result.doa_gt_deg = data.doa_gt_deg;
result.error_deg = error_deg;
result.abs_error_deg = abs_error_deg;
result.rmse_deg = m.rmse;
result.rmse_los_deg = m.rmse_los;
result.rmse_nlos_deg = m.rmse_nlos;
result.rmse_affine_deg = rmse_affine_deg;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.cdf_basis = 'abs_error_deg';
result.pol_type = data.pol_type;
result.scenario = data.scenario;
result.guide_source = guide_source;
result.inverse_mode = char(inverse_mode);
result.sign_applied = sign_applied;
result.corr_coef = doa_corr;
result.corr_rssd_vs_gt = rssd_corr;
result.corr_affine_vs_gt = doa_affine_corr;
result.is_valid_for_positioning = is_valid_for_positioning;
result.ambiguity_flag = inv_info.ambiguity_flag;
result.best_branch_idx = inv_info.best_branch_idx;
result.inv_residual = inv_info.residual;
result.allowed_segment_idx = inv_info.allowed_segment_idx;
result.segment_filter_applied = inv_info.segment_filter_applied;
result.doa_candidate_deg = doa_candidate_deg;
if isfield(inv_info, 'candidate_cost')
    result.doa_candidate_cost = inv_info.candidate_cost;
else
    result.doa_candidate_cost = nan(size(doa_candidate_deg));
end
if isfield(inv_info, 'candidate_branch_idx')
    result.doa_candidate_branch_idx = inv_info.candidate_branch_idx;
else
    result.doa_candidate_branch_idx = nan(size(doa_candidate_deg));
end
if isfield(inv_info, 'candidate_in_range')
    result.doa_candidate_in_range = inv_info.candidate_in_range;
else
    result.doa_candidate_in_range = false(size(doa_candidate_deg));
end
if isfield(inv_info, 'candidate_abs_slope_db_per_deg')
    result.doa_candidate_abs_slope_db_per_deg = inv_info.candidate_abs_slope_db_per_deg;
else
    result.doa_candidate_abs_slope_db_per_deg = nan(size(doa_candidate_deg));
end
result.abs_slope_db_per_deg = slope_info.abs_slope_db_per_deg;
result.low_slope_mask = slope_info.low_slope_mask;
result.slope_conditioning_enabled = slope_info.enabled;
result.slope_conditioning_mode = slope_info.mode;
result.slope_min_db_per_deg = slope_info.s_min_db_per_deg;
result.slope_valid_ratio = slope_info.valid_ratio;
end

function mode = resolve_inverse_mode(pol_type, cfg)
% RESOLVE_INVERSE_MODE Returns inverse mode with polarization-specific override.
mode = lower(string(cfg.doa.inverse_mode));
if isfield(cfg, 'doa') && isfield(cfg.doa, 'inverse_mode_by_pol') && ...
        isstruct(cfg.doa.inverse_mode_by_pol) && isfield(cfg.doa.inverse_mode_by_pol, pol_type)
    mode = lower(string(cfg.doa.inverse_mode_by_pol.(pol_type)));
end
end

function [lut, guide_source] = build_rssd_lut(pol_type, cfg)
% BUILD_RSSD_LUT Builds LUT from guide CSV (preferred) or theory fallback.
if nargin < 2
    error('stage2_doa:build_lut_args', 'build_rssd_lut requires pol_type and cfg.');
end
pol_type = upper(char(string(pol_type)));

if isfield(cfg, 'guide') && isfield(cfg.guide, 'use_external') && cfg.guide.use_external
    candidates = resolve_guide_candidates(pol_type, cfg);
    guide_path = first_existing_file(candidates);
    if ~isempty(guide_path)
        lut = build_lut_from_guide_csv(guide_path, cfg);
        guide_source = guide_path;
        return;
    end

    if ~(isfield(cfg.guide, 'fallback_to_theory') && cfg.guide.fallback_to_theory)
        error('stage2_doa:guideMissing', 'Guide CSV not found for %s.', pol_type);
    end
    warning('stage2_doa:guideMissingFallback', ...
        'Guide CSV not found for %s. Falling back to theory LUT.', pol_type);
end

lut = build_lut_theory(cfg);
guide_source = 'theory';
end

function candidates = resolve_guide_candidates(pol_type, cfg)
candidates = {};
if strcmp(pol_type, 'CP')
    if isfield(cfg.guide, 'cp_csv_candidates')
        candidates = [candidates, cfg.guide.cp_csv_candidates]; %#ok<AGROW>
    end
    if isfield(cfg.guide, 'cp_csv') && ~isempty(cfg.guide.cp_csv)
        candidates{end+1} = cfg.guide.cp_csv; %#ok<AGROW>
    end
elseif strcmp(pol_type, 'LP')
    if isfield(cfg.guide, 'lp_csv_candidates')
        candidates = [candidates, cfg.guide.lp_csv_candidates]; %#ok<AGROW>
    end
    if isfield(cfg.guide, 'lp_csv') && ~isempty(cfg.guide.lp_csv)
        candidates{end+1} = cfg.guide.lp_csv; %#ok<AGROW>
    end
else
    error('stage2_doa:unknownPolType', 'Unknown polarization type: %s', pol_type);
end

for i = 1:numel(candidates)
    candidates{i} = char(string(candidates{i}));
end
end

function path_out = first_existing_file(candidates)
path_out = '';
for i = 1:numel(candidates)
    p = char(string(candidates{i}));
    if isfile(p)
        path_out = p;
        return;
    end
end
end

function lut = build_lut_from_guide_csv(guide_path, cfg)
% BUILD_LUT_FROM_GUIDE_CSV Builds branch-aware LUT from guide CSV.
tbl = readtable(guide_path, 'VariableNamingRule', 'preserve');

if isfield(cfg.guide, 'column_candidates')
    cc = cfg.guide.column_candidates;
else
    cc = struct();
end

inc_patterns = local_get_struct_field(cc, 'inc_ang', {'inc_ang', 'inc ang', 'inc_ang_deg', 'anc_ang'});
mag1_patterns = local_get_struct_field(cc, 'mag_rx1', {'mag(S(rx1_p1,tx_p1))', 'mag_s_rx1', 'rx1'});
mag2_patterns = local_get_struct_field(cc, 'mag_rx2', {'mag(S(rx2_p1,tx_p1))', 'mag_s_rx2', 'rx2'});

inc_col = find_column_name(tbl, inc_patterns, true);
mag1_col = find_column_name(tbl, mag1_patterns, true);
mag2_col = find_column_name(tbl, mag2_patterns, true);

inc_ang_deg = double(tbl.(inc_col));
mag1 = double(tbl.(mag1_col));
mag2 = double(tbl.(mag2_col));

valid = isfinite(inc_ang_deg) & isfinite(mag1) & isfinite(mag2) & (mag1 > 0) & (mag2 > 0);
inc_ang_deg = inc_ang_deg(valid);
mag1 = mag1(valid);
mag2 = mag2(valid);
if isempty(inc_ang_deg)
    error('stage2_doa:emptyGuideData', 'No valid rows in guide CSV: %s', guide_path);
end

pow1 = mag1.^2;
pow2 = mag2.^2;
[g, inc_unique] = findgroups(inc_ang_deg);
pow1_mean = splitapply(@(x) mean(x, 'omitnan'), pow1, g);
pow2_mean = splitapply(@(x) mean(x, 'omitnan'), pow2, g);
rssd_mean = 10 .* log10(max(pow1_mean, eps)) - 10 .* log10(max(pow2_mean, eps));

[inc_sorted, idx_sort] = sort(inc_unique, 'ascend');
rssd_sorted = rssd_mean(idx_sort);

ang_axis = (inc_sorted(1):cfg.rssd_lut_step:inc_sorted(end)).';
rssd_curve = interp1(inc_sorted, rssd_sorted, ang_axis, 'pchip', 'extrap');
smooth_span = max(1, round(cfg.doa.curve_smooth_span));
if smooth_span > 1
    rssd_curve = movmean(rssd_curve, smooth_span, 'Endpoints', 'shrink');
end

segments = build_segments(ang_axis, rssd_curve, cfg);
affine = polyfit(rssd_sorted, inc_sorted, 1); % doa ~= a*rssd + b

lut = struct();
lut.ang_axis = ang_axis;
lut.rssd_curve = rssd_curve;
lut.slope_curve = gradient(rssd_curve, ang_axis);
lut.ang_raw = inc_sorted;
lut.rssd_raw = rssd_sorted;
lut.segments = segments;
lut.affine_coeff = affine;
end

function lut = build_lut_theory(cfg)
% BUILD_LUT_THEORY Theory fallback: tilted-tag sin^2 gain model.
ang_axis = (cfg.doa_range_deg(1):cfg.rssd_lut_step:cfg.doa_range_deg(2)).';
phi_rad = deg2rad(ang_axis);
theta_rad = deg2rad(cfg.theta_tilt_deg);

G1 = sin(phi_rad - theta_rad).^2;
G2 = sin(phi_rad + theta_rad).^2;
G1 = max(G1, eps);
G2 = max(G2, eps);
rssd_curve = 10 .* log10(G1 ./ G2);

segments = build_segments(ang_axis, rssd_curve, cfg);
affine = polyfit(rssd_curve, ang_axis, 1);

lut = struct();
lut.ang_axis = ang_axis;
lut.rssd_curve = rssd_curve;
lut.slope_curve = gradient(rssd_curve, ang_axis);
lut.ang_raw = ang_axis;
lut.rssd_raw = rssd_curve;
lut.segments = segments;
lut.affine_coeff = affine;
end

function segments = build_segments(ang_axis, rssd_curve, cfg)
% BUILD_SEGMENTS Splits LUT curve into monotonic segments for branch-aware inverse.
dr = diff(rssd_curve);
sign_dr = zeros(size(dr));
sign_dr(dr > cfg.doa.lut_slope_eps) = 1;
sign_dr(dr < -cfg.doa.lut_slope_eps) = -1;
sign_dr = fill_zero_sign(sign_dr);

break_idx = find(diff(sign_dr) ~= 0) + 1;
seg_start = [1; break_idx(:)];
seg_end = [break_idx(:); numel(ang_axis)];
min_pts = max(2, round(cfg.doa.lut_min_segment_points));

segments = struct([]);
cnt = 0;
for i = 1:numel(seg_start)
    i0 = seg_start(i);
    i1 = seg_end(i);
    if (i1 - i0 + 1) < min_pts
        continue;
    end

    ang_seg = ang_axis(i0:i1);
    rssd_seg = rssd_curve(i0:i1);
    dir_sign = sign(rssd_seg(end) - rssd_seg(1));
    if dir_sign == 0
        dir_sign = 1;
    end

    if dir_sign > 0
        rssd_inv = rssd_seg;
        ang_inv = ang_seg;
    else
        rssd_inv = flipud(rssd_seg);
        ang_inv = flipud(ang_seg);
    end

    [rssd_inv_u, idx_u] = unique(rssd_inv, 'stable');
    ang_inv_u = ang_inv(idx_u);
    if numel(rssd_inv_u) < 2
        continue;
    end

    cnt = cnt + 1;
    segments(cnt).idx_start = i0; %#ok<AGROW>
    segments(cnt).idx_end = i1; %#ok<AGROW>
    segments(cnt).ang_min = ang_seg(1); %#ok<AGROW>
    segments(cnt).ang_max = ang_seg(end); %#ok<AGROW>
    segments(cnt).ang_span = abs(ang_seg(end) - ang_seg(1)); %#ok<AGROW>
    segments(cnt).rssd_min = min(rssd_seg); %#ok<AGROW>
    segments(cnt).rssd_max = max(rssd_seg); %#ok<AGROW>
    segments(cnt).monotonic_dir = dir_sign; %#ok<AGROW>
    segments(cnt).rssd_inv = rssd_inv_u; %#ok<AGROW>
    segments(cnt).ang_inv = ang_inv_u; %#ok<AGROW>
end

if isempty(segments)
    [rssd_inv_u, idx_u] = unique(rssd_curve, 'stable');
    ang_inv_u = ang_axis(idx_u);
    segments = struct( ...
        'idx_start', 1, ...
        'idx_end', numel(ang_axis), ...
        'ang_min', ang_axis(1), ...
        'ang_max', ang_axis(end), ...
        'ang_span', abs(ang_axis(end) - ang_axis(1)), ...
        'rssd_min', min(rssd_curve), ...
        'rssd_max', max(rssd_curve), ...
        'monotonic_dir', 1, ...
        'rssd_inv', rssd_inv_u, ...
        'ang_inv', ang_inv_u);
end
end

function sign_dr = fill_zero_sign(sign_dr)
if isempty(sign_dr)
    return;
end
nonzero = find(sign_dr ~= 0, 1, 'first');
if isempty(nonzero)
    sign_dr(:) = 1;
    return;
end
sign_dr(1:nonzero-1) = sign_dr(nonzero);
for i = nonzero+1:numel(sign_dr)
    if sign_dr(i) == 0
        sign_dr(i) = sign_dr(i - 1);
    end
end
end

function [doa_deg, info] = invert_rssd_to_doa(rssd_dB, lut, cfg, mode_str, pol_type)
% INVERT_RSSD_TO_DOA Inverts RSSD to DoA using configured mode.
n = numel(rssd_dB);
doa_deg = nan(n, 1);
ambiguity = false(n, 1);
best_branch_idx = zeros(n, 1);
residual = nan(n, 1);
selected_seg_idx = resolve_allowed_segments(lut, cfg, pol_type);
segment_filter_applied = numel(selected_seg_idx) < numel(lut.segments);
n_seg_out = max(1, numel(selected_seg_idx));
candidate_angle = nan(n, n_seg_out);
candidate_cost = nan(n, n_seg_out);
candidate_branch_idx = nan(n, n_seg_out);
candidate_in_range = false(n, n_seg_out);
candidate_abs_slope = nan(n, n_seg_out);

switch lower(string(mode_str))
    case "affine"
        doa_deg = invert_rssd_affine(rssd_dB, lut);
        candidate_angle(:, 1) = doa_deg;
        candidate_cost(:, 1) = 0;
        candidate_branch_idx(:, 1) = 0;
        candidate_in_range(:, 1) = true;
    case "legacy_single"
        for i = 1:n
            v = rssd_dB(i);
            if ~isfinite(v), continue; end
            [residual(i), k] = min(abs(lut.rssd_curve - v));
            doa_deg(i) = lut.ang_axis(k);
            n_close = sum(abs(lut.rssd_curve - v) <= cfg.doa.candidate_tol_db);
            ambiguity(i) = n_close > 1;
            candidate_angle(i, 1) = doa_deg(i);
            candidate_cost(i, 1) = residual(i);
            candidate_branch_idx(i, 1) = 0;
            candidate_in_range(i, 1) = true;
        end
    otherwise % branch_aware
        for i = 1:n
            v = rssd_dB(i);
            if ~isfinite(v), continue; end

            n_seg = numel(selected_seg_idx);
            cand_angle = nan(n_seg, 1);
            cand_cost = nan(n_seg, 1);
            in_range = false(n_seg, 1);
            cand_branch_idx = zeros(n_seg, 1);

            for j = 1:n_seg
                s = selected_seg_idx(j);
                seg = lut.segments(s);
                rmin = min(seg.rssd_min, seg.rssd_max);
                rmax = max(seg.rssd_min, seg.rssd_max);
                in_range(j) = (v >= rmin) && (v <= rmax);

                v_clip = min(max(v, rmin), rmax);
                a_hat = interp1(seg.rssd_inv, seg.ang_inv, v_clip, 'linear', 'extrap');
                a_hat = min(max(a_hat, seg.ang_min), seg.ang_max);
                r_hat = interp1(lut.ang_axis, lut.rssd_curve, a_hat, 'linear', 'extrap');

                cost = abs(r_hat - v);
                if ~in_range(j)
                    cost = cost + cfg.doa.out_of_range_penalty_db;
                end
                if cfg.doa.default_branch > 0 && s ~= cfg.doa.default_branch
                    cost = cost + cfg.doa.branch_penalty_db;
                end
                cand_angle(j) = a_hat;
                cand_cost(j) = cost;
                cand_branch_idx(j) = s;
            end
            candidate_angle(i, 1:n_seg) = cand_angle;
            candidate_cost(i, 1:n_seg) = cand_cost;
            candidate_branch_idx(i, 1:n_seg) = cand_branch_idx;
            candidate_in_range(i, 1:n_seg) = in_range;

            [best_cost, idx_best] = min(cand_cost);
            doa_deg(i) = cand_angle(idx_best);
            best_branch_idx(i) = cand_branch_idx(idx_best);
            residual(i) = best_cost;

            n_close_cost = sum(cand_cost <= (best_cost + cfg.doa.candidate_tol_db));
            ambiguity(i) = (n_close_cost > 1) || (sum(in_range) > 1);
        end
end
candidate_abs_slope = estimate_abs_slope_at_angle(candidate_angle, lut);

info = struct();
info.ambiguity_flag = ambiguity;
info.best_branch_idx = best_branch_idx;
info.residual = residual;
info.allowed_segment_idx = selected_seg_idx(:).';
info.segment_filter_applied = segment_filter_applied;
info.candidate_angle_deg = candidate_angle;
info.candidate_cost = candidate_cost;
info.candidate_branch_idx = candidate_branch_idx;
info.candidate_in_range = candidate_in_range;
info.candidate_abs_slope_db_per_deg = candidate_abs_slope;
end

function seg_idx = resolve_allowed_segments(lut, cfg, pol_type)
% RESOLVE_ALLOWED_SEGMENTS Selects segment candidates for branch-aware inversion.
n_seg = numel(lut.segments);
seg_idx = (1:n_seg).';
if n_seg <= 1
    return;
end

enabled = false;
direction = "all";
use_largest_only = false;

if isfield(cfg, 'doa') && isfield(cfg.doa, 'segment_filter')
    sf = cfg.doa.segment_filter;
    if isfield(sf, 'enabled'), enabled = logical(sf.enabled); end
    if isfield(sf, 'direction'), direction = lower(string(sf.direction)); end
    if isfield(sf, 'use_largest_only'), use_largest_only = logical(sf.use_largest_only); end

    if isfield(sf, 'by_pol') && isstruct(sf.by_pol) && isfield(sf.by_pol, pol_type)
        sp = sf.by_pol.(pol_type);
        if isfield(sp, 'enabled'), enabled = logical(sp.enabled); end
        if isfield(sp, 'direction'), direction = lower(string(sp.direction)); end
        if isfield(sp, 'use_largest_only'), use_largest_only = logical(sp.use_largest_only); end
    end
end

if ~enabled
    return;
end

direction = replace(direction, "_", "");
dirs = arrayfun(@(s) s.monotonic_dir, lut.segments(:));
switch char(direction)
    case 'increasing'
        seg_idx = find(dirs > 0);
    case 'decreasing'
        seg_idx = find(dirs < 0);
    otherwise
        seg_idx = (1:n_seg).';
end

if isempty(seg_idx)
    seg_idx = (1:n_seg).';
end

if use_largest_only && numel(seg_idx) > 1
    spans = arrayfun(@(k) max(lut.segments(k).ang_span, eps), seg_idx);
    [~, kmax] = max(spans);
    seg_idx = seg_idx(kmax);
end

seg_idx = seg_idx(:);
end

function [doa_out_deg, info] = apply_slope_conditioning(doa_in_deg, lut, pol_type, cfg)
% APPLY_SLOPE_CONDITIONING Optionally invalidates DoA where inverse slope is too small.
doa_out_deg = doa_in_deg;
abs_slope = estimate_abs_slope_at_angle(doa_in_deg, lut);

[enabled, mode_str, s_min] = resolve_slope_cfg(pol_type, cfg);
low_mask = false(size(doa_in_deg));
if enabled
    low_mask = isfinite(abs_slope) & (abs_slope < s_min);
    switch char(mode_str)
        case 'invalidate'
            doa_out_deg(low_mask) = NaN;
        otherwise
            % no-op
    end
end

valid_ratio = mean(isfinite(doa_out_deg), 'omitnan');
if ~isfinite(valid_ratio)
    valid_ratio = NaN;
end

info = struct();
info.abs_slope_db_per_deg = abs_slope;
info.low_slope_mask = low_mask;
info.enabled = enabled;
info.mode = char(mode_str);
info.s_min_db_per_deg = s_min;
info.valid_ratio = valid_ratio;
end

function [enabled, mode_str, s_min] = resolve_slope_cfg(pol_type, cfg)
% RESOLVE_SLOPE_CFG Reads slope-conditioning config with polarization override.
enabled = false;
mode_str = "invalidate";
s_min = 0.02;

if ~isfield(cfg, 'doa') || ~isfield(cfg.doa, 'slope_conditioning')
    return;
end
sc = cfg.doa.slope_conditioning;
if isfield(sc, 'enabled'), enabled = logical(sc.enabled); end
if isfield(sc, 'mode') && ~isempty(sc.mode), mode_str = lower(string(sc.mode)); end
if isfield(sc, 's_min_db_per_deg') && ~isempty(sc.s_min_db_per_deg)
    s_min = abs(double(sc.s_min_db_per_deg));
end

if isfield(sc, 'by_pol') && isstruct(sc.by_pol) && isfield(sc.by_pol, pol_type)
    sp = sc.by_pol.(pol_type);
    if isfield(sp, 'enabled'), enabled = logical(sp.enabled); end
    if isfield(sp, 'mode') && ~isempty(sp.mode), mode_str = lower(string(sp.mode)); end
    if isfield(sp, 's_min_db_per_deg') && ~isempty(sp.s_min_db_per_deg)
        s_min = abs(double(sp.s_min_db_per_deg));
    end
end

mode_str = replace(mode_str, "_", "");
s_min = max(s_min, eps);
end

function abs_slope = estimate_abs_slope_at_angle(doa_deg, lut)
% ESTIMATE_ABS_SLOPE_AT_ANGLE Returns |dRSSD/dtheta| at estimated angle.
if isfield(lut, 'slope_curve') && ~isempty(lut.slope_curve)
    slope_curve = lut.slope_curve(:);
else
    slope_curve = gradient(lut.rssd_curve(:), lut.ang_axis(:));
end
abs_slope = nan(size(doa_deg));
v = isfinite(doa_deg);
if any(v)
    abs_slope(v) = abs(interp1(lut.ang_axis, slope_curve, doa_deg(v), 'linear', 'extrap'));
end
end

function doa_deg = invert_rssd_affine(rssd_dB, lut)
% INVERT_RSSD_AFFINE Fast sanity baseline: affine mapping.
doa_deg = polyval(lut.affine_coeff, rssd_dB);
doa_deg = min(max(doa_deg, min(lut.ang_axis)), max(lut.ang_axis));
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
    error('stage2_doa:columnNotFound', ...
        'Required guide column not found. Available columns: %s', strjoin(names, ', '));
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

function v = local_get_struct_field(s, f, default_v)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
else
    v = default_v;
end
end

function s = get_doa_sign(pol_type, cfg)
s = 1;
if isfield(cfg, 'doa') && isfield(cfg.doa, 'sign_correction')
    if isfield(cfg.doa.sign_correction, pol_type)
        s = cfg.doa.sign_correction.(pol_type);
    end
end
if ~isscalar(s) || ~isfinite(s) || s == 0
    error('stage2_doa:invalidSign', 'Invalid DoA sign correction for %s.', pol_type);
end
end

function c = compute_linear_corr(x, y)
x = x(:);
y = y(:);
valid = isfinite(x) & isfinite(y);
if sum(valid) < 2
    c = NaN;
    return;
end
R = corrcoef(x(valid), y(valid));
if numel(R) < 4
    c = NaN;
else
    c = R(1, 2);
end
end

function a = wrap_to_180(a)
a = mod(a + 180, 360) - 180;
end
