# Satellite Navigation Principles Lab 1

基于广播星历计算卫星位置的C++程序。

## 功能

- 解析RINEX混合广播星历文件（brdm3350.19p）
- 计算GPS/BDS卫星在任意时刻的ECEF坐标
- 支持GEO/MEO/IGSO卫星轨道类型区分处理
- 智能星历选择（处理重复TOE和异常数据）
- 时间系统自动转换（GPST/BDT）

## 文件说明

| 文件 | 说明 |
|------|------|
| `main.cpp` | 主程序源代码 |
| `brdm3350.19p` | RINEX混合广播星历文件（2019年第335天） |
| `WUM0MGXFIN_*.SP3` | IGS精密星历文件（用于精度验证） |
| `coordinates.txt` | 输出的卫星坐标结果 |

## 使用方法

```bash
g++ main.cpp -o main.exe -std=c++17
./main.exe
```

程序会读取`brdm3350.19p`文件，计算一天内（0-86400秒，每5分钟一个点）所有GPS和北斗卫星的坐标，输出到`coordinates.txt`。

---

# 开发日志

## 2024-12-22

### 发现1：北斗卫星与精密星历对比误差过大

**现象描述**

将程序计算的预报星历卫星位置与IGS发布的SP3精密星历进行对比验证。GPS卫星的3D位置误差在正常范围内（米级到十几米），但北斗卫星的误差异常大，达到数百公里甚至更多。

**问题分析**

怀疑是时间系统不一致导致的问题。经查阅资料确认：

| 文件类型 | 北斗卫星使用的时间系统 |
|---------|----------------------|
| 广播星历（RINEX） | **BDT（北斗时）** |
| 精密星历（SP3） | **GPST（GPS时）** |

GPS时和北斗时的关系：

- GPS时起点：1980年1月6日 00:00:00 UTC
- 北斗时起点：2006年1月1日 00:00:00 UTC
- 在这两个起点之间，UTC累计了14个闰秒
- 因此：**BDT = GPST - 14秒**（固定偏移，永远成立）

**解决方案**

在计算卫星位置时，对北斗卫星进行时间系统转换：

```cpp
double tk;
if(PRN[0]=='C'){
    // 北斗卫星：广播星历用BDT，需要将GPST转换为BDT
    tk = t - TOE - 14;
} else {
    // GPS卫星：直接用GPST
    tk = t - TOE;
}
```

修改后，北斗卫星的误差降到了与GPS卫星相当的水平。

---

### 发现2：部分卫星轨迹出现诡异突变

**现象描述**

在MATLAB中绑制卫星轨迹图时，发现部分北斗卫星（如C36）的轨迹出现不连续的跳变，坐标在某些时刻突然跃迁到完全不同的位置。

**调试过程**

在代码中添加调试输出，打印异常时刻使用的星历参数：

```cpp
if(sat.PRN == "C36" && t == 41400) {
    cout << "使用的星历 TOE = " << best_ephem->TOE << endl;
    cout << "sqrt(A) = " << best_ephem->sqrt_A << endl;
    cout << "e = " << best_ephem->e << endl;
    // ... 其他参数
}
```

**问题分析**

通过调试输出发现：

1. 广播星历文件中，同一卫星在同一TOE时刻存在**多条星历记录**
2. 这些星历的轨道参数（如sqrt_A, e, M0等）可能完全不同
3. 其中部分星历数据存在**异常值**
4. 原代码只根据TOE与观测时间的差值选择星历，当多条星历TOE相同时，只会选择第一条遇到的

老师给出的建议：如果多个星历的TOE相同，选择**toc（钟差参考时间）与toe接近**的那个，因为通常这种星历数据更可靠。

**解决方案**

添加toc转换函数，将toc时间转为周内秒（与TOE同单位）：

```cpp
double toc_to_gps_seconds() const {
    // 使用蔡勒公式计算星期几
    int y = toc.year, m = toc.month, d = toc.day;
    if (m < 3) { m += 12; y -= 1; }
    int k = y % 100, j = y / 100;
    int dow = (d + (13*(m+1))/5 + k + k/4 + j/4 - 2*j) % 7;
    dow = ((dow + 6) % 7);  // 转换为0=周日
    
    double seconds_in_day = toc.hour*3600.0 + toc.minute*60.0 + toc.second;
    return dow * 86400.0 + seconds_in_day;
}
```

修改星历选择逻辑：

