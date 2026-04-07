function result = stage4_positioning(s1_result, s2_result, data, cfg)
% STAGE4_POSITIONING Computes 2D position errors from dual-range + DoA fusion.
%
% Objective per tag:
%   min_p  ((||p-pa||-r1)^2 / sigma_r1^2)
%        + ((||p-pa||-r2)^2 / sigma_r2^2)
%        + (wrap(atan2()-psi_a-theta)^2 / sigma_theta^2)
%
% INPUT
%   s1_result : struct from stage1_ranging()
%   s2_result : struct from stage2_doa()
%   data      : struct from load_case_data()
%   cfg       : struct from setup_config()
%
% OUTPUT
%   result.pos_est_mm            : [N x 2] estimated position [mm] from WLS
%   result.pos_est_cart_mm       : [N x 2] direct conversion using weighted range + DoA
%   result.pos_gt_mm             : [N x 2] ground-truth position [mm]
%   result.error_m               : [N x 1] Euclidean 2D error [m]
%   result.rmse_m                : scalar RMSE [m]
%   result.rmse_los_m            : scalar RMSE over LoS [m]
%   result.rmse_nlos_m           : scalar RMSE over NLoS [m]
%   result.p90_m                 : scalar 90th percentile [m]
%   result.cep67_m               : scalar 67th percentile [m]
%   result.cep95_m               : scalar 95th percentile [m]
%   result.range_residual_m      : [N x 1] weighted range residual [m]
%   result.range_residual_rx1_m  : [N x 1] residual vs rx1 range [m]
%   result.range_residual_rx2_m  : [N x 1] residual vs rx2 range [m]
%   result.angle_residual_deg    : [N x 1] angular residual [deg]

n_tags = data.n_tags;
pos_gt_mm = data.pos_mm;
pos_est_mm = nan(n_tags, 2);
pos_est_cart_mm = nan(n_tags, 2);
range_residual_m = nan(n_tags, 1);
range_residual_rx1_m = nan(n_tags, 1);
range_residual_rx2_m = nan(n_tags, 1);
angle_residual_deg = nan(n_tags, 1);
wls_cost = nan(n_tags, 1);
is_converged = false(n_tags, 1);
range_est_fused_m = nan(n_tags, 1);
selected_theta_deg = nan(n_tags, 1);
selected_theta_candidate_col = nan(n_tags, 1);
selected_theta_candidate_branch = nan(n_tags, 1);
theta_candidate_count = zeros(n_tags, 1);
used_joint_theta_selection = false(n_tags, 1);

