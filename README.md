# Satellite Navigation Principles Lab 1

基于广播星历计算卫星位置的C++程序。

## 功能

- 解析RINEX混合广播星历文件
- 计算GPS/BDS卫星在指定时刻的ECEF坐标
- 支持GEO/MEO/IGSO卫星轨道类型区分
- 智能星历选择（处理重复TOE问题）

## 文件说明

| 文件 | 说明 |
|------|------|
| `main.cpp` | 主程序 |
| `brdm3350.19p` | RINEX广播星历文件 |
| `WUM0MGXFIN_*.SP3` | SP3精密星历（用于对比验证） |
| `coordinates.txt` | 输出的卫星坐标结果 |
| `星历选择逻辑优化记录.md` | 代码优化记录 |
| `调试过程记录.md` | 调试过程记录 |

## 使用方法

```bash
g++ main.cpp -o main.exe -std=c++17
./main.exe
```

## 技术要点

1. **时间系统转换**：北斗时(BDT) = GPS时(GPST) - 14秒
2. **GEO卫星处理**：需要额外的地球自转修正和绕X轴旋转-5°
3. **星历选择**：当多个星历TOE相同时，优先选择toc与toe接近的星历
