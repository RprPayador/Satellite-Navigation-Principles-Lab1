% 卫星误差分析脚本
% 读取 coordinates.txt 和 SP3 文件，计算并绘制误差

clc; clear; close all;

%% 1. 设置参数
target_prn = 'G09';  % 要分析的卫星
sp3_file = 'WUM0MGXFIN_20193350000_01D_15M_ORB.SP3';
brd_file = 'coordinates.txt';

%% 2. 读取广播星历计算结果 (coordinates.txt)
fprintf('正在读取 %s ...\n', brd_file);
fid = fopen(brd_file, 'r');
if fid == -1
    error('无法打开文件 %s', brd_file);
end

% 跳过第一行表头
fgetl(fid);

brd_t = [];
brd_pos = []; % [x, y, z]
brd_t_toe = [];  % t-toe时间差

while ~feof(fid)
    line = fgetl(fid);
    if isempty(line), continue; end
    
    % 解析行: PRN t X Y Z t_minus_toe
    C = textscan(line, '%s %f %f %f %f %f');
    if isempty(C{1}), continue; end
    
    prn = C{1}{1};
    if strcmp(prn, target_prn)
        t = C{2};
        x = C{3};
        y = C{4};
        z = C{5};
        t_toe = C{6};  % |t - TOE|
        
        brd_t = [brd_t; t];
        brd_pos = [brd_pos; x, y, z];
        brd_t_toe = [brd_t_toe; t_toe];
    end
end
fclose(fid);

fprintf('广播星历: 找到 %d 个 %s 的数据点\n', length(brd_t), target_prn);

%% 3. 读取SP3精密星历
fprintf('正在读取 %s ...\n', sp3_file);
fid = fopen(sp3_file, 'r');
if fid == -1
    error('无法打开文件 %s', sp3_file);
end

sp3_t = [];
sp3_pos = []; % [x, y, z] (米)
current_time = -1;

while ~feof(fid)
    line = fgetl(fid);
    if isempty(line), continue; end
    
    if startswith(line, '*')
        % 历元行: *  2019 12  1  0  0  0.00000000
        [year, month, day, hour, minute, second] = strread(line(2:end), '%d %d %d %d %d %f');
        current_time = hour * 3600 + minute * 60 + second;
    elseif startswith(line, 'P')
        % 卫星行: PC01 -32319.475268 ...
        % PRN位置: line(2:4) -> "C01"
        prn_str = line(2:4);
        
        if strcmp(prn_str, target_prn) && current_time ~= -1
            % 解析坐标 (km 转 m)
            % 格式是固定列宽，但也通常可以用空格分割解析
            % PC01 xxxxx yyyyy zzzzz ccccc
            vals = sscanf(line(5:end), '%f %f %f');
            if length(vals) >= 3
                x_m = vals(1) * 1000;
                y_m = vals(2) * 1000;
                z_m = vals(3) * 1000;
                
                sp3_t = [sp3_t; current_time];
                sp3_pos = [sp3_pos; x_m, y_m, z_m];
            end
        end
    end
end
fclose(fid);

fprintf('精密星历: 找到 %d 个 %s 的数据点\n', length(sp3_t), target_prn);

%% 4. 生成对比数据
error_data = [];  % [t, dx, dy, dz, d3d, t_toe]
for i = 1:length(sp3_t)
    t_check = sp3_t(i);
    idx = find(abs(brd_t - t_check) < 0.1);
    if ~isempty(idx)
        idx = idx(1);
        diff = brd_pos(idx, :) - sp3_pos(i, :);
        error_data = [error_data; t_check, diff, norm(diff), brd_t_toe(idx)];
    end
end

% 把t-toe四舍五入到最近的15分钟(900秒)倍数
error_data(:, 6) = round(error_data(:, 6) / 900) * 900;

fprintf('共生成 %d 个对比点\n', size(error_data, 1));

%% 5. 绑图
if isempty(error_data)
    warning('没有找到重叠的时间点');
