%% One-Channel 3D Drift Correction with Interactive Column & Unit Selection
% Adapted for custom Bead and Single-Molecule (SM) localization CSV tables.
% Performs interactive ROI bead selection, trajectory smoothing (csaps), 
% and fiducial drift correction.

clear;
clc;
close all;

%% ---------------- 1. Load Single-Molecule (SM) Data ----------------
[fileSM, pathSM] = uigetfile('*.csv', 'Select Single-Molecule (SM) Data CSV', 'MultiSelect', 'on');
if isequal(fileSM, 0), error('Process aborted: No SM data selected.'); end

SM_rawTable = table();
if iscell(fileSM)
    for i = 1:length(fileSM)
        tempT = readtable(fullfile(pathSM, fileSM{i}), 'VariableNamingRule', 'preserve');
        SM_rawTable = [SM_rawTable; tempT]; %#ok<AGROW>
    end
else
    SM_rawTable = readtable(fullfile(pathSM, fileSM), 'VariableNamingRule', 'preserve');
end

%% ---------------- 2. Load Fiducial Bead (FB) Data ------------------
[fileFB, pathFB] = uigetfile('*.csv', 'Select Fiducial Bead (FB) CSV');
if isequal(fileFB, 0), error('Process aborted: No Bead data selected.'); end

FB_rawTable = readtable(fullfile(pathFB, fileFB), 'VariableNamingRule', 'preserve');

%% ---------------- 3. Interactive Column & Unit Selection GUI -------
smCols = SM_rawTable.Properties.VariableNames;
fbCols = FB_rawTable.Properties.VariableNames;

% Auto-detection helper
findMatch = @(cols, target) find(strcmpi(cols, target) | ...
    cellfun(@(x) ~isempty(regexpi(x, ['^', target], 'once')), cols), 1);

def_SM_frame = findMatch(smCols, 'frame'); if isempty(def_SM_frame), def_SM_frame = 1; end
def_SM_x     = findMatch(smCols, 'x');     if isempty(def_SM_x),     def_SM_x = min(2, numel(smCols)); end
def_SM_y     = findMatch(smCols, 'y');     if isempty(def_SM_y),     def_SM_y = min(3, numel(smCols)); end
def_SM_z     = findMatch(smCols, 'z');     if isempty(def_SM_z),     def_SM_z = min(4, numel(smCols)); end
def_SM_I     = findMatch(smCols, 'phot');  if isempty(def_SM_I),     def_SM_I = min(5, numel(smCols)); end

def_FB_frame = findMatch(fbCols, 'frame'); if isempty(def_FB_frame), def_FB_frame = 1; end
def_FB_x     = findMatch(fbCols, 'x');     if isempty(def_FB_x),     def_FB_x = min(2, numel(fbCols)); end
def_FB_y     = findMatch(fbCols, 'y');     if isempty(def_FB_y),     def_FB_y = min(3, numel(fbCols)); end
def_FB_z     = findMatch(fbCols, 'z');     if isempty(def_FB_z),     def_FB_z = min(4, numel(fbCols)); end

% Build GUI Dialog
dlg = uifigure('Name', 'Select CSV Columns and Coordinate Units', 'Position', [100 100 680 500]);
grid = uigridlayout(dlg, [10, 4]);
grid.RowHeight = {30, 30, 30, 30, 30, 30, 30, 30, 35, 40};
grid.ColumnWidth = {160, 160, 160, 160};

% Section Headers
uilabel(grid, 'Text', 'Single-Molecule (SM) CSV', 'FontWeight', 'bold');
uilabel(grid, 'Text', '');
uilabel(grid, 'Text', 'Fiducial Bead (FB) CSV', 'FontWeight', 'bold');
uilabel(grid, 'Text', '');

% Frame Column
uilabel(grid, 'Text', 'SM Frame Column:');
dd_SM_frame = uidropdown(grid, 'Items', smCols, 'Value', smCols{def_SM_frame});
uilabel(grid, 'Text', 'FB Frame Column:');
dd_FB_frame = uidropdown(grid, 'Items', fbCols, 'Value', fbCols{def_FB_frame});

