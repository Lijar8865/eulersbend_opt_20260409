function result = parse_basic_tlist_summary(basic_mat_path)
% Parse center-wavelength T_list summary from a basic.mat file.

sim_data = load(basic_mat_path);
if ~isfield(sim_data, 'T_list') || numel(sim_data.T_list) < 2 || ...
        ~isstruct(sim_data.T_list{1}) || ~isstruct(sim_data.T_list{2})
    error('Invalid T_list content in %s', basic_mat_path);
end

lambda_all_nm = sim_data.T_list{1}.lambda * 1e9;
lambda_idx = round(length(lambda_all_nm) / 2);

result = struct();
result.lambda_center_nm = lambda_all_nm(lambda_idx);
result.num_ports_in_T_list = numel(sim_data.T_list);
result.T_list1_center_all = abs(squeeze(sim_data.T_list{1}.T_net(lambda_idx, :)));
result.T_list2_center_all = abs(squeeze(sim_data.T_list{2}.T_net(lambda_idx, :)));
result.T_list2_center = result.T_list2_center_all(1);
end
