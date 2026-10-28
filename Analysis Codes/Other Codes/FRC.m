%% Multi-Channel FRC Resolution vs. Frame Progression (Handles 1, 2, or 3 Channels)
% Allows uploading Green, Red, and/or Merged datasets.
% If only 1 channel is selected (others cancelled), it still plots the curve.

clear; clc; close all;

channel_names = {'Green', 'Red', 'Merged'};
num_channels  = numel(channel_names);

% Style configurations
line_colors = [0.12, 0.65, 0.25;   % Green
               0.85, 0.20, 0.20;   % Red
               0.10, 0.45, 0.85];  % Blue
marker_styles = {'o', 's', '^'};
line_styles   = {'--', '--', '-'};

thresh_1_7 = 1 / 7;

% Storage
all_frames   = cell(num_channels, 1);
all_res      = cell(num_channels, 1);
active_ch    = false(num_channels, 1);
col_name_q   = '';
col_name_frc = '';

%% 1. Interactive File Selection & Processing per Channel
for ch = 1:num_channels
    cur_ch = channel_names{ch};
    fprintf('\n=====================================================\n');
    fprintf('Select CSV files for [%s Channel] (Cancel if not available)\n', cur_ch);
    fprintf('=====================================================\n');
    
    [file_names, file_path] = uigetfile('*.csv', ...
        sprintf('Select CSV files for [%s Channel] (Cancel to skip)', cur_ch), ...
        'MultiSelect', 'on');
    
    % If user cancels selection for this channel, skip it gracefully
    if isequal(file_names, 0)
        fprintf('-> Skipping [%s Channel]: No files selected.\n', cur_ch);
        continue;
    end
    
    if ischar(file_names)
        file_names = {file_names};
    end
    
    num_files = numel(file_names);
    fprintf('Loaded %d file(s) for %s.\n', num_files, cur_ch);
    active_ch(ch) = true;
    
    % Extract numeric frame count from filenames
    extracted_frames = zeros(num_files, 1);
    for i = 1:num_files
        matches = regexp(file_names{i}, '\d+', 'match');
        if ~isempty(matches)
            nums = cellfun(@str2double, matches);
            extracted_frames(i) = nums(end);
        else
            fprintf('  No frame number found in %s\n', file_names{i});
            extracted_frames(i) = input('    Enter frame number manually: ');
        end
    end
    
    % Sort chronologically by frame number
    [frames_sorted, s_idx] = sort(extracted_frames, 'ascend');
    file_names_sorted = file_names(s_idx);
    
    res_cutoffs = nan(num_files, 1);
    
    % Process files for current channel
    for i = 1:num_files
        cur_file = fullfile(file_path, file_names_sorted{i});
        tbl = readtable(cur_file);
        var_names = tbl.Properties.VariableNames;
        
        % Auto-detect columns once across all files
        if isempty(col_name_q) || isempty(col_name_frc)
            q_idx = find(~cellfun(@isempty, regexpi(var_names, ...
                '^(spatial_freq|frequency|freq|spatial_frequency|spatial|q|k)\b|freq.*nm|freq.*um')), 1);
            frc_idx = find(~cellfun(@isempty, regexpi(var_names, ...
                '^(smooth|smoothed|frc_smooth|frc_smoothed|frc|corr|correlation)\b')), 1);
            
            if isempty(q_idx)
                fprintf('\n  Could not auto-detect Frequency column in %s:\n', file_names_sorted{i});
                disp(var_names);
                user_col = strtrim(input('  Enter exact column name for Frequency: ', 's'));
                while ~ismember(user_col, var_names)
                    user_col = strtrim(input('  Column not found. Re-enter: ', 's'));
                end
                col_name_q = user_col;
            else
                col_name_q = var_names{q_idx};
            end
            
            if isempty(frc_idx)
                fprintf('\n  Could not auto-detect FRC column in %s:\n', file_names_sorted{i});
                disp(var_names);
                user_col = strtrim(input('  Enter exact column name for FRC: ', 's'));
                while ~ismember(user_col, var_names)
                    user_col = strtrim(input('  Column not found. Re-enter: ', 's'));
                end
                col_name_frc = user_col;
            else
                col_name_frc = var_names{frc_idx};
            end
            
            fprintf('  [Shared Columns] Frequency: "%s" | Correlation: "%s"\n\n', col_name_q, col_name_frc);
        end
        
        q_raw   = double(tbl.(col_name_q));
        frc_raw = double(tbl.(col_name_frc));
        
        % Clean NaNs/Infs and sort ascending by spatial frequency
        valid_mask = isfinite(q_raw) & isfinite(frc_raw);
        q_clean    = q_raw(valid_mask);
        frc_clean  = frc_raw(valid_mask);
        [q_sorted, q_order] = sort(q_clean, 'ascend');
        frc_sorted          = frc_clean(q_order);
        
        % Apply 5-point moving mean if raw un-smoothed correlation was loaded
        if ~contains(lower(col_name_frc), 'smooth')
            frc_sorted = movmean(frc_sorted, 5);
        end
        
        % Linear interpolation for 1/7 threshold crossing
        idx_cross = find(frc_sorted < thresh_1_7, 1);
        if ~isempty(idx_cross) && idx_cross > 1
            q1 = q_sorted(idx_cross - 1); q2 = q_sorted(idx_cross);
            c1 = frc_sorted(idx_cross - 1); c2 = frc_sorted(idx_cross);
            q_interp = q1 + (thresh_1_7 - c1) * (q2 - q1) / (c2 - c1);
            if q_interp > 0
                res_cutoffs(i) = 1 / q_interp;
            end
        end
    end
    
    all_frames{ch} = frames_sorted;
    all_res{ch}    = res_cutoffs;
