function [fp_idx, fp_range_m, fp_amp, info] = extract_first_path(cir_mag, d_axis_m, cfg)
% EXTRACT_FIRST_PATH Finds first-path index/range from CIR magnitude.
%
% INPUT
%   cir_mag  : [N x 1] double   CIR magnitude (linear)
%   d_axis_m : [N x 1] double   range axis [m]
%   cfg      : struct
%
% OUTPUT
%   fp_idx     : scalar int     first-path sample index
%   fp_range_m : scalar double  first-path range [m]
%   fp_amp     : scalar double  first-path amplitude
%   info       : struct         detector diagnostics

cir_mag = double(cir_mag(:));
d_axis_m = double(d_axis_m(:));
if numel(cir_mag) ~= numel(d_axis_m)
    error('extract_first_path:sizeMismatch', 'cir_mag and d_axis_m size mismatch.');
end
if isempty(cir_mag)
    error('extract_first_path:emptyInput', 'cir_mag is empty.');
end

n = numel(cir_mag);
search_start_idx = find(d_axis_m >= cfg.fp_search_start_m, 1, 'first');
if isempty(search_start_idx)
    search_start_idx = 1;
end
search_idx = search_start_idx:n;
cir_search = cir_mag(search_idx);

[peak_val, peak_rel] = max(cir_search);
peak_idx = search_idx(peak_rel);

threshold_peak = cfg.fp_threshold_ratio * peak_val;
noise_head = local_get_cfg(cfg, 'fp_noise_head_samples', 32);
noise_head = max(1, round(noise_head));
if search_start_idx > 1
    noise_ref = cir_mag(1:min(search_start_idx - 1, noise_head));
else
    noise_ref = cir_search(1:min(numel(cir_search), noise_head));
end
noise_mu = mean(noise_ref, 'omitnan');
noise_sigma = std(noise_ref, 0, 'omitnan');
if ~isfinite(noise_mu), noise_mu = 0; end
if ~isfinite(noise_sigma), noise_sigma = 0; end

noise_k = local_get_cfg(cfg, 'fp_noise_sigma', 6.0);
threshold_noise = noise_mu + noise_k * noise_sigma;
threshold_floor = local_get_cfg(cfg, 'fp_min_peak_ratio', 0.03) * peak_val;

mode_str = lower(string(local_get_cfg(cfg, 'fp_threshold_mode', 'hybrid')));
mode_norm = replace(mode_str, "_", "");
switch mode_norm
    case "peakratio"
        threshold = threshold_peak;
    case "noisesigma"
        threshold = max(threshold_noise, threshold_floor);
    case "hybrid"
        threshold = max(min(threshold_peak, threshold_noise), threshold_floor);
    otherwise
        threshold = threshold_peak;
end
threshold = min(threshold, peak_val);

run_len = max(1, round(local_get_cfg(cfg, 'fp_min_run_len', 1)));
cross_rel = local_first_run_index(cir_search >= threshold, run_len);

peak_rel_all = local_local_peak_indices(cir_search, threshold);
if ~isempty(cross_rel) && ~isempty(peak_rel_all)
    peak_rel_all = peak_rel_all(peak_rel_all >= cross_rel);
end

fallback_used = false;
if ~isempty(peak_rel_all)
    fp_rel = peak_rel_all(1);
elseif ~isempty(cross_rel)
    fp_rel = cross_rel;
else
    fp_rel = peak_rel;
    fallback_used = true;
end

fp_idx = search_idx(fp_rel);
fp_range_m = d_axis_m(fp_idx);
fp_amp = cir_mag(fp_idx);

info = struct();
info.search_start_idx = search_start_idx;
info.peak_idx = peak_idx;
info.peak_val = peak_val;
info.threshold = threshold;
info.threshold_peak = threshold_peak;
info.threshold_noise = threshold_noise;
info.threshold_floor = threshold_floor;
info.noise_mean = noise_mu;
info.noise_std = noise_sigma;
info.threshold_mode = char(mode_str);
info.fallback_used = fallback_used;
end

function val = local_get_cfg(cfg, field_name, default_val)
if isfield(cfg, field_name) && ~isempty(cfg.(field_name))
    val = cfg.(field_name);
else
    val = default_val;
end
end

function idx = local_first_run_index(mask, run_len)
idx = [];
mask = logical(mask(:));
if isempty(mask)
    return;
end
if run_len <= 1
    idx = find(mask, 1, 'first');
    return;
end
hits = conv(double(mask), ones(run_len, 1), 'valid');
i0 = find(hits >= run_len, 1, 'first');
if ~isempty(i0)
    idx = i0;
end
end

function peaks = local_local_peak_indices(x, threshold)
peaks = [];
n = numel(x);
if n < 3
    return;
end
for k = 2:n-1
    if x(k) >= threshold && x(k) >= x(k-1) && x(k) >= x(k+1)
        peaks(end+1) = k; %#ok<AGROW>
    end
end
end