[sigma_r1_m, sigma_r2_m, sigma_theta_deg] = local_pick_sigmas(s1_result, s2_result, cfg);
sigma_theta_rad = deg2rad(sigma_theta_deg);
anchor_m = cfg.anchor_mm(:).' / 1000;
psi_a_rad = deg2rad(cfg.anchor_boresight_deg);
fusion_method = lower(string(cfg.fusion.method));
doa_hypothesis_mode = lower(string(local_get_fusion_field(cfg.fusion, 'doa_hypothesis_mode', 'single')));
use_joint_theta = (doa_hypothesis_mode == "jointwls") || (doa_hypothesis_mode == "joint_wls");

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
    prev_theta_for_joint_deg = NaN;
    for i = 1:n_tags
        r1_m = s1_result.range_est_m(i);
        r2_m = s1_result.range_est_rx2_m(i);
        theta_hat_deg = s2_result.doa_est_deg(i);
        if (~isfinite(r1_m) && ~isfinite(r2_m))
            continue;
        end

        solved = false;
        if use_joint_theta
            [theta_candidates_deg, cand_cols, cand_branches, cand_inv_cost, cand_in_range] = ...
                local_get_theta_candidates(s2_result, i);
            theta_candidate_count(i) = numel(theta_candidates_deg);
            if ~isempty(theta_candidates_deg)
                [solved, p_est_m, p_cart_m, info, theta_sel_deg, cand_col_sel, cand_branch_sel] = ...
                    local_select_theta_by_joint_cost( ...
                        theta_candidates_deg, cand_cols, cand_branches, ...
                        cand_inv_cost, cand_in_range, prev_theta_for_joint_deg, cfg.fusion, ...
                        r1_m, r2_m, anchor_m, psi_a_rad, ...
                        sigma_r1_m, sigma_r2_m, sigma_theta_rad, cfg.fusion, fusion_method);
                if solved
                    theta_hat_deg = theta_sel_deg;
                    selected_theta_candidate_col(i) = cand_col_sel;
                    selected_theta_candidate_branch(i) = cand_branch_sel;
                    used_joint_theta_selection(i) = true;
                    prev_theta_for_joint_deg = theta_sel_deg;
                end
            end
        end

        if ~solved
            if ~isfinite(theta_hat_deg)
                continue;
            end
            [p_est_m, p_cart_m, info] = local_solve_with_theta( ...
                theta_hat_deg, r1_m, r2_m, ...
                anchor_m, psi_a_rad, sigma_r1_m, sigma_r2_m, sigma_theta_rad, ...
                cfg.fusion, fusion_method);
        end

        pos_est_mm(i, :) = p_est_m * 1000;
        pos_est_cart_mm(i, :) = p_cart_m * 1000;
        range_residual_m(i) = info.range_residual_m;
        range_residual_rx1_m(i) = info.range_residual_rx1_m;
        range_residual_rx2_m(i) = info.range_residual_rx2_m;
        angle_residual_deg(i) = info.angle_residual_deg;
        wls_cost(i) = info.cost;
        is_converged(i) = info.converged;
        range_est_fused_m(i) = info.r_pred_m;
        selected_theta_deg(i) = theta_hat_deg;
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
result.range_est_fused_m = range_est_fused_m;
result.range_residual_m = range_residual_m;
result.range_residual_rx1_m = range_residual_rx1_m;
result.range_residual_rx2_m = range_residual_rx2_m;
result.angle_residual_deg = angle_residual_deg;
result.wls_cost = wls_cost;
result.sigma_r_m = sigma_r1_m; % backward-compatible alias
result.sigma_r1_m = sigma_r1_m;
result.sigma_r2_m = sigma_r2_m;
result.sigma_theta_deg = sigma_theta_deg;
result.fusion_method = char(fusion_method);
result.doa_hypothesis_mode = char(doa_hypothesis_mode);
result.selected_theta_deg = selected_theta_deg;
result.selected_theta_candidate_col = selected_theta_candidate_col;
result.selected_theta_candidate_branch = selected_theta_candidate_branch;
result.theta_candidate_count = theta_candidate_count;
result.used_joint_theta_selection = used_joint_theta_selection;
result.convergence_rate = convergence_rate;
result.approx_pos_error_m = approx_pos_error_m;
result.approx_pos_rmse_m = approx_pos_rmse_m;
result.pol_type = data.pol_type;
result.scenario = data.scenario;
end

function [sigma_r1_m, sigma_r2_m, sigma_theta_deg] = local_pick_sigmas(s1_result, s2_result, cfg)
% LOCAL_PICK_SIGMAS Returns fusion sigmas from stage RMSE or fixed config.
mode = lower(string(cfg.fusion.sigma_mode));
switch mode
    case "from_stage_rmse"
        sigma_r1_m = s1_result.rmse_m;
        if isfield(s1_result, 'rmse_rx2_m')
            sigma_r2_m = s1_result.rmse_rx2_m;
        else
            sigma_r2_m = s1_result.rmse_m;
        end
        sigma_theta_deg = s2_result.rmse_deg;
    case "fixed"
        sigma_r1_m = cfg.fusion.fixed_sigma_r1_m;
        sigma_r2_m = cfg.fusion.fixed_sigma_r2_m;
        sigma_theta_deg = cfg.fusion.fixed_sigma_theta_deg;
    otherwise
        error('stage4_positioning:unknownSigmaMode', ...
            'Unknown cfg.fusion.sigma_mode: %s', cfg.fusion.sigma_mode);
end

sigma_r1_m = max(abs(sigma_r1_m), cfg.fusion.min_sigma_r_m);
sigma_r2_m = max(abs(sigma_r2_m), cfg.fusion.min_sigma_r_m);
sigma_theta_deg = max(abs(sigma_theta_deg), cfg.fusion.min_sigma_theta_deg);
end

