%% Generate HTML report for pairwise width comparisons
clc;
clear;
close all;

scriptPath = mfilename('fullpath');
[scriptFolder, ~, ~] = fileparts(scriptPath);
cd(scriptFolder);

device_name = 'eulersbend_opt';
fdtdOutputRoot = [scriptFolder, 'data'];
report_date = datestr(now, 'yyyymmdd');
reportFolder = fullfile(scriptFolder, ['comparison_report_pairwise_widths_', report_date]);
if ~exist(reportFolder, 'dir')
    mkdir(reportFolder);
end

target_widths = [0.45, 1.5, 1.66];
target_width_labels = arrayfun(@(x) num2str(x, '%.10g'), target_widths, 'UniformOutput', false);
allowed_width_strings = string(target_width_labels);

files = dir(fullfile(fdtdOutputRoot, 'dat_*', '*', 'basic.mat'));
results = struct([]);

for i_file = 1:numel(files)
    basic_mat_path = fullfile(files(i_file).folder, files(i_file).name);
    sim_data = load(basic_mat_path);
    if ~isfield(sim_data, 'para') || ~isfield(sim_data, 'T_list') || numel(sim_data.T_list) < 2
        continue;
    end
    if ~iscell(sim_data.T_list) || ...
            ~isstruct(sim_data.T_list{1}) || ~isfield(sim_data.T_list{1}, 'lambda') || ...
            ~isstruct(sim_data.T_list{2}) || ~isfield(sim_data.T_list{2}, 'T_net')
        continue;
    end
    para = sim_data.para;
    width_in = para.W_in;
    width_out = para.W_out;
    if ~ismember(string(num2str(width_in, '%.10g')), allowed_width_strings) || ...
            ~ismember(string(num2str(width_out, '%.10g')), allowed_width_strings)
        continue;
    end

    lambda_nm = sim_data.T_list{1}.lambda * 1e9;
    lambda_idx = round(length(lambda_nm) / 2);
    n_ports = numel(sim_data.T_list);
    T_abs = cell(1, n_ports);
    center_rows = cell(1, n_ports);
    center_col1 = NaN(1, n_ports);
    for i_port = 1:n_ports
        if isstruct(sim_data.T_list{i_port}) && isfield(sim_data.T_list{i_port}, 'T_net')
            T_abs{i_port} = abs(sim_data.T_list{i_port}.T_net);
            center_rows{i_port} = abs(sim_data.T_list{i_port}.T_net(lambda_idx, :));
            center_col1(i_port) = abs(sim_data.T_list{i_port}.T_net(lambda_idx, 1));
        else
            T_abs{i_port} = [];
            center_rows{i_port} = [];
        end
    end

    result = struct();
    result.basic_mat_path = basic_mat_path;
    result.folder = files(i_file).folder;
    result.para = para;
    result.W_in = width_in;
    result.W_out = width_out;
    result.R_min = para.R_min;
    result.lambda_nm = lambda_nm;
    result.lambda_center_nm = lambda_nm(lambda_idx);
    result.lambda_idx = lambda_idx;
    result.T_abs = {T_abs};
    result.center_rows = {center_rows};
    result.center_col1 = center_col1;
    result.case_label = sprintf('W_in=%.4f, W_out=%.4f, R_{min}=%.4f', width_in, width_out, para.R_min);
    results = [results; result]; %#ok<AGROW>
end

if isempty(results)
    error('No matching basic.mat files found for target widths.');
end

save(fullfile(reportFolder, 'pairwise_width_full_tlist.mat'), 'results', 'target_widths');

pair_keys = unique(arrayfun(@(r) sprintf('%.10g__%.10g', r.W_in, r.W_out), results, 'UniformOutput', false), 'stable');

plot_records = struct([]);
for i_pair = 1:numel(pair_keys)
    pair_key = pair_keys{i_pair};
    pair_mask = arrayfun(@(r) strcmp(sprintf('%.10g__%.10g', r.W_in, r.W_out), pair_key), results);
    pair_results = results(pair_mask);
    [~, sort_idx] = sort([pair_results.R_min]);
    pair_results = pair_results(sort_idx);

    fig = figure('Visible', 'off', 'Position', [100, 100, 1100, 700]);
    tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    hold on;
    legends = cell(1, numel(pair_results));
    for i_case = 1:numel(pair_results)
        plot(pair_results(i_case).lambda_nm, pair_results(i_case).T_abs{1}{2}(:, 1), 'LineWidth', 1.5);
        legends{i_case} = sprintf('R_{min}=%.4f', pair_results(i_case).R_min);
    end
    hold off;
    grid on;
    xlabel('Wavelength (nm)');
    ylabel('|T\_list\{2\}.T\_net(:,1)|');
    title(sprintf('Primary mode spectrum, W_{in}=%.4f, W_{out}=%.4f', pair_results(1).W_in, pair_results(1).W_out));
    legend(legends, 'Location', 'best');

    nexttile;
    hold on;
    cmap = lines(numel(pair_results));
    for i_case = 1:numel(pair_results)
        vals = pair_results(i_case).center_rows{1}{2};
        plot(1:numel(vals), vals, '-o', 'LineWidth', 1.5, 'Color', cmap(i_case, :));
    end
    hold off;
    grid on;
    xlabel('Column index at lambda_{center}');
    ylabel('|T\_list\{2\}.T\_net(lambda\_idx,:)|');
    title('Center-wavelength full row comparison');
    legend(legends, 'Location', 'best');

    pair_label = sprintf('Win_%s_Wout_%s', num2str(pair_results(1).W_in, '%.10g'), num2str(pair_results(1).W_out, '%.10g'));
    img_name = [pair_label, '.png'];
    exportgraphics(fig, fullfile(reportFolder, img_name), 'Resolution', 180);
    close(fig);

    plot_records(end + 1).pair_key = pair_key; %#ok<SAGROW>
    plot_records(end).image_name = img_name;
    plot_records(end).pair_results = pair_results;
