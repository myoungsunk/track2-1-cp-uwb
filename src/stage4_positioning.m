function result = stage4_positioning(s1_result, s2_result, data, cfg)
% STAGE4_POSITIONING Computes 2D position errors from range + DoA estimates.
% Position estimate uses measurement-space weighted least squares:
%   p_hat = argmin_p ((||p-pa||-r_hat)^2/sigma_r^2 + (wrap(atan2()-psi_a-theta_hat)^2/sigma_theta^2))
%
% INPUT
%   s1_result : struct from stage1_ranging()
%   s2_result : struct from stage2_doa()
%   data      : struct from load_case_data()
%   cfg       : struct from setup_config()
%
% OUTPUT
%   result.pos_est_mm          : [N x 2] estimated position [mm]
%   result.pos_est_cart_mm     : [N x 2] direct Cartesian conversion [mm]
%   result.pos_gt_mm           : [N x 2] ground-truth position [mm]
%   result.error_m             : [N x 1] Euclidean 2D error [m]
%   result.rmse_m              : scalar  RMSE over all tags [m]
%   result.rmse_los_m          : scalar  RMSE over LoS tags [m]
%   result.rmse_nlos_m         : scalar  RMSE over NLoS tags [m]
%   result.p90_m               : scalar  90th percentile error [m]
%   result.cep67_m             : scalar  67th percentile error [m]
%   result.cep95_m             : scalar  95th percentile error [m]
%   result.cdf_x               : [K x 1] CDF x-axis
%   result.cdf_y               : [K x 1] CDF y-axis
%   result.range_residual_m    : [N x 1] fused residual ||p-pa||-r_hat [m]
%   result.angle_residual_deg  : [N x 1] fused residual angle [deg]
%   result.sigma_r_m           : scalar  range sigma used in fusion [m]
%   result.sigma_theta_deg     : scalar  DoA sigma used in fusion [deg]
%   result.fusion_method       : char    fusion method label
%   result.convergence_rate    : scalar  converged ratio over valid tags
%   result.approx_pos_error_m  : [N x 1] sqrt(e_r^2 + (r*e_theta)^2) small-angle approximation
%   result.approx_pos_rmse_m   : scalar  RMSE of small-angle approximation
%   result.pol_type            : char    polarization label
%   result.scenario            : char    scenario label

n_tags = data.n_tags;
pos_gt_mm = data.pos_mm;
pos_est_mm = nan(n_tags, 2);
pos_est_cart_mm = nan(n_tags, 2);
range_residual_m = nan(n_tags, 1);
angle_residual_deg = nan(n_tags, 1);
is_converged = false(n_tags, 1);

[sigma_r_m, sigma_theta_deg] = local_pick_sigmas(s1_result, s2_result, cfg);
sigma_theta_rad = deg2rad(sigma_theta_deg);
anchor_m = cfg.anchor_mm(:).' / 1000;
psi_a_rad = deg2rad(cfg.anchor_boresight_deg);
fusion_method = lower(string(cfg.fusion.method));

if isfield(cfg, 'doa') && isfield(cfg.doa, 'invalidate_positioning_if_low_corr') ...
        && cfg.doa.invalidate_positioning_if_low_corr ...
        && isfield(s2_result, 'is_valid_for_positioning') ...
        && ~s2_result.is_valid_for_positioning
    warning('stage4_positioning:invalidDoA', ...
        ['Skipping positioning for %s-%s due to invalid DoA ', ...
         '(corr=%.3f below threshold).'], ...
        data.pol_type, data.scenario, s2_result.corr_coef);
    error_m = nan(n_tags, 1);
else
    for i = 1:n_tags
        r_hat_m = s1_result.range_est_m(i);
        theta_hat_deg = s2_result.doa_est_deg(i);
        if ~isfinite(r_hat_m) || ~isfinite(theta_hat_deg)
            continue;
        end
        theta_hat_rad = deg2rad(theta_hat_deg);

        p_cart_m = local_cartesian_from_measurement(r_hat_m, theta_hat_rad, anchor_m, psi_a_rad);
        pos_est_cart_mm(i, :) = p_cart_m * 1000;

        switch fusion_method
            case "measurement_space_wls"
                [p_est_m, info] = local_fuse_single_wls( ...
                    r_hat_m, theta_hat_rad, anchor_m, psi_a_rad, ...
                    sigma_r_m, sigma_theta_rad, cfg.fusion);
            case "cartesian_direct"
                p_est_m = p_cart_m;
                info = local_eval_residuals(p_est_m, r_hat_m, theta_hat_rad, ...
                    anchor_m, psi_a_rad, sigma_r_m, sigma_theta_rad, true, 0);
            otherwise
                error('stage4_positioning:unknownFusionMethod', ...
                    'Unknown cfg.fusion.method: %s', cfg.fusion.method);
        end

        pos_est_mm(i, :) = p_est_m * 1000;
        range_residual_m(i) = info.range_residual_m;
        angle_residual_deg(i) = info.angle_residual_deg;
        is_converged(i) = info.converged;
    end

    dx_mm = pos_est_mm(:, 1) - pos_gt_mm(:, 1);
    dy_mm = pos_est_mm(:, 2) - pos_gt_mm(:, 2);
    error_m = hypot(dx_mm, dy_mm) / 1000;
end

m = compute_metrics(error_m, data.is_los);
valid_err = error_m(isfinite(error_m));
if isempty(valid_err)
    p90_m = NaN;
else
    p90_m = prctile(valid_err, 90);
end

approx_pos_error_m = sqrt(s1_result.error_m(:).^2 + ...
    (s1_result.range_gt_m(:) .* deg2rad(s2_result.error_deg(:))).^2);