% X Column
uilabel(grid, 'Text', 'SM X Column:');
dd_SM_x = uidropdown(grid, 'Items', smCols, 'Value', smCols{def_SM_x});
uilabel(grid, 'Text', 'FB X Column:');
dd_FB_x = uidropdown(grid, 'Items', fbCols, 'Value', fbCols{def_FB_x});

% Y Column
uilabel(grid, 'Text', 'SM Y Column:');
dd_SM_y = uidropdown(grid, 'Items', smCols, 'Value', smCols{def_SM_y});
uilabel(grid, 'Text', 'FB Y Column:');
dd_FB_y = uidropdown(grid, 'Items', fbCols, 'Value', fbCols{def_FB_y});

% Z Column
uilabel(grid, 'Text', 'SM Z Column:');
dd_SM_z = uidropdown(grid, 'Items', smCols, 'Value', smCols{def_SM_z});
uilabel(grid, 'Text', 'FB Z Column:');
dd_FB_z = uidropdown(grid, 'Items', fbCols, 'Value', fbCols{def_FB_z});

% Intensity / Photons (SM only)
uilabel(grid, 'Text', 'SM Photons/Intensity:');
dd_SM_I = uidropdown(grid, 'Items', smCols, 'Value', smCols{def_SM_I});
uilabel(grid, 'Text', '');
uilabel(grid, 'Text', '');

% Units selection
uilabel(grid, 'Text', 'SM Coordinate Unit:');
dd_SM_unit = uidropdown(grid, 'Items', {'Nanometers (nm)', 'Pixels (px)'}, 'Value', 'Nanometers (nm)');
uilabel(grid, 'Text', 'FB Coordinate Unit:');
dd_FB_unit = uidropdown(grid, 'Items', {'Nanometers (nm)', 'Pixels (px)'}, 'Value', 'Nanometers (nm)');

% Pixel size input
uilabel(grid, 'Text', 'SM Pixel Size (nm/px):');
ef_SM_px = uieditfield(grid, 'numeric', 'Value', 160.0);
uilabel(grid, 'Text', 'FB Pixel Size (nm/px):');
ef_FB_px = uieditfield(grid, 'numeric', 'Value', 160.0);

% Frame sequential shift checkbox
cb_seqFrames = uicheckbox(grid, 'Text', 'Accumulate frames if multiple SM files', 'Value', true);
cb_seqFrames.Layout.Column = [1 4];

% Confirm button
btnConfirm = uibutton(grid, 'push', 'Text', 'Apply Selection & Proceed', 'FontWeight', 'bold');
btnConfirm.Layout.Column = [1 4];

% Wait for user interaction
isConfirmed = false;
btnConfirm.ButtonPushedFcn = @(src, event) uiresume(dlg);
uiwait(dlg);

if ~isvalid(dlg)
    error('Selection dialog closed before confirmation.');
end

% Extract selected parameters
colSM_frame = dd_SM_frame.Value;
colSM_x     = dd_SM_x.Value;
colSM_y     = dd_SM_y.Value;
colSM_z     = dd_SM_z.Value;
colSM_I     = dd_SM_I.Value;
unit_SM     = dd_SM_unit.Value;
px_size_SM  = ef_SM_px.Value;

colFB_frame = dd_FB_frame.Value;
colFB_x     = dd_FB_x.Value;
colFB_y     = dd_FB_y.Value;
colFB_z     = dd_FB_z.Value;
unit_FB     = dd_FB_unit.Value;
px_size_FB  = ef_FB_px.Value;
accumulateFrames = cb_seqFrames.Value;

close(dlg);

