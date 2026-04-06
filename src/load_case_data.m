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

is_los = false(n_tags, 1);
los_idx = cfg.los_idx.(scenario);
if isempty(los_idx)
    warning('load_case_data:missingLosIdx', ...
        'cfg.los_idx.%s is empty. Set LoS indices from simulation metadata.', scenario);
end
los_idx = los_idx(:);
los_idx = los_idx(los_idx >= 1 & los_idx <= n_tags);
is_los(los_idx) = true;

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
end