```cpp
double min_toc_toe_diff = TMP_MAX;

for(auto& ephem : sat.Ephemerys){
    double time_diff = fabs(ephem.TOE - t);
    double toc_seconds = ephem.toc_to_gps_seconds();
    double toc_toe_diff = fabs(toc_seconds - ephem.TOE);
    if(toc_toe_diff > 302400) toc_toe_diff = 604800 - toc_toe_diff;  // 跨周处理
    
    if(time_diff < min_time_diff){
        min_time_diff = time_diff;
        min_toc_toe_diff = toc_toe_diff;
        best_ephem = &ephem;
    } else if(time_diff == min_time_diff && toc_toe_diff < min_toc_toe_diff){
        // TOE相同时，选择toc与toe更接近的星历
        min_toc_toe_diff = toc_toe_diff;
        best_ephem = &ephem;
    }
}
```

---

### 改进1：GEO卫星坐标变换

**背景**

查阅北斗ICD接口控制文件（B1I 3.0版），发现**GEO卫星**（地球静止轨道卫星）的坐标计算方式与MEO/IGSO卫星不同，需要额外的坐标变换。

北斗卫星轨道类型对应的PRN编号：

| 轨道类型 | PRN编号 | 说明 |
|---------|---------|------|
| **GEO** | C01-C05, C59-C63 | 地球静止轨道，需特殊处理 |
| **IGSO** | C06-C10, C13, C16, C38-C40 | 倾斜地球同步轨道 |
| **MEO** | C11-C12, C14, C19-C37, C41-C46 | 中圆地球轨道 |

**坐标计算公式**

**情况A：GPS卫星及BDS MEO/IGSO卫星**

计算升交点经度L（已包含地球自转修正）：
$$L = \Omega_0 + (\dot{\Omega} - \omega_e)t_k - \omega_e t_{oe}$$

转换到ECEF坐标：
$$X = x_k' \cos L - y_k' \cos i_k \sin L$$
$$Y = x_k' \sin L + y_k' \cos i_k \cos L$$
$$Z = y_k' \sin i_k$$

**情况B：BDS GEO卫星**

Step 1：计算惯性系下的升交点经度
$$\Omega_k = \Omega_0 + \dot{\Omega} t_k - \omega_e t_{oe}$$

Step 2：计算惯性系坐标
$$X_{GK} = x_k' \cos \Omega_k - y_k' \cos i_k \sin \Omega_k$$
$$Y_{GK} = x_k' \sin \Omega_k + y_k' \cos i_k \cos \Omega_k$$
$$Z_{GK} = y_k' \sin i_k$$

Step 3：地球自转修正（绕Z轴旋转$\omega_e t_k$）

Step 4：绕X轴旋转$-5°$

**实现代码**

```cpp
bool is_geo = false;
if(PRN[0] == 'C') {
    int prn_num = stoi(PRN.substr(1, 2));
    if((prn_num >= 1 && prn_num <= 5) || (prn_num >= 59 && prn_num <= 63)) {
        is_geo = true;
    }
}

if(is_geo) {
    double Omega_k = Omega + Omega_dot * tk - omega_e * TOE;
    double X_GK = x_orbit * cos(Omega_k) - y_orbit * cos(i) * sin(Omega_k);
    double Y_GK = x_orbit * sin(Omega_k) + y_orbit * cos(i) * cos(Omega_k);
    double Z_GK = y_orbit * sin(i);
    
    double phi = omega_e * tk;
    double angle_x = -5.0 * M_PI / 180.0;
    
    double X_temp = X_GK * cos(phi) + Y_GK * sin(phi);
    double Y_temp = -X_GK * sin(phi) + Y_GK * cos(phi);
    
    X = X_temp;
    Y = Y_temp * cos(angle_x) + Z_GK * sin(angle_x);
    Z = -Y_temp * sin(angle_x) + Z_GK * cos(angle_x);
} else {
    double L = Omega + (Omega_dot - omega_e) * tk - omega_e * TOE;
    X = x_orbit * cos(L) - y_orbit * cos(i) * sin(L);
    Y = x_orbit * sin(L) + y_orbit * cos(i) * cos(L);
    Z = y_orbit * sin(i);
}
```

---

### 发现3：C31/C32卫星依然异常

**现象描述**

完成上述所有修改后，大部分卫星轨迹已经正常，但C31和C32两颗卫星的轨迹仍然存在明显跳变。

**深入分析**

使用Python脚本分析广播星历文件中C31和C32的原始数据。

**C31问题：星历数据严重稀疏**

C31在整个广播星历文件中只有4条星历记录：

| 序号 | TOE (周内秒) | 对应时间 |
|-----|-------------|---------|
| 1 | 14400 | 04:00 |
| 2 | 21600 | 06:00 |
| 3 | 50400 | 14:00 |
| 4 | 75600 | 21:00 |

问题：

- 06:00到14:00之间有**8小时空白**
- 星历有效期一般是±2小时，中间大段时间超出有效期
- 更严重的是，这4条星历之间的轨道参数**不连续**

轨道参数跳变分析：

