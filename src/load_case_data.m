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

filepath = resolve_case_filepath(pol_type, scenario, cfg);

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
validate_los_mask_counts(scenario, is_los, n_tags, cfg, los_source);

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
data.los_count = sum(is_los);
data.nlos_count = sum(~is_los);
data.source_file = filepath;
end

function filepath = resolve_case_filepath(pol_type, scenario, cfg)
% RESOLVE_CASE_FILEPATH Resolves one case file with flexible naming patterns.
case_stem = sprintf('%s_case%s', pol_type, scenario);
if strcmpi(pol_type, 'LP')
    preferred_stems = { ...
        case_stem, ...
        [case_stem '_2rx'], ...
        [case_stem '_new_vpol'], ...
        [case_stem '_new'] ...
        };
else
    preferred_stems = { ...
        case_stem, ...
        [case_stem '_2rx'], ...
        [case_stem '_new'] ...
        };
end
extensions = {'.csv', '.xlsx', '.xls'};

for i = 1:numel(preferred_stems)
    for j = 1:numel(extensions)
        cand = fullfile(cfg.data_dir, [preferred_stems{i} extensions{j}]);
        if isfile(cand)
            filepath = cand;
            return;
        end
    end
end

% Fallback: any file that starts with "<POL>_case<SCENARIO>" and supported ext.
all_files = dir(fullfile(cfg.data_dir, [case_stem '*']));
supported = false(numel(all_files), 1);
for k = 1:numel(all_files)
    if all_files(k).isdir
        continue;
    end
    [~, ~, ext] = fileparts(all_files(k).name);
    supported(k) = any(strcmpi(ext, extensions));
end
hits = all_files(supported);

if numel(hits) == 1
    filepath = fullfile(cfg.data_dir, hits(1).name);
    return;
end

if isempty(hits)
    error('load_case_data: file not found for %s-%s under %s', pol_type, scenario, cfg.data_dir);
end

% Multiple candidates: choose the most recently modified file.
[~, idx] = max([hits.datenum]);
filepath = fullfile(cfg.data_dir, hits(idx).name);
warning('load_case_data:multipleCandidates', ...
    ['Multiple files found for %s-%s. Using latest: %s'], ...
    pol_type, scenario, filepath);
end

function [is_los, source] = resolve_los_mask(scenario, pos_mm, n_tags, cfg)
% RESOLVE_LOS_MASK Builds LoS mask from external exported CSV if available.
is_los = false(n_tags, 1);
source = 'fallback_cfg_los_idx';
require_external = false;
if isfield(cfg, 'los_nlos') && isfield(cfg.los_nlos, 'require_external')
    require_external = logical(cfg.los_nlos.require_external);
end

if isfield(cfg, 'los_nlos') && isfield(cfg.los_nlos, 'use_external') && cfg.los_nlos.use_external
    [ok, mask_ext, src_path, coverage_ratio] = try_load_los_from_export(scenario, pos_mm, n_tags, cfg.los_nlos);
    if ok
        is_los = mask_ext;
        source = src_path;
        return;
    end
    if require_external
        error('load_case_data:missingExternalLoS', ...
            'External LoS/NLoS labels are required but not available for scenario %s.', scenario);
    else
        warning('load_case_data:externalLoSMissingFallback', ...
            'External LoS/NLoS labels not available for %s (coverage=%.3f). Falling back to cfg.los_idx.', ...
            scenario, coverage_ratio);
    end
end

% Fallback to legacy cfg.los_idx lists.
if isfield(cfg, 'los_idx') && isfield(cfg.los_idx, scenario)
    los_idx = cfg.los_idx.(scenario);
    los_idx = los_idx(:);
    los_idx = los_idx(los_idx >= 1 & los_idx <= n_tags);
    is_los(los_idx) = true;
end

if require_external
    error('load_case_data:missingExternalLoS', ...
        'External LoS/NLoS labels are required; fallback cfg.los_idx is disabled for scenario %s.', scenario);
end
end

function [ok, is_los, source, coverage_ratio] = try_load_los_from_export(scenario, pos_mm, n_tags, los_cfg)
% TRY_LOAD_LOS_FROM_EXPORT Loads scenario LoS mask from exported CSV files.
ok = false;
is_los = false(n_tags, 1);
source = '';
coverage_ratio = 0;

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

    [ok_local, mask_local, coverage_local] = build_mask_from_table(tbl, scenario, pos_mm, n_tags, los_cfg);
    if ok_local
        ok = true;
        is_los = mask_local;
        source = csv_path;
        coverage_ratio = coverage_local;
        return;
    elseif coverage_local > coverage_ratio
        coverage_ratio = coverage_local;
    end
end
end

function [ok, is_los, coverage_ratio] = build_mask_from_table(tbl, scenario, pos_mm, n_tags, los_cfg)
% BUILD_MASK_FROM_TABLE Parses one LOS/NLOS table into tag-wise mask.
ok = false;
is_los = false(n_tags, 1);
coverage_ratio = 0;
assigned = false(n_tags, 1);

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
            assigned(rx_idx) = true;
            if nnz(valid) >= n_tags - 1
                coverage_ratio = nnz(assigned) / n_tags;
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
        assigned(hit) = true;
    end
end

coverage_ratio = nnz(assigned) / n_tags;
require_complete = isfield(los_cfg, 'require_complete_tag_coverage') && ...
    logical(los_cfg.require_complete_tag_coverage);
if require_complete
    ok = nnz(assigned) == n_tags;
else
    ok = true;
end
end

function validate_los_mask_counts(scenario, is_los, n_tags, cfg, los_source)
% VALIDATE_LOS_MASK_COUNTS Enforces expected LoS/NLoS sample counts when configured.
if numel(is_los) ~= n_tags
    error('load_case_data:losMaskLengthMismatch', ...
        'LoS mask length mismatch for scenario %s (mask=%d, n_tags=%d).', ...
        scenario, numel(is_los), n_tags);
end

if ~isfield(cfg, 'los_nlos') || ~isfield(cfg.los_nlos, 'expected_counts') || ...
        ~isfield(cfg.los_nlos.expected_counts, scenario)
    return;
end
exp_counts = cfg.los_nlos.expected_counts.(scenario);
if ~isfield(exp_counts, 'los') || ~isfield(exp_counts, 'nlos')
    return;
end

n_los = sum(is_los);
n_nlos = sum(~is_los);
if n_los ~= exp_counts.los || n_nlos ~= exp_counts.nlos
    error('load_case_data:unexpectedLoSCounts', ...
        ['Scenario %s LoS/NLoS count mismatch from source %s. ', ...
         'Expected %d/%d but got %d/%d.'], ...
        scenario, los_source, exp_counts.los, exp_counts.nlos, n_los, n_nlos);
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