end

%% 2. Check if at least one dataset was loaded
if ~any(active_ch)
    disp('No files were loaded for any channel. Exiting.');
    return;
end

%% 3. Plot Curve(s)
figure('Color', 'w', 'Position', [150, 150, 950, 560]);
hold on;

min_frame_val = inf;
max_frame_val = -inf;
max_res_val   = -inf;

% Plot only the channel(s) that were uploaded
active_indices = find(active_ch)';
for ch = active_indices
    f_vals = all_frames{ch};
    r_vals = all_res{ch};
    
    plot(f_vals, r_vals, ...
         'LineStyle', line_styles{ch}, ...
         'LineWidth', 2.2, ...
         'Color', line_colors(ch, :), ...
         'Marker', marker_styles{ch}, ...
         'MarkerSize', 7, ...
         'MarkerFaceColor', line_colors(ch, :), ...
         'MarkerEdgeColor', [0.2, 0.2, 0.2], ...
         'DisplayName', channel_names{ch});
     
    min_frame_val = min(min_frame_val, min(f_vals));
    max_frame_val = max(max_frame_val, max(f_vals));
    max_res_val   = max(max_res_val, max(r_vals));
end

hold off;
grid on;

set(gca, 'Box', 'on', ...
         'FontSize', 11, ...
         'LineWidth', 1.2, ...
         'GridLineStyle', '--', ...
         'GridAlpha', 0.5);

% Adjust limits safely whether 1 or multiple points exist
if min_frame_val == max_frame_val
    xlim([min_frame_val * 0.8, max_frame_val * 1.2]);
else
    xlim([min_frame_val * 0.95, max_frame_val * 1.05]);
end
ylim([0, max_res_val * 1.25]);

xlabel('Number of Frames', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('FRC Resolution Cutoff R_{1/7} (nm)', 'FontSize', 12, 'FontWeight', 'bold');

if sum(active_ch) == 1
    title(sprintf('FRC Resolution Progression (%s Channel)', channel_names{active_indices}), ...
          'FontSize', 13, 'FontWeight', 'bold');
else
    title('FRC Resolution Progression Comparison Across Channels', ...
          'FontSize', 13, 'FontWeight', 'bold');
end

legend('Location', 'northeast', 'FontSize', 10.5, 'Interpreter', 'tex');