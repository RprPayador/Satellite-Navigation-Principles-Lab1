% 卫星误差分析脚本
% 读取 coordinates.txt 和 SP3 文件，计算并绘制误差

clc; clear; close all;

%% 1. 设置参数
target_prn = 'C01';  % 要分析的卫星
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

while ~feof(fid)
    line = fgetl(fid);
    if isempty(line), continue; end
    
    % 解析行: PRN t X Y Z ...
    % 示例: C01 0.00000000 -32319483.79 ...
    C = textscan(line, '%s %f %f %f %f %f');
    if isempty(C{1}), continue; end
    
    prn = C{1}{1};
    if strcmp(prn, target_prn)
        t = C{2};
        x = C{3};
        y = C{4};
        z = C{5};
        
        brd_t = [brd_t; t];
        brd_pos = [brd_pos; x, y, z];
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
% 策略：遍历SP3的每个时间点，在广播星历中找完全匹配的时间点
% (因为SP3点少且精确，广播星历点多)

error_data = []; % [t, dx, dy, dz, d3d]
valid_sp3_t = [];

for i = 1:length(sp3_t)
    t_check = sp3_t(i);
    
    % 在广播星历数据中查找匹配的时间 (允许微小误差，例如0.1秒)
    idx = find(abs(brd_t - t_check) < 0.1);
    
    if ~isempty(idx)
        % 找到了
        idx = idx(1); % 取第一个匹配的
        
        pos_brd = brd_pos(idx, :);
        pos_sp3 = sp3_pos(i, :);
        
        diff = pos_brd - pos_sp3;
        dist = norm(diff);
        
        error_data = [error_data; t_check, diff, dist];
    end
end

fprintf('共生成 %d 个对比点\n', size(error_data, 1));

%% 5. 绘图
if isempty(error_data)
    warning('没有找到重叠的时间点，无法绘图。请检查时间范围是否匹配。');
else
    figure('Name', ['Error Analysis: ' target_prn], 'Color', 'w');
    
    t_hours = error_data(:, 1) / 3600;
    
    % 子图1: XYZ 误差
    subplot(2, 1, 1);
    plot(t_hours, error_data(:, 2), 'r-o', 'DisplayName', 'dX'); hold on;
    plot(t_hours, error_data(:, 3), 'g-o', 'DisplayName', 'dY');
    plot(t_hours, error_data(:, 4), 'b-o', 'DisplayName', 'dZ');
    grid on;
    legend('show');
    title([target_prn ' XYZ Axis Error']);
    xlabel('Time (hours)');
    ylabel('Error (m)');
    
    % 子图2: 3D 距离误差
    subplot(2, 1, 2);
    plot(t_hours, error_data(:, 5), 'k-s', 'LineWidth', 1.5);
    grid on;
    title([target_prn ' 3D Position Error']);
    xlabel('Time (hours)');
    ylabel('Error (m)');
    
    % 输出一些统计
    max_err = max(error_data(:, 5));
    mean_err = mean(error_data(:, 5));
    rms_err = rms(error_data(:, 5));
    
    fprintf('统计结果 (%s):\n', target_prn);
    fprintf('  MAX Error: %.3f m\n', max_err);
    fprintf('  MEAN Error: %.3f m\n', mean_err);
    fprintf('  RMS Error: %.3f m\n', rms_err);
end

% 辅助函数
function b = startswith(str, pattern)
    b = strncmp(str, pattern, length(pattern));
end
