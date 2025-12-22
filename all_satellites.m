function all_satellites_fixed()
%% === 读取文件 (如果文件不存在，生成模拟数据用于测试) ===
filename = 'coordinates.txt';
if exist(filename, 'file')
    fid = fopen(filename,'r');
    header = fgetl(fid);
    C = textscan(fid, '%s %f %f %f %f %f', ...
                 'Delimiter',' ', 'MultipleDelimsAsOne',1);
    fclose(fid);
    PRN = strtrim(C{1});
    X = C{3}; Y = C{4}; Z = C{5};
else
    % === 仅供测试用的模拟数据 ===
    disp('未找到文件，生成模拟数据...');
    t_sim = linspace(0, 2*pi, 100)';
    nSim = 35; % 模拟35颗卫星
    PRN = {}; X=[]; Y=[]; Z=[];
    for i=1:nSim
        PRN = [PRN; repmat({sprintf('G%02d',i)}, 100, 1)];
        X = [X; 26000e3 * cos(t_sim + i)];
        Y = [Y; 26000e3 * sin(t_sim + i)];
        Z = [Z; 26000e3 * sin(t_sim) * 0.5 + i*1000];
    end
end

%% === 分组 ===
[prnList, ~, id] = unique(PRN,'stable');
nSat = length(prnList);

%% === 创建窗口 ===
fig = figure('Name','GNSS卫星轨迹',...
    'Position',[200 80 1300 760]);
ax = axes('Parent',fig,'Position',[0.36 0.08 0.62 0.88]);
hold(ax,'on'); grid(ax,'on'); axis equal; view(3)
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title('卫星运行轨迹');

%% === 地球球体 ===
R = 6371e3;
[xe,ye,ze] = sphere(60);
surf(ax, xe*R, ye*R, ze*R,...
    'FaceColor',[0.4 0.65 1],...
    'EdgeColor','none',...
    'FaceAlpha',0.25);

%% === 轨迹句柄 ===
ph = gobjects(nSat,1);
cmap = lines(nSat);

%% === 左侧外层面板 ===
outer = uipanel(fig, 'Title','选择卫星',...
                'Position',[0.02 0.02 0.30 0.96]);

%% === 布局参数计算 ===
% 预留顶部空间给"全选"按钮
topMargin = 0.06; 
viewH = 1 - topMargin; % 可视区域高度 (0 ~ 0.94)

itemH_abs = 0.045;     % 单个控件的"绝对"归一化高度 (相对于outer)
itemGap = 0.005;       
lineH_abs = itemH_abs + itemGap;

% 计算内部面板总高度
reqH = nSat * lineH_abs + 0.02; % 需要的总高度
innerH = max(viewH, reqH);      % innerH 至少要填满可视区

% 比例因子：因为 inner 变高了，内部控件的 normalized 高度需要除以 innerH 才能保持原大小
scale = 1 / innerH; 

%% === 内层滚动区域 ===
% 初始位置：Y坐标由 scroll 函数控制
inner = uipanel(outer, 'Units','normalized',...
                       'Position',[0, viewH-innerH, 0.94, innerH],...
                       'BorderType','none', ...
                       'BackgroundColor', 'white'); % 加个背景色方便看

%% === 滚动条 ===
% 只有当内容高度超过可视高度时才启用
sliderStep = [1/(nSat), 0.1]; 
if innerH <= viewH
    enableSlider = 'off';
else
    enableSlider = 'on';
end

slider = uicontrol(outer, 'Style','slider',...
    'Units','normalized',...
    'Position',[0.94 0.01 0.06 viewH-0.01],...
    'Min',0, 'Max',1, 'Value',1,...
    'SliderStep', sliderStep, ...
    'Enable', enableSlider, ...
    'Callback', @(s,~) scroll());

%% === 复选框 + 绘图 ===
cb = gobjects(nSat,1);
for k = 1:nSat
    rows = (id == k);
    ph(k) = plot3(ax, X(rows),Y(rows),Z(rows),...
        'LineWidth',1.3,'Color',cmap(mod(k-1,size(cmap,1))+1,:),...
        'DisplayName',prnList{k});
    
    % 计算内部位置：从上往下排
    % 注意：这里的高度和位置都要乘以 scale (即除以 innerH)
    rowH_rel = lineH_abs * scale; 
    itemH_rel = itemH_abs * scale;
    
    % ypos 是相对于 inner 面板底部的
    % inner 顶部是 1.0。第一行在 1.0 往下一点
    ypos = 1 - k * rowH_rel;
    
    cb(k) = uicontrol(inner, 'Style','checkbox',...
        'String',prnList{k},...
        'Units','normalized',...
        'Position',[0.05, ypos, 0.9, itemH_rel],...
        'Value',1,...
        'FontSize', 10, ...
        'Callback', @(s,~) set(ph(k),'Visible',bool2vis(s.Value)));
end

%% === Legend ===
legend(ax, ph, prnList, 'NumColumns', 2, 'Location','best');

%% === 全选 / 全不选 (放在 outer 顶部) ===
uicontrol(outer, 'Style','pushbutton','String','全选',...
    'Units','normalized','Position',[0.02 0.95 0.40 0.04],...
    'Callback', @(~,~) selAll(1));
uicontrol(outer, 'Style','pushbutton','String','全不选',...
    'Units','normalized','Position',[0.48 0.95 0.40 0.04],...
    'Callback', @(~,~) selAll(0));

%% === 强制触发一次滚动以校准位置 ===
scroll(); 

%% === 内部函数 ===
    function scroll()
        val = get(slider,'Value');
        % 核心修复逻辑：
        % 当 val=1 (滑块在顶)，inner顶部与view顶部对齐 -> y = viewH - innerH
        % 当 val=0 (滑块在底)，inner底部与view底部对齐 -> y = 0
        % 线性插值公式：
        y = val * (viewH - innerH);
        
        pos = get(inner, 'Position');
        pos(2) = y;
        set(inner, 'Position', pos);
    end

    function selAll(v)
        for ii = 1:nSat
            cb(ii).Value = v;
            % 触发回调或直接设置属性
            set(ph(ii),'Visible',bool2vis(v));
        end
    end

    function s = bool2vis(v)
        if v, s='on'; else, s='off'; end
    end
end

