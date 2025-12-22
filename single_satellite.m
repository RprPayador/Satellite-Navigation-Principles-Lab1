% ==================== 修正版 MATLAB卫星轨迹绘图脚本 ====================
% 专门针对你的数据格式

clear all; close all; clc;

%% 1. 读取数据文件
filename = 'coordinates.txt';  % 你的数据文件名
fprintf('正在读取文件: %s\n', filename);

% 由于文件格式特殊，使用更灵活的读取方式
fid = fopen(filename, 'r');
if fid == -1
    error('无法打开文件: %s', filename);
end
% 读取文件头（只有2行，不是3行！）
header1 = fgetl(fid);  % 第1行：PRN ...
header2 = fgetl(fid);  % 第2行：可能是空行或分割线
fprintf('文件头行1: %s\n', header1);

% 检查第2行是否是分隔线或空行
if contains(header2, '===') || contains(header2, '---') || isempty(strtrim(header2))
    fprintf('文件头行2: %s (分隔线)\n', header2);
    % 如果有第3行作为真正的数据开始
    data_start_line = fgetl(fid);
else
    % 第2行可能就是数据
    data_start_line = header2;
end

% 初始化存储所有数据的容器
all_data = {};

% 先读取data_start_line（可能是第一个数据行）
if ~isempty(data_start_line)
    all_data{end+1} = data_start_line;
end

% 继续读取剩余数据
while ~feof(fid)
    line = fgetl(fid);
    if ~isempty(strtrim(line))  % 忽略空行
        all_data{end+1} = line;
    end
end
fclose(fid);

fprintf('读取到 %d 行数据\n', length(all_data));

%% 2. 解析卫星数据（支持G和C卫星）
fprintf('\n解析卫星数据...\n');

% 初始化存储不同卫星数据的容器
satellite_data = struct();

for i = 1:length(all_data)
    line = all_data{i};
    
    % 检查是否为卫星数据行（以G或C开头）
    if startsWith(line, 'G') || startsWith(line, 'C')
        % 使用更灵活的正则表达式解析数据
        % 匹配模式：卫星PRN 时间 X Y Z toe
        tokens = regexp(line, ...
            '^([GC][0-9]+)\s+([0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([0-9.]+)$', ...
            'tokens');
        
        if isempty(tokens)
            % 尝试另一种格式（可能有更多空格）
            tokens = regexp(line, ...
                '^([GC][0-9]+)\s+([0-9.]+)\s+([-0-9.eE+]+)\s+([-0-9.eE+]+)\s+([-0-9.eE+]+)\s+([0-9.]+)$', ...
                'tokens');
        end
        
        if ~isempty(tokens)
            tokens = tokens{1};
            
            % 提取数据
            prn = tokens{1};  % 卫星PRN，如'G01'或'C01'
            time_val = str2double(tokens{2});
            X_val = str2double(tokens{3});
            Y_val = str2double(tokens{4});
            Z_val = str2double(tokens{5});
            toe_val = str2double(tokens{6});
            
            % 初始化该卫星的数据结构（如果不存在）
            if ~isfield(satellite_data, prn)
                satellite_data.(prn).time = [];
                satellite_data.(prn).X = [];
                satellite_data.(prn).Y = [];
                satellite_data.(prn).Z = [];
                satellite_data.(prn).toe = [];
            end
            
            % 存储数据
            satellite_data.(prn).time = [satellite_data.(prn).time; time_val];
            satellite_data.(prn).X = [satellite_data.(prn).X; X_val];
            satellite_data.(prn).Y = [satellite_data.(prn).Y; Y_val];
            satellite_data.(prn).Z = [satellite_data.(prn).Z; Z_val];
            satellite_data.(prn).toe = [satellite_data.(prn).toe; toe_val];
        else
            fprintf('警告: 无法解析第 %d 行: %s\n', i, line);
        end
    end
end

% 显示找到的卫星信息
satellite_names = fieldnames(satellite_data);
fprintf('\n找到 %d 颗卫星的数据:\n', length(satellite_names));
for i = 1:length(satellite_names)
    prn = satellite_names{i};
    n_points = length(satellite_data.(prn).time);
    fprintf('  %s: %d 个数据点\n', prn, n_points);
end

