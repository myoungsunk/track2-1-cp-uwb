function test_doa_validity_gate_signed()
% TEST_DOA_VALIDITY_GATE_SIGNED Verifies signed-vs-abs correlation gating policy.
cfg = struct();
cfg.validity_corr_threshold = 0.30;

cfg.validity_corr_mode = 'signed';
[is_valid_signed, metric_signed, mode_signed] = is_doa_valid_for_positioning(-0.9, cfg);
assert(~is_valid_signed, 'Signed gating must reject negative correlation.');
assert(abs(metric_signed + 0.9) < 1e-12, 'Signed gating metric mismatch.');
assert(strcmp(mode_signed, 'signed'), 'Signed gating mode mismatch.');

cfg.validity_corr_mode = 'abs';
[is_valid_abs, metric_abs, mode_abs] = is_doa_valid_for_positioning(-0.9, cfg);
assert(is_valid_abs, 'Abs gating should accept large negative correlation.');
assert(abs(metric_abs - 0.9) < 1e-12, 'Abs gating metric mismatch.');
assert(strcmp(mode_abs, 'abs'), 'Abs gating mode mismatch.');
end

