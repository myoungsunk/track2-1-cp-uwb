function manifest = capture_run_manifest(cfg)
% CAPTURE_RUN_MANIFEST Captures environment and provenance for reproducibility.
script_dir = fileparts(mfilename('fullpath'));
repo_dir = fullfile(script_dir, '..');

manifest = struct();
manifest.generated_at = char(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
manifest.matlab_version = version;
manifest.matlab_release = version('-release');
manifest.computer = computer;
manifest.results_dir = cfg.results_dir;
manifest.data_dir = cfg.data_dir;
manifest.seed = local_get_nested(cfg, {'stats', 'rng_seed'}, NaN);
manifest.git_commit = local_git(repo_dir, 'rev-parse --short HEAD');
manifest.git_branch = local_git(repo_dir, 'rev-parse --abbrev-ref HEAD');
manifest.git_dirty = local_git(repo_dir, 'status --porcelain');
manifest.toolboxes = local_collect_toolboxes();
end

function out = local_git(repo_dir, args)
cmd = sprintf('git -C "%s" %s', repo_dir, args);
[status, txt] = system(cmd);
if status == 0
    out = strtrim(txt);
else
    out = '';
end
end

function t = local_collect_toolboxes()
v = ver;
t = struct('name', {}, 'version', {}, 'release', {});
for i = 1:numel(v)
    t(i).name = v(i).Name; %#ok<AGROW>
    t(i).version = v(i).Version; %#ok<AGROW>
    t(i).release = v(i).Release; %#ok<AGROW>
end
end

function v = local_get_nested(s, path_cells, default_v)
v = default_v;
cur = s;
for i = 1:numel(path_cells)
    f = path_cells{i};
    if ~isstruct(cur) || ~isfield(cur, f)
        return;
    end
    cur = cur.(f);
end
v = cur;
end