%% 3. 选择要绘制的卫星
% 你可以在这里修改要绘制的卫星PRN
target_sat = 'C01';  % 默认绘制G01
if ~isfield(satellite_data, target_sat)
    fprintf('\n警告: 未找到卫星 %s\n', target_sat);
    fprintf('可用的卫星: %s\n', strjoin(satellite_names, ', '));
    
    % 如果有其他卫星，选择第一个
    if ~isempty(satellite_names)
        target_sat = satellite_names{1};
        fprintf('将绘制卫星: %s\n', target_sat);
    else
        error('没有找到任何卫星数据！');
    end
end

% 提取目标卫星数据
g01_time = satellite_data.(target_sat).time;
g01_X = satellite_data.(target_sat).X;
g01_Y = satellite_data.(target_sat).Y;
g01_Z = satellite_data.(target_sat).Z;
g01_toe = satellite_data.(target_sat).toe;

fprintf('\n正在绘制卫星: %s\n', target_sat);
fprintf('数据点数: %d\n', length(g01_time));

%% 4. 计算轨道参数
if length(g01_time) < 2
    error('卫星 %s 数据点不足，至少需要2个点', target_sat);
end

fprintf('\n计算轨道参数...\n');

% 计算地心距离
distance = sqrt(g01_X.^2 + g01_Y.^2 + g01_Z.^2);
mean_distance = mean(distance);
max_distance = max(distance);
min_distance = min(distance);

fprintf('轨道高度统计:\n');
fprintf('  平均地心距离: %.2f km\n', mean_distance/1000);
fprintf('  最大地心距离: %.2f km\n', max_distance/1000);
fprintf('  最小地心距离: %.2f km\n', min_distance/1000);
fprintf('  轨道高度(减去地球半径): %.2f km\n', (mean_distance - 6371000)/1000);

% 计算速度（近似）
dt = diff(g01_time);
dX = diff(g01_X);
dY = diff(g01_Y);
dZ = diff(g01_Z);
velocity = sqrt((dX./dt).^2 + (dY./dt).^2 + (dZ./dt).^2);
mean_velocity = mean(velocity);

fprintf('平均速度: %.2f km/s\n', mean_velocity/1000);

%% 5. 绘制3D轨道图
figure('Position', [100, 100, 1400, 500], 'Name', sprintf('%s卫星轨道分析', target_sat));

% 子图1: 3D轨道
subplot(1,3,1);

% 绘制地球（简化版）
[xx, yy, zz] = sphere(30);
R_earth = 6371000;  % 地球半径，单位：m
surf(xx*R_earth, yy*R_earth, zz*R_earth, ...
    'FaceColor', [0.2 0.6 1.0], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.3);
hold on;

% 绘制卫星轨道
plot3(g01_X, g01_Y, g01_Z, 'r-', 'LineWidth', 2);

% 按时间着色显示轨迹点
scatter3(g01_X, g01_Y, g01_Z, 30, g01_time, 'filled');
colorbar;
colormap jet;
caxis([min(g01_time), max(g01_time)]);
ylabel(colorbar, '时间 (秒)');

