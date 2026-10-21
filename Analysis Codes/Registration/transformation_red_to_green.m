%% 2D Transformation for FB - EASY DHPSF
clc; clear; close all;

%% 1. Load Data Files (Single or Multi-select)
[file, path] = uigetfile({'*.csv', 'CSV Files (*.csv)'}, ...
                         'Select FB data from Easy DHPSF', ...
                         'MultiSelect', 'on');
if isequal(file, 0), error('User cancelled file selection.'); end

% Standardize single file selection to cell array
if ischar(file)
    fileList = {file};
else
    fileList = file;
end

% Read the first table to let user pick columns from its header names
firstTable = readtable(fullfile(path, fileList{1}));
varNames = firstTable.Properties.VariableNames;

%% 2. Interactive Column Selection
[idxFrame, ok1] = listdlg('PromptString', 'Select FRAME column:', ...
                          'SelectionMode', 'single', ...
                          'ListString', varNames);
if ~ok1, error('Frame column selection cancelled.'); end

[idxX, ok2] = listdlg('PromptString', 'Select X (lateral) column:', ...
                      'SelectionMode', 'single', ...
                      'ListString', varNames);
if ~ok2, error('X column selection cancelled.'); end

[idxY, ok3] = listdlg('PromptString', 'Select Y (lateral) column:', ...
                      'SelectionMode', 'single', ...
                      'ListString', varNames);
if ~ok3, error('Y column selection cancelled.'); end

[idxZ, ok4] = listdlg('PromptString', 'Select Z (axial) column:', ...
                      'SelectionMode', 'single', ...
                      'ListString', varNames);
if ~ok4, error('Z column selection cancelled.'); end

fprintf('\nSelected Columns:\n');
fprintf('  Frame: %s (col %d)\n', varNames{idxFrame}, idxFrame);
fprintf('  X:     %s (col %d)\n', varNames{idxX}, idxX);
fprintf('  Y:     %s (col %d)\n', varNames{idxY}, idxY);
fprintf('  Z:     %s (col %d)\n', varNames{idxZ}, idxZ);

%% 3. Concatenate Multi-File Datasets with Frame Offset
FB_data = [];

for i = 1:length(fileList)
    currentTable = readtable(fullfile(path, fileList{i}));
    
    % Extract user-selected columns: [Frame, X, Y, Z]
    subData = [double(currentTable{:, idxFrame}), ...
               double(currentTable{:, idxX}), ...
               double(currentTable{:, idxY}), ...
               double(currentTable{:, idxZ})];
    
    if i > 1
        % Offset current frame count by last frame of accumulated data
        lastFrame = FB_data(end, 1);
        subData(:, 1) = subData(:, 1) + lastFrame;
    end
    
    FB_data = [FB_data; subData];
end

% Remove any rows containing NaN in the coordinate columns
validRows = ~any(isnan(FB_data), 2);
FB_data = FB_data(validRows, :);
fprintf('Loaded %d valid localizations.\n', size(FB_data, 1));

%% 4. Scatter Plot Drift Corrected Raw Data
figure(1);
scatter(FB_data(:, 2), FB_data(:, 3), 10, 'r.');
xlabel('X Position'); ylabel('Y Position');
title('Raw / Drift Corrected Coordinates');
axis equal; grid on;

%% 5. Load Transformation Matrix (.mat)
[tformFile, tformPath] = uigetfile('*.mat', 'Select Registration tform.mat file');
if isequal(tformFile, 0), error('User cancelled tform selection.'); end

loadedMat = load(fullfile(tformPath, tformFile));

% Check for common transformation variable names
if isfield(loadedMat, 'tform')
    tformObj = loadedMat.tform;
elseif isfield(loadedMat, 'tformToSave')
    tformObj = loadedMat.tformToSave;
else
    % Fall back to the first variable found in the .mat
    varsInMat = fieldnames(loadedMat);
    tformObj = loadedMat.(varsInMat{1});
end

%% 6. Coordinate Scaling & Transformation
pixelSizeNm = 108; % nm per pixel

x_px = FB_data(:, 2) / pixelSizeNm; 
y_px = FB_data(:, 3) / pixelSizeNm;

% Transform points forward
[transformed_x_px, transformed_y_px] = transformPointsForward(tformObj, x_px, y_px);

% Scatter plot transformed data
figure(2);
scatter(transformed_x_px, transformed_y_px, 10, 'g.');
title('Drift Corrected and Transformed 2D');
xlabel('X (pixels)'); ylabel('Y (pixels)');
axis equal; grid on;

% Convert back to nanometers
transformed_x_nm = transformed_x_px * pixelSizeNm;
transformed_y_nm = transformed_y_px * pixelSizeNm;

%% 7. Assemble Transformed Table
FB_Transformed = FB_data;
FB_Transformed(:, 2) = transformed_x_nm;
FB_Transformed(:, 3) = transformed_y_nm;

finalTable = array2table(FB_Transformed, ...
    'VariableNames', {'frame', 'x_nm', 'y_nm', 'z_nm'});

%% 8. Save Transformed CSV
[saveFile, savePath] = uiputfile('*.csv', 'Save transformed CSV as', 'transformed_data.csv');
if isequal(saveFile, 0)
    disp('❌ Save cancelled by user.');
else
    outPath = fullfile(savePath, saveFile);
    writetable(finalTable, outPath);
    fprintf('✅ Transformed CSV saved successfully at:\n%s\n', outPath);
end