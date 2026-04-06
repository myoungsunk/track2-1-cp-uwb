function result = stage4_positioning(s1_result, s2_result, data, cfg)
% STAGE4_POSITIONING Computes 2D position errors from range + DoA estimates.
%
% INPUT
%   s1_result : struct from stage1_ranging()
%   s2_result : struct from stage2_doa()
%   data      : struct from load_case_data()
%   cfg       : struct from setup_config()
%
% OUTPUT
%   result.pos_est_mm    : [N x 2] estimated position [mm]
%   result.pos_gt_mm     : [N x 2] ground-truth position [mm]
%   result.error_m       : [N x 1] Euclidean 2D error [m]
%   result.rmse_m        : scalar  RMSE over all tags [m]
%   result.rmse_los_m    : scalar  RMSE over LoS tags [m]
%   result.rmse_nlos_m   : scalar  RMSE over NLoS tags [m]
%   result.cep67_m       : scalar  67th percentile error [m]
%   result.cep95_m       : scalar  95th percentile error [m]
%   result.cdf_x         : [K x 1] CDF x-axis
%   result.cdf_y         : [K x 1] CDF y-axis
%   result.pol_type      : char    polarization label
%   result.scenario      : char    scenario label

n_tags = data.n_tags;
pos_est_mm = nan(n_tags, 2);
pos_gt_mm = data.pos_mm;

for i = 1:n_tags
    d_m = s1_result.range_est_m(i);
    phi_rad = deg2rad(s2_result.doa_est_deg(i));

    x_est_mm = cfg.anchor_mm(1) + d_m * cos(phi_rad) * 1000;
    y_est_mm = cfg.anchor_mm(2) + d_m * sin(phi_rad) * 1000;
    pos_est_mm(i, :) = [x_est_mm, y_est_mm];
end

dx_mm = pos_est_mm(:, 1) - pos_gt_mm(:, 1);
dy_mm = pos_est_mm(:, 2) - pos_gt_mm(:, 2);
error_m = hypot(dx_mm, dy_mm) / 1000;

m = compute_metrics(error_m, data.is_los);

result = struct();
result.pos_est_mm = pos_est_mm;
result.pos_gt_mm = pos_gt_mm;
result.error_m = error_m;
result.rmse_m = m.rmse;
result.rmse_los_m = m.rmse_los;
result.rmse_nlos_m = m.rmse_nlos;
result.cep67_m = m.cep67;
result.cep95_m = m.cep95;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end