%% ---------------- 4. Coordinate Standardization ------------------
% Multi-file SM frame continuity handling
if iscell(fileSM) && accumulateFrames
    SM_rawTable = table();
    lastFrame = 0;
    for i = 1:length(fileSM)
        tempT = readtable(fullfile(pathSM, fileSM{i}), 'VariableNamingRule', 'preserve');
        tempT.(colSM_frame) = tempT.(colSM_frame) + lastFrame;
        lastFrame = tempT.(colSM_frame)(end);
        SM_rawTable = [SM_rawTable; tempT]; %#ok<AGROW>
    end
end

% Extract SM variables
frames  = double(SM_rawTable.(colSM_frame));
xnm     = double(SM_rawTable.(colSM_x));
ynm     = double(SM_rawTable.(colSM_y));
znm     = double(SM_rawTable.(colSM_z));
photons = double(SM_rawTable.(colSM_I));

if strcmp(unit_SM, 'Pixels (px)')
    xnm = xnm * px_size_SM;
    ynm = ynm * px_size_SM;
    znm = znm * px_size_SM;
end

% Extract Bead variables
framesBead = double(FB_rawTable.(colFB_frame));
xBead_nm   = double(FB_rawTable.(colFB_x));
yBead_nm   = double(FB_rawTable.(colFB_y));
zBead_nm   = double(FB_rawTable.(colFB_z));

if strcmp(unit_FB, 'Pixels (px)')
    xBead_nm = xBead_nm * px_size_FB;
    yBead_nm = yBead_nm * px_size_FB;
    zBead_nm = zBead_nm * px_size_FB;
end

%% ---------------- 5. Isolate Fiducial Bead ROI -------------------
figure(1);
scatter(xBead_nm, yBead_nm, [], framesBead, 'filled');
set(gca, 'YDir', 'reverse');
h2 = colorbar;
colormap jet;
ylabel(h2, 'Frames [#]');
xlabel('X [nm]');
ylabel(gca, 'Y [nm]');
title('Draw a Freehand ROI Around the Fiducial Bead Trajectory');

% User draws freehand contour around bead
hpolygon = drawfreehand();
in = inpolygon(xBead_nm, yBead_nm, hpolygon.Position(:,1), hpolygon.Position(:,2));

validIdx = (in == 1);
if sum(validIdx) < 5
    error('Insufficient bead points enclosed in the ROI. Please re-run and select a valid bead.');
end

xBead = [xBead_nm(validIdx), framesBead(validIdx)];
yBead = [yBead_nm(validIdx), framesBead(validIdx)];
zBead = [zBead_nm(validIdx), framesBead(validIdx)];

figure(2);
scatter(xBead(:,1), yBead(:,1), 15, 'filled');
title('Selected In-ROI Bead Coordinates');
xlabel('X [nm]'); ylabel('Y [nm]');

%% ---------------- 6. Filter Outlier Localizations ----------------
frameWindow = 50;

% If your workspace includes 'filterlocs.m', it will be used.
% Otherwise, local windowed median/MAD outlier rejection is applied:
if exist('filterlocs', 'file') == 2
    [xBeadFiltered(:,2), xBeadFiltered(:,1)] = filterlocs(xBead(:,2), xBead(:,1), frameWindow, 1, 'x');
    [yBeadFiltered(:,2), yBeadFiltered(:,1)] = filterlocs(yBead(:,2), yBead(:,1), frameWindow, 1, 'y');
    [zBeadFiltered(:,2), zBeadFiltered(:,1)] = filterlocs(zBead(:,2), zBead(:,1), frameWindow, 1, 'z');
else
    filterLocalWindow = @(f, val, w) ...
        deal(f(abs(val - movmedian(val, w, 'Endpoints', 'shrink')) <= 3 * movmad(val, w, 'Endpoints', 'shrink')), ...
             val(abs(val - movmedian(val, w, 'Endpoints', 'shrink')) <= 3 * movmad(val, w, 'Endpoints', 'shrink')));
    
    [xF_frames, xF_vals] = filterLocalWindow(xBead(:,2), xBead(:,1), frameWindow);
    [yF_frames, yF_vals] = filterLocalWindow(yBead(:,2), yBead(:,1), frameWindow);
    [zF_frames, zF_vals] = filterLocalWindow(zBead(:,2), zBead(:,1), frameWindow);
    
    xBeadFiltered = [xF_vals, xF_frames];
    yBeadFiltered = [yF_vals, yF_frames];
    zBeadFiltered = [zF_vals, zF_frames];