% 标记起始点和结束点
plot3(g01_X(1), g01_Y(1), g01_Z(1), ...
    'o', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
plot3(g01_X(end), g01_Y(end), g01_Z(end), ...
    's', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');

% 添加坐标轴
plot3([-3e7, 3e7], [0, 0], [0, 0], 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
plot3([0, 0], [-3e7, 3e7], [0, 0], 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
plot3([0, 0], [0, 0], [-3e7, 3e7], 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');

% 设置图形属性
xlabel('X (m)', 'FontSize', 11);
ylabel('Y (m)', 'FontSize', 11);
zlabel('Z (m)', 'FontSize', 11);
title(sprintf('%s卫星3D轨道轨迹', target_sat), 'FontSize', 12);
legend({'地球', '轨道', '起始点', '结束点'}, 'Location', 'best');
grid on;
axis equal;
view(45, 30);
xlim([-3e7, 3e7]);
ylim([-3e7, 3e7]);
zlim([-3e7, 3e7]);

%% 子图2: 地心距离随时间变化
subplot(1,3,2);

plot(g01_time/3600, distance/1000, 'b-', 'LineWidth', 2);
hold on;

% 标记地球半径
plot([min(g01_time/3600), max(g01_time/3600)], [6371, 6371], ...
    'r--', 'LineWidth', 1.5, 'DisplayName', '地球表面');

% 标记平均轨道高度
avg_altitude = mean_distance/1000;
plot([min(g01_time/3600), max(g01_time/3600)], [avg_altitude, avg_altitude], ...
    'g--', 'LineWidth', 1.5, 'DisplayName', sprintf('平均高度: %.0f km', avg_altitude));

xlabel('时间 (小时)', 'FontSize', 11);
ylabel('地心距离 (km)', 'FontSize', 11);
title('轨道高度变化', 'FontSize', 12);
legend('Location', 'best');
grid on;
xlim([min(g01_time/3600), max(g01_time/3600)]);

% 添加高度差信息
text(0.05, 0.95, sprintf('高度变化范围:\n%.0f - %.0f km', ...
    min_distance/1000, max_distance/1000), ...
    'Units', 'normalized', 'FontSize', 10, ...
    'VerticalAlignment', 'top', 'BackgroundColor', 'w');

%% 子图3: 轨道参数分析
subplot(1,3,3);

% 绘制速度变化
plot(g01_time(2:end)/3600, velocity/1000, 'm-', 'LineWidth', 2);
hold on;

% 绘制TOE时间差
plot(g01_time/3600, abs(g01_toe)/3600, 'k-', 'LineWidth', 1.5);

xlabel('时间 (小时)', 'FontSize', 11);
ylabel('速度 (km/s) / TOE差 (小时)', 'FontSize', 11);
title('速度和TOE时间差', 'FontSize', 12);
legend({'卫星速度', '|t-TOE|'}, 'Location', 'best');
grid on;
xlim([min(g01_time/3600), max(g01_time/3600)]);

% 添加统计信息
text(0.05, 0.95, sprintf('速度统计:\n平均: %.2f km/s\n最大: %.2f km/s\n最小: %.2f km/s', ...
    mean_velocity/1000, max(velocity)/1000, min(velocity)/1000), ...
    'Units', 'normalized', 'FontSize', 10, ...
    'VerticalAlignment', 'top', 'BackgroundColor', 'w');

%% 6. 额外绘制XY平面投影图
figure('Position', [100, 100, 1000, 800], 'Name', sprintf('%s卫星轨道投影', target_sat));

% 地球投影
theta = linspace(0, 2*pi, 100);
plot(cos(theta)*R_earth, sin(theta)*R_earth, ...
    'Color', [0.2 0.6 1.0], 'LineWidth', 2);
hold on;

% 卫星轨道投影
plot(g01_X, g01_Y, 'r-', 'LineWidth', 2);

% 按时间着色
scatter(g01_X, g01_Y, 30, g01_time, 'filled');
colorbar;
colormap jet;
caxis([min(g01_time), max(g01_time)]);
ylabel(colorbar, '时间 (秒)');

% 标记特殊点
plot(g01_X(1), g01_Y(1), 'o', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'DisplayName', '起始点');
plot(g01_X(end), g01_Y(end), 's', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'DisplayName', '结束点');

xlabel('X (m)', 'FontSize', 12);
ylabel('Y (m)', 'FontSize', 12);
title(sprintf('%s卫星轨道在XY平面投影', target_sat), 'FontSize', 14);
legend('Location', 'best');
grid on;
axis equal;
xlim([-3e7, 3e7]);
ylim([-3e7, 3e7]);

%% 7. 保存图片
% 保存为PNG文件
output_filename = sprintf('%s_satellite_orbit.png', target_sat);
print(output_filename, '-dpng', '-r300');
fprintf('\n图片已保存为: %s\n', output_filename);

%% 8. 显示数据摘要
fprintf('\n=== %s卫星数据摘要 ===\n', target_sat);
fprintf('时间范围: %.1f - %.1f 秒 (%.2f - %.2f 小时)\n', ...
    min(g01_time), max(g01_time), min(g01_time)/3600, max(g01_time)/3600);
fprintf('计算点间隔: %.1f 秒\n', mean(diff(g01_time)));
fprintf('TOE时间差范围: %.1f - %.1f 秒\n', min(abs(g01_toe)), max(abs(g01_toe)));
fprintf('轨道周期估计: %.2f 小时 (基于速度估算)\n', ...
    2*pi*mean_distance/mean_velocity/3600);