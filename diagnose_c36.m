% ==================== C36卫星诊断分析脚本 ====================
% 详细分析C36的广播星历参数和计算结果的问题

clear all; close all; clc;

fprintf('========== C36 卫星诊断分析 ==========\n\n');

%% 1. 读取广播星历计算结果
fprintf('1. 读取广播星历计算结果...\n');
fid = fopen('coordinates.txt', 'r');
header = fgetl(fid);
C = textscan(fid, '%s %f %f %f %f %f', 'Delimiter',' ', 'MultipleDelimsAsOne',1);
fclose(fid);

brd_prn = strtrim(C{1});
brd_time = C{2};
brd_X = C{3};
brd_Y = C{4};
brd_Z = C{5};
brd_toe_diff = C{6};

% 提取C36数据
c36_idx = strcmp(brd_prn, 'C36');
c36_time = brd_time(c36_idx);
c36_X = brd_X(c36_idx);
c36_Y = brd_Y(c36_idx);
c36_Z = brd_Z(c36_idx);
c36_toe_diff = brd_toe_diff(c36_idx);

fprintf('   C36数据点数: %d\n', length(c36_time));
fprintf('   时间范围: %.0f - %.0f 秒 (%.2f - %.2f 小时)\n', ...
    min(c36_time), max(c36_time), min(c36_time)/3600, max(c36_time)/3600);

%% 2. 读取SP3精密星历
fprintf('\n2. 读取SP3精密星历...\n');
fid = fopen('WUM0MGXFIN_20193350000_01D_15M_ORB.SP3', 'r');
sp3_time = [];
sp3_X = [];
sp3_Y = [];
sp3_Z = [];
current_epoch = [];

while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line), break; end

    if startsWith(line, '*')
        tokens = sscanf(line(3:end), '%d %d %d %d %d %f');
        if length(tokens) == 6
            current_epoch = tokens(4)*3600 + tokens(5)*60 + tokens(6);
        end
    elseif startsWith(line, 'PC36') && ~isempty(current_epoch)
        coords = sscanf(line(5:end), '%f %f %f %f');
        if length(coords) >= 3
            sp3_time(end+1) = current_epoch;
            sp3_X(end+1) = coords(1) * 1000;  % km -> m
            sp3_Y(end+1) = coords(2) * 1000;
            sp3_Z(end+1) = coords(3) * 1000;
        end
    end
end
fclose(fid);

fprintf('   SP3数据点数: %d\n', length(sp3_time));
fprintf('   时间范围: %.0f - %.0f 秒\n', min(sp3_time), max(sp3_time));

%% 3. 分析TOE时间差异常
fprintf('\n3. 分析TOE时间差 (t-TOE)...\n');

% 找到TOE差的跳变点
toe_diff_change = diff(c36_toe_diff);
jump_idx = find(abs(toe_diff_change) > 1000);  % 跳变超过1000秒

fprintf('   发现 %d 个TOE跳变点:\n', length(jump_idx));
for i = 1:min(10, length(jump_idx))
    idx = jump_idx(i);
    fprintf('     t=%.0fs: TOE差从 %.0fs 跳至 %.0fs (变化 %.0fs)\n', ...
        c36_time(idx), c36_toe_diff(idx), c36_toe_diff(idx+1), toe_diff_change(idx));
end

% 检查是否有超过有效期(7200s)的点
invalid_idx = find(abs(c36_toe_diff) > 7200);
fprintf('   超过2小时有效期的数据点: %d 个\n', length(invalid_idx));
if ~isempty(invalid_idx)
    fprintf('   这些点的时间: ');
    fprintf('%.0f ', c36_time(invalid_idx(1:min(10,end))));
    fprintf('...\n');
end

%% 4. 计算误差
fprintf('\n4. 计算与SP3精密星历的误差...\n');

% 插值到相同时间点
valid_idx = (c36_time >= min(sp3_time)) & (c36_time <= max(sp3_time));
comp_time = c36_time(valid_idx);
comp_brd_X = c36_X(valid_idx);
comp_brd_Y = c36_Y(valid_idx);
comp_brd_Z = c36_Z(valid_idx);
comp_toe_diff = c36_toe_diff(valid_idx);

comp_sp3_X = interp1(sp3_time, sp3_X, comp_time, 'linear');
comp_sp3_Y = interp1(sp3_time, sp3_Y, comp_time, 'linear');
comp_sp3_Z = interp1(sp3_time, sp3_Z, comp_time, 'linear');

% 计算误差
error_X = comp_brd_X - comp_sp3_X;
error_Y = comp_brd_Y - comp_sp3_Y;
error_Z = comp_brd_Z - comp_sp3_Z;
error_3d = sqrt(error_X.^2 + error_Y.^2 + error_Z.^2);

