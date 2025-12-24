% analyze_c31_ephemeris.m
% 分析C31的4条星历，分别绘制一天的卫星轨迹
% 目的：展示不同星历参数导致的轨迹差异

clc; clear; close all;

%% 常量定义
GM = 3.986005e14;       % 地球引力常数 (m^3/s^2)
omega_e = 7.2921151467e-5;  % 地球自转角速度 (rad/s)

%% C31的4条星历参数 (从brdm3350.19p提取)
% 星历1: toc=04:00, TOE=14400
eph(1).toc = 4*3600;
eph(1).TOE = 14400;
eph(1).sqrt_A = 5282.624328613;
eph(1).e = 5.169581854716e-04;
eph(1).i0 = 9.599401292681e-01;
eph(1).Omega0 = -2.894237525936;
eph(1).omega = -6.241259382877e-01;
eph(1).M0 = -2.194234725769;
eph(1).delta_n = 3.793015137162e-09;
eph(1).i_dot = -3.485859485754e-10;
eph(1).Omega_dot = -6.663134689162e-09;
eph(1).Cuc = 1.990236341953e-06;
eph(1).Cus = 9.379349648952e-06;
eph(1).Crc = 1.728281250000e+02;
eph(1).Crs = 4.010937500000e+01;
eph(1).Cic = -5.215406417847e-08;
eph(1).Cis = 1.490116119385e-08;
eph(1).label = 'TOE=04:00';
eph(1).color = 'r';

% 星历2: toc=06:00, TOE=21600
eph(2).toc = 6*3600;
eph(2).TOE = 21600;
eph(2).sqrt_A = 5282.628129959;
eph(2).e = 6.613732548431e-04;
eph(2).i0 = 9.558775969844e-01;
eph(2).Omega0 = -2.915600249470;
eph(2).omega = 4.815878918402e-02;
eph(2).M0 = -2.696807870244;
eph(2).delta_n = 3.834088276595e-09;
eph(2).i_dot = -3.407284784231e-10;
eph(2).Omega_dot = -6.705993617266e-09;
eph(2).Cuc = 1.715496182442e-06;
eph(2).Cus = 9.108334779739e-06;
eph(2).Crc = 1.751406250000e+02;
eph(2).Crs = 3.484375000000e+01;
eph(2).Cic = -4.237517714500e-08;
eph(2).Cis = 6.984919309616e-09;
eph(2).label = 'TOE=06:00';
eph(2).color = 'g';

% 星历3: toc=14:00, TOE=50400
eph(3).toc = 14*3600;
eph(3).TOE = 50400;
eph(3).sqrt_A = 5282.619262695;
eph(3).e = 2.516389358789e-04;
eph(3).i0 = 9.546973146781e-01;
eph(3).Omega0 = -2.890103451106;
eph(3).omega = -1.247048453831;
eph(3).M0 = 1.601763136778e-01;
eph(3).delta_n = 3.887304778990e-09;
eph(3).i_dot = -5.175215568501e-10;
eph(3).Omega_dot = -6.729923185457e-09;
eph(3).Cuc = 1.263804733753e-06;
eph(3).Cus = 8.659437298775e-06;
eph(3).Crc = 1.857031250000e+02;
eph(3).Crs = 2.525000000000e+01;
eph(3).Cic = 1.164153218269e-08;
eph(3).Cis = -6.100162863731e-08;
eph(3).label = 'TOE=14:00';
eph(3).color = 'b';

% 星历4: toc=21:00, TOE=75600 (异常：Omega0正负相反)
eph(4).toc = 21*3600;
eph(4).TOE = 75600;
eph(4).sqrt_A = 5282.625623703;
eph(4).e = 1.736429985613e-04;
eph(4).i0 = 9.608086213071e-01;
eph(4).Omega0 = 1.274882736349;  % 注意：这里是正值！
eph(4).omega = -1.049395499786;
eph(4).M0 = -1.596422834790;
eph(4).delta_n = 3.775157250453e-09;
eph(4).i_dot = 4.068026592493e-10;
eph(4).Omega_dot = -6.649205537528e-09;
eph(4).Cuc = -2.132728695869e-06;
eph(4).Cus = 1.010531559587e-05;
eph(4).Crc = 1.568906250000e+02;
eph(4).Crs = -4.323437500000e+01;
eph(4).Cic = -3.725290298462e-08;
eph(4).Cis = 1.955777406693e-08;
eph(4).label = 'TOE=21:00 (Omega异常)';
eph(4).color = 'm';

%% 计算一天的轨迹 (0-86400秒，每5分钟)
t_vec = 0:300:86400;
n_points = length(t_vec);

