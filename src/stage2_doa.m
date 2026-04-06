function result = stage2_doa(data, cfg)
% STAGE2_DOA Computes DoA error from two-antenna RSSD with LUT mapping.
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

rss1_dB = 20 .* log10(max(mean(abs(data.S21_rx1), 2), eps));
rss2_dB = 20 .* log10(max(mean(abs(data.S21_rx2), 2), eps));
rssd_dB = rss1_dB - rss2_dB;

[rssd_lut, doa_lut] = build_rssd_lut(cfg);

lut_min = min(rssd_lut);
lut_max = max(rssd_lut);
if any(rssd_dB < lut_min | rssd_dB > lut_max)
    warning('stage2_doa:rssdOutOfRange', ...
        'Some RSSD values are outside LUT range [%.3f, %.3f] dB. Extrapolation used.', ...
        lut_min, lut_max);
end

doa_est_deg = interp1(rssd_lut, doa_lut, rssd_dB, 'linear', 'extrap');

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
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end

function [rssd_lut, doa_lut] = build_rssd_lut(cfg)
% BUILD_RSSD_LUT Builds a monotone RSSD-versus-DoA lookup table.
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

if numel(rssd_lut) < 2
    error('stage2_doa:lutInvalid', 'RSSD LUT is degenerate; check cfg.theta_tilt_deg.');
end
end