fprintf('   3D位置误差统计:\n');
fprintf('     平均: %.3f m\n', mean(error_3d));
fprintf('     中位数: %.3f m\n', median(error_3d));
fprintf('     最大: %.3f m (在 t=%.0fs)\n', max(error_3d), comp_time(error_3d == max(error_3d)));
fprintf('     最小: %.3f m\n', min(error_3d));
fprintf('     RMS: %.3f m\n', sqrt(mean(error_3d.^2)));

% 找出误差异常大的点
large_error_idx = find(error_3d > 10);  % 误差超过10米
fprintf('   误差超过10米的点: %d 个\n', length(large_error_idx));
if ~isempty(large_error_idx)
    fprintf('   前10个异常点:\n');
    fprintf('     时间(s)  误差(m)  TOE差(s)\n');
    for i = 1:min(10, length(large_error_idx))
        idx = large_error_idx(i);
        fprintf('     %6.0f  %8.2f  %8.0f\n', ...
            comp_time(idx), error_3d(idx), comp_toe_diff(idx));
    end
end

%% 5. 读取RINEX星历参数
fprintf('\n5. 分析RINEX广播星历参数...\n');

% 手动读取C36的所有星历记录
fid = fopen('brdm3350.19p', 'r');
line_text = {};
while ~feof(fid)
    line_text{end+1} = fgetl(fid);
end
fclose(fid);

% 找到所有C36星历记录
c36_ephem = {};
for i = 1:length(line_text)
    if length(line_text{i}) >= 3 && strcmp(line_text{i}(1:3), 'C36')
        ephem_block = line_text(i:min(i+7, length(line_text)));
        c36_ephem{end+1} = ephem_block;
    end
end

fprintf('   找到 %d 个C36星历记录\n', length(c36_ephem));

% 解析每个星历的TOE和关键参数
toe_list = [];
sqrt_a_list = [];
ecc_list = [];
i0_list = [];
omega0_list = [];

for i = 1:length(c36_ephem)
    if length(c36_ephem{i}) >= 8
        % 第一行：时间
        line1 = c36_ephem{i}{1};
        % 第二行包含TOE (第8个参数)
        line2 = c36_ephem{i}{2};

        % 解析TOE (在第2行的第4个数值)
        % 格式复杂，使用正则表达式
        vals = regexp(line2, '[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', 'match');
        if length(vals) >= 4
            toe = str2double(vals{4});
            toe_list(i) = toe;
        end

        % 解析sqrt(a) (在第2行)
        line3 = c36_ephem{i}{3};
        vals3 = regexp(line3, '[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', 'match');
        if length(vals3) >= 4
            sqrt_a_list(i) = str2double(vals3{4});
        end

        % 解析偏心率 (在第2行第3个参数)
        if length(vals) >= 3
            ecc_list(i) = str2double(vals{3});
        end

        % 解析i0 (在第4行第4个参数)
        line5 = c36_ephem{i}{5};
        vals5 = regexp(line5, '[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', 'match');
        if length(vals5) >= 4
            i0_list(i) = str2double(vals5{4});
        end

        % 解析Omega0 (在第4行第2个参数)
        if length(vals5) >= 2
            omega0_list(i) = str2double(vals5{2});
        end
    end
end

fprintf('   星历TOE时刻: ');
fprintf('%.0f ', toe_list);
fprintf('秒\n');

fprintf('   sqrt(A): ');
fprintf('%.6f ', sqrt_a_list);
fprintf('m^0.5\n');

fprintf('   偏心率: ');
fprintf('%.8f ', ecc_list);
fprintf('\n');

% 检查参数异常
fprintf('\n   参数异常检查:\n');
for i = 1:length(toe_list)
    abnormal = [];

    % 检查轨道半径
    a = sqrt_a_list(i)^2;
    if a < 40e6 || a > 50e6  % 正常GEO轨道约42164km
        abnormal{end+1} = sprintf('轨道半径异常(%.0f km)', a/1000);
    end

    % 检查偏心率
    if ecc_list(i) > 0.1
        abnormal{end+1} = sprintf('偏心率过大(%.6f)', ecc_list(i));
    end

    if ~isempty(abnormal)
        fprintf('     TOE=%.0fs: %s\n', toe_list(i), strjoin(abnormal, ', '));
    end
end

%% 6. 可视化
fprintf('\n6. 生成诊断图...\n');

figure('Position', [50, 50, 1600, 900], 'Name', 'C36卫星诊断分析');

