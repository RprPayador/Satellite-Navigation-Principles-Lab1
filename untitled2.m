% plot_sp3_trajectory.m
% 目的：读取SP3精密星历文件，绘制指定卫星（G01）的轨迹。
% 已修正：移除了错误的坐标除以 1000 转换。

function plot_sp3_trajectory()

    clc; clear; close all;

    % --- 配置参数 ---
    % 请确保此文件名与您的上传文件匹配
    sp3FileName = 'WUM0MGXFIN_20193350000_01D_15M_ORB.SP3'; 
    satelliteID = 'C01'; % 目标卫星ID (GPS 01号)
    
    % --- Step 1: 读取数据 ---
    disp(['正在读取 SP3 文件：' sp3FileName '...']);
    [X, Y, Z, ~] = extract_sp3_data(sp3FileName, satelliteID); 
    
    % 检查数据是否成功提取
    if isempty(X)
        error(['未能在文件中找到卫星 ' satelliteID ' 的坐标数据，请检查文件名和卫星ID是否正确。']);
    end
    disp(['成功提取 ' satelliteID ' 的 ' num2str(length(X)) ' 个坐标点。']);
    
    % --- Step 2: 绘制地球和轨迹 ---
    figure('Name', [satelliteID ' 精密星历轨迹'], 'Color', 'w');
    
    % 绘制地球 (半径约 6378 km)
    draw_earth();
    hold on;
    
    % 绘制卫星轨迹
    % **** 关键修正: SP3 坐标已经是千米(km)，直接使用 X, Y, Z ****
    plot3(X, Y, Z, 'LineWidth', 2, 'Color', [0.85 0.33 0.1], 'DisplayName', [satelliteID ' 轨迹']); 
    
    % 绘制起始点和结束点
    plot3(X(1), Y(1), Z(1), 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'DisplayName', '起点');
    plot3(X(end), Y(end), Z(end), 's', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'DisplayName', '终点');
    
    % --- Step 3: 设置图表样式 ---
    grid on;
    axis equal; % 确保X,Y,Z轴比例一致，图形不失真
    
    title(['卫星 ' satelliteID ' 精密星历轨迹 (' sp3FileName ')'], 'FontSize', 14);
    xlabel('X 坐标 (km)', 'FontSize', 12);
    ylabel('Y 坐标 (km)', 'FontSize', 12);
    zlabel('Z 坐标 (km)', 'FontSize', 12);
    
    % 调整视角
    view(130, 20); % 设置一个较好的初始视角
    
    legend('show', 'Location', 'best');
    hold off;
    
    disp('绘图完成。');

end % 主函数结束

% =========================================================
%                  本地辅助函数定义
% =========================================================

% ---------------------------------------------------------
% 辅助函数 1: 从 SP3 文件中提取数据 (固定列宽解析，确保解析鲁棒性)
% ---------------------------------------------------------
function [X, Y, Z, C] = extract_sp3_data(sp3FileName, satelliteID)

    X = []; Y = []; Z = []; C = [];
    
    fid = fopen(sp3FileName, 'rt');
    if fid == -1
        error(['无法打开文件: ' sp3FileName]);
    end

    % --- Step A: 跳过头部信息 ---
    currentLine = fgetl(fid);
    while ischar(currentLine) && currentLine(1) ~= '*' % 星历数据以 '*' 符号开头
        currentLine = fgetl(fid);
    end

    % --- Step B: 逐行读取坐标数据 ---
    while ischar(currentLine)
        
        % 只处理位置记录行（以 'P' 字符开头）
        if length(currentLine) >= 60 && currentLine(1) == 'P' 
            
            % 提取卫星ID 
            currentSatID = strtrim(currentLine(2:4)); 
            
            if strcmp(currentSatID, satelliteID)
                % 找到目标卫星，使用固定列宽解析 (SP3 F14.4 格式)
                try
                    % 列宽：X [5-18], Y [19-32], Z [33-46], C [47-60]
                    % 使用 strtrim 移除前导和后继空格，确保 str2double 成功解析数值
                    X(end+1) = str2double(strtrim(currentLine(5:18)));
                    Y(end+1) = str2double(strtrim(currentLine(19:32)));
                    Z(end+1) = str2double(strtrim(currentLine(33:46)));
                    C(end+1) = str2double(strtrim(currentLine(47:60))); 

                catch
                    % 忽略解析错误的行
                end
            end
        end
        
        % 读取下一行
        currentLine = fgetl(fid);
    end

    fclose(fid);
end % extract_sp3_data 结束

% ---------------------------------------------------------
% 辅助函数 2: 绘制地球模型
% ---------------------------------------------------------
function draw_earth()
    R = 6378.137; % 地球平均半径 (km)
    [x, y, z] = sphere(50);
    
    h = surf(R*x, R*y, R*z);
    
    % 设置地球颜色和透明度
    set(h, 'FaceColor', [0.3 0.7 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.3);
    
    light; % 添加光源
    lighting phong; % 设置光照模型
    
    % 调整坐标轴范围，以适应 MEO 轨道 (约 20000 km)
    max_coord = 30000; 
    xlim([-max_coord max_coord]);
    ylim([-max_coord max_coord]);
    zlim([-max_coord max_coord]);
end % draw_earth 结束