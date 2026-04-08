function test_compute_cir_delay()
% TEST_COMPUTE_CIR_DELAY Verifies peak delay from synthetic single-path S21.
cfg = setup_config();
cfg.window_type = 'rect';
cfg.N_fft = 2^15;

tau_true_s = 18e-9;
f = cfg.f_start + (0:cfg.N_freq-1).' * cfg.delta_f;
S21 = exp(-1j * 2 * pi * f * tau_true_s);

[cir_mag, t_axis_s, d_axis_m] = compute_cir(S21, cfg);
[~, k] = max(cir_mag);
t_hat_s = t_axis_s(k);

dt_s = 1 / (cfg.N_fft * cfg.delta_f);
assert(abs(t_hat_s - tau_true_s) <= 4 * dt_s, ...
    'CIR peak delay mismatch: true=%.3e, est=%.3e', tau_true_s, t_hat_s);
assert(abs(d_axis_m(k) - cfg.c * t_hat_s) <= 1e-9, ...
    'Range axis is inconsistent with one-way c*t mapping.');
end

