function out = plot_spatial_heatmaps_by_antenna(cfg, all_results)
% PLOT_SPATIAL_HEATMAPS_BY_ANTENNA
% Generates location-wise heatmaps for DoA/ranging/position errors.
%
% Output heatmaps (per polarization and scenario):
%   1) DoA abs error [deg]
%   2) Ranging abs error rx1 [m]
%   3) Ranging abs error rx2 [m]
%   4) Position abs error from rx1 range [m]
%   5) Position abs error from rx2 range [m]
%
% INPUT
%   cfg         : struct from setup_config() (optional)
%   all_results : struct from results/all_results.mat (optional)
%
% OUTPUT
%   out.files : cell array of saved file paths

if nargin < 1 || isempty(cfg)
    cfg = setup_config();
end

if nargin < 2 || isempty(all_results)
    mat_path = fullfile(cfg.results_dir, 'all_results.mat');
    if ~isfile(mat_path)
        error('plot_spatial_heatmaps_by_antenna:MissingResults', ...
            'all_results.mat not found: %s', mat_path);
    end
    S = load(mat_path, 'all_results');
    all_results = S.all_results;
end

saved_files = {};

for p = 1:numel(cfg.pol_types)
    pol = cfg.pol_types{p};
    for s = 1:numel(cfg.scenarios)
        scenario = cfg.scenarios{s};
        data = load_case_data(pol, scenario, cfg);
        leaf = all_results.(pol).(scenario);

        doa_abs_deg = abs(leaf.s2.error_deg(:));
        range_abs_rx1_m = abs(leaf.s1.error_m(:));
        range_abs_rx2_m = abs(leaf.s1.error_rx2_m(:));
        pos_abs_rx1_m = leaf.s4.error_m(:);

        s1_rx2 = local_build_rx2_stage1(leaf.s1, data);
        s4_rx2 = stage4_positioning(s1_rx2, leaf.s2, data, cfg);
        pos_abs_rx2_m = s4_rx2.error_m(:);

        [x_m, y_m, Z_doa] = local_grid(data.pos_mm, doa_abs_deg);
        [~, ~, Z_rng1] = local_grid(data.pos_mm, range_abs_rx1_m);
        [~, ~, Z_rng2] = local_grid(data.pos_mm, range_abs_rx2_m);
        [~, ~, Z_pos1] = local_grid(data.pos_mm, pos_abs_rx1_m);
        [~, ~, Z_pos2] = local_grid(data.pos_mm, pos_abs_rx2_m);

        tag = sprintf('%s_scenario%s', pol, scenario);
        saved_files = [saved_files; local_save_heatmap(cfg, x_m, y_m, Z_doa, ... %#ok<AGROW>
            sprintf('DoA abs error (%s)', tag), '[deg]', ...
            sprintf('heatmap_doa_abs_%s', tag))];
        saved_files = [saved_files; local_save_heatmap(cfg, x_m, y_m, Z_rng1, ... %#ok<AGROW>
            sprintf('Ranging abs error rx1 (%s)', tag), '[m]', ...
            sprintf('heatmap_ranging_abs_rx1_%s', tag))];
        saved_files = [saved_files; local_save_heatmap(cfg, x_m, y_m, Z_rng2, ... %#ok<AGROW>
            sprintf('Ranging abs error rx2 (%s)', tag), '[m]', ...
            sprintf('heatmap_ranging_abs_rx2_%s', tag))];
        saved_files = [saved_files; local_save_heatmap(cfg, x_m, y_m, Z_pos1, ... %#ok<AGROW>
            sprintf('Position abs error rx1 (%s)', tag), '[m]', ...
            sprintf('heatmap_position_abs_rx1_%s', tag))];
        saved_files = [saved_files; local_save_heatmap(cfg, x_m, y_m, Z_pos2, ... %#ok<AGROW>
            sprintf('Position abs error rx2 (%s)', tag), '[m]', ...
            sprintf('heatmap_position_abs_rx2_%s', tag))];

        saved_files = [saved_files; local_save_bundle(cfg, x_m, y_m, ... %#ok<AGROW>
            Z_doa, Z_rng1, Z_rng2, Z_pos1, Z_pos2, tag)];
    end
end

out = struct();
out.files = saved_files;
end

