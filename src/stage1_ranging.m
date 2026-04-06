function result = stage1_ranging(data, cfg)
% STAGE1_RANGING Computes ranging error from CIR first-path detection.
%
% INPUT
%   data : struct from load_case_data()
%   cfg  : struct from setup_config()
%
% OUTPUT
%   result.range_est_m   : [N x 1] estimated range [m]
%   result.range_gt_m    : [N x 1] ground-truth range [m]
%   result.error_m       : [N x 1] signed error [m]
%   result.abs_error_m   : [N x 1] absolute error [m]
%   result.rmse_m        : scalar  RMSE over all tags
%   result.rmse_los_m    : scalar  RMSE over LoS tags
%   result.rmse_nlos_m   : scalar  RMSE over NLoS tags
%   result.cdf_x         : [K x 1] CDF x-axis
%   result.cdf_y         : [K x 1] CDF y-axis
%   result.pol_type      : char    polarization label
%   result.scenario      : char    scenario label

n_tags = data.n_tags;
range_est_m = nan(n_tags, 1);

for i = 1:n_tags
    S21_vec = data.S21_rx1(i, :).';
    [cir_mag, ~, d_axis_m] = compute_cir(S21_vec, cfg);
    range_est_m(i) = extract_first_path_range(cir_mag, d_axis_m, cfg);
end

error_m = range_est_m - data.range_gt_m;
abs_error_m = abs(error_m);
m = compute_metrics(abs_error_m, data.is_los);

result = struct();
result.range_est_m = range_est_m;
result.range_gt_m = data.range_gt_m;
result.error_m = error_m;
result.abs_error_m = abs_error_m;
result.rmse_m = m.rmse;
result.rmse_los_m = m.rmse_los;
result.rmse_nlos_m = m.rmse_nlos;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end

function d_fp = extract_first_path_range(cir_mag, d_axis_m, cfg)
% EXTRACT_FIRST_PATH_RANGE Returns first-path range estimate from CIR.
[~, fp_idx] = find_first_path_peak(cir_mag, d_axis_m, cfg);
d_fp = d_axis_m(fp_idx);
end

function [fp_amp, fp_idx] = find_first_path_peak(cir_mag, d_axis_m, cfg)
% FIND_FIRST_PATH_PEAK Finds first local peak above threshold after guard range.
n = numel(cir_mag);
threshold = cfg.fp_threshold_ratio * max(cir_mag);
search_idx = find(d_axis_m >= cfg.fp_search_start_m);

fp_idx = [];
for k = search_idx(:).'
    if k <= 1 || k >= n
        continue;
    end
    if cir_mag(k) > threshold && cir_mag(k) > cir_mag(k-1) && cir_mag(k) > cir_mag(k+1)
        fp_idx = k;
        break;
    end
end

if isempty(fp_idx)
    [~, fp_idx] = max(cir_mag);
end
fp_amp = cir_mag(fp_idx);
end