function r = local_weighted_range(r1, r2, sigma1, sigma2)
% LOCAL_WEIGHTED_RANGE Weighted average of available ranges.
w1 = 0;
w2 = 0;
if isfinite(r1), w1 = 1 / max(sigma1^2, eps); end
if isfinite(r2), w2 = 1 / max(sigma2^2, eps); end
if (w1 + w2) <= 0
    r = NaN;
elseif w1 <= 0
    r = r2;
elseif w2 <= 0
    r = r1;
else
    r = (w1 * r1 + w2 * r2) / (w1 + w2);
end
r = max(real(r), eps);
end

function r = local_primary_range(r1, r2)
% LOCAL_PRIMARY_RANGE Baseline direct conversion range (rx1-first for compatibility).
if isfinite(r1)
    r = r1;
elseif isfinite(r2)
    r = r2;
else
    r = NaN;
end
r = max(real(r), eps);
end

function p_m = local_cartesian_from_measurement(r_hat_m, theta_hat_rad, anchor_m, psi_a_rad)
% LOCAL_CARTESIAN_FROM_MEASUREMENT Direct conversion from (r,theta) to XY.
r_use = max(real(r_hat_m), eps);
bearing = psi_a_rad + theta_hat_rad;
p_m = anchor_m + [r_use * cos(bearing), r_use * sin(bearing)];
end

function [p_est_m, p_cart_m, info] = local_solve_with_theta( ...
    theta_hat_deg, r1_m, r2_m, ...
    anchor_m, psi_a_rad, sigma_r1_m, sigma_r2_m, sigma_theta_rad, ...
    fusion_cfg, fusion_method)
% LOCAL_SOLVE_WITH_THETA Solves positioning for one DoA hypothesis.
theta_hat_rad = deg2rad(theta_hat_deg);
r_cart = local_primary_range(r1_m, r2_m);
p_cart_m = local_cartesian_from_measurement(r_cart, theta_hat_rad, anchor_m, psi_a_rad);
r_init = local_weighted_range(r1_m, r2_m, sigma_r1_m, sigma_r2_m);
p0_m = local_cartesian_from_measurement(r_init, theta_hat_rad, anchor_m, psi_a_rad);

switch fusion_method
    case "measurement_space_wls"
        [p_est_m, info] = local_fuse_dual_range_wls( ...
            r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
            sigma_r1_m, sigma_r2_m, sigma_theta_rad, fusion_cfg, p0_m);
    case "cartesian_direct"
        p_est_m = p_cart_m;
        info = local_eval_residuals_dual( ...
            p_est_m, r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
            sigma_r1_m, sigma_r2_m, sigma_theta_rad, true, 0);
    otherwise
        error('stage4_positioning:unknownFusionMethod', ...
            'Unknown cfg.fusion.method: %s', fusion_method);
end
end

function [theta_deg, cand_cols, cand_branches, cand_inv_cost, cand_in_range] = local_get_theta_candidates(s2_result, i)
% LOCAL_GET_THETA_CANDIDATES Returns finite unique DoA candidates for one tag.
theta_deg = [];
cand_cols = [];
cand_branches = [];
cand_inv_cost = [];
cand_in_range = [];
if ~isfield(s2_result, 'doa_candidate_deg') || isempty(s2_result.doa_candidate_deg)
    return;
end

row_theta = s2_result.doa_candidate_deg(i, :);
if isfield(s2_result, 'doa_candidate_branch_idx') && ~isempty(s2_result.doa_candidate_branch_idx)
    row_branch = s2_result.doa_candidate_branch_idx(i, :);
else
    row_branch = nan(size(row_theta));
end
if isfield(s2_result, 'doa_candidate_cost') && ~isempty(s2_result.doa_candidate_cost)
    row_cost = s2_result.doa_candidate_cost(i, :);
else
    row_cost = nan(size(row_theta));
end
if isfield(s2_result, 'doa_candidate_in_range') && ~isempty(s2_result.doa_candidate_in_range)
    row_in_range = logical(s2_result.doa_candidate_in_range(i, :));
else
    row_in_range = false(size(row_theta));