% 子图1: 3D轨迹对比
subplot(2,3,1);
plot3(comp_brd_X/1e6, comp_brd_Y/1e6, comp_brd_Z/1e6, 'r-', 'LineWidth', 1.5, 'DisplayName', '广播星历');
hold on;
plot3(comp_sp3_X/1e6, comp_sp3_Y/1e6, comp_sp3_Z/1e6, 'b--', 'LineWidth', 1.2, 'DisplayName', 'SP3精密星历');
% 地球
[xx,yy,zz] = sphere(30);
surf(xx*6.371, yy*6.371, zz*6.371, 'FaceColor', [0.3 0.6 1], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
grid on;
xlabel('X (×10^6 m)');
ylabel('Y (×10^6 m)');
zlabel('Z (×10^6 m)');
title('C36 3D轨迹对比');
legend('Location', 'best');
axis equal;
view(45, 30);

% 子图2: 3D误差随时间
subplot(2,3,2);
plot(comp_time/3600, error_3d, 'b-', 'LineWidth', 1.5);
grid on;
xlabel('时间 (小时)');
ylabel('3D位置误差 (m)');
title(sprintf('C36位置误差 (RMS=%.2fm)', sqrt(mean(error_3d.^2))));
% 标注最大误差点
[max_err, max_idx] = max(error_3d);
hold on;
plot(comp_time(max_idx)/3600, max_err, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
text(comp_time(max_idx)/3600, max_err, sprintf(' 最大: %.2fm\n t=%.0fs', max_err, comp_time(max_idx)), ...
    'FontSize', 9, 'VerticalAlignment', 'bottom');

% 子图3: TOE时间差
subplot(2,3,3);
plot(c36_time/3600, c36_toe_diff/3600, 'g-', 'LineWidth', 1.5);
hold on;
plot([0 24], [2 2], 'r--', 'LineWidth', 1, 'DisplayName', '2小时有效期');
plot([0 24], [-2 -2], 'r--', 'LineWidth', 1);
grid on;
xlabel('时间 (小时)');
ylabel('|t - TOE| (小时)');
title('星历时间差');
legend('Location', 'best');
ylim([-3 3]);

% 子图4: XYZ分量误差
subplot(2,3,4);
plot(comp_time/3600, error_X, 'r-', 'DisplayName', 'X误差');
hold on;
plot(comp_time/3600, error_Y, 'g-', 'DisplayName', 'Y误差');
plot(comp_time/3600, error_Z, 'b-', 'DisplayName', 'Z误差');
grid on;
xlabel('时间 (小时)');
ylabel('坐标分量误差 (m)');
title('XYZ各分量误差');
legend('Location', 'best');

% 子图5: 误差与TOE差的关系
subplot(2,3,5);
scatter(abs(comp_toe_diff)/3600, error_3d, 30, comp_time/3600, 'filled');
colorbar;
colormap jet;
ylabel(colorbar, '时间 (小时)');
grid on;
xlabel('|t - TOE| (小时)');
ylabel('3D位置误差 (m)');
title('误差与星历时间差的关系');

% 子图6: 轨道高度变化
subplot(2,3,6);
brd_r = sqrt(c36_X.^2 + c36_Y.^2 + c36_Z.^2);
sp3_r = sqrt(sp3_X.^2 + sp3_Y.^2 + sp3_Z.^2);
plot(c36_time/3600, brd_r/1000, 'r-', 'LineWidth', 1.5, 'DisplayName', '广播星历');
hold on;
plot(sp3_time/3600, sp3_r/1000, 'b--', 'LineWidth', 1.2, 'DisplayName', 'SP3精密星历');
% GEO标准高度
plot([0 24], [42164 42164], 'k:', 'LineWidth', 1, 'DisplayName', 'GEO标准高度');
grid on;
xlabel('时间 (小时)');
ylabel('地心距离 (km)');
title('轨道高度对比');
legend('Location', 'best');

% 保存图片
print('C36_diagnostic.png', '-dpng', '-r300');
fprintf('   诊断图已保存: C36_diagnostic.png\n');

%% 7. 总结报告
fprintf('\n========== C36 诊断总结 ==========\n');
fprintf('卫星类型: 北斗C36 (可能是GEO静止轨道卫星)\n');
fprintf('数据质量:\n');
fprintf('  - 广播星历数据点: %d\n', length(c36_time));
fprintf('  - SP3精密星历数据点: %d\n', length(sp3_time));
fprintf('  - 星历记录数: %d\n', length(c36_ephem));
fprintf('\n误差统计:\n');
fprintf('  - RMS误差: %.3f m\n', sqrt(mean(error_3d.^2)));
fprintf('  - 最大误差: %.3f m (t=%.0fs)\n', max(error_3d), comp_time(error_3d == max(error_3d)));
fprintf('  - 超过10m的点: %d (%.1f%%)\n', length(large_error_idx), ...
    length(large_error_idx)/length(error_3d)*100);

fprintf('\n可能的问题:\n');
if max(error_3d) > 100
    fprintf('  ⚠ 存在超过100米的大误差点\n');
end
if length(invalid_idx) > 0
    fprintf('  ⚠ 有 %d 个点超过2小时星历有效期\n', length(invalid_idx));
end

fprintf('\n建议:\n');
fprintf('  1. C36是GEO卫星，轨道特性与MEO不同\n');
fprintf('  2. 检查是否需要特殊的GEO卫星轨道模型\n');
fprintf('  3. 确认星历选择策略是否合理\n');
fprintf('=====================================\n');
