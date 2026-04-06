function result = stage2_doa(data, cfg)
% STAGE2_DOA Computes DoA error using RSSD and a guide-derived LUT.
%
% INPUT
%   data : struct from load_case_data()
%   cfg  : struct from setup_config()
%
% OUTPUT
%   result.rss1_dB       : [N x 1] broadband RSS of antenna 1 [dB]
%   result.rss2_dB       : [N x 1] broadband RSS of antenna 2 [dB]
%   result.rssd_dB       : [N x 1] RSSD = RSS1 - RSS2 [dB]
%   result.doa_est_deg   : [N x 1] estimated DoA [deg]
%   result.doa_gt_deg    : [N x 1] ground-truth DoA [deg]
%   result.error_deg     : [N x 1] signed error [deg]
%   result.abs_error_deg : [N x 1] absolute error [deg]
%   result.rmse_deg      : scalar  RMSE over all tags
%   result.rmse_los_deg  : scalar  RMSE over LoS tags
%   result.rmse_nlos_deg : scalar  RMSE over NLoS tags
%   result.cdf_x         : [K x 1] CDF x-axis
%   result.cdf_y         : [K x 1] CDF y-axis
%   result.pol_type      : char    polarization label
%   result.scenario      : char    scenario label
%   result.guide_source  : char    guide source path ('theory' if fallback)

% Broadband RSS per tag from case data (power-domain average).
rss1_dB = 10 .* log10(max(mean(abs(data.S21_rx1).^2, 2), eps));
rss2_dB = 10 .* log10(max(mean(abs(data.S21_rx2).^2, 2), eps));
rssd_dB = rss1_dB - rss2_dB;

[rssd_lut, doa_lut, guide_source] = build_rssd_lut(data.pol_type, cfg);

lut_min = min(rssd_lut);
lut_max = max(rssd_lut);
if any(rssd_dB < lut_min | rssd_dB > lut_max)
    warning('stage2_doa:rssdOutOfRange', ...
        'Some RSSD values are outside LUT range [%.3f, %.3f] dB. Extrapolation used.', ...
        lut_min, lut_max);
end

doa_est_raw_deg = interp1(rssd_lut, doa_lut, rssd_dB, 'linear', 'extrap');
sign_applied = get_doa_sign(data.pol_type, cfg);
doa_est_deg = sign_applied .* doa_est_raw_deg;

doa_corr = compute_linear_corr(doa_est_deg, data.doa_gt_deg);
is_valid_for_positioning = abs(doa_corr) >= cfg.doa.validity_corr_threshold;
if ~is_valid_for_positioning
    warning('stage2_doa:lowDoACorrelation', ...
        ['Low DoA correlation for %s-%s (corr=%.3f < %.3f). ', ...
         'Positioning can be invalid.'], ...
        data.pol_type, data.scenario, doa_corr, cfg.doa.validity_corr_threshold);
end

error_deg = doa_est_deg - data.doa_gt_deg;
abs_error_deg = abs(error_deg);
m = compute_metrics(abs_error_deg, data.is_los);

result = struct();
result.rss1_dB = rss1_dB;
result.rss2_dB = rss2_dB;
result.rssd_dB = rssd_dB;
result.doa_est_deg = doa_est_deg;
result.doa_gt_deg = data.doa_gt_deg;
result.error_deg = error_deg;
result.abs_error_deg = abs_error_deg;
result.rmse_deg = m.rmse;
result.rmse_los_deg = m.rmse_los;
result.rmse_nlos_deg = m.rmse_nlos;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.cdf_basis = 'abs_error_deg';
result.pol_type = data.pol_type;
result.scenario = data.scenario;
result.guide_source = guide_source;
result.sign_applied = sign_applied;
result.corr_coef = doa_corr;
result.is_valid_for_positioning = is_valid_for_positioning;
end

function [rssd_lut, doa_lut, guide_source] = build_rssd_lut(pol_type, cfg)
% BUILD_RSSD_LUT Builds RSSD-vs-inc_ang LUT from external guide CSV.
if nargin < 2
    error('stage2_doa:build_lut_args', 'build_rssd_lut requires pol_type and cfg.');