end
valid = isfinite(row_theta);
if ~any(valid)
    return;
end

row_theta = row_theta(valid);
row_branch = row_branch(valid);
row_cost = row_cost(valid);
row_in_range = row_in_range(valid);
row_cols = find(valid);
[theta_u, ia] = unique(row_theta, 'stable');
theta_deg = theta_u(:).';
cand_cols = row_cols(ia);
cand_branches = row_branch(ia);
cand_inv_cost = row_cost(ia);
cand_in_range = row_in_range(ia);
end

function [ok, p_best_m, p_cart_best_m, info_best, theta_best_deg, col_best, branch_best] = ...
    local_select_theta_by_joint_cost( ...
    theta_candidates_deg, cand_cols, cand_branches, ...
    cand_inv_cost, cand_in_range, prev_theta_deg, fusion_cfg_full, ...
    r1_m, r2_m, anchor_m, psi_a_rad, ...
    sigma_r1_m, sigma_r2_m, sigma_theta_rad, fusion_cfg, fusion_method)
% LOCAL_SELECT_THETA_BY_JOINT_COST Selects best DoA candidate by Stage4 cost.
ok = false;
p_best_m = [NaN, NaN];
p_cart_best_m = [NaN, NaN];
info_best = struct('range_residual_m', NaN, 'range_residual_rx1_m', NaN, ...
    'range_residual_rx2_m', NaN, 'angle_residual_deg', NaN, ...
    'cost', NaN, 'converged', false, 'iter_used', 0, 'r_pred_m', NaN);
theta_best_deg = NaN;
col_best = NaN;
branch_best = NaN;

[lambda_inv, lambda_cont_deg, out_of_range_penalty] = local_joint_theta_params(fusion_cfg_full);
inv_min = min(cand_inv_cost(isfinite(cand_inv_cost)));
if isempty(inv_min) || ~isfinite(inv_min)
    inv_min = 0;
end
best_score = inf;
for k = 1:numel(theta_candidates_deg)
    th = theta_candidates_deg(k);
    if ~isfinite(th)
        continue;
    end
    [p_k, p_cart_k, info_k] = local_solve_with_theta( ...
        th, r1_m, r2_m, ...
        anchor_m, psi_a_rad, sigma_r1_m, sigma_r2_m, sigma_theta_rad, ...
        fusion_cfg, fusion_method);
    if ~isfinite(info_k.cost)
        continue;
    end
    score = info_k.cost;
    inv_k = cand_inv_cost(k);
    if isfinite(inv_k)
        score = score + lambda_inv * max(inv_k - inv_min, 0);
    end
    if ~cand_in_range(k)
        score = score + out_of_range_penalty;
    end
    if isfinite(prev_theta_deg)
        dtheta = abs(rad2deg(local_wrap_to_pi(deg2rad(th - prev_theta_deg))));
        score = score + lambda_cont_deg * dtheta;
    end

    if score < best_score
        best_score = score;
        p_best_m = p_k;
        p_cart_best_m = p_cart_k;
        info_best = info_k;
        info_best.theta_selection_score = score;
        theta_best_deg = th;
        col_best = cand_cols(k);
        branch_best = cand_branches(k);
        ok = true;
    end
end
end

function [lambda_inv, lambda_cont_deg, out_of_range_penalty] = local_joint_theta_params(fusion_cfg)
% LOCAL_JOINT_THETA_PARAMS Reads optional weighting params for candidate selection.
lambda_inv = 1.0;
lambda_cont_deg = 0.0;
out_of_range_penalty = 0.0;
if ~isstruct(fusion_cfg) || ~isfield(fusion_cfg, 'joint_theta') || ~isstruct(fusion_cfg.joint_theta)
    return;
end
jt = fusion_cfg.joint_theta;
if isfield(jt, 'lambda_inv_cost') && ~isempty(jt.lambda_inv_cost)
    lambda_inv = double(jt.lambda_inv_cost);
end
if isfield(jt, 'lambda_cont_deg') && ~isempty(jt.lambda_cont_deg)
    lambda_cont_deg = double(jt.lambda_cont_deg);
end
if isfield(jt, 'out_of_range_penalty') && ~isempty(jt.out_of_range_penalty)
    out_of_range_penalty = double(jt.out_of_range_penalty);
