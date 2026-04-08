function cfg = setup_config()
% SETUP_CONFIG Returns the global configuration struct.
%
% OUTPUT
%   cfg : struct with project-wide parameters.

cfg = struct();

% ---- Paths ----
script_dir = fileparts(mfilename('fullpath'));
cfg.data_dir = fullfile(script_dir, '..', 'data');
cfg.results_dir = fullfile(script_dir, '..', 'results');
if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end

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
cfg.anchor_mm = [0, 0];       % anchor position [mm]
cfg.anchor_boresight_deg = 0; % boresight angle [deg] from +x axis

% ---- First-path detection ----
cfg.fp_threshold_ratio = 0.1;
cfg.fp_search_start_m = 0.3;
cfg.fp_threshold_mode = 'hybrid';   % 'peak_ratio' | 'noise_sigma' | 'hybrid'
cfg.fp_noise_sigma = 6.0;
cfg.fp_min_peak_ratio = 0.03;
cfg.fp_min_run_len = 1;
cfg.fp_noise_head_samples = 32;

% ---- Stage 3: multipath window ----
cfg.fp_window_ns = 5;

% ---- Stage 3: first-path sharpness metric ----
cfg.sharpness = struct();
cfg.sharpness.exclusion_ns = 1.0;

% ---- Stage 2: DoA / tilted tag ----
cfg.theta_tilt_deg = 45;
cfg.rssd_lut_step = 0.1;
cfg.doa_range_deg = [-90, 90];

cfg.doa = struct();
cfg.doa.sign_correction = struct();
cfg.doa.sign_correction.CP = -1;  % CP guide inc_ang sign is opposite to GT azimuth
cfg.doa.sign_correction.LP = -1;  % LP follows same sign convention as CP
cfg.doa.validity_corr_threshold = 0.30;
cfg.doa.validity_corr_mode = 'signed';  % 'signed' | 'abs'
cfg.doa.invalidate_positioning_if_low_corr = true;
cfg.doa.sign_autoflip_if_better = true;
cfg.doa.sign_autoflip_margin = 0.05;

% LUT inverse behavior
cfg.doa.inverse_mode = 'branch_aware';  % global fallback: 'branch_aware' | 'legacy_single' | 'affine'
cfg.doa.inverse_mode_by_pol = struct();
cfg.doa.inverse_mode_by_pol.CP = 'branch_aware';
cfg.doa.inverse_mode_by_pol.LP = 'branch_aware'; % LP guide mismatch ?꾪솕??湲곕낯 ?ㅼ젙
% Optional branch filter for branch-aware inverse.
% direction: 'all' | 'increasing' | 'decreasing'
cfg.doa.segment_filter = struct();
cfg.doa.segment_filter.enabled = false;
cfg.doa.segment_filter.direction = 'all';
cfg.doa.segment_filter.use_largest_only = false;
cfg.doa.segment_filter.by_pol = struct();
cfg.doa.segment_filter.by_pol.CP = struct('enabled', false, 'direction', 'all', 'use_largest_only', false);
cfg.doa.segment_filter.by_pol.LP = struct('enabled', false, 'direction', 'all', 'use_largest_only', false);
% Optional slope conditioning for inverse stability.
% If |dRSSD/dtheta| < s_min, DoA estimate can be unreliable.
cfg.doa.slope_conditioning = struct();
cfg.doa.slope_conditioning.enabled = false;
cfg.doa.slope_conditioning.mode = 'invalidate';  % 'invalidate' | 'off'
cfg.doa.slope_conditioning.s_min_db_per_deg = 0.02;
cfg.doa.slope_conditioning.by_pol = struct();
cfg.doa.slope_conditioning.by_pol.CP = struct('enabled', false, 'mode', 'invalidate', 's_min_db_per_deg', 0.02);
cfg.doa.slope_conditioning.by_pol.LP = struct('enabled', false, 'mode', 'invalidate', 's_min_db_per_deg', 0.02);
cfg.doa.candidate_tol_db = 0.1;
cfg.doa.default_branch = 0;             % 0 means "no preferred branch"
cfg.doa.branch_penalty_db = 0.0;
cfg.doa.out_of_range_penalty_db = 0.2;
cfg.doa.prior_weight = 0.0;
cfg.doa.lut_slope_eps = 1e-6;
cfg.doa.lut_min_segment_points = 8;
cfg.doa.curve_smooth_span = 1;
cfg.doa.compute_affine_sanity = true;

