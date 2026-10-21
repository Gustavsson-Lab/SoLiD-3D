%% Calibration_Zscan_MCL_PiezoStages
% Code for controlling the MCL stages to take z scans for DHPSF calibration
% Current version: ccamera in continuous mode

% Last modified on Aug 23, 2023 by Siyang Cheng


clear

%% Load MCL stage
% loadlibary(dll name, header file name) : Load a DLL into memory so that MATLAB can call it.
loadlibrary('Madlib', 'Madlib'); 

if (~libisloaded('Madlib'))
	disp('Error: Library did not load correctly');
    return
end

% libfunctions: List the functions available in a DLL
m = libfunctions('Madlib', '-full');
disp('The following functions are availible to use from Madlib')
disp(m)

% calllib: Call a function in a loaded DLL
handle = calllib('Madlib', 'MCL_InitHandle');
if (handle == 0)
	disp('Error: Handle was not initialized correctly');
    cleanup(handle, 1);
    return;
end 

% print out information about the NanoDrive
prInfo = libstruct('ProductInformation'); % external structure
pprInfo = libpointer('ProductInformation', get(prInfo)); % need a pointer to the struct

err = calllib('Madlib', 'MCL_GetProductInfo', pprInfo, handle);
if (err ~= 0)
    message = sprintf('Error: NanoDrive did not correctly get product info. Error code %d', err);
    disp(message);
    clear pprInfo 
    clear prInfo
    cleanup(handle, 1);
    return;
else
    disp('NanoDrive product information:');
    disp(pprInfo.value)
    
end

% check for which axis is valid
prInfo = pprInfo.value; % get the info from the pointer back to the structure
axis_bitmap = prInfo.axis_bitmap; % pull out the axis bitmap

% no longer needed, so delete
clear pprInfo 
clear prInfo

% Use Z axis only for Z scans
% debug
% if (bitand(axis_bitmap, 4) == 4)
%     axis = 3;
%     disp('Using Z axis');
% elseif (bitand(axis_bitmap, 2) == 2)
%     axis = 2;
%     disp('Using Y axis');
% elseif (bitand(axis_bitmap, 1) == 1)
%     axis = 1;
%     disp('Using X axis');
% else
%     disp('Error: No axes are valid');
%     cleanup(handle, 1);
%     return;
% end

axis = 3;
disp('Using Z axis');

calibration = calllib('Madlib', 'MCL_GetCalibration', axis, handle);
calibration

% try reading and writing to the NanoDrive
pos = calllib('Madlib', 'MCL_SingleReadN', axis, handle);
if (pos < 0)
    message = sprintf('Error: NanoDrive did not correctly read position. Error Code %d', pos);
	disp(message);
    cleanup(handle, 1);
    return;
else 
    percent = (pos/calibration)*100;
	message = sprintf('Current position = %f%% of the total range of motion', percent);
	disp(message);	
end

%% Initialize stage position
percent_initial = percent;
% pos = (percent_initial*calibration)/100;
% pos
% pause(1);
% disp('Piezo stage is ready.');% messeage = sprintf('Current position = %f (um)', pos); disp(message);


%% Load Prime 95B camera
cameraRed = daq.createSession('ni'); % create daq session
addAnalogOutputChannel(cameraRed,'Dev1','ao1','Voltage'); % initialize output port
% cameraGreen = daq.createSession('ni'); % create daq session
% addAnalogOutputChannel(cameraGreen,'Dev1','ao0','Voltage'); % initialize output port
lagTime = 0.05; % after each frame [s]
disp('Cameras ready.')


%% Configurate parameters
scanRange = input('Scan range? (um)\n');
stepSize = input('Step size? (um)\n');
nFrames_per_step = input('Number of frames at each z?\n');
exposureTime = input('Camera exposure time? (ms)\n')/1000;


%% Manually refocus the microscope
disp('Please manually focus the microscope. DISABLE THE PFS. When finish, press Enter.')
pause();


%% Aquisition
percent_scanRange = scanRange/calibration*100;
percent_stepSize = stepSize/calibration*100;

% Move the stage to the lowest position
percent_lowest = percent_initial-percent_scanRange/2;
pos = (percent_lowest*calibration)/100;

disp('Start camera aquisition manually now. When finish, press Enter.');
pause();

% Z scan
percent = 0:percent_stepSize:percent_scanRange;
N = length(percent); % Number of Z positions of the scan
stage_pause_period = 3;

for i=1:N
    i
    percent_current = percent_lowest+percent(i);
    pos = (percent_current*calibration)/100;
    pos
    err = calllib('Madlib', 'MCL_SingleWriteN', pos, axis, handle);
    if (err ~= 0)
        message = sprintf('Error: NanoDrive did not correctly write position. Error Code %d', err);
	    disp(message);
        cleanup(handle, 1);
        return;    
    end
    pause(1);
    % pause(stage_pause_period);

    for frameNo = 1:nFrames_per_step
        frameNo
        outputSingleScan(cameraRed,5); % start exposure
        pause(exposureTime); % acquire
        outputSingleScan(cameraRed,0); % finish exposure
        pause(lagTime); % wait
    end
    outputSingleScan(cameraRed,0); % finish exposure

end

% disp('Z scan finished. Stop camera aquisition manually now.');



%% cleanup
cleanup(handle, 0);

function cleanup(handle, errors)
calllib('Madlib', 'MCL_ReleaseHandle', handle);
unloadlibrary('Madlib');
if (errors == 1)
    disp('Exiting');
else
    disp('Program finished without any errors');
end
end