end
end

function v = local_get_fusion_field(fusion_cfg, field_name, default_v)
% LOCAL_GET_FUSION_FIELD Gets optional field from cfg.fusion.
if isstruct(fusion_cfg) && isfield(fusion_cfg, field_name) && ~isempty(fusion_cfg.(field_name))
    v = fusion_cfg.(field_name);
else
    v = default_v;
end
end

function [p_est_m, info] = local_fuse_dual_range_wls( ...
    r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
    sigma_r1_m, sigma_r2_m, sigma_theta_rad, fusion_cfg, p0_m)
% LOCAL_FUSE_DUAL_RANGE_WLS Nonlinear solve using dual ranges + angle residual.
obj = @(p) local_dual_objective(p, r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
    sigma_r1_m, sigma_r2_m, sigma_theta_rad);
opts = optimset('Display', 'off', ...
    'MaxIter', fusion_cfg.max_iter, ...
    'MaxFunEvals', fusion_cfg.max_fun_eval, ...
    'TolX', fusion_cfg.tol_step_m, ...
    'TolFun', fusion_cfg.tol_fun);
[p_est_m, fval, exitflag] = fminsearch(obj, p0_m, opts);
if any(~isfinite(p_est_m))
    p_est_m = p0_m;
    exitflag = -1;
    fval = obj(p_est_m);
end

info = local_eval_residuals_dual( ...
    p_est_m, r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
    sigma_r1_m, sigma_r2_m, sigma_theta_rad, exitflag > 0, exitflag);
info.cost = fval;
end

function cost = local_dual_objective(p_est_m, r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, sigma_r1_m, sigma_r2_m, sigma_theta_rad)
res = local_eval_residuals_dual( ...
    p_est_m, r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
    sigma_r1_m, sigma_r2_m, sigma_theta_rad, true, 0);
cost = res.cost;
end

function info = local_eval_residuals_dual( ...
    p_est_m, r1_m, r2_m, theta_hat_rad, anchor_m, psi_a_rad, ...
    sigma_r1_m, sigma_r2_m, sigma_theta_rad, converged, iter_used)
% LOCAL_EVAL_RESIDUALS_DUAL Evaluates residuals and weighted objective.
dx = p_est_m(1) - anchor_m(1);
dy = p_est_m(2) - anchor_m(2);
r_pred = hypot(dx, dy);
theta_pred = atan2(dy, dx) - psi_a_rad;

res_theta_rad = local_wrap_to_pi(theta_pred - theta_hat_rad);

res_r1 = NaN;
res_r2 = NaN;
w1 = 0;
w2 = 0;
if isfinite(r1_m)
    res_r1 = r_pred - r1_m;
    w1 = 1 / max(sigma_r1_m^2, eps);
end
if isfinite(r2_m)
    res_r2 = r_pred - r2_m;
    w2 = 1 / max(sigma_r2_m^2, eps);
end

if (w1 + w2) > 0
    res_r = (w1 * local_nan_to_zero(res_r1) + w2 * local_nan_to_zero(res_r2)) / (w1 + w2);
else
    res_r = NaN;
end

cost = 0;
if isfinite(res_r1), cost = cost + (res_r1^2) / max(sigma_r1_m^2, eps); end
if isfinite(res_r2), cost = cost + (res_r2^2) / max(sigma_r2_m^2, eps); end
if isfinite(res_theta_rad), cost = cost + (res_theta_rad^2) / max(sigma_theta_rad^2, eps); end

info = struct();
info.r_pred_m = r_pred;
info.range_residual_m = res_r;
info.range_residual_rx1_m = res_r1;
info.range_residual_rx2_m = res_r2;
info.angle_residual_deg = rad2deg(res_theta_rad);
info.cost = cost;
info.converged = converged;
info.iter_used = iter_used;
end

function x = local_nan_to_zero(x)
if ~isfinite(x)
    x = 0;
end
end

function a = local_wrap_to_pi(a)
% LOCAL_WRAP_TO_PI Wraps angle(s) to [-pi, pi).
a = mod(a + pi, 2 * pi) - pi;
end
