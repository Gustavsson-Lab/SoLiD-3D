clc; clear; close all;

%% === STEP 1: Select EXACTLY THREE CSV / Excel files ===
[files, path] = uigetfile({'*.csv;*.xlsx','CSV or Excel files'}, ...
                          'Select EXACTLY THREE files', ...
                          'MultiSelect','on');

if isequal(files,0)
    disp('❌ File selection canceled.');
    return;
end

if ischar(files) || numel(files) ~= 3
    error('❌ Please select EXACTLY three files.');
end

disp('📄 Files selected:');
disp(files');

%% === STEP 2: Read data ===
data = cell(3,1);
for i = 1:3
    data{i} = readtable(fullfile(path, files{i}));
end

%% === STEP 3: Fixed column names ===
sx = 'std_x_nm';   sy = 'std_y_nm';   sz = 'std_z_nm';
ex = 'err_x_nm';   ey = 'err_y_nm';   ez = 'err_z_nm';

labels = erase(files, {'.csv','.xlsx'});

%% === Colors (automatic but consistent) ===
colors = lines(3);

%% =====================================================
% %% === STEP 4: X with shaded error ===
% figure; hold on; box on;
% 
% h = gobjects(3,1);   % store line handles
% 
% for i = 1:3
%     N = height(data{i});
%     x = (1:N) - (N+1)/2;
% 
%     y   = data{i}.(sx);
%     eyv = data{i}.(ex);
% 
%     % Shaded error (HIDDEN from legend)
%     fill([x fliplr(x)], ...
%          [y-eyv; flipud(y+eyv)]', ...
%          colors(i,:), ...
%          'FaceAlpha',0.25, ...
%          'EdgeColor','none', ...
%          'HandleVisibility','off');
% 
%     % Mean line (USED in legend)
%     h(i) = plot(x, y, ...
%         'LineWidth',1.8, ...
%         'Color',colors(i,:));
% end
% 
% xlabel('Centered row index');
% ylabel('\sigma_x (nm)');
% title('X localization precision comparison');
% legend(h, labels, 'Interpreter','none', 'Location','best');
% grid off;
% % xline(0,'--k','Center');
% ylim([0 50])
% %% =====================================================
% figure; hold on; box on;
% 
% h = gobjects(3,1);
% 
% for i = 1:3
%     N = height(data{i});
%     x = (1:N) - (N+1)/2;
% 
%     y   = data{i}.(sy);
%     eyv = data{i}.(ey);
% 
%     % Shaded error (hidden from legend)
%     fill([x fliplr(x)], ...
%          [y-eyv; flipud(y+eyv)]', ...
%          colors(i,:), ...
%          'FaceAlpha',0.25, ...
%          'EdgeColor','none', ...
%          'HandleVisibility','off');
% 
%     % Mean line (used for legend)
%     h(i) = plot(x, y, ...
%         'LineWidth',1.8, ...
%         'Color',colors(i,:));
% end
% 
% xlabel('Centered row index');
% ylabel('\sigma_y (nm)');
% title('Y localization precision comparison');
% legend(h, labels, 'Interpreter','none', 'Location','best');
% grid on;
% % xline(0,'--k','Center');
% ylim([0 50])
% 

% %% =====================================================
% figure; hold on; box on;
% 
% h = gobjects(3,1);
% 
% for i = 1:3
%     N = height(data{i});
%     x = (1:N) - (N+1)/2;
% 
%     y   = data{i}.(sz);
%     eyv = data{i}.(ez);
% 
%     % Shaded error (hidden from legend)
%     fill([x fliplr(x)], ...
%          [y-eyv; flipud(y+eyv)]', ...
%          colors(i,:), ...
%          'FaceAlpha',0.25, ...
%          'EdgeColor','none', ...
%          'HandleVisibility','off');
% 
%     % Mean line (used for legend)
%     h(i) = plot(x, y, ...
%         'LineWidth',1.8, ...
%         'Color',colors(i,:));
% end
% 
% xlabel('Centered row index');
% ylabel('\sigma_z (nm)');
% title('Z localization precision comparison');
% legend(h, labels, 'Interpreter','none', 'Location','best');
% grid off;
% % xline(0,'--k','Center');
% ylim([0 80])
% 
% 
% xlim([-10 10])
% ylim([4 30])

%% === STEP 4: X with shaded error (SMOOTHED + CENTERED) ===
figure; hold on; box on;

h = gobjects(3,1);           % handles for legend
w = 5;                       % smoothing window (odd number recommended)

for i = 1:3
    % Centered x-axis
    N = height(data{i});
    x = (1:N) - (N+1)/2;

    % Raw data
    y   = data{i}.(sx);
    eyv = data{i}.(ex);

    % === Smoothing ===
    y_s  = smoothdata(y,  'movmean', w);
    ey_s = smoothdata(eyv,'movmean', w);

    % === Shaded error (hidden from legend) ===
    fill([x fliplr(x)], ...
         [y_s-ey_s; flipud(y_s+ey_s)]', ...
         colors(i,:), ...
         'FaceAlpha',0.25, ...
         'EdgeColor','none', ...
         'HandleVisibility','off');

    % === Smoothed mean curve (legend entry) ===
    h(i) = plot(x, y_s, ...
        'LineWidth',2.0, ...
        'Color',colors(i,:));
end

xlabel('Centered row index');
ylabel('\sigma_x (nm)');
title('X localization precision comparison');
legend(h, labels, 'Interpreter','none', 'Location','best');
% grid on;
xline(0,'--k','Center');
ylim([0 40])


figure; hold on; box on;

h = gobjects(3,1);
w = 3;

for i = 1:3
    N = height(data{i});
    x = (1:N) - (N+1)/2;

    y   = data{i}.(sy);
    eyv = data{i}.(ey);

    % Smoothing
    y_s  = smoothdata(y,  'movmean', w);
    ey_s = smoothdata(eyv,'movmean', w);

    % Shaded error
    fill([x fliplr(x)], ...
         [y_s-ey_s; flipud(y_s+ey_s)]', ...
         colors(i,:), ...
         'FaceAlpha',0.25, ...
         'EdgeColor','none', ...
         'HandleVisibility','off');

    % Mean curve
    h(i) = plot(x, y_s, ...
        'LineWidth',2.0, ...
        'Color',colors(i,:));
end

xlabel('Centered row index');
ylabel('\sigma_y (nm)');
title('Y localization precision comparison');
legend(h, labels, 'Interpreter','none', 'Location','best');
% grid on;
xline(0,'--k','Center');
ylim([0 50])




figure; hold on; box on;

h = gobjects(3,1);
w = 3;

for i = 1:3
    N = height(data{i});
    x = (1:N) - (N+1)/2;

    y   = data{i}.(sz);
    eyv = data{i}.(ez);

    % Smoothing
    y_s  = smoothdata(y,  'movmean', w);
    ey_s = smoothdata(eyv,'movmean', w);

    % Shaded error
    fill([x fliplr(x)], ...
         [y_s-ey_s; flipud(y_s+ey_s)]', ...
         colors(i,:), ...
         'FaceAlpha',0.25, ...
         'EdgeColor','none', ...
         'HandleVisibility','off');

    % Mean curve
    h(i) = plot(x, y_s, ...
        'LineWidth',2.0, ...
        'Color',colors(i,:));
end

xlabel('Centered row index');
ylabel('\sigma_z (nm)');
title('Z localization precision comparison');
legend(h, labels, 'Interpreter','none', 'Location','best');
% grid on;
xline(0,'--k','Center');
ylim([0 80])
