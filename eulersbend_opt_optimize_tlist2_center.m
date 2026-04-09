%% Euler S-bend optimization for center(abs(T_list{2}.T_net))
% Resumable sweep over R_min while preserving the current data root.
clc;
clear;
close all;

scriptPath = mfilename('fullpath');
[scriptFolder, ~, ~] = fileparts(scriptPath);
cd(scriptFolder);

customLibFolder = 'G:\matlab_photonic_gds_sim\lib';
% customLibFolder = '/home/wcli/mydata/FDTD_sim/matlab_photonic_gds_sim/lib';
device_name = 'eulersbend_opt';
run_date = datestr(now, 'yyyymmdd');

addpath(customLibFolder);

% Keep the user's current result root exactly as configured in the workspace.
fdtdOutputRoot = [scriptFolder, 'data'];
reportFolder = fullfile(scriptFolder, ['optimization_report_tlist2_center_rmin_', run_date]);
if ~exist(reportFolder, 'dir')
    mkdir(reportFolder);
end

nm = 1e-9;
um = 1e-6;

para_default = struct(...
    'etch_angle', 83, ...
    'h_wg', 0.22, ...
    'W_in', 0.45, ...
    'W_out', 1.66, ...
    'R_min', 30, ...
    'total_angle_deg', 30, ...
    'straight_length', 5, ...
    'N_point', 501 ...
);

sweep_params = struct();
sweep_params.R_min = 30:5:80;
param_combinations = Wcli_wg.generate_param_combinations(para_default, sweep_params);

logPath = fullfile(reportFolder, 'optimization_log.txt');
csvPath = fullfile(reportFolder, 'all_results.csv');
fdtd_exe = resolve_fdtd_exe();
total_points = numel(param_combinations);

log_fid = fopen(logPath, 'a');
cleanupObj = onCleanup(@() fclose(log_fid));
run_tic = tic;

log_fid = log_line(log_fid, logPath, sprintf('Start sweep with %d points', total_points));
log_fid = log_line(log_fid, logPath, sprintf('Sweep range: R_min = %.2f:%.2f:%.2f, fixed W_in = %.2f, fixed W_out = %.2f', ...
    sweep_params.R_min(1), sweep_params.R_min(2) - sweep_params.R_min(1), sweep_params.R_min(end), ...
    para_default.W_in, para_default.W_out));
fprintf('Report folder: %s\n', reportFolder);
fprintf('Output root: %s\n', fdtdOutputRoot);

results = repmat(struct( ...
    'index', NaN, ...
    'para_name', "", ...
    'W_in', NaN, ...
    'W_out', NaN, ...
    'R_min', NaN, ...
    'lambda_center_nm', NaN, ...
    'T_list2_center', NaN, ...
    'valid', false, ...
    'status', "", ...
    'basic_mat_path', "" ...
    ), numel(param_combinations), 1);
best_metric_so_far = -Inf;
best_result_so_far = struct('index', NaN, 'W_in', NaN, 'W_out', NaN, 'R_min', NaN, 'T_list2_center', NaN, 'para_name', "");

