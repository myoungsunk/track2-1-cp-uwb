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
%   result.rmse_m        : scalar  RMSE over all tags
%   result.rmse_los_m    : scalar  RMSE over LoS tags
%   result.rmse_nlos_m   : scalar  RMSE over NLoS tags
%   result.error_rx2_m   : [N x 1] signed error [m] for antenna 2 (auxiliary)
%   result.abs_error_rx2_m : [N x 1] absolute error [m] for antenna 2 (auxiliary)
%   result.rmse_rx2_m      : scalar RMSE over all tags for antenna 2
%   result.rmse_los_rx2_m  : scalar RMSE over LoS tags for antenna 2
%   result.rmse_nlos_rx2_m : scalar RMSE over NLoS tags for antenna 2
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

result = struct();
result.range_est_m = range_est_m;
result.range_est_rx2_m = range_est_rx2_m;
result.range_gt_m = data.range_gt_m;
result.error_m = error_m;
result.abs_error_m = abs_error_m;
result.rmse_m = m.rmse;
result.rmse_los_m = m.rmse_los;
result.rmse_nlos_m = m.rmse_nlos;
result.error_rx2_m = error_rx2_m;
result.abs_error_rx2_m = abs_error_rx2_m;
result.rmse_rx2_m = m_rx2.rmse;
result.rmse_los_rx2_m = m_rx2.rmse_los;
result.rmse_nlos_rx2_m = m_rx2.rmse_nlos;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.cdf_basis = 'abs_error_m';
result.primary_ranging_rx = 'rx1';
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end
