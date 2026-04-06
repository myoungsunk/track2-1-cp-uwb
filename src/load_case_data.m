function data = load_case_data(pol_type, scenario, cfg)
% LOAD_CASE_DATA Loads one CSV case file and returns structured data.
%
% INPUT
%   pol_type : char/string  'CP' or 'LP'
%   scenario : char/string  'A', 'B', or 'C'
%   cfg      : struct       from setup_config()
%
% OUTPUT
%   data.pol_type   : char          polarization type
%   data.scenario   : char          scenario ID
%   data.n_tags     : int           number of tags
%   data.pos_mm     : [N x 2]       tag positions [x, y] in mm
%   data.freq_Hz    : [N_freq x 1]  frequency axis [Hz]
%   data.S21_rx1    : [N x N_freq]  complex S21 (antenna 1)
%   data.S21_rx2    : [N x N_freq]  complex S21 (antenna 2)
%   data.range_gt_m : [N x 1]       ground-truth range [m]
%   data.doa_gt_deg : [N x 1]       ground-truth DoA [deg]
%   data.is_los     : [N x 1]       LoS mask

pol_type = upper(char(string(pol_type)));
scenario = upper(char(string(scenario)));

if ~ismember(pol_type, cfg.pol_types)
    error('load_case_data: invalid pol_type "%s".', pol_type);
end
if ~ismember(scenario, cfg.scenarios)
    error('load_case_data: invalid scenario "%s".', scenario);
end

filepath = fullfile(cfg.data_dir, sprintf('%s_case%s.csv', pol_type, scenario));
assert(isfile(filepath), 'load_case_data: file not found: %s', filepath);

tbl = readtable(filepath, 'VariableNamingRule', 'preserve');
if width(tbl) < 7
    error('load_case_data: expected >=7 columns in %s', filepath);
end

x_mm_flat = double(tbl{:, 1});
y_mm_flat = double(tbl{:, 2});
freq_ghz_flat = double(tbl{:, 3});
mag1_flat = double(tbl{:, 4});
ang1_deg_flat = double(tbl{:, 5});
mag2_flat = double(tbl{:, 6});
ang2_deg_flat = double(tbl{:, 7});

n_rows = numel(x_mm_flat);
if mod(n_rows, cfg.N_freq) ~= 0
    error('load_case_data: row count %d is not divisible by cfg.N_freq=%d.', n_rows, cfg.N_freq);
end

n_tags = n_rows / cfg.N_freq;
if n_tags ~= cfg.n_tags
    warning('load_case_data:nTagsMismatch', ...
        'Expected cfg.n_tags=%d, but file has %d tags.', cfg.n_tags, n_tags);
end

x_mm_mat = reshape(x_mm_flat, cfg.N_freq, n_tags).';
y_mm_mat = reshape(y_mm_flat, cfg.N_freq, n_tags).';
freq_hz_mat = reshape(freq_ghz_flat * 1e9, cfg.N_freq, n_tags).';

S21_rx1_flat = mag1_flat .* exp(1j * deg2rad(ang1_deg_flat));
S21_rx2_flat = mag2_flat .* exp(1j * deg2rad(ang2_deg_flat));
S21_rx1 = reshape(S21_rx1_flat, cfg.N_freq, n_tags).';
S21_rx2 = reshape(S21_rx2_flat, cfg.N_freq, n_tags).';

pos_mm = [x_mm_mat(:, 1), y_mm_mat(:, 1)];
freq_Hz = freq_hz_mat(1, :).';

dx_mm = pos_mm(:, 1) - cfg.anchor_mm(1);
dy_mm = pos_mm(:, 2) - cfg.anchor_mm(2);
range_gt_m = hypot(dx_mm, dy_mm) / 1000;
doa_gt_deg = atan2d(dy_mm, dx_mm);

[is_los, los_source] = resolve_los_mask(scenario, pos_mm, n_tags, cfg);

data = struct();
data.pol_type = pol_type;
data.scenario = scenario;
data.n_tags = n_tags;
data.pos_mm = pos_mm;
data.freq_Hz = freq_Hz;
data.S21_rx1 = S21_rx1;
data.S21_rx2 = S21_rx2;
data.range_gt_m = range_gt_m;
data.doa_gt_deg = doa_gt_deg;
data.is_los = is_los;
data.los_source = los_source;
end

function [is_los, source] = resolve_los_mask(scenario, pos_mm, n_tags, cfg)
% RESOLVE_LOS_MASK Builds LoS mask from external exported CSV if available.
is_los = false(n_tags, 1);
source = 'fallback_cfg_los_idx';

if isfield(cfg, 'los_nlos') && isfield(cfg.los_nlos, 'use_external') && cfg.los_nlos.use_external
    [ok, mask_ext, src_path] = try_load_los_from_export(scenario, pos_mm, n_tags, cfg.los_nlos);
    if ok
        is_los = mask_ext;
        source = src_path;
        return;
    end