else
    figure('Name', ['Error Analysis: ' target_prn], 'Color', 'w');
    t_hours = error_data(:, 1) / 3600;
    t_toe_sec = error_data(:, 6);  % |t - TOE|
    
    % 用t-toe来判断TOE点：t-toe < 60秒的认为是接近TOE的点
    toe_idx = find(t_toe_sec < 60);
    non_toe_idx = find(t_toe_sec >= 60);
    
    % 子图1: XYZ误差
    subplot(2, 1, 1);
    plot(t_hours, error_data(:, 2), 'r-', 'HandleVisibility', 'off'); hold on;
    plot(t_hours, error_data(:, 3), 'g-', 'HandleVisibility', 'off');
    plot(t_hours, error_data(:, 4), 'b-', 'HandleVisibility', 'off');
    % 空心点
    plot(t_hours(non_toe_idx), error_data(non_toe_idx, 2), 'ro', 'MarkerSize', 5, 'DisplayName', 'dX');
    plot(t_hours(non_toe_idx), error_data(non_toe_idx, 3), 'go', 'MarkerSize', 5, 'DisplayName', 'dY');
    plot(t_hours(non_toe_idx), error_data(non_toe_idx, 4), 'bo', 'MarkerSize', 5, 'DisplayName', 'dZ');
    % 实心点(TOE)
    if ~isempty(toe_idx)
        plot(t_hours(toe_idx), error_data(toe_idx, 2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');
        plot(t_hours(toe_idx), error_data(toe_idx, 3), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'HandleVisibility', 'off');
        plot(t_hours(toe_idx), error_data(toe_idx, 4), 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'HandleVisibility', 'off');
        plot(NaN, NaN, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'DisplayName', 't≈TOE');
    end
    grid on; legend('show', 'Location', 'best');
    title([target_prn ' XYZ Axis Error']);
    xlabel('Time (hours)'); ylabel('Error (m)');
    
    % 子图2: 3D误差
    subplot(2, 1, 2);
    plot(t_hours, error_data(:, 5), 'k-', 'HandleVisibility', 'off'); hold on;
    plot(t_hours(non_toe_idx), error_data(non_toe_idx, 5), 'ks', 'MarkerSize', 5, 'DisplayName', '3D Error');
    if ~isempty(toe_idx)
        plot(t_hours(toe_idx), error_data(toe_idx, 5), 'ks', 'MarkerSize', 8, 'MarkerFaceColor', 'm', 'DisplayName', 't≈TOE');
    end
    grid on; legend('show', 'Location', 'best');
    title([target_prn ' 3D Position Error']);
    xlabel('Time (hours)'); ylabel('Error (m)');
    
    % 输出一些统计
    max_err = max(error_data(:, 5));
    mean_err = mean(error_data(:, 5));
    rms_err = rms(error_data(:, 5));
    
    fprintf('统计结果 (%s):\n', target_prn);
    fprintf('  MAX Error: %.3f m\n', max_err);
    fprintf('  MEAN Error: %.3f m\n', mean_err);
    fprintf('  RMS Error: %.3f m\n', rms_err);
    
    % 新增: t-toe vs 误差散点图
    figure('Name', ['t-TOE vs Error: ' target_prn], 'Color', 'w');
    t_toe_hours = error_data(:, 6) / 3600;  % 转换为小时
    scatter(t_toe_hours, error_data(:, 5), 50, 'b', 'filled', 'MarkerFaceAlpha', 0.6);
    grid on;
    xlabel('|t - TOE| (hours)');
    ylabel('3D Error (m)');
    title([target_prn ' Error vs Time from TOE']);
    
    % 按t-toe分组计算平均误差
    hold on;
    t_toe_sec = error_data(:, 6);
    unique_t_toe = unique(t_toe_sec);
    avg_errors = zeros(length(unique_t_toe), 1);
    for k = 1:length(unique_t_toe)
        idx = t_toe_sec == unique_t_toe(k);
        avg_errors(k) = mean(error_data(idx, 5));
    end
    
    % 排序后画折线
    [sorted_t, sort_idx] = sort(unique_t_toe);
    plot(sorted_t/3600, avg_errors(sort_idx), 'r-o', 'LineWidth', 2, 'MarkerFaceColor', 'r');
    legend('Data', 'Mean', 'Location', 'best');
end

% 辅助函数
function b = startswith(str, pattern)
    b = strncmp(str, pattern, length(pattern));
end
