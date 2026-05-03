function append_fdtd_case_log(scriptFolder, logFileName, result)
% Append one completed-case summary to a plain-text log.

if nargin < 2 || isempty(logFileName)
    logFileName = 'fdtd_case_results.log';
end

logPath = fullfile(scriptFolder, logFileName);
fid = fopen(logPath, 'a');
if fid == -1
    error('Unable to open case log: %s', logPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '[%s] CASE DONE\n', datestr(now, 31));
fprintf(fid, 'script_name=%s\n', result.script_name);
fprintf(fid, 'para_name=%s\n', result.para_name);
fprintf(fid, 'basic_mat_path=%s\n', result.basic_mat_path);
fprintf(fid, 'W_in=%.10g\n', result.para.W_in);
fprintf(fid, 'W_out=%.10g\n', result.para.W_out);
fprintf(fid, 'R_min=%.10g\n', result.para.R_min);
fprintf(fid, 'total_angle_deg=%.10g\n', result.para.total_angle_deg);
fprintf(fid, 'lambda_center_nm=%.10f\n', result.lambda_center_nm);
fprintf(fid, 'T_list2_center_col1=%.10f\n', result.T_list2_center);
fprintf(fid, 'T_list1_center_all=[ %s]\n', vector_to_text(result.T_list1_center_all));
fprintf(fid, 'T_list2_center_all=[ %s]\n', vector_to_text(result.T_list2_center_all));
fprintf(fid, 'num_ports_in_T_list=%d\n', result.num_ports_in_T_list);
fprintf(fid, '------------------------------------------------------------\n\n');
end

function txt = vector_to_text(vec)
txt = sprintf('%.10f ', vec);
end