end

target_pairs = {
    [0.45, 1.5]
    [1.5, 0.45]
    [0.45, 1.66]
    [1.66, 0.45]
    [1.5, 1.66]
    [1.66, 1.5]
    [1.5, 1.5]
    [1.66, 1.66]
    [0.45, 0.45]
    };

html_lines = {};
html_lines{end + 1} = '<html><head><meta charset="utf-8"><title>Pairwise Width Comparison</title>';
html_lines{end + 1} = '<style>body{font-family:Arial,sans-serif;margin:24px;line-height:1.45;} table{border-collapse:collapse;margin:12px 0;width:100%;} th,td{border:1px solid #ccc;padding:6px 8px;text-align:left;vertical-align:top;} th{background:#f5f5f5;} code{background:#f3f3f3;padding:2px 4px;} .missing{color:#999;} img{max-width:100%;height:auto;border:1px solid #ddd;} pre{white-space:pre-wrap;word-break:break-word;background:#fafafa;padding:10px;border:1px solid #eee;}</style></head><body>';
html_lines{end + 1} = '<h1>Pairwise Width Comparison Report</h1>';
html_lines{end + 1} = sprintf('<p>Generated on %s. This report compares available cases for widths <code>0.45</code>, <code>1.5</code>, and <code>1.66</code>. It includes complete <code>T_list{2}</code> spectra and full center-wavelength rows <code>|T_list{2}.T_net(lambda_idx,:)|</code> for all available <code>R_min</code>.</p>', datestr(now, 31));
html_lines{end + 1} = '<p>Raw consolidated data: <code>pairwise_width_full_tlist.mat</code></p>';

html_lines{end + 1} = '<h2>Availability</h2>';
html_lines{end + 1} = '<table><tr><th>W_in</th><th>W_out</th><th>Available R_min</th></tr>';
for i_pair = 1:numel(target_pairs)
    w_in = target_pairs{i_pair}(1);
    w_out = target_pairs{i_pair}(2);
    mask = arrayfun(@(r) abs(r.W_in - w_in) < 1e-12 && abs(r.W_out - w_out) < 1e-12, results);
    pair_results = results(mask);
    if isempty(pair_results)
        r_text = '<span class="missing">No data</span>';
    else
        r_vals = sort([pair_results.R_min]);
        r_text = strjoin(arrayfun(@(x) num2str(x, '%.10g'), r_vals, 'UniformOutput', false), ', ');
    end
    html_lines{end + 1} = sprintf('<tr><td>%.4f</td><td>%.4f</td><td>%s</td></tr>', w_in, w_out, r_text);
end
html_lines{end + 1} = '</table>';

for i_plot = 1:numel(plot_records)
    pair_results = plot_records(i_plot).pair_results;
    html_lines{end + 1} = sprintf('<h2>W_in = %.4f, W_out = %.4f</h2>', pair_results(1).W_in, pair_results(1).W_out);
    html_lines{end + 1} = sprintf('<p><img src="%s" alt="pair plot"></p>', plot_records(i_plot).image_name);
    html_lines{end + 1} = '<table><tr><th>R_min</th><th>lambda_center_nm</th><th>|T_list{2}.T_net(lambda_idx,1)|</th><th>|T_list{2}.T_net(lambda_idx,:)|</th><th>basic.mat</th></tr>';
    for i_case = 1:numel(pair_results)
        center_row_text = sprintf('%.10f ', pair_results(i_case).center_rows{1}{2});
        html_lines{end + 1} = sprintf(['<tr><td>%.4f</td><td>%.6f</td><td>%.10f</td>' ...
            '<td><code>[ %s]</code></td><td><code>%s</code></td></tr>'], ...
            pair_results(i_case).R_min, pair_results(i_case).lambda_center_nm, ...
            pair_results(i_case).center_col1(2), center_row_text, pair_results(i_case).basic_mat_path);
    end
    html_lines{end + 1} = '</table>';

    for i_case = 1:numel(pair_results)
        html_lines{end + 1} = sprintf('<h3>Case: W_in = %.4f, W_out = %.4f, R_min = %.4f</h3>', ...
            pair_results(i_case).W_in, pair_results(i_case).W_out, pair_results(i_case).R_min);
        html_lines{end + 1} = sprintf('<p>Center row for T_list{1}: <code>[ %s]</code></p>', ...
            sprintf('%.10f ', pair_results(i_case).center_rows{1}{1}));
        html_lines{end + 1} = sprintf('<p>Center row for T_list{2}: <code>[ %s]</code></p>', ...
            sprintf('%.10f ', pair_results(i_case).center_rows{1}{2}));
        html_lines{end + 1} = '<details><summary>Full T_list{2} spectrum matrix (abs)</summary>';
        html_lines{end + 1} = ['<pre>', matrix_to_text(pair_results(i_case).T_abs{1}{2}), '</pre></details>'];
    end
end

html_lines{end + 1} = '</body></html>';

html_path = fullfile(reportFolder, 'pairwise_width_comparison.html');
fid = fopen(html_path, 'w');
fprintf(fid, '%s', strjoin(html_lines, newline));
fclose(fid);

fprintf('HTML report generated: %s\n', html_path);

function txt = matrix_to_text(mat)
    rows = cell(size(mat, 1), 1);
    for i_row = 1:size(mat, 1)
        rows{i_row} = sprintf('%.10f ', mat(i_row, :));
    end
    txt = strjoin(rows, newline);
end