| 跳变时刻 | 跳变参数 | 跳变量 |
|---------|---------|--------|
| t≈18000s (TOE从14400→21600) | omega | 从-0.62rad变为+0.05rad，差0.67rad(38°) |
| t≈36000s (TOE从21600→50400) | M0, omega | M0和omega同时大幅跳变 |
| t≈63000s (TOE从50400→75600) | Omega0 | 从-2.89rad变为+1.27rad，差4.16rad(238°) |

**C32问题：同TOE存在多条冲突星历**

C32在广播星历文件中有31条记录，但存在以下问题：

| TOE | 问题描述 |
|-----|---------|
| 14400 | 有3条完全不同的星历，轨道参数差异巨大 |
| 18000 | 有2条不同的星历 |
| 72000 | 其中一条sqrt_A=6492.92（异常值，正常MEO卫星应为5282左右） |

具体来说，TOE=72000有两条星历：

- 正常星历：sqrt_A=5282.62，对应轨道半径27.91万km
- 异常星历：sqrt_A=6492.92，对应轨道半径42.16万km（这是GEO卫星的高度！）

**结论**

C31和C32的轨迹异常是**广播星历文件本身的数据质量问题**，不是程序逻辑错误：

1. C31：星历稀疏且参数不连续（可能是卫星机动或数据上注异常）
2. C32：同一TOE存在多条完全不同的星历，toc-toe筛选逻辑对这种情况作用有限

---

## 2024-12-23

### 发现4：GEO卫星坐标变换旋转顺序错误

**现象描述**

使用`error_analysis.m`脚本对比广播星历计算结果与SP3精密星历，发现GEO卫星（如C01）的误差高达约200km，而MEO/IGSO卫星误差正常（米级）。

具体观察：

- C01在15分钟内X坐标变化约9km（卫星在"绕地球转"）
- SP3显示C01几乎静止（X变化仅约0.5km，符合GEO卫星特性）
- 误差随时间线性增长

**问题分析**

重新查阅北斗ICD文档（B1I 3.0版）第21页，发现GEO卫星坐标变换公式的**旋转矩阵顺序**有明确定义：

![北斗ICD GEO坐标变换公式](GEO_formula_ICD.png)

公式为：
$$\begin{bmatrix} X_k \\ Y_k \\ Z_k \end{bmatrix} = R_z(\dot{\Omega}_e t_k) \cdot R_x(-5°) \cdot \begin{bmatrix} X_{GK} \\ Y_{GK} \\ Z_{GK} \end{bmatrix}$$

即：**先对惯性系坐标进行Rx(-5°)旋转，再进行Rz(ωe·tk)旋转**。

而之前的代码错误地**先Rz再Rx**：

```cpp
// 错误代码：先Rz再Rx
double X_temp = X_GK * cos(phi) + Y_GK * sin(phi);  // Rz
double Y_temp = -X_GK * sin(phi) + Y_GK * cos(phi);
double Z_temp = Z_GK;

X = X_temp;
Y = Y_temp * cos(angle_x) + Z_temp * sin(angle_x);  // Rx
Z = -Y_temp * sin(angle_x) + Z_temp * cos(angle_x);
```

**解决方案**

修正旋转顺序为**先Rx再Rz**：

```cpp
// 正确代码：先Rx再Rz
// 1. 先绕X轴旋转-5度 (Rx)
double X_temp = X_GK;
double Y_temp = Y_GK * cos(angle_x) + Z_GK * sin(angle_x);
double Z_temp = -Y_GK * sin(angle_x) + Z_GK * cos(angle_x);

// 2. 再绕Z轴旋转phi (Rz)
X = X_temp * cos(phi) + Y_temp * sin(phi);
Y = -X_temp * sin(phi) + Y_temp * cos(phi);
Z = Z_temp;
```

**验证结果**

修正后使用`error_analysis.m`重新验证：

| 卫星 | 修正前误差 | 修正后误差 |
|-----|----------|----------|
| C01 (GEO) | ~200 km | RMS 2.4 m |
| G03 (GPS) | 1.8 m | 1.8 m（无变化） |

所有GEO卫星误差降至正常水平，问题解决。

---

### 新增：误差分析脚本 error_analysis.m

为了方便验证计算结果，创建了`error_analysis.m`脚本。

**功能**：

- 读取`coordinates.txt`（广播星历计算结果）
- 读取SP3精密星历文件
- 自动匹配相同时刻的数据点
- 计算并绘制XYZ方向误差和3D距离误差
- 输出统计信息（MAX, MEAN, RMS）

**使用方法**：

1. 修改脚本开头的`target_prn`变量选择要分析的卫星（如`'C01'`、`'G03'`）
2. 在MATLAB中运行`error_analysis`
