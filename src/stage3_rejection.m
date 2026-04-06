function result = stage3_rejection(data, cfg)
% STAGE3_REJECTION Computes first-path multipath rejection ratio (MRR).
%
% INPUT
%   data : struct from load_case_data()
%   cfg  : struct from setup_config()
%
% OUTPUT
%   result.ratio_dB      : [N x 1] MRR per tag [dB]
%   result.mean_ratio_dB : scalar  mean MRR over all tags [dB]
%   result.mean_los_dB   : scalar  mean MRR over LoS tags [dB]
%   result.mean_nlos_dB  : scalar  mean MRR over NLoS tags [dB]
%   result.cdf_x         : [K x 1] CDF x-axis
%   result.cdf_y         : [K x 1] CDF y-axis
%   result.pol_type      : char    polarization label
%   result.scenario      : char    scenario label

n_tags = data.n_tags;
ratio_dB = nan(n_tags, 1);

dt_s = 1 / (cfg.N_fft * cfg.delta_f);
T_win_samples = max(1, round(cfg.fp_window_ns * 1e-9 / dt_s));

for i = 1:n_tags
    [cir_mag, ~, d_axis_m] = compute_cir(data.S21_rx1(i, :).', cfg);
    fp_idx = find_first_path_index(cir_mag, d_axis_m, cfg);
    fp_end_idx = min(fp_idx + T_win_samples - 1, numel(cir_mag));

    E_fp = sum(cir_mag(fp_idx:fp_end_idx).^2);
    E_total = sum(cir_mag.^2);
    ratio_dB(i) = 10 * log10(max(E_fp, eps) / max(E_total, eps));
end

is_los = logical(data.is_los(:));
ratio_valid = ratio_dB(isfinite(ratio_dB));

result = struct();
result.ratio_dB = ratio_dB;
result.mean_ratio_dB = mean(ratio_valid, 'omitnan');
result.mean_los_dB = local_mean_subset(ratio_dB, is_los);
result.mean_nlos_dB = local_mean_subset(ratio_dB, ~is_los);

x = sort(ratio_valid, 'ascend');
result.cdf_x = x;
if isempty(x)
    result.cdf_y = [];
else
    result.cdf_y = (1:numel(x)).' ./ numel(x);
end

result.pol_type = data.pol_type;
result.scenario = data.scenario;
end

function fp_idx = find_first_path_index(cir_mag, d_axis_m, cfg)
% FIND_FIRST_PATH_INDEX Finds first local peak above threshold after guard range.
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
end

function m = local_mean_subset(x, mask)
% LOCAL_MEAN_SUBSET Computes mean for a subset; returns NaN for empty subset.
vals = x(mask);
vals = vals(isfinite(vals));
if isempty(vals)
    m = NaN;
else
    m = mean(vals, 'omitnan');
end
end