% ---- Stage 4: measurement-space fusion ----
cfg.fusion = struct();
cfg.fusion.method = 'measurement_space_wls';   % 'measurement_space_wls' | 'cartesian_direct'
cfg.fusion.objective = 'dual_range_angle';     % use r_rx1, r_rx2, theta together
cfg.fusion.doa_hypothesis_mode = 'joint_wls';     % 'single' | 'joint_wls' (multi-section DoA candidates)
cfg.fusion.joint_theta = struct();
cfg.fusion.joint_theta.lambda_inv_cost = 1.0;
cfg.fusion.joint_theta.lambda_cont_deg = 0.05;
cfg.fusion.joint_theta.out_of_range_penalty = 0.0;
cfg.fusion.sigma_mode = 'from_stage_rmse';     % 'from_stage_rmse' | 'fixed'
cfg.fusion.fixed_sigma_r1_m = 0.25;
cfg.fusion.fixed_sigma_r2_m = 0.25;
cfg.fusion.fixed_sigma_theta_deg = 10;
cfg.fusion.min_sigma_r_m = 1e-3;
cfg.fusion.min_sigma_theta_deg = 1e-2;
cfg.fusion.max_iter = 500;
cfg.fusion.max_fun_eval = 2000;
cfg.fusion.tol_step_m = 1e-8;
cfg.fusion.tol_fun = 1e-8;

% ---- Stage 2: external RSSD guide files ----
% Reproducible default is project-local; user can override with absolute path.
cfg.guide = struct();
cfg.guide.use_external = true;
cfg.guide.fallback_to_theory = true;
cfg.guide.cp_csv_candidates = { ...
    fullfile(cfg.data_dir, 'inc_ang_RSSD_validation_patch_height=1m_23R1.csv'), ...
    fullfile(cfg.data_dir, 'inc_ang_RSSD_validation_patch.csv'), ...
    fullfile(cfg.data_dir, 'guide_cp_incang_rssd.csv') ...
    };
cfg.guide.lp_csv_candidates = { ...
    fullfile(cfg.data_dir, 'step3_baseline_inc_ang_align.csv'), ...
    fullfile(cfg.data_dir, 'step3_baseline_inc_ang_height=1m_23R1.csv'), ...
    fullfile(cfg.data_dir, 'step3_baseline_inc_ang.csv'), ...
    fullfile(cfg.data_dir, 'guide_lp_incang_rssd.csv') ...
    };
cfg.guide.column_candidates = struct();
cfg.guide.column_candidates.inc_ang = {'inc_ang', 'inc ang', 'inc_ang_deg', 'anc_ang'};
cfg.guide.column_candidates.mag_rx1 = {'mag(S(rx1_p1,tx_p1))', 'mag_s_rx1', 'rx1'};
cfg.guide.column_candidates.mag_rx2 = {'mag(S(rx2_p1,tx_p1))', 'mag_s_rx2', 'rx2'};

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
cfg.los_nlos.require_external = true;
cfg.los_nlos.require_complete_tag_coverage = true;
cfg.los_nlos.class_field = 'geometric_class';  % 'geometric_class' | 'material_class'
cfg.los_nlos.coord_tolerance_m = 1e-6;
cfg.los_nlos.base_dir = fullfile(script_dir, '..', 'LOS_NLOS_EXPORT_20260405');
cfg.los_nlos.all_csv = fullfile(cfg.los_nlos.base_dir, 'track23_all_scenarios_los_nlos.csv');
cfg.los_nlos.scenario_csv = struct();
cfg.los_nlos.scenario_csv.A = fullfile(cfg.los_nlos.base_dir, 'track23_scenario_a_los_nlos.csv');
cfg.los_nlos.scenario_csv.B = fullfile(cfg.los_nlos.base_dir, 'track23_scenario_b_los_nlos.csv');
cfg.los_nlos.scenario_csv.C = fullfile(cfg.los_nlos.base_dir, 'track23_scenario_c_los_nlos.csv');

cfg.los_nlos.expected_counts = struct();
cfg.los_nlos.expected_counts.A = struct('los', 56, 'nlos', 0);
cfg.los_nlos.expected_counts.B = struct('los', 35, 'nlos', 21);
cfg.los_nlos.expected_counts.C = struct('los', 21, 'nlos', 35);

% ---- Range calibration ----
cfg.range_calibration = struct();
cfg.range_calibration.mode = 'fixed_offset';      % 'none' | 'fixed_offset' | 'los_median'
cfg.range_calibration.fixed_offset_m = 0.0;       % positive value shortens estimated range
cfg.range_calibration.min_los_count = 8;

% ---- Cross-stage analysis ----
cfg.analysis = struct();
cfg.analysis.enable_counterfactual = true;
cfg.analysis.enable_fusion_ablation = true;
cfg.analysis.counterfactual_disable_doa_gate = true;

% ---- Statistics / uncertainty ----
cfg.stats = struct();
cfg.stats.rng_seed = 20260408;
cfg.stats.bootstrap_enabled = true;
cfg.stats.bootstrap_n = 2000;
cfg.stats.bootstrap_alpha = 0.05;

% ---- Run manifest ----
cfg.manifest = struct();
cfg.manifest.save_json = true;
end

