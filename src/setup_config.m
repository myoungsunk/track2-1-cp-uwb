function cfg = setup_config()
% SETUP_CONFIG Returns the global configuration struct.
%
% OUTPUT
%   cfg : struct with project-wide parameters.
%
% NOTES
%   - LoS index lists for scenarios B/C must be updated from simulation logs.
%   - Results directory is created automatically when missing.

cfg = struct();

% ---- System parameters ----
cfg.c = 3e8;                 % speed of light [m/s]
cfg.f_start = 6.24e9;        % start frequency [Hz]
cfg.f_stop = 6.74e9;         % stop frequency [Hz]
cfg.delta_f = 1e6;           % frequency step [Hz]
cfg.N_freq = 501;            % number of frequency points
cfg.BW = 500e6;              % bandwidth [Hz]
cfg.fc = 6.49e9;             % center frequency [Hz]

% ---- IFFT / CIR parameters ----
cfg.N_fft = 2^14;            % zero-pad length (16384)
cfg.window_type = 'hann';    % 'hann' | 'hamming' | 'rect'

% ---- Geometry ----
cfg.anchor_mm = [0, 0];      % anchor position [mm]

% ---- First-path detection ----
cfg.fp_threshold_ratio = 0.1;
cfg.fp_search_start_m = 0.3;

% ---- Stage 3: multipath window ----
cfg.fp_window_ns = 5;

% ---- Stage 2: DoA / tilted tag ----
cfg.theta_tilt_deg = 45;
cfg.rssd_lut_step = 0.1;
cfg.doa_range_deg = [-90, 90];

% ---- Scenario metadata ----
cfg.scenarios = {'A', 'B', 'C'};
cfg.pol_types = {'CP', 'LP'};
cfg.n_tags = 56;

cfg.los_idx = struct();
cfg.los_idx.A = 1:56;
cfg.los_idx.B = 1:34;  % TODO: insert exact 34 LoS tag indices from simulation log
cfg.los_idx.C = 1:21;  % TODO: insert exact 21 LoS tag indices from simulation log

% ---- Paths ----
script_dir = fileparts(mfilename('fullpath'));
cfg.data_dir = fullfile(script_dir, '..', 'data');
cfg.results_dir = fullfile(script_dir, '..', 'results');

if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end
end

