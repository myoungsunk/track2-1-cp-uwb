function test_los_mask_strictness()
% TEST_LOS_MASK_STRICTNESS Ensures external LoS labels fail-fast when required.
cfg = setup_config();
cfg.los_nlos.use_external = true;
cfg.los_nlos.require_external = true;
cfg.los_nlos.all_csv = fullfile(tempdir, 'missing_all_labels.csv');
cfg.los_nlos.scenario_csv.A = fullfile(tempdir, 'missing_A_labels.csv');
cfg.los_nlos.scenario_csv.B = fullfile(tempdir, 'missing_B_labels.csv');
cfg.los_nlos.scenario_csv.C = fullfile(tempdir, 'missing_C_labels.csv');

did_fail = false;
try
    load_case_data('CP', 'B', cfg); %#ok<NASGU>
catch ME
    did_fail = contains(ME.identifier, 'load_case_data:missingExternalLoS');
end
assert(did_fail, 'Expected fail-fast error for missing external LoS/NLoS labels.');
end

