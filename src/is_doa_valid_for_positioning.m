function [is_valid, metric, mode_str] = is_doa_valid_for_positioning(doa_corr, doa_cfg)
% IS_DOA_VALID_FOR_POSITIONING Applies DoA validity gate policy.
%
% INPUT
%   doa_corr : scalar correlation between DoA estimate and GT
%   doa_cfg  : struct with fields:
%       .validity_corr_threshold
%       .validity_corr_mode ('signed' | 'abs')
%
% OUTPUT
%   is_valid : logical scalar
%   metric   : scalar correlation metric used for gating
%   mode_str : char gating mode

thr = local_get_field(doa_cfg, 'validity_corr_threshold', 0.30);
mode_str = lower(string(local_get_field(doa_cfg, 'validity_corr_mode', 'signed')));
mode_norm = replace(mode_str, "_", "");

if ~isfinite(doa_corr)
    is_valid = false;
    metric = NaN;
    mode_str = char(mode_norm);
    return;
end

switch char(mode_norm)
    case 'abs'
        metric = abs(doa_corr);
    otherwise
        metric = doa_corr;
        mode_norm = "signed";
end

is_valid = metric >= thr;
mode_str = char(mode_norm);
end

function v = local_get_field(s, f, default_v)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
else
    v = default_v;
end
end

