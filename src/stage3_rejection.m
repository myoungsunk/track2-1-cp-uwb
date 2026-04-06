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

% Convert fp_window_ns to sample count using explicit sample period in ns.
sample_period_ns = 1e9 / (cfg.N_fft * cfg.delta_f);
T_win_samples = max(1, round(cfg.fp_window_ns / sample_period_ns));

for i = 1:n_tags
    [cir_mag, ~, d_axis_m] = compute_cir(data.S21_rx1(i, :).', cfg);
    [fp_idx, ~] = extract_first_path(cir_mag, d_axis_m, cfg);
    fp_end_idx = min(fp_idx + T_win_samples - 1, numel(cir_mag));

    E_fp = sum(cir_mag(fp_idx:fp_end_idx).^2);
    E_total = sum(cir_mag.^2);
    ratio_dB(i) = 10 * log10(max(E_fp, eps) / max(E_total, eps));
end

is_los = logical(data.is_los(:));
ratio_valid = ratio_dB(isfinite(ratio_dB));
m = compute_metrics(ratio_dB, data.is_los, struct('force_abs', false));

result = struct();
result.ratio_dB = ratio_dB;
result.mean_ratio_dB = mean(ratio_valid, 'omitnan');
result.mean_los_dB = local_mean_subset(ratio_dB, is_los);
result.mean_nlos_dB = local_mean_subset(ratio_dB, ~is_los);
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.cdf_basis = 'ratio_dB';

result.pol_type = data.pol_type;
result.scenario = data.scenario;
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
