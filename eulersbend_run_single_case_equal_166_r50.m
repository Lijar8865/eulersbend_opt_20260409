%% Run one specified equal-width Euler S-bend FDTD case at R_min=50
clc;
clear;
close all;

scriptPath = mfilename('fullpath');
[scriptFolder, ~, ~] = fileparts(scriptPath);
cd(scriptFolder);

customLibFolder = '/home/wcli/mydata/FDTD_sim/matlab_photonic_gds_sim/lib';
device_name = 'eulersbend_opt';
run_date = datestr(now, 'yyyymmdd');

addpath(customLibFolder);

fdtdOutputRoot = [scriptFolder, 'data'];
nm = 1e-9;
um = 1e-6;

para = struct(...
    'etch_angle', 83, ...
    'h_wg', 0.22, ...
    'W_in', 1.66, ...
    'W_out', 1.66, ...
    'R_min', 50, ...
    'total_angle_deg', 30, ...
    'straight_length', 5, ...
    'N_point', 501 ...
);

fdtd_exe = resolve_fdtd_exe();
para_name = Wcli_wg.generate_save_name(para, device_name);
fprintf('Running case: W_in=%.4f, W_out=%.4f, R_min=%.4f\n', para.W_in, para.W_out, para.R_min);

fdtd_data = build_fdtd_data(para, para_name, device_name, run_date, fdtdOutputRoot, nm, um);
Wcli_wg.run_fdtd_sim( ...
    fdtd_data, ...
    "flag_run", 1, ...
    "gui_flag", 0, ...
    "lsf_script", 'FDTD_lsf.lsf', ...
    "fdtd_exe", fdtd_exe);

basic_mat_path = fullfile(fdtdOutputRoot, ...
    ['dat_', device_name, '_', run_date], ...
    para_name, ...
    'basic.mat');
if ~exist(basic_mat_path, 'file')
    error('Missing basic.mat for case %s', para_name);
end

[metric, lambda_center_nm, num_ports, row_vals] = parse_center_metric(basic_mat_path);

result = struct();
result.para = para;
result.para_name = para_name;
result.basic_mat_path = basic_mat_path;
result.lambda_center_nm = lambda_center_nm;
result.T_list2_center = metric;
result.T_list2_center_all = row_vals;
result.num_ports_in_T_list = num_ports;
save(fullfile(scriptFolder, 'single_case_result_equal_166_r50.mat'), 'result');

fprintf('Completed case: lambda_center_nm=%.6f, T_list2_center=%.10f\n', lambda_center_nm, metric);
fprintf('T_list2_center_all = [');
fprintf(' %.10f', row_vals);
fprintf(' ]\n');

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

    fdtd_data = struct();
    fdtd_data.sim_file_name = 'bend_sim_basic.fsp';
    fdtd_data.para_name = para_name;
    fdtd_data.device_name = device_name;
    fdtd_data.run_date = run_date;
    fdtd_data.output_root = fdtdOutputRoot;
    fdtd_data.fdtd_pos_list = {full_bend.posdata2fdtd * nm};
    fdtd_data.port_xy_list = port_xy_list * um;
    fdtd_data.port_xy_dir = port_xy_dir;
    fdtd_data.sim_edge_xy = sim_edge_xy * um;
    fdtd_data.para = para;
    fdtd_data.h_slab = para.h_wg * um;
end

function [metric, lambda_center_nm, num_ports, row_vals] = parse_center_metric(basic_mat_path)
    sim_data = load(basic_mat_path);
    if ~isfield(sim_data, 'T_list') || numel(sim_data.T_list) < 2 || ~isstruct(sim_data.T_list{2})
        error('Invalid T_list content in %s', basic_mat_path);
    end
    lambda_all_nm = sim_data.T_list{1}.lambda * 1e9;
    lambda_idx = round(length(lambda_all_nm) / 2);
    row_vals = abs(squeeze(sim_data.T_list{2}.T_net(lambda_idx, :)));
    metric = row_vals(1);
    lambda_center_nm = lambda_all_nm(lambda_idx);
    num_ports = numel(sim_data.T_list);
end

function fdtd_exe = resolve_fdtd_exe()
    candidates = {
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