end

pol_type = upper(char(string(pol_type)));

if isfield(cfg, 'guide') && isfield(cfg.guide, 'use_external') && cfg.guide.use_external
    guide_path = '';
    switch pol_type
        case 'CP'
            if isfield(cfg.guide, 'cp_csv')
                guide_path = cfg.guide.cp_csv;
            end
        case 'LP'
            if isfield(cfg.guide, 'lp_csv')
                guide_path = cfg.guide.lp_csv;
            end
        otherwise
            error('stage2_doa:unknownPolType', 'Unknown polarization type: %s', pol_type);
    end

    if ~isempty(guide_path) && isfile(guide_path)
        [rssd_lut, doa_lut] = build_lut_from_guide_csv(guide_path);
        guide_source = guide_path;
        return;
    end

    if ~(isfield(cfg.guide, 'fallback_to_theory') && cfg.guide.fallback_to_theory)
        error('stage2_doa:guideMissing', ...
            'Guide CSV not found for %s: %s', pol_type, guide_path);
    end

    warning('stage2_doa:guideMissingFallback', ...
        'Guide CSV not found for %s (%s). Falling back to theory LUT.', pol_type, guide_path);
end

[rssd_lut, doa_lut] = build_lut_theory(cfg);
guide_source = 'theory';
end

function [rssd_lut, doa_lut] = build_lut_from_guide_csv(guide_path)
% BUILD_LUT_FROM_GUIDE_CSV Builds LUT by averaging broadband RSSD per inc_ang.
tbl = readtable(guide_path, 'VariableNamingRule', 'preserve');

inc_col = find_column_name(tbl, {'inc_ang', 'inc ang'});
mag1_col = find_column_name(tbl, {'mag(S(rx1_p1,tx_p1))', 'mag_s_rx1', 'rx1'});
mag2_col = find_column_name(tbl, {'mag(S(rx2_p1,tx_p1))', 'mag_s_rx2', 'rx2'});

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

% Interpolation uses RSSD as x-axis, so enforce strictly increasing x.
[rssd_sorted, idx_sort] = sort(rssd_mean, 'ascend');
doa_sorted = inc_unique(idx_sort);
[rssd_lut, idx_unique] = unique(rssd_sorted, 'stable');
doa_lut = doa_sorted(idx_unique);

if numel(rssd_lut) < 2
    error('stage2_doa:lutInvalidGuide', ...
        'Guide-derived LUT is degenerate: %s', guide_path);
end
end

function [rssd_lut, doa_lut] = build_lut_theory(cfg)
% BUILD_LUT_THEORY Theory fallback: tilted-tag sin^2 gain model.
doa_lut = (cfg.doa_range_deg(1):cfg.rssd_lut_step:cfg.doa_range_deg(2)).';
phi_rad = deg2rad(doa_lut);
theta_rad = deg2rad(cfg.theta_tilt_deg);

G1 = sin(phi_rad - theta_rad).^2;
G2 = sin(phi_rad + theta_rad).^2;
G1 = max(G1, eps);
G2 = max(G2, eps);

rssd_raw = 10 .* log10(G1 ./ G2);
[rssd_sorted, sort_idx] = sort(rssd_raw, 'ascend');
doa_sorted = doa_lut(sort_idx);
[rssd_lut, unique_idx] = unique(rssd_sorted, 'stable');
doa_lut = doa_sorted(unique_idx);
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

error('stage2_doa:columnNotFound', ...
    'Required guide column not found. Available columns: %s', strjoin(names, ', '));
end

function out = normalize_tokens(in)
% NORMALIZE_TOKENS Lowercases and removes non-alnum chars for robust matching.
out = cell(size(in));
for i = 1:numel(in)
    s = lower(char(string(in{i})));
    s = regexprep(s, '[^a-z0-9]', '');
    out{i} = s;
end
end

function s = get_doa_sign(pol_type, cfg)
% GET_DOA_SIGN Returns sign correction factor for polarization.
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
% COMPUTE_LINEAR_CORR Computes Pearson correlation for finite pairs.
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
