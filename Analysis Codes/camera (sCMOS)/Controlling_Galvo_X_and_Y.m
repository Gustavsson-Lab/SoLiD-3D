   %wriclear; clc; 
%checking to see if daq board is initialized
if exist('iniwrite()') 
else
    init = 0; 
end

%if daq board not initialized/galvo is not connected, then
%initialize/connect

%% 
% Galvo XX and YY - Green LS
% Galvo X and Y - Red LS

if init == 0
    
    disp('Connecting devices...')
    galvoY = daq('ni');
    addoutput(galvoY,'Dev1','ao1','Voltage');
    disp('galvoX connected');
    galvoX = daq('ni');
    addoutput(galvoX,'Dev1','ao0','Voltage');
    disp('galvoY connected');

    galvoYY = daq('ni');
    addoutput(galvoYY,'Dev1','ao2','Voltage');
    disp('galvoYY connected');
    galvoXX = daq('ni');
    addoutput(galvoXX,'Dev1','ao3','Voltage');
    disp('galvoXX connected');
    
    init = 1; 
end

%moving galvoX using write function (value is how many volts are being
%sent)
%galvoX.Rate = 1000; 
%x = 0:0.001:2*pi;
%y = (x);
%outputData = y';
write(galvoY,0)
write(galvoX,0)
write(galvoYY,0)
write(galvoXX,0)

%moving galvoY using write function (value is how many volts are being
%sent)
%galvoY.Rate = 1000;
%x = 0:0.001:2*pi;
%y = (x);
% %outputData = y';
% write(galvoY, 0)
 