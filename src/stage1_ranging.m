function result = stage1_ranging(data, cfg)
% STAGE1_RANGING Computes ranging error from CIR first-path detection.
%
% INPUT
%   data : struct from load_case_data()
%   cfg  : struct from setup_config()
%
% OUTPUT
%   result.range_est_m   : [N x 1] estimated range [m] using antenna 1 (primary)
%   result.range_est_rx2_m : [N x 1] estimated range [m] using antenna 2 (auxiliary)
%   result.range_gt_m    : [N x 1] ground-truth range [m]
%   result.error_m       : [N x 1] signed error [m]
%   result.abs_error_m   : [N x 1] absolute error [m]
%   result.bias_m        : scalar  mean signed bias [m]
%   result.rmse_m        : scalar  RMSE over all tags
%   result.rmse_debiased_m : scalar RMSE after removing mean bias
%   result.rmse_los_m    : scalar  RMSE over LoS tags
%   result.rmse_nlos_m   : scalar  RMSE over NLoS tags
%   result.error_rx2_m   : [N x 1] signed error [m] for antenna 2 (auxiliary)
%   result.abs_error_rx2_m : [N x 1] absolute error [m] for antenna 2 (auxiliary)
%   result.bias_rx2_m      : scalar mean signed bias [m] for antenna 2
%   result.rmse_rx2_m      : scalar RMSE over all tags for antenna 2
%   result.rmse_debiased_rx2_m : scalar debiased RMSE for antenna 2
%   result.rmse_los_rx2_m  : scalar RMSE over LoS tags for antenna 2
%   result.rmse_nlos_rx2_m : scalar RMSE over NLoS tags for antenna 2
%   result.abs_error_best2_m : [N x 1] per-tag min absolute error of {rx1, rx2}
%   result.rmse_best2_m      : scalar RMSE from abs_error_best2_m
%   result.rmse_los_best2_m  : scalar LoS RMSE from abs_error_best2_m
%   result.rmse_nlos_best2_m : scalar NLoS RMSE from abs_error_best2_m
%   result.best_port_idx     : [N x 1] 1 if rx1 better, 2 if rx2 better
%   result.best_port_share_rx2 : scalar fraction of tags where rx2 is better
%   result.cdf_x         : [K x 1] CDF x-axis
%   result.cdf_y         : [K x 1] CDF y-axis
%   result.pol_type      : char    polarization label
%   result.scenario      : char    scenario label

n_tags = data.n_tags;
range_est_m = nan(n_tags, 1);
range_est_rx2_m = nan(n_tags, 1);

for i = 1:n_tags
    S21_rx1 = data.S21_rx1(i, :).';
    [cir_mag_rx1, ~, d_axis_m_rx1] = compute_cir(S21_rx1, cfg);
    [~, fp_range_rx1_m] = extract_first_path(cir_mag_rx1, d_axis_m_rx1, cfg);
    range_est_m(i) = fp_range_rx1_m;

    S21_rx2 = data.S21_rx2(i, :).';
    [cir_mag_rx2, ~, d_axis_m_rx2] = compute_cir(S21_rx2, cfg);
    [~, fp_range_rx2_m] = extract_first_path(cir_mag_rx2, d_axis_m_rx2, cfg);
    range_est_rx2_m(i) = fp_range_rx2_m;
end

error_m = range_est_m - data.range_gt_m;
abs_error_m = abs(error_m);
m = compute_metrics(abs_error_m, data.is_los);
error_rx2_m = range_est_rx2_m - data.range_gt_m;
abs_error_rx2_m = abs(error_rx2_m);
m_rx2 = compute_metrics(abs_error_rx2_m, data.is_los);
abs_error_best2_m = min(abs_error_m, abs_error_rx2_m);
m_best2 = compute_metrics(abs_error_best2_m, data.is_los);
best_port_idx = ones(n_tags, 1);
best_port_idx(abs_error_rx2_m < abs_error_m) = 2;
best_port_share_rx2 = mean(best_port_idx == 2, 'omitnan');

bias_m = mean(error_m, 'omitnan');
bias_rx2_m = mean(error_rx2_m, 'omitnan');
rmse_debiased_m = sqrt(mean((error_m - bias_m).^2, 'omitnan'));
rmse_debiased_rx2_m = sqrt(mean((error_rx2_m - bias_rx2_m).^2, 'omitnan'));
n_los = sum(data.is_los);
n_nlos = sum(~data.is_los);

result = struct();
result.range_est_m = range_est_m;
result.range_est_rx2_m = range_est_rx2_m;
result.range_gt_m = data.range_gt_m;
result.error_m = error_m;
result.abs_error_m = abs_error_m;
result.bias_m = bias_m;
result.rmse_m = m.rmse;
result.rmse_debiased_m = rmse_debiased_m;
result.rmse_los_m = m.rmse_los;
result.rmse_nlos_m = m.rmse_nlos;
result.error_rx2_m = error_rx2_m;
result.abs_error_rx2_m = abs_error_rx2_m;
result.bias_rx2_m = bias_rx2_m;
result.rmse_rx2_m = m_rx2.rmse;
result.rmse_debiased_rx2_m = rmse_debiased_rx2_m;
result.rmse_los_rx2_m = m_rx2.rmse_los;
result.rmse_nlos_rx2_m = m_rx2.rmse_nlos;
result.abs_error_best2_m = abs_error_best2_m;
result.rmse_best2_m = m_best2.rmse;
result.rmse_los_best2_m = m_best2.rmse_los;
result.rmse_nlos_best2_m = m_best2.rmse_nlos;
result.best_port_idx = best_port_idx;
result.best_port_share_rx2 = best_port_share_rx2;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.cdf_basis = 'abs_error_m';
result.primary_ranging_rx = 'rx1';
result.n_los = n_los;
result.n_nlos = n_nlos;
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end
