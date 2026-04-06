function m = compute_metrics(err_vec, is_los, opts)
% COMPUTE_METRICS Computes RMSE, CEP, and empirical CDF from metric values.
%
% INPUT
%   err_vec : [N x 1] double   metric vector
%   is_los  : [N x 1] logical  LoS mask
%   opts    : struct (optional)
%       .force_abs : logical (default true)
%           true  -> use abs(err_vec) for RMSE/CEP/CDF
%           false -> keep signed/raw err_vec for RMSE/CEP/CDF
%
% OUTPUT
%   m.rmse      : scalar
%   m.rmse_los  : scalar
%   m.rmse_nlos : scalar (NaN if subset is empty)
%   m.cep67     : scalar
%   m.cep95     : scalar
%   m.cdf_x     : [K x 1] sorted error values
%   m.cdf_y     : [K x 1] cumulative probabilities

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'force_abs')
    opts.force_abs = true;
end

err = err_vec(:);
if opts.force_abs
    err = abs(err);
end
if nargin < 2 || isempty(is_los)
    is_los = true(size(err));
else
    is_los = logical(is_los(:));
end

if numel(err) ~= numel(is_los)
    error('compute_metrics: err_vec and is_los must have equal length.');
end

valid = isfinite(err);
err = err(valid);
is_los = is_los(valid);

m = struct();
if isempty(err)
    m.rmse = NaN;
    m.rmse_los = NaN;
    m.rmse_nlos = NaN;
    m.cep67 = NaN;
    m.cep95 = NaN;
    m.cdf_x = [];
    m.cdf_y = [];
    return;
end

m.rmse = sqrt(mean(err.^2, 'omitnan'));
m.rmse_los = local_rmse_subset(err, is_los);
m.rmse_nlos = local_rmse_subset(err, ~is_los);
m.cep67 = prctile(err, 67);
m.cep95 = prctile(err, 95);

m.cdf_x = sort(err, 'ascend');
m.cdf_y = (1:numel(m.cdf_x)).' ./ numel(m.cdf_x);
end

function r = local_rmse_subset(err, mask)
% LOCAL_RMSE_SUBSET Computes RMSE on masked entries; returns NaN if empty.
vals = err(mask);
if isempty(vals)
    r = NaN;
else
    r = sqrt(mean(vals.^2, 'omitnan'));
end
end
