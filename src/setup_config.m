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
cfg.anchor_boresight_deg = 0; % anchor boresight angle [deg] from +x axis

% ---- First-path detection ----
cfg.fp_threshold_ratio = 0.1;
cfg.fp_search_start_m = 0.3;

% ---- Stage 3: multipath window ----
cfg.fp_window_ns = 5;

% ---- Stage 3: first-path sharpness metric ----
cfg.sharpness = struct();
cfg.sharpness.exclusion_ns = 1.0;   % exclude +/- around FP peak when building background

% ---- Stage 2: DoA / tilted tag ----
cfg.theta_tilt_deg = 45;
cfg.rssd_lut_step = 0.1;
cfg.doa_range_deg = [-90, 90];

% ---- Stage 2/4: DoA convention + validity gating ----
cfg.doa = struct();
cfg.doa.sign_correction = struct();
cfg.doa.sign_correction.CP = -1;   % CP guide inc_ang sign is opposite to GT azimuth
cfg.doa.sign_correction.LP = -1;   % LP uses same sign convention as CP for consistency
cfg.doa.validity_corr_threshold = 0.30;
cfg.doa.invalidate_positioning_if_low_corr = true;

% ---- Stage 4: measurement-space fusion ----
cfg.fusion = struct();
cfg.fusion.method = 'measurement_space_wls';   % 'measurement_space_wls' | 'cartesian_direct'
cfg.fusion.sigma_mode = 'from_stage_rmse';     % 'from_stage_rmse' | 'fixed'
cfg.fusion.fixed_sigma_r_m = 0.25;             % used when sigma_mode='fixed'
cfg.fusion.fixed_sigma_theta_deg = 10;         % used when sigma_mode='fixed'
cfg.fusion.min_sigma_r_m = 1e-3;
cfg.fusion.min_sigma_theta_deg = 1e-2;
cfg.fusion.max_iter = 20;
cfg.fusion.tol_step_m = 1e-6;
cfg.fusion.damping = 1e-12;

% ---- Stage 2: external RSSD guide files ----
cfg.guide = struct();
cfg.guide.use_external = true;
cfg.guide.fallback_to_theory = true;
cfg.guide.cp_csv = 'E:\0. CP Antenna\CP_sbr_re\0.step1_ranging+Los\inc_ang_RSSD_validation_patch.csv';
cfg.guide.lp_csv = 'E:\0. CP Antenna\CP_sbr_re\0.step3_new_ffd_synthesis_data\step3\step3_baseline_inc_ang.csv';

% ---- Scenario metadata ----
cfg.scenarios = {'A', 'B', 'C'};
cfg.pol_types = {'CP', 'LP'};
cfg.n_tags = 56;

cfg.los_idx = struct();
cfg.los_idx.A = 1:56;
cfg.los_idx.B = [];    % fallback only (external label file is preferred)
cfg.los_idx.C = [];    % fallback only (external label file is preferred)

% ---- LoS/NLoS label source (external exported CSV) ----
cfg.los_nlos = struct();
cfg.los_nlos.use_external = true;
cfg.los_nlos.class_field = 'geometric_class';  % 'geometric_class' | 'material_class'
cfg.los_nlos.coord_tolerance_m = 1e-6;
cfg.los_nlos.base_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'LOS_NLOS_EXPORT_20260405');
cfg.los_nlos.all_csv = fullfile(cfg.los_nlos.base_dir, 'track23_all_scenarios_los_nlos.csv');
cfg.los_nlos.scenario_csv = struct();
cfg.los_nlos.scenario_csv.A = fullfile(cfg.los_nlos.base_dir, 'track23_scenario_a_los_nlos.csv');
cfg.los_nlos.scenario_csv.B = fullfile(cfg.los_nlos.base_dir, 'track23_scenario_b_los_nlos.csv');
cfg.los_nlos.scenario_csv.C = fullfile(cfg.los_nlos.base_dir, 'track23_scenario_c_los_nlos.csv');

% ---- Paths ----
script_dir = fileparts(mfilename('fullpath'));
cfg.data_dir = fullfile(script_dir, '..', 'data');
cfg.results_dir = fullfile(script_dir, '..', 'results');

if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end
end
