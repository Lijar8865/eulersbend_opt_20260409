%% Euler S-bend optimization smoke test
% Keeps the existing FDTD data root behavior and verifies one point can run.
clc;
clear;
close all;

scriptPath = mfilename('fullpath');
[scriptFolder, ~, ~] = fileparts(scriptPath);
cd(scriptFolder);

customLibFolder = '/home/wcli/mydata/FDTD_sim/matlab_photonic_gds_sim/lib';
device_name = 'eulersbend_opt';
run_date = datestr(now, 'yyyymmdd');

if isempty(customLibFolder)
    error('customLibFolder 不能为空。');
end
addpath(customLibFolder);

% Preserve the current workspace's output-root convention exactly.
customFdtdOutputRoot = [scriptFolder, 'data'];
fdtdOutputRoot = customFdtdOutputRoot;

nm = 1e-9;
um = 1e-6;

para_default = struct(...
    'etch_angle', 83, ...
    'h_wg', 0.22, ...
    'W_in', 1.5, ...
    'W_out', 1.5, ...
    'R_min', 30, ...
    'total_angle_deg', 30, ...
    'straight_length', 5, ...
    'N_point', 501 ...
);

sweep_params = struct();
sweep_params.W_in = 1.5:0.1:2;
sweep_params.W_out = 1.5:0.1:2;
param_combinations = Wcli_wg.generate_param_combinations(para_default, sweep_params);

smoke_index = 1;
para = param_combinations(smoke_index);

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

para_name = Wcli_wg.generate_save_name(para, device_name);
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

fdtd_exe = resolve_fdtd_exe();
fprintf('Smoke test parameter point:\n');
disp(para);
fprintf('Output root: %s\n', fdtdOutputRoot);
fprintf('FDTD exe: %s\n', fdtd_exe);

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
    error('Smoke test failed: missing basic.mat at %s', basic_mat_path);
end

sim_data = load(basic_mat_path);
if ~isfield(sim_data, 'T_list') || isempty(sim_data.T_list)
    error('Smoke test failed: basic.mat 中未找到 T_list 结果。');
end

lambda_all_nm = sim_data.T_list{1}.lambda * 1e9;
lambda_idx = round(length(lambda_all_nm) / 2);
num_ports = numel(sim_data.T_list);
T_out_center = NaN;
if num_ports >= 2 && isstruct(sim_data.T_list{2})
    T_out_center = abs(squeeze(sim_data.T_list{2}.T_net(lambda_idx, 1)));
end

fprintf('\nSmoke test finished successfully.\n');
fprintf('basic.mat: %s\n', basic_mat_path);
fprintf('num_ports_in_T_list: %d\n', num_ports);
fprintf('lambda_center_nm: %.6f\n', lambda_all_nm(lambda_idx));
if isnan(T_out_center)
    fprintf('T_list2_center: unavailable (T_list{2} missing in current setup)\n');
else
    fprintf('T_list2_center: %.10f\n', T_out_center);
end

summary = struct();
summary.run_date = run_date;
summary.para = para;
summary.para_name = para_name;
summary.basic_mat_path = basic_mat_path;
summary.num_ports_in_T_list = num_ports;
summary.lambda_center_nm = lambda_all_nm(lambda_idx);
summary.T_list2_center = T_out_center;
summary.objective_name = 'center(abs(T_list{2}.T_net))';
save(fullfile(scriptFolder, 'smoketest_result.mat'), '-struct', 'summary');

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