for i_d = 1:total_points
    para = param_combinations(i_d);
    para_name = Wcli_wg.generate_save_name(para, device_name);
    basic_mat_path = fullfile(fdtdOutputRoot, ...
        ['dat_', device_name, '_', run_date], ...
        para_name, ...
        'basic.mat');
    progress_pct = 100 * i_d / total_points;
    point_tic = tic;
    log_fid = log_line(log_fid, logPath, sprintf('Point %d/%d (%.2f%%) START para=%s, W_in=%.4f, W_out=%.4f, R_min=%.4f', ...
        i_d, total_points, progress_pct, para_name, para.W_in, para.W_out, para.R_min));

    metric = NaN;
    status = "missing";
    valid = false;

    if exist(basic_mat_path, 'file')
        [metric, lambda_center_nm, valid] = parse_center_metric(basic_mat_path);
        if valid
            status = "reused";
        else
            status = "invalid_existing";
        end
    else
        lambda_center_nm = NaN;
    end
    log_fid = log_line(log_fid, logPath, sprintf('  precheck: existing_basic_mat=%d, status=%s', exist(basic_mat_path, 'file') == 2, status));

    if ~valid
        fdtd_data = build_fdtd_data(para, para_name, device_name, run_date, fdtdOutputRoot, nm, um);
        log_fid = log_line(log_fid, logPath, sprintf('  run: launching FDTD for W_in=%.4f, W_out=%.4f, R_min=%.4f', para.W_in, para.W_out, para.R_min));
        Wcli_wg.run_fdtd_sim( ...
            fdtd_data, ...
            "flag_run", 1, ...
            "gui_flag", 0, ...
            "lsf_script", 'FDTD_lsf.lsf', ...
            "fdtd_exe", fdtd_exe);

        if exist(basic_mat_path, 'file')
            [metric, lambda_center_nm, valid] = parse_center_metric(basic_mat_path);
            if valid
                status = "simulated";
            else
                status = "parse_failed";
            end
        else
            lambda_center_nm = NaN;
            status = "missing_after_run";
        end
    end

    results(i_d).index = i_d;
    results(i_d).para_name = string(para_name);
    results(i_d).W_in = para.W_in;
    results(i_d).W_out = para.W_out;
    results(i_d).R_min = para.R_min;
    results(i_d).lambda_center_nm = lambda_center_nm;
    results(i_d).T_list2_center = metric;
    results(i_d).valid = valid;
    results(i_d).status = status;
    results(i_d).basic_mat_path = string(basic_mat_path);

    if valid && metric > best_metric_so_far
        best_metric_so_far = metric;
        best_result_so_far = results(i_d);
    end

    point_elapsed = toc(point_tic);
    total_elapsed = toc(run_tic);
    avg_time_per_point = total_elapsed / i_d;
    est_remaining = avg_time_per_point * (total_points - i_d);

    log_fid = log_line(log_fid, logPath, sprintf('  result: status=%s, lambda_center_nm=%.6f, T_list2_center=%.10f, point_elapsed_s=%.2f', ...
        status, lambda_center_nm, metric, point_elapsed));
    if isfinite(best_metric_so_far)
        log_fid = log_line(log_fid, logPath, sprintf('  best_so_far: index=%d, W_in=%.4f, W_out=%.4f, R_min=%.4f, T_list2_center=%.10f, para=%s', ...
            best_result_so_far.index, best_result_so_far.W_in, best_result_so_far.W_out, best_result_so_far.R_min, ...
            best_result_so_far.T_list2_center, best_result_so_far.para_name));
    else
        log_fid = log_line(log_fid, logPath, '  best_so_far: none yet');
    end
    log_fid = log_line(log_fid, logPath, sprintf('  progress: completed=%d/%d (%.2f%%), elapsed=%s, eta_remaining=%s', ...
        i_d, total_points, progress_pct, format_duration(total_elapsed), format_duration(est_remaining)));
    write_results_csv(results, csvPath);
end

valid_mask = [results.valid];
if ~any(valid_mask)
    error('没有可用的有效结果，无法给出最优点。');
end

valid_results = results(valid_mask);
[best_metric, best_idx_local] = max([valid_results.T_list2_center]);
best_result = valid_results(best_idx_local);

summaryPath = fullfile(reportFolder, 'best_result_summary.mat');
save(summaryPath, 'best_result', 'results');

mdPath = fullfile(reportFolder, 'optimization_report.md');
htmlPath = fullfile(reportFolder, 'optimization_report.html');
write_reports(mdPath, htmlPath, best_result, results, csvPath, logPath, summaryPath, scriptFolder);

fprintf('\nSweep complete.\n');
fprintf('Best para: %s\n', best_result.para_name);
fprintf('Best T_list2 center: %.10f\n', best_metric);
fprintf('Report folder: %s\n', reportFolder);
log_fid = log_line(log_fid, logPath, sprintf('Sweep complete: best_index=%d, W_in=%.4f, W_out=%.4f, R_min=%.4f, T_list2_center=%.10f, total_elapsed=%s', ...
    best_result.index, best_result.W_in, best_result.W_out, best_result.R_min, best_result.T_list2_center, format_duration(toc(run_tic))));

