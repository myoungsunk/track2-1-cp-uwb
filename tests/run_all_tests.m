function run_all_tests()
% RUN_ALL_TESTS Runs project sanity tests.
tests_dir = fileparts(mfilename('fullpath'));
src_dir = fullfile(tests_dir, '..', 'src');
addpath(src_dir);

test_funcs = { ...
    @test_compute_cir_delay, ...
    @test_los_mask_strictness, ...
    @test_doa_validity_gate_signed ...
    };

fprintf('[TEST] Running %d tests...\n', numel(test_funcs));
for i = 1:numel(test_funcs)
    f = test_funcs{i};
    name = func2str(f);
    fprintf('[TEST] %s ... ', name);
    f();
    fprintf('OK\n');
end
fprintf('[TEST] All tests passed.\n');
end