end

% Fallback to legacy cfg.los_idx lists.
if isfield(cfg, 'los_idx') && isfield(cfg.los_idx, scenario)
    los_idx = cfg.los_idx.(scenario);
    los_idx = los_idx(:);
    los_idx = los_idx(los_idx >= 1 & los_idx <= n_tags);
    is_los(los_idx) = true;
end
end

function [ok, is_los, source] = try_load_los_from_export(scenario, pos_mm, n_tags, los_cfg)
% TRY_LOAD_LOS_FROM_EXPORT Loads scenario LoS mask from exported CSV files.
ok = false;
is_los = false(n_tags, 1);
source = '';

candidate_paths = {};
if isfield(los_cfg, 'all_csv') && ~isempty(los_cfg.all_csv)
    candidate_paths{end+1} = los_cfg.all_csv; %#ok<AGROW>
end
if isfield(los_cfg, 'scenario_csv') && isfield(los_cfg.scenario_csv, scenario)
    candidate_paths{end+1} = los_cfg.scenario_csv.(scenario); %#ok<AGROW>
end

for i = 1:numel(candidate_paths)
    csv_path = candidate_paths{i};
    if ~isfile(csv_path)
        continue;
    end

    try
        tbl = readtable(csv_path, 'VariableNamingRule', 'preserve');
    catch
        continue;
    end
    if isempty(tbl)
        continue;
    end

    [ok_local, mask_local] = build_mask_from_table(tbl, scenario, pos_mm, n_tags, los_cfg);
    if ok_local
        ok = true;
        is_los = mask_local;
        source = csv_path;
        return;
    end
end
end

function [ok, is_los] = build_mask_from_table(tbl, scenario, pos_mm, n_tags, los_cfg)
% BUILD_MASK_FROM_TABLE Parses one LOS/NLOS table into tag-wise mask.
ok = false;
is_los = false(n_tags, 1);

names = tbl.Properties.VariableNames;
scenario_col = find_col(names, {'scenario'});
if isempty(scenario_col)
    return;
end

scenario_vals = upper(string(tbl.(scenario_col)));
row_sel = scenario_vals == upper(string(scenario));
if ~any(row_sel)
    return;
end

sub = tbl(row_sel, :);
sub_names = sub.Properties.VariableNames;

class_col = find_col(sub_names, {char(los_cfg.class_field), 'geometric_class', 'material_class'});
if isempty(class_col)
    return;
end
class_vals = upper(string(sub.(class_col)));

rx_col = find_col(sub_names, {'rx_index', 'rx index'});
if ~isempty(rx_col)
    rx_idx = double(sub.(rx_col));
    valid = isfinite(rx_idx) & rx_idx >= 1 & rx_idx <= n_tags;
    rx_idx = rx_idx(valid);
    class_vals_v = class_vals(valid);
    if ~isempty(rx_idx)
        is_los(rx_idx) = class_vals_v == "LOS";
        if nnz(valid) >= n_tags - 1
            ok = true;
            return;
        end
    end
end

% Coordinate fallback mapping if rx_index is missing/incomplete.
x_col = find_col(sub_names, {'x_m', 'x m'});
y_col = find_col(sub_names, {'y_m', 'y m'});
if isempty(x_col) || isempty(y_col)
    return;
end

x_m = double(sub.(x_col));
y_m = double(sub.(y_col));
coord_tol = los_cfg.coord_tolerance_m;

for r = 1:height(sub)
    if ~isfinite(x_m(r)) || ~isfinite(y_m(r))
        continue;
    end
    dx = abs(pos_mm(:, 1) / 1000 - x_m(r));
    dy = abs(pos_mm(:, 2) / 1000 - y_m(r));
    hit = find(dx <= coord_tol & dy <= coord_tol, 1, 'first');
    if ~isempty(hit)
        is_los(hit) = class_vals(r) == "LOS";
    end
end

if any(is_los) || any(class_vals == "NLOS")
    ok = true;
end
end

function col = find_col(names, patterns)
% FIND_COL Finds variable name by normalized substring match.
col = '';
norm_names = normalize_list(names);
norm_patterns = normalize_list(patterns);
for p = 1:numel(norm_patterns)
    hit = contains(norm_names, norm_patterns{p});
    if any(hit)
        col = names{find(hit, 1, 'first')};
        return;
    end
end
end

function out = normalize_list(in)
% NORMALIZE_LIST Lowercases and strips non-alnum.
out = cell(size(in));
for i = 1:numel(in)
    s = lower(char(string(in{i})));
    s = regexprep(s, '[^a-z0-9]', '');
    out{i} = s;
end
end