approx_pos_rmse_m = sqrt(mean(approx_pos_error_m.^2, 'omitnan'));

valid_fusion = isfinite(error_m);
if any(valid_fusion)
    convergence_rate = mean(is_converged(valid_fusion));
else
    convergence_rate = NaN;
end

result = struct();
result.pos_est_mm = pos_est_mm;
result.pos_est_cart_mm = pos_est_cart_mm;
result.pos_gt_mm = pos_gt_mm;
result.error_m = error_m;
result.rmse_m = m.rmse;
result.rmse_los_m = m.rmse_los;
result.rmse_nlos_m = m.rmse_nlos;
result.p90_m = p90_m;
result.cep67_m = m.cep67;
result.cep95_m = m.cep95;
result.cdf_x = m.cdf_x;
result.cdf_y = m.cdf_y;
result.cdf_basis = 'error_m';
result.range_residual_m = range_residual_m;
result.angle_residual_deg = angle_residual_deg;
result.sigma_r_m = sigma_r_m;
result.sigma_theta_deg = sigma_theta_deg;
result.fusion_method = char(fusion_method);
result.convergence_rate = convergence_rate;
result.approx_pos_error_m = approx_pos_error_m;
result.approx_pos_rmse_m = approx_pos_rmse_m;
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end

function [sigma_r_m, sigma_theta_deg] = local_pick_sigmas(s1_result, s2_result, cfg)
% LOCAL_PICK_SIGMAS Returns fusion sigmas from stage RMSE or fixed config.
mode = lower(string(cfg.fusion.sigma_mode));
switch mode
    case "from_stage_rmse"
        sigma_r_m = s1_result.rmse_m;
        sigma_theta_deg = s2_result.rmse_deg;
    case "fixed"
        sigma_r_m = cfg.fusion.fixed_sigma_r_m;
        sigma_theta_deg = cfg.fusion.fixed_sigma_theta_deg;
    otherwise
        error('stage4_positioning:unknownSigmaMode', ...
            'Unknown cfg.fusion.sigma_mode: %s', cfg.fusion.sigma_mode);
end

sigma_r_m = max(abs(sigma_r_m), cfg.fusion.min_sigma_r_m);
sigma_theta_deg = max(abs(sigma_theta_deg), cfg.fusion.min_sigma_theta_deg);
end

function p_m = local_cartesian_from_measurement(r_hat_m, theta_hat_rad, anchor_m, psi_a_rad)
% LOCAL_CARTESIAN_FROM_MEASUREMENT Direct conversion from (r,theta) to XY.
r_use = max(real(r_hat_m), eps);
bearing = psi_a_rad + theta_hat_rad;
p_m = anchor_m + [r_use * cos(bearing), r_use * sin(bearing)];
end

function [p_est_m, info] = local_fuse_single_wls( ...
    r_hat_m, theta_hat_rad, anchor_m, psi_a_rad, sigma_r_m, sigma_theta_rad, fusion_cfg)
% LOCAL_FUSE_SINGLE_WLS Gauss-Newton solve for one tag position.
p_est_m = local_cartesian_from_measurement(r_hat_m, theta_hat_rad, anchor_m, psi_a_rad);
converged = false;
iter_used = 0;

w_r = 1 / max(sigma_r_m^2, eps);
w_theta = 1 / max(sigma_theta_rad^2, eps);
W = diag([w_r, w_theta]);

for iter = 1:fusion_cfg.max_iter
    iter_used = iter;
    dx = p_est_m(1) - anchor_m(1);
    dy = p_est_m(2) - anchor_m(2);
    r_pred = hypot(dx, dy);
    if r_pred < eps
        r_pred = eps;
    end

    theta_pred = atan2(dy, dx) - psi_a_rad;
    v = [r_pred - r_hat_m; local_wrap_to_pi(theta_pred - theta_hat_rad)];
    J = [dx / r_pred, dy / r_pred; -dy / (r_pred^2), dx / (r_pred^2)];

    A = J' * W * J + fusion_cfg.damping * eye(2);
    b = J' * W * v;
    step = -A \ b;
    if any(~isfinite(step))
        break;
    end

    p_est_m = p_est_m + step.';
    if norm(step) < fusion_cfg.tol_step_m
        converged = true;
        break;
    end
end

info = local_eval_residuals(p_est_m, r_hat_m, theta_hat_rad, ...
    anchor_m, psi_a_rad, sigma_r_m, sigma_theta_rad, converged, iter_used);
end

function info = local_eval_residuals( ...
    p_est_m, r_hat_m, theta_hat_rad, anchor_m, psi_a_rad, sigma_r_m, sigma_theta_rad, converged, iter_used)
% LOCAL_EVAL_RESIDUALS Evaluates fused range/angle residuals and cost.
dx = p_est_m(1) - anchor_m(1);
dy = p_est_m(2) - anchor_m(2);
r_pred = hypot(dx, dy);
theta_pred = atan2(dy, dx) - psi_a_rad;

res_r = r_pred - r_hat_m;
res_theta_rad = local_wrap_to_pi(theta_pred - theta_hat_rad);

cost = (res_r^2) / max(sigma_r_m^2, eps) + ...
    (res_theta_rad^2) / max(sigma_theta_rad^2, eps);

info = struct();
info.range_residual_m = res_r;
info.angle_residual_deg = rad2deg(res_theta_rad);
info.cost = cost;
info.converged = converged;
info.iter_used = iter_used;
end

function a = local_wrap_to_pi(a)
% LOCAL_WRAP_TO_PI Wraps angle(s) to [-pi, pi).
a = mod(a + pi, 2 * pi) - pi;
end