figure('Name', 'C31 星历对比', 'Color', 'w', 'Position', [100 100 1200 600]);

%% 左图：3D轨迹
subplot(1, 2, 1);
hold on; grid on; axis equal;
view(3);

% 画地球
[sx, sy, sz] = sphere(30);
R_earth = 6371000;
surf(sx*R_earth, sy*R_earth, sz*R_earth, 'FaceColor', [0.3 0.5 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

legend_str = {};

for k = 1:4
    X = zeros(n_points, 1);
    Y = zeros(n_points, 1);
    Z = zeros(n_points, 1);
    
    for i = 1:n_points
        t = t_vec(i);
        [X(i), Y(i), Z(i)] = calc_sat_pos(t, eph(k), GM, omega_e);
    end
    
    plot3(X, Y, Z, 'Color', eph(k).color, 'LineWidth', 1.5);
    legend_str{end+1} = eph(k).label;
end

xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title('C31 四条星历计算的轨迹对比');
legend(legend_str, 'Location', 'best');

%% 右图：轨迹距离差异
subplot(1, 2, 2);
hold on; grid on;

% 以星历3(14:00)为基准计算其他星历的距离差
ref_idx = 3;
X_ref = zeros(n_points, 1);
Y_ref = zeros(n_points, 1);
Z_ref = zeros(n_points, 1);

for i = 1:n_points
    t = t_vec(i);
    [X_ref(i), Y_ref(i), Z_ref(i)] = calc_sat_pos(t, eph(ref_idx), GM, omega_e);
end

for k = [1 2 4]  % 跳过基准星历
    diff_dist = zeros(n_points, 1);
    for i = 1:n_points
        t = t_vec(i);
        [X, Y, Z] = calc_sat_pos(t, eph(k), GM, omega_e);
        diff_dist(i) = sqrt((X-X_ref(i))^2 + (Y-Y_ref(i))^2 + (Z-Z_ref(i))^2);
    end
    plot(t_vec/3600, diff_dist/1000, 'Color', eph(k).color, 'LineWidth', 1.5);
end

xlabel('时间 (小时)');
ylabel('与TOE=14:00星历的距离差 (km)');
title('不同星历计算结果的差异');
legend({'TOE=04:00', 'TOE=06:00', 'TOE=21:00'}, 'Location', 'best');

fprintf('分析完成。\n');
fprintf('注意：TOE=21:00的星历Omega0=+1.27，而其他星历约为-2.89，差约4.16rad(238°)\n');

%% 卫星位置计算函数
function [X, Y, Z] = calc_sat_pos(t, eph, GM, omega_e)
    A = eph.sqrt_A^2;
    n0 = sqrt(GM / A^3);
    n = n0 + eph.delta_n;
    
    tk = t - eph.TOE;
    if tk > 302400, tk = tk - 604800; end
    if tk < -302400, tk = tk + 604800; end
    
    Mk = eph.M0 + n * tk;
    
    % 迭代求解偏近点角
    Ek = Mk;
    for iter = 1:10
        Ek = Mk + eph.e * sin(Ek);
    end
    
    % 真近点角
    sin_vk = sqrt(1 - eph.e^2) * sin(Ek) / (1 - eph.e * cos(Ek));
    cos_vk = (cos(Ek) - eph.e) / (1 - eph.e * cos(Ek));
    vk = atan2(sin_vk, cos_vk);
    
    % 升交点角距
    phi_k = vk + eph.omega;
    
    % 二阶调和改正
    delta_uk = eph.Cus * sin(2*phi_k) + eph.Cuc * cos(2*phi_k);
    delta_rk = eph.Crs * sin(2*phi_k) + eph.Crc * cos(2*phi_k);
    delta_ik = eph.Cis * sin(2*phi_k) + eph.Cic * cos(2*phi_k);
    
    uk = phi_k + delta_uk;
    rk = A * (1 - eph.e * cos(Ek)) + delta_rk;
    ik = eph.i0 + delta_ik + eph.i_dot * tk;
    
    % 轨道平面内坐标
    x_orbit = rk * cos(uk);
    y_orbit = rk * sin(uk);
    
    % 升交点经度
    Omega_k = eph.Omega0 + (eph.Omega_dot - omega_e) * tk - omega_e * eph.TOE;
    
    % ECEF坐标
    X = x_orbit * cos(Omega_k) - y_orbit * cos(ik) * sin(Omega_k);
    Y = x_orbit * sin(Omega_k) + y_orbit * cos(ik) * cos(Omega_k);
    Z = y_orbit * sin(ik);
end
