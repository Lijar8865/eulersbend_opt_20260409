%% Generate a simple sorted HTML table for pairwise width comparisons
clc;
clear;
close all;

scriptPath = mfilename('fullpath');
[scriptFolder, ~, ~] = fileparts(scriptPath);
cd(scriptFolder);

source_mat = fullfile(scriptFolder, 'comparison_report_pairwise_widths_20260410', 'pairwise_width_full_tlist.mat');
if ~exist(source_mat, 'file')
    error('Missing source data file: %s', source_mat);
end

load(source_mat, 'results');

rows = struct([]);
for i = 1:numel(results)
    if numel(results(i).center_rows{1}) < 2 || isempty(results(i).center_rows{1}{2})
        continue;
    end
    vals = results(i).center_rows{1}{2};
    row = struct();
    row.W_in = results(i).W_in;
    row.W_out = results(i).W_out;
    row.R_min = results(i).R_min;
    row.lambda_center_nm = results(i).lambda_center_nm;
    row.T2_col1 = vals(1);
    row.T2_row = vals;
    row.leakage_sum = sum(vals(2:end));
    row.basic_mat_path = results(i).basic_mat_path;
    rows = [rows; row]; %#ok<AGROW>
end

if isempty(rows)
    error('No valid rows found.');
end

sort_matrix = [[rows.T2_col1]', -[rows.leakage_sum]'];
[~, order] = sortrows(sort_matrix, [-1, -2]);
rows = rows(order);

report_folder = fullfile(scriptFolder, 'comparison_report_pairwise_widths_20260410');
html_path = fullfile(report_folder, 'pairwise_width_sorted_table.html');

html = {};
html{end+1} = '<html><head><meta charset="utf-8"><title>Sorted Pairwise Width Table</title>';
html{end+1} = '<style>body{font-family:Arial,sans-serif;margin:24px;line-height:1.4;} table{border-collapse:collapse;width:100%;} th,td{border:1px solid #ccc;padding:8px;text-align:left;vertical-align:top;} th{background:#f5f5f5;position:sticky;top:0;} code{background:#f4f4f4;padding:2px 4px;} .small{color:#666;font-size:12px;}</style></head><body>';
html{end+1} = '<h1>Sorted Pairwise Width Results</h1>';
html{end+1} = '<p>Sorted by <code>T2_col1</code> descending. Secondary key: smaller leakage sum <code>sum(T2_row(2:end))</code>.</p>';
html{end+1} = '<table>';
html{end+1} = '<tr><th>Rank</th><th>W_in</th><th>W_out</th><th>R_min</th><th>lambda_center_nm</th><th>T2_col1</th><th>Leakage sum</th><th>T2_row_center</th><th>basic.mat</th></tr>';

for i = 1:numel(rows)
    row_text = sprintf('%.10f ', rows(i).T2_row);
    html{end+1} = sprintf(['<tr><td>%d</td><td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%.6f</td>' ...
        '<td>%.10f</td><td>%.10f</td><td><code>[ %s]</code></td><td><span class="small">%s</span></td></tr>'], ...
        i, rows(i).W_in, rows(i).W_out, rows(i).R_min, rows(i).lambda_center_nm, ...
        rows(i).T2_col1, rows(i).leakage_sum, row_text, rows(i).basic_mat_path);
end

html{end+1} = '</table></body></html>';

fid = fopen(html_path, 'w');
fprintf(fid, '%s', strjoin(html, newline));
fclose(fid);

fprintf('Sorted HTML table generated: %s\n', html_path);