end

%% ---------------- 7. Spline Fitting & Drift Estimation -----------
% Smoothing parameters (smaller value = smoother spline)
p_x = 1.0e-7;
p_y = 1.0e-6;
p_z = 0.01;

% Fit cubic smoothing splines[cite: 1]
fidTrackX = csaps(xBeadFiltered(:,2), xBeadFiltered(:,1), p_x);
fidTrackY = csaps(yBeadFiltered(:,2), yBeadFiltered(:,1), p_y);
fidTrackZ = csaps(zBeadFiltered(:,2), zBeadFiltered(:,1), p_z);

% Visual validation of spline trajectories[cite: 1]
figure(3);
subplot(3,1,1);
fnplt(fidTrackX, 'r'); hold on;
scatter(xBeadFiltered(:,2), xBeadFiltered(:,1), 10, 'k.');
ylabel('X [nm]'); title('Fiducial Bead Drift Tracks');

subplot(3,1,2);
fnplt(fidTrackY, 'g'); hold on;
scatter(yBeadFiltered(:,2), yBeadFiltered(:,1), 10, 'k.');
ylabel('Y [nm]');

subplot(3,1,3);
fnplt(fidTrackZ, 'b'); hold on;
scatter(zBeadFiltered(:,2), zBeadFiltered(:,1), 10, 'k.');
xlabel('Frame [#]'); ylabel('Z [nm]');

% Evaluate drift along all frames of the single-molecule dataset[cite: 1]
beadArrayX = fnval(fidTrackX, frames);
beadArrayY = fnval(fidTrackY, frames);
beadArrayZ = fnval(fidTrackZ, frames);

% Calculate relative shift from initial position[cite: 1]
devBeadX = beadArrayX - beadArrayX(1);
devBeadY = beadArrayY - beadArrayY(1);
devBeadZ = beadArrayZ - beadArrayZ(1);

%% ---------------- 8. Apply Drift Correction ----------------------
xnmDriftCorrected = xnm - devBeadX;
ynmDriftCorrected = ynm - devBeadY;
znmDriftCorrected = znm - devBeadZ;

%% ---------------- 9. Save Corrected CSV & Metadata ---------------
probes = zeros(length(frames), 1);

fmt_DC_SM_Data = table(frames, ...
                       xnmDriftCorrected, ...
                       ynmDriftCorrected, ...
                       znmDriftCorrected, ...
                       photons, ...
                       probes, ...
                       'VariableNames', {'frames', 'x [nm]', 'y [nm]', 'z [nm]', 'photons', 'probes'});

[saveFile, savePath] = uiputfile('*.csv', 'Save Drift Corrected CSV As', 'DriftCorrected_SM.csv');
if isequal(saveFile, 0) || isequal(savePath, 0)
    disp('File save canceled by user.');
else
    outFullPath = fullfile(savePath, saveFile);
    writetable(fmt_DC_SM_Data, outFullPath);
    fprintf('Corrected localization CSV saved: %s\n', outFullPath);
    
    % Save runtime tracking parameters[cite: 1]
    params.smoothingParam_x = p_x;
    params.smoothingParam_y = p_y;
    params.smoothingParam_z = p_z;
    params.frameWindow      = frameWindow;
    params.initialBeadPos_x = xBeadFiltered(1,1);
    params.initialBeadPos_y = yBeadFiltered(1,1);
    params.initialBeadPos_z = zBeadFiltered(1,1);
    params.unit_SM          = unit_SM;
    params.unit_FB          = unit_FB;
    
    matFile = fullfile(savePath, sprintf('params_%s.mat', erase(saveFile, '.csv')));
    save(matFile, 'params');
    fprintf('Tracking parameters saved: %s\n', matFile);
end