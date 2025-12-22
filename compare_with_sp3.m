% ==================== 广播星历与精密星历误差对比分析 ====================
% 对比 coordinates.txt (广播星历计算结果) 和 SP3 精密星历
% 可视化位置误差随时间的变化

clear all; close all; clc;

%% 1. 读取广播星历计算结果
fprintf('正在读取广播星历计算结果 (coordinates.txt)...\n');
brd_file = 'coordinates.txt';
fid = fopen(brd_file, 'r');
if fid == -1
    error('无法打开文件: %s', brd_file);
end

% 跳过表头
header = fgetl(fid);
fprintf('广播星历文件表头: %s\n', header);

% 读取数据
C = textscan(fid, '%s %f %f %f %f %f', ...
             'Delimiter',' ', 'MultipleDelimsAsOne', 1);
fclose(fid);

brd_prn = strtrim(C{1});
brd_time = C{2};
brd_X = C{3};
brd_Y = C{4};
brd_Z = C{5};

fprintf('广播星历数据点总数: %d\n', length(brd_prn));

%% 2. 读取SP3精密星历文件
fprintf('\n正在读取SP3精密星历文件...\n');
sp3_file = 'WUM0MGXFIN_20193350000_01D_15M_ORB.SP3';
fid = fopen(sp3_file, 'r');
if fid == -1
    error('无法打开SP3文件: %s', sp3_file);
end

% 初始化存储
sp3_data = struct();
current_epoch = [];

while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line), break; end

    % 历元行 (以 * 开头)
    if startsWith(line, '*')
        % 格式: *  2019 12  1  0  0  0.00000000
        tokens = sscanf(line(3:end), '%d %d %d %d %d %f');
        if length(tokens) == 6
            year = tokens(1);
            month = tokens(2);
            day = tokens(3);
            hour = tokens(4);
            minute = tokens(5);
            second = tokens(6);

            % 转换为GPS周内秒 (简化计算，假设从当天0点开始)
            current_epoch = hour*3600 + minute*60 + second;
        end

    % 卫星位置行 (以 P 开头)
    elseif startsWith(line, 'P') && ~isempty(current_epoch)
        prn = strtrim(line(2:4));  % 如 'G01', 'C10'

        % 只处理 GPS 和北斗卫星
        if ~(startsWith(prn, 'G') || startsWith(prn, 'C'))
            continue;
        end

        % 读取坐标 (单位: km)
        coords = sscanf(line(5:end), '%f %f %f %f');
        if length(coords) >= 3
            X_km = coords(1);
            Y_km = coords(2);
            Z_km = coords(3);

            % 转换为米
            X = X_km * 1000;
            Y = Y_km * 1000;
            Z = Z_km * 1000;

            % 初始化卫星数据结构
            if ~isfield(sp3_data, prn)
                sp3_data.(prn).time = [];
                sp3_data.(prn).X = [];
                sp3_data.(prn).Y = [];
                sp3_data.(prn).Z = [];
            end

            % 存储数据
            sp3_data.(prn).time = [sp3_data.(prn).time; current_epoch];
            sp3_data.(prn).X = [sp3_data.(prn).X; X];
            sp3_data.(prn).Y = [sp3_data.(prn).Y; Y];
            sp3_data.(prn).Z = [sp3_data.(prn).Z; Z];
        end
    end
end
fclose(fid);

% 显示SP3数据统计
sp3_satellites = fieldnames(sp3_data);
fprintf('SP3文件中找到 %d 颗卫星\n', length(sp3_satellites));

%% 3. 对比分析
fprintf('\n开始对比分析...\n');

% 找出两个数据集都有的卫星
brd_satellites = unique(brd_prn);
common_sats = intersect(brd_satellites, sp3_satellites);

fprintf('共有 %d 颗卫星同时存在于两个数据集中:\n', length(common_sats));
fprintf('%s\n', strjoin(common_sats', ', '));

% 选择要分析的卫星（可以修改）
if ismember('C01', common_sats)
    target_sats = {'C01'};  % 北斗C01
elseif ismember('G01', common_sats)
    target_sats = {'G01'};  % GPS G01
else
    target_sats = common_sats(1);  % 第一颗
end

% 也可以对比多颗卫星
% target_sats = common_sats(1:min(6, length(common_sats)));  % 前6颗

fprintf('\n将详细分析以下卫星: %s\n', strjoin(target_sats, ', '));

%% 4. 为每颗卫星计算误差并绘图
for sat_idx = 1:length(target_sats)
    sat_prn = target_sats{sat_idx};
    fprintf('\n--- 处理卫星 %s ---\n', sat_prn);

    % 提取广播星历数据
    brd_idx = strcmp(brd_prn, sat_prn);
    brd_t = brd_time(brd_idx);
    brd_x = brd_X(brd_idx);
    brd_y = brd_Y(brd_idx);
    brd_z = brd_Z(brd_idx);

    % 提取SP3数据
    sp3_t = sp3_data.(sat_prn).time;
    sp3_x = sp3_data.(sat_prn).X;
    sp3_y = sp3_data.(sat_prn).Y;
    sp3_z = sp3_data.(sat_prn).Z;

    fprintf('  广播星历数据点: %d\n', length(brd_t));
    fprintf('  SP3精密星历数据点: %d\n', length(sp3_t));

    % 找到时间重叠区间
    t_min = max(min(brd_t), min(sp3_t));
    t_max = min(max(brd_t), max(sp3_t));

    fprintf('  时间重叠区间: %.0f - %.0f 秒 (%.2f - %.2f 小时)\n', ...
        t_min, t_max, t_min/3600, t_max/3600);

    % 在重叠区间内找到共同时间点
    % 由于广播星历是每300s一个点，SP3是每900s一个点
    % 我们以广播星历的时间点为准，插值SP3数据

    valid_brd_idx = (brd_t >= t_min) & (brd_t <= t_max);
    comp_time = brd_t(valid_brd_idx);
    comp_brd_x = brd_x(valid_brd_idx);
    comp_brd_y = brd_y(valid_brd_idx);
    comp_brd_z = brd_z(valid_brd_idx);

    % 插值SP3数据到相同时间点
    comp_sp3_x = interp1(sp3_t, sp3_x, comp_time, 'linear');
    comp_sp3_y = interp1(sp3_t, sp3_y, comp_time, 'linear');
    comp_sp3_z = interp1(sp3_t, sp3_z, comp_time, 'linear');

    % 计算误差
    error_x = comp_brd_x - comp_sp3_x;
    error_y = comp_brd_y - comp_sp3_y;
    error_z = comp_brd_z - comp_sp3_z;
    error_3d = sqrt(error_x.^2 + error_y.^2 + error_z.^2);

    % 统计信息
    fprintf('  3D位置误差统计:\n');
    fprintf('    平均值: %.3f m\n', mean(error_3d));
    fprintf('    中位数: %.3f m\n', median(error_3d));
    fprintf('    最大值: %.3f m\n', max(error_3d));
    fprintf('    最小值: %.3f m\n', min(error_3d));
    fprintf('    标准差: %.3f m\n', std(error_3d));
    fprintf('    RMS:    %.3f m\n', sqrt(mean(error_3d.^2)));

    %% 5. 绘图
    figure('Position', [50 + sat_idx*30, 50 + sat_idx*30, 1400, 900], ...
           'Name', sprintf('%s 广播星历误差分析', sat_prn));

    % 子图1: 3D误差随时间变化
    subplot(3,2,1);
    plot(comp_time/3600, error_3d, 'b-', 'LineWidth', 1.5);
    grid on;
    xlabel('时间 (小时)');
    ylabel('3D位置误差 (m)');
    title(sprintf('%s - 3D位置误差', sat_prn));
    text(0.02, 0.98, sprintf('RMS: %.3f m\n平均: %.3f m\n最大: %.3f m', ...
        sqrt(mean(error_3d.^2)), mean(error_3d), max(error_3d)), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'w', 'FontSize', 9);

    % 子图2: XYZ分量误差
    subplot(3,2,2);
    plot(comp_time/3600, error_x, 'r-', 'LineWidth', 1.2, 'DisplayName', 'X误差');
    hold on;
    plot(comp_time/3600, error_y, 'g-', 'LineWidth', 1.2, 'DisplayName', 'Y误差');
    plot(comp_time/3600, error_z, 'b-', 'LineWidth', 1.2, 'DisplayName', 'Z误差');
    grid on;
    xlabel('时间 (小时)');
    ylabel('坐标分量误差 (m)');
    title('XYZ各分量误差');
    legend('Location', 'best');

    % 子图3: 误差直方图
    subplot(3,2,3);
    histogram(error_3d, 30, 'FaceColor', [0.2 0.6 1]);
    grid on;
    xlabel('3D位置误差 (m)');
    ylabel('频数');
    title('误差分布直方图');

    % 子图4: 3D轨迹对比
    subplot(3,2,4);
    plot3(comp_brd_x/1e6, comp_brd_y/1e6, comp_brd_z/1e6, 'r-', ...
        'LineWidth', 1.5, 'DisplayName', '广播星历');
    hold on;
    plot3(comp_sp3_x/1e6, comp_sp3_y/1e6, comp_sp3_z/1e6, 'b--', ...
        'LineWidth', 1.2, 'DisplayName', 'SP3精密星历');
    grid on;
    xlabel('X (×10^6 m)');
    ylabel('Y (×10^6 m)');
    zlabel('Z (×10^6 m)');
    title('3D轨迹对比');
    legend('Location', 'best');
    view(45, 30);
    axis equal;

    % 子图5: 误差累积分布
    subplot(3,2,5);
    sorted_error = sort(error_3d);
    cdf = (1:length(sorted_error))' / length(sorted_error) * 100;
    plot(sorted_error, cdf, 'b-', 'LineWidth', 2);
    grid on;
    xlabel('3D位置误差 (m)');
    ylabel('累积概率 (%)');
    title('误差累积分布函数 (CDF)');
    % 标注特殊点
    hold on;
    error_50 = sorted_error(find(cdf >= 50, 1));
    error_95 = sorted_error(find(cdf >= 95, 1));
    plot(error_50, 50, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    plot(error_95, 95, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    text(error_50, 50, sprintf(' 50%%: %.2fm', error_50), 'FontSize', 9);
    text(error_95, 95, sprintf(' 95%%: %.2fm', error_95), 'FontSize', 9);

    % 子图6: XY平面误差向量场
    subplot(3,2,6);
    % 为避免过密，只显示部分点
    step = max(1, floor(length(comp_time) / 30));
    quiver(comp_sp3_x(1:step:end)/1e6, comp_sp3_y(1:step:end)/1e6, ...
           error_x(1:step:end), error_y(1:step:end), 0, 'b');
    hold on;
    plot(comp_sp3_x/1e6, comp_sp3_y/1e6, 'k-', 'LineWidth', 0.5);
    grid on;
    xlabel('X (×10^6 m)');
    ylabel('Y (×10^6 m)');
    title('XY平面误差向量');
    axis equal;

    % 保存图片
    output_file = sprintf('%s_error_analysis.png', sat_prn);
    print(output_file, '-dpng', '-r300');
    fprintf('  图片已保存: %s\n', output_file);
end

%% 6. 多卫星对比（如果有多颗）
if length(common_sats) > 1
    fprintf('\n\n=== 多卫星误差统计对比 ===\n');

    figure('Position', [100, 100, 1200, 600], 'Name', '多卫星误差统计对比');

    % 为所有卫星计算RMS误差
    sat_names = {};
    rms_errors = [];
    mean_errors = [];
    max_errors = [];

    for i = 1:length(common_sats)
        sat_prn = common_sats{i};

        % 提取数据
        brd_idx = strcmp(brd_prn, sat_prn);
        brd_t = brd_time(brd_idx);
        brd_x = brd_X(brd_idx);
        brd_y = brd_Y(brd_idx);
        brd_z = brd_Z(brd_idx);

        sp3_t = sp3_data.(sat_prn).time;
        sp3_x = sp3_data.(sat_prn).X;
        sp3_y = sp3_data.(sat_prn).Y;
        sp3_z = sp3_data.(sat_prn).Z;

        % 时间对齐
        t_min = max(min(brd_t), min(sp3_t));
        t_max = min(max(brd_t), max(sp3_t));
        valid_idx = (brd_t >= t_min) & (brd_t <= t_max);

        if sum(valid_idx) < 2
            continue;  % 数据点太少
        end

        comp_time = brd_t(valid_idx);
        comp_brd_x = brd_x(valid_idx);
        comp_brd_y = brd_y(valid_idx);
        comp_brd_z = brd_z(valid_idx);

        % 插值
        comp_sp3_x = interp1(sp3_t, sp3_x, comp_time, 'linear');
        comp_sp3_y = interp1(sp3_t, sp3_y, comp_time, 'linear');
        comp_sp3_z = interp1(sp3_t, sp3_z, comp_time, 'linear');

        % 计算误差
        error_x = comp_brd_x - comp_sp3_x;
        error_y = comp_brd_y - comp_sp3_y;
        error_z = comp_brd_z - comp_sp3_z;
        error_3d = sqrt(error_x.^2 + error_y.^2 + error_z.^2);

        % 统计
        sat_names{end+1} = sat_prn;
        rms_errors(end+1) = sqrt(mean(error_3d.^2));
        mean_errors(end+1) = mean(error_3d);
        max_errors(end+1) = max(error_3d);

        fprintf('%s: RMS=%.3fm, 平均=%.3fm, 最大=%.3fm\n', ...
            sat_prn, rms_errors(end), mean_errors(end), max_errors(end));
    end

    % 绘制柱状图
    subplot(1,2,1);
    bar(rms_errors);
    set(gca, 'XTickLabel', sat_names, 'XTickLabelRotation', 45);
    ylabel('RMS误差 (m)');
    title('各卫星RMS位置误差');
    grid on;

    subplot(1,2,2);
    bar([mean_errors; max_errors]');
    set(gca, 'XTickLabel', sat_names, 'XTickLabelRotation', 45);
    ylabel('误差 (m)');
    title('各卫星平均误差和最大误差');
    legend({'平均误差', '最大误差'}, 'Location', 'best');
    grid on;

    % 保存
    print('all_satellites_error_comparison.png', '-dpng', '-r300');
    fprintf('\n多卫星对比图已保存: all_satellites_error_comparison.png\n');
end

fprintf('\n\n========== 分析完成 ==========\n');
