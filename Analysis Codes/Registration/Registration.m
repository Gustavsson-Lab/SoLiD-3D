
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
% Moving = fliplr(Moving);


%% Settings
[optimizer,metric]=imregconfig('Multimodal');
optimizer.InitialRadius = 0.002;
optimizer.Epsilon = 1e-20;
optimizer.GrowthFactor = 1.0001;
optimizer.MaximumIterations = 5000;

  NumberOfSpatialSamples=500;
     NumberOfHistogramBins=50;
              UseAllPixels=1;

%% Transform
tform = imregtform(Moving, Fixed, 'affine', optimizer, metric);
movingRegistered = imwarp(Moving,tform,'OutputView',imref2d(size(Fixed)));

%%
figure
imshowpair(movingRegistered,Fixed,'Scaling','Independent');

% %%
% %%Save tform
% save ('Z:\ag134\JOSHI\Project\lightsheet_super_res\multicolor\Registration\tform.mat')

% Ask user where to save
[file, path] = uiputfile('*.mat', 'Save transformation file as');

if isequal(file,0)
    disp('❌ Save cancelled by user.');
else
    save(fullfile(path, file), 'tform');
    disp(['✅ File saved at: ', fullfile(path, file)]);
end