function fdtd_data = build_fdtd_data(para, para_name, device_name, run_date, fdtdOutputRoot, nm, um)
    str_wg_in = Wcli_wg.st_wg_gen("len", 15, "Wid", para.W_in);
    str_wg_out = Wcli_wg.st_wg_gen("len", 15, "Wid", para.W_out);

    full_bend = Wcli_wg.euler_s_stwg_gen( ...
        "R_min", para.R_min, ...
        "total_angle", deg2rad(para.total_angle_deg), ...
        "straight_length", para.straight_length, ...
        "N_point", para.N_point, ...
        "Wid_in", para.W_in, ...
        "Wid_out", para.W_out, ...
        "etch_angle", para.etch_angle, ...
        "h_wg", para.h_wg);
    full_bend.move_to("cleft");
    full_bend.calc_trace_length;
    full_bend.merge_wg(str_wg_out);
    full_bend.flip_shape;
    full_bend.merge_wg(str_wg_in.flip_shape);
    full_bend.flip_shape;

    sim_edge_xy = full_bend.get_boundary_points + [5, -5; -5, 5];
    port_in1 = full_bend.get_port_in + [8, 0, 0];
    port_out1 = full_bend.get_port_out + [-8, 0, 0];
    port_xy_list = [port_in1; port_out1];
    port_xy_dir = ['X', 'X'];
    fdtd_pos_list = {full_bend.posdata2fdtd * nm};

    fdtd_data = struct();
    fdtd_data.sim_file_name = 'bend_sim_basic.fsp';
    fdtd_data.para_name = para_name;
    fdtd_data.device_name = device_name;
    fdtd_data.run_date = run_date;
    fdtd_data.output_root = fdtdOutputRoot;
    fdtd_data.fdtd_pos_list = fdtd_pos_list;
    fdtd_data.port_xy_list = port_xy_list * um;
    fdtd_data.port_xy_dir = port_xy_dir;
    fdtd_data.sim_edge_xy = sim_edge_xy * um;
    fdtd_data.para = para;
    fdtd_data.h_slab = para.h_wg * um;
end

function [metric, lambda_center_nm, valid] = parse_center_metric(basic_mat_path)
    metric = NaN;
    lambda_center_nm = NaN;
    valid = false;

    sim_data = load(basic_mat_path);
    if ~isfield(sim_data, 'T_list') || numel(sim_data.T_list) < 2 || ~isstruct(sim_data.T_list{2})
        return;
    end

    lambda_all_nm = sim_data.T_list{1}.lambda * 1e9;
    lambda_idx = round(length(lambda_all_nm) / 2);
    metric = abs(squeeze(sim_data.T_list{2}.T_net(lambda_idx, 1)));
    lambda_center_nm = lambda_all_nm(lambda_idx);
    valid = isfinite(metric);
end

function write_results_csv(results, csvPath)
    T = table( ...
        [results.index]', ...
        string({results.para_name})', ...
        [results.W_in]', ...
        [results.W_out]', ...
        [results.R_min]', ...
        [results.lambda_center_nm]', ...
        [results.T_list2_center]', ...
        [results.valid]', ...
        string({results.status})', ...
        string({results.basic_mat_path})', ...
        'VariableNames', { ...
        'index', 'para_name', 'W_in', 'W_out', 'R_min', 'lambda_center_nm', ...
        'T_list2_center', 'valid', 'status', 'basic_mat_path'});
    writetable(T, csvPath);
end

