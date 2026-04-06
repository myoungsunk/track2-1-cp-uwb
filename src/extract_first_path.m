function [fp_idx, fp_range_m, fp_amp] = extract_first_path(cir_mag, d_axis_m, cfg)
% EXTRACT_FIRST_PATH Finds first-path peak index/range from CIR magnitude.
%
% INPUT
%   cir_mag  : [N x 1] double   CIR magnitude (linear)
%   d_axis_m : [N x 1] double   range axis [m]
%   cfg      : struct           must include fp_threshold_ratio, fp_search_start_m
%
% OUTPUT
%   fp_idx     : scalar int     first-path sample index
%   fp_range_m : scalar double  first-path range [m]
%   fp_amp     : scalar double  first-path amplitude

cir_mag = cir_mag(:);
d_axis_m = d_axis_m(:);
if numel(cir_mag) ~= numel(d_axis_m)
    error('extract_first_path: size mismatch between cir_mag and d_axis_m.');
end

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

fp_range_m = d_axis_m(fp_idx);
fp_amp = cir_mag(fp_idx);
end