function s1_rx2 = local_build_rx2_stage1(s1, data)
% LOCAL_BUILD_RX2_STAGE1 Builds a stage1-like struct using rx2 range results.
s1_rx2 = s1;
s1_rx2.range_est_m = s1.range_est_rx2_m(:);
s1_rx2.error_m = s1_rx2.range_est_m - data.range_gt_m(:);
s1_rx2.abs_error_m = abs(s1_rx2.error_m);
m = compute_metrics(s1_rx2.abs_error_m, data.is_los);
s1_rx2.rmse_m = m.rmse;
s1_rx2.rmse_los_m = m.rmse_los;
s1_rx2.rmse_nlos_m = m.rmse_nlos;
s1_rx2.cdf_x = m.cdf_x;
s1_rx2.cdf_y = m.cdf_y;
end

function [x_m, y_m, Z] = local_grid(pos_mm, values)
% LOCAL_GRID Maps tag-wise vector to 2D grid by x/y coordinates.
x_vals_mm = pos_mm(:, 1);
y_vals_mm = pos_mm(:, 2);
ux = unique(x_vals_mm, 'sorted');
uy = unique(y_vals_mm, 'sorted');

Z = nan(numel(uy), numel(ux));
for i = 1:numel(values)
    ix = find(ux == x_vals_mm(i), 1, 'first');
    iy = find(uy == y_vals_mm(i), 1, 'first');
    if ~isempty(ix) && ~isempty(iy)
        Z(iy, ix) = values(i);
    end
end

x_m = ux / 1000;
y_m = uy / 1000;
end

function files = local_save_heatmap(cfg, x_m, y_m, Z, ttl, cbar_label, stem)
% LOCAL_SAVE_HEATMAP Saves one heatmap as fig/png.
fig = figure('Visible', 'off', 'Color', 'w');
imagesc(x_m, y_m, Z);
axis xy;
axis tight;
colormap(turbo);
cb = colorbar;
cb.Label.String = cbar_label;
grid on;
xlabel('x [m]');
ylabel('y [m]');
title(ttl, 'Interpreter', 'none');

fig_path = fullfile(cfg.results_dir, [stem '.fig']);
png_path = fullfile(cfg.results_dir, [stem '.png']);
savefig(fig, fig_path);
exportgraphics(fig, png_path, 'Resolution', 180);
close(fig);
files = {fig_path; png_path};
end

function files = local_save_bundle(cfg, x_m, y_m, Z_doa, Z_rng1, Z_rng2, Z_pos1, Z_pos2, tag)
% LOCAL_SAVE_BUNDLE Saves one bundled multi-panel heatmap.
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1400, 800]);
t = tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
title(t, sprintf('Spatial Error Heatmaps - %s', tag), 'Interpreter', 'none');

nexttile;
imagesc(x_m, y_m, Z_doa); axis xy tight; colormap(turbo); colorbar; grid on;
title('DoA abs [deg]'); xlabel('x [m]'); ylabel('y [m]');

nexttile;
imagesc(x_m, y_m, Z_rng1); axis xy tight; colormap(turbo); colorbar; grid on;
title('Ranging abs rx1 [m]'); xlabel('x [m]'); ylabel('y [m]');

nexttile;
imagesc(x_m, y_m, Z_rng2); axis xy tight; colormap(turbo); colorbar; grid on;
title('Ranging abs rx2 [m]'); xlabel('x [m]'); ylabel('y [m]');

nexttile;
imagesc(x_m, y_m, Z_pos1); axis xy tight; colormap(turbo); colorbar; grid on;
title('Position abs rx1 [m]'); xlabel('x [m]'); ylabel('y [m]');

nexttile;
imagesc(x_m, y_m, Z_pos2); axis xy tight; colormap(turbo); colorbar; grid on;
title('Position abs rx2 [m]'); xlabel('x [m]'); ylabel('y [m]');

nexttile;
axis off;
text(0.02, 0.92, 'Notes', 'FontWeight', 'bold');
text(0.02, 0.78, '- DoA is pair-based (rx1-rx2 RSSD).');
text(0.02, 0.64, '- Position rx2 uses stage1 range(rx2) + stage2 DoA.');
text(0.02, 0.50, '- Grid is directly mapped from tag coordinates.');

fig_path = fullfile(cfg.results_dir, sprintf('heatmap_bundle_%s.fig', tag));
png_path = fullfile(cfg.results_dir, sprintf('heatmap_bundle_%s.png', tag));
savefig(fig, fig_path);
exportgraphics(fig, png_path, 'Resolution', 180);
close(fig);

files = {fig_path; png_path};
end