function write_reports(mdPath, htmlPath, best_result, results, csvPath, logPath, summaryPath, scriptFolder)
    valid_results = results([results.valid]);
    lines = {
        '# T_list2 Center Optimization Report'
        ''
        '## Problem Statement'
        'Optimize the center-wavelength transmission amplitude `abs(T_list{2}.T_net)` for the current two-port Euler S-bend setup by sweeping `R_min`.'
        ''
        '## Final Best Result'
        sprintf('- Best point: `%s`', best_result.para_name)
        sprintf('- `W_in = %.4f`, `W_out = %.4f`, `R_min = %.4f`', best_result.W_in, best_result.W_out, best_result.R_min)
        sprintf('- `lambda_center_nm = %.6f`', best_result.lambda_center_nm)
        sprintf('- `T_list2_center = %.10f`', best_result.T_list2_center)
        ''
        '## Search Summary'
        sprintf('- Total points: %d', numel(results))
        sprintf('- Valid points: %d', numel(valid_results))
        ''
        '## File Links'
        sprintf('- all_results.csv: `%s`', relative_path(csvPath, scriptFolder))
        sprintf('- optimization_log.txt: `%s`', relative_path(logPath, scriptFolder))
        sprintf('- best_result_summary.mat: `%s`', relative_path(summaryPath, scriptFolder))
        };
    mdText = strjoin(lines, newline);
    fid = fopen(mdPath, 'w');
    fwrite(fid, mdText);
    fclose(fid);

    htmlText = sprintf(['<html><body><h1>T_list2 Center Optimization Report</h1>' ...
        '<h2>Problem Statement</h2><p>Optimize the center-wavelength transmission amplitude <code>abs(T_list{2}.T_net)</code> for the current two-port Euler S-bend setup by sweeping <code>R_min</code>.</p>' ...
        '<h2>Final Best Result</h2><ul>' ...
        '<li>Best point: <code>%s</code></li>' ...
        '<li>W_in = %.4f, W_out = %.4f, R_min = %.4f</li>' ...
        '<li>lambda_center_nm = %.6f</li>' ...
        '<li>T_list2_center = %.10f</li>' ...
        '</ul><h2>Search Summary</h2><ul><li>Total points: %d</li><li>Valid points: %d</li></ul>' ...
        '<h2>File Links</h2><ul><li>%s</li><li>%s</li><li>%s</li></ul></body></html>'], ...
        best_result.para_name, best_result.W_in, best_result.W_out, best_result.R_min, ...
        best_result.lambda_center_nm, best_result.T_list2_center, ...
        numel(results), numel(valid_results), ...
        relative_path(csvPath, scriptFolder), ...
        relative_path(logPath, scriptFolder), ...
        relative_path(summaryPath, scriptFolder));
    fid = fopen(htmlPath, 'w');
    fwrite(fid, htmlText);
    fclose(fid);
end

function relPath = relative_path(targetPath, basePath)
    relPath = strrep(targetPath, [basePath filesep], '');
end

function fdtd_exe = resolve_fdtd_exe()
    candidates = {
        'C:\Program Files\Lumerical\v252\bin\fdtd-solutions.exe', ...
        'C:\Program Files\Lumerical\v251\bin\fdtd-solutions.exe', ...
        'C:\Program Files\ANSYS Inc\v252\Lumerical\bin\fdtd-solutions.exe', ...
        'C:\Program Files\ANSYS Inc\v251\Lumerical\bin\fdtd-solutions.exe', ...
        '/opt/lumerical/v252/bin/fdtd-solutions', ...
        '/opt/lumerical/v251/bin/fdtd-solutions' ...
    };
    fdtd_exe = '';
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file')
            fdtd_exe = candidates{i};
            return;
        end
    end
    error('未找到 fdtd-solutions 可执行文件。');
end

function log_fid = log_line(log_fid, logPath, message)
    fprintf(log_fid, '[%s] %s\n', datestr(now, 31), message);
    fclose(log_fid);
    log_fid = fopen(logPath, 'a');
end

function text = format_duration(seconds_value)
    if ~isfinite(seconds_value) || seconds_value < 0
        text = 'unknown';
        return;
    end
    total_seconds = round(seconds_value);
    hours_value = floor(total_seconds / 3600);
    minutes_value = floor(mod(total_seconds, 3600) / 60);
    seconds_only = mod(total_seconds, 60);
    text = sprintf('%02dh:%02dm:%02ds', hours_value, minutes_value, seconds_only);
end
