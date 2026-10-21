%% Load data
[fileName1, filePath1] = uigetfile({'*.tif';'*.*'}, 'Open green channel "fixed" image .tif');
if isequal(fileName1,0)
    error('User cancelled the program');
end
[fileName2, filePath2] = uigetfile({'*.tif';'*.*'}, 'Open red channel "moving" image .tif');
if isequal(fileName2,0)
    error('User cancelled the program');
end

Fixed = imread([filePath1 fileName1]);
Moving = imread([filePath2 fileName2]);

%% Settings & Registration
[optimizer, metric] = imregconfig('Multimodal');
optimizer.InitialRadius = 0.005;
optimizer.GrowthFactor = 1.02;
optimizer.Epsilon = 1.5e-6;
optimizer.MaximumIterations = 3000;

metric.NumberOfHistogramBins = 64;
metric.UseAllPixels = true;

%% Transform
tform = imregtform(Moving, Fixed, 'affine', optimizer, metric);
movingRegistered = imwarp(Moving, tform, 'OutputView', imref2d(size(Fixed)));

%% Contrast Adjustment & Normalization
% Convert to single precision [0, 1]
fixed_norm  = mat2gray(single(Fixed));
moving_norm = mat2gray(single(movingRegistered));

% Robust background subtraction & percentile contrast stretching
% Suppresses background noise (2nd percentile) and avoids saturation from hot pixels (99.8th percentile)
pLow_G  = prctile(fixed_norm(:), 2.0);
pHigh_G = prctile(fixed_norm(:), 99.8);
green_adj = imadjust(fixed_norm, [pLow_G, pHigh_G], [0, 1], 0.7); % Gamma = 0.7 boosts faint structures

pLow_R  = prctile(moving_norm(:), 2.0);
pHigh_R = prctile(moving_norm(:), 99.8);
red_adj = imadjust(moving_norm, [pLow_R, pHigh_R], [0, 1], 0.7);

%% Build Pure-Color & Merged RGB Images
sz = size(Fixed);

% 1. Pure Green Channel: [0, Green, 0]
greenRGB = zeros([sz(1), sz(2), 3], 'single');
greenRGB(:, :, 2) = green_adj;

% 2. Pure Red Channel: [Red, 0, 0]
redRGB = zeros([sz(1), sz(2), 3], 'single');
redRGB(:, :, 1) = red_adj;

% 3. Merged Dual-Color Composite: Red + Green (Overlapping areas mix into Yellow)
mergedRGB = zeros([sz(1), sz(2), 3], 'single');
mergedRGB(:, :, 1) = red_adj;    % R
mergedRGB(:, :, 2) = green_adj;  % G
mergedRGB(:, :, 3) = 0;          % B

%% Display in Three Separate Figures
% Figure 1: Green Reference Channel
figure('Name', 'Green Channel (Fixed)', 'NumberTitle', 'off', 'Color', 'k');
imshow(greenRGB);
title('Green Channel (Reference)', 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');

% Figure 2: Red Registered Channel
figure('Name', 'Red Channel (Registered)', 'NumberTitle', 'off', 'Color', 'k');
imshow(redRGB);
title('Red Channel (Warped Moving)', 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');

% Figure 3: Merged Two-Color Overlay
figure('Name', 'Merged Two-Color Overlay', 'NumberTitle', 'off', 'Color', 'k');
imshow(mergedRGB);
title('Merged Channels (Red + Green = Yellow Overlap)', 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');

%% Save Transformation Object
[file, path] = uiputfile('*.mat', 'Save transformation file as', 'tform.mat');
if isequal(file, 0)
    disp('❌ Save cancelled by user.');
else
    save(fullfile(path, file), 'tform');
    disp(['✅ File saved at: ', fullfile(path, file)]);
end