%% Convert Easy-DHPSF MAT Results to CSV
% Allows interactive selection of Output.mat and user-defined save path.

clear; clc; close all;

%% 1. Interactive MAT-File Selection
fprintf('Please select your Easy-DHPSF MAT file (e.g., Output.mat)...\n');
[matFileName, matFilePath] = uigetfile({'*.mat', 'MAT-Files (*.mat)'; ...
                                       '*.*',   'All Files (*.*)'}, ...
                                       'Select Easy-DHPSF Output File');

if isequal(matFileName, 0)
    disp('File selection cancelled by user.');
    return;
end

matFullPath = fullfile(matFilePath, matFileName);
fprintf('Loading: %s ...\n', matFullPath);
loadedData = load(matFullPath);

%% 2. Check for Required Fields & Extract Data
% Define the required localization fields
requiredFields = {'frameNum', 'lobeDist', 'numPhotons', 'meanBkgnd', ...
                  'sigmaX', 'sigmaY', 'sigmaZ', 'xLoc', 'yLoc', 'zLoc'};

% Check presence of essential localization arrays
missingFields = requiredFields(~isfield(loadedData, requiredFields));
if ~isempty(missingFields)
    error('The selected MAT-file is missing required variable(s): %s', ...
          strjoin(missingFields, ', '));
end

% Determine dataset length (using xLoc or xLocPix)
if isfield(loadedData, 'xLoc')
    nPoints = numel(loadedData.xLoc);
elseif isfield(loadedData, 'xLocPix')
    nPoints = numel(loadedData.xLocPix);
else
    nPoints = numel(loadedData.frameNum);
end

% Ensure column vectors (:) for all fields
frameNum   = loadedData.frameNum(:);
lobeDist   = loadedData.lobeDist(:);
numPhotons = loadedData.numPhotons(:);
meanBkgnd  = loadedData.meanBkgnd(:);
sigmaX     = loadedData.sigmaX(:);
sigmaY     = loadedData.sigmaY(:);
sigmaZ     = loadedData.sigmaZ(:);
xLoc       = loadedData.xLoc(:);
yLoc       = loadedData.yLoc(:);
zLoc       = loadedData.zLoc(:);

% Generate sequential ID
id = (1:nPoints)';

% Extract or generate Probe channel
if isfield(loadedData, 'Probe')
    Probe = loadedData.Probe(:);
else
    Probe = zeros(nPoints, 1);
end

%% 3. Construct Localization Table
Localizations = table(frameNum, id, lobeDist, numPhotons, meanBkgnd, ...
                      sigmaX, sigmaY, sigmaZ, xLoc, yLoc, zLoc, Probe, ...
    'VariableNames', {'frame', 'id', 'lobeDist', ...
                      'intensity[photon]', 'offset[photon]', ...
                      'UncertaintyX', 'UncertaintyY', 'UncertaintyZ', ...
                      'x[nm]', 'y[nm]', 'z[nm]', 'Probe'});

fprintf('Successfully parsed %d localizations.\n\n', nPoints);

%% 4. Select Save Location and Save CSV
[~, baseName, ~] = fileparts(matFileName);
defaultSaveName = [baseName, '_EasyDHPSF_Locs.csv'];

fprintf('Please select where to save the converted CSV...\n');
[saveFileName, saveFilePath] = uiputfile('*.csv', ...
                                        'Save Localizations as CSV', ...
                                        fullfile(matFilePath, defaultSaveName));

if isequal(saveFileName, 0)
    disp('Saving cancelled: No destination selected.');
    return;
end

outputCSVPath = fullfile(saveFilePath, saveFileName);
writetable(Localizations, outputCSVPath);

fprintf('====================================================\n');
fprintf('  File saved successfully!\n');
fprintf('  Destination: %s\n', outputCSVPath);
fprintf('  Total rows:  %d\n', height(Localizations));
fprintf('====================================================\n');