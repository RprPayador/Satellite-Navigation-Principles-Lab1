#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""分析C36重复星历问题"""

import re
import math

def parse_rinex_float(s):
    """解析RINEX格式的浮点数（D notation）"""
    s = s.strip()
    s = s.replace('D', 'E').replace('d', 'E')
    try:
        return float(s)
    except:
        return 0.0

# 读取RINEX文件
with open('brdm3350.19p', 'r') as f:
    lines = f.readlines()

# 找到所有C36 11:00:00的星历
c36_11_ephem = []
i = 0
while i < len(lines):
    if lines[i].startswith('C36 2019 12 01 11 00 00'):
        # 读取8行星历
        ephem = lines[i:i+8]
        c36_11_ephem.append(ephem)
        i += 8
    else:
        i += 1

print("="*80)
print("C36 在 11:00:00 的重复星历分析")
print("="*80)
print(f"\n找到 {len(c36_11_ephem)} 个 C36 11:00:00 星历\n")

for idx, ephem in enumerate(c36_11_ephem):
    print(f"\n第 {idx+1} 个星历:")
    print("-"*80)

    # 第1行：PRN, TOC, af0, af1, af2
    line1 = ephem[0]
    af0 = parse_rinex_float(line1[23:42])
    af1 = parse_rinex_float(line1[42:61])
    af2 = parse_rinex_float(line1[61:80])

    # 第2行：IODE, Crs, Delta_n, M0
    line2 = ephem[1]
    params2 = []
    for j in range(4):
        params2.append(parse_rinex_float(line2[4+j*19:4+(j+1)*19]))
    IODE, Crs, Delta_n, M0 = params2

    # 第3行：Cuc, e, Cus, sqrt(A), TOE
    line3 = ephem[2]
    params3 = []
    for j in range(4):
        params3.append(parse_rinex_float(line3[4+j*19:4+(j+1)*19]))
    Cuc, e, Cus, sqrt_A = params3
    TOE = parse_rinex_float(line3[4+4*19:])  # TOE可能在最后
    if TOE == 0 and len(line3) > 80:
        # 尝试其他位置
        for possible_toe in re.findall(r'[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', line3):
            val = parse_rinex_float(possible_toe)
            if val > 10000:  # TOE应该是几万秒
                TOE = val
                break

    # 第4行：Cic, OMEGA0, Cis
    line4 = ephem[3]
    params4 = []
    for j in range(4):
        params4.append(parse_rinex_float(line4[4+j*19:4+(j+1)*19]))
    # 从文本中直接提取TOE（如果是科学计数法）
    if TOE == 0:
        toe_match = re.findall(r'\d\.\d+e\+0\d', line3)
        if toe_match:
            for tm in toe_match:
                val = parse_rinex_float(tm)
                if val > 10000:
                    TOE = val

    # 尝试直接从原始行中找TOE
    all_numbers_line3 = re.findall(r'[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', line3)
    if len(all_numbers_line3) >= 5:
        # TOE通常是第5个数字（第4个索引）
        potential_toe = parse_rinex_float(all_numbers_line3[4])
        if potential_toe > 1000:  # TOE应该是大数字
            TOE = potential_toe

    # 第5行：i0, Crc, omega, OMEGA_DOT, IDOT
    line5 = ephem[4]
    params5 = []
    for j in range(4):
        params5.append(parse_rinex_float(line5[4+j*19:4+(j+1)*19]))
    i0, Crc, omega, OMEGA_DOT = params5

    # 第6行：...
    line6 = ephem[5]

    # 计算轨道参数
    A = sqrt_A ** 2

    print(f"  TOE (星历参考时间) = {TOE:.1f} 秒 = {TOE/3600:.2f} 小时")
    print(f"  sqrt(A) = {sqrt_A:.6f} m^0.5")
    print(f"  半长轴 A = {A:.2f} m = {A/1000:.2f} km")
    print(f"  轨道高度 = {(A-6371000)/1000:.2f} km")
    print(f"  偏心率 e = {e:.10f}")
    print(f"  轨道倾角 i0 = {i0:.6f} rad = {math.degrees(i0):.2f}°")
    print(f"  近地点幅角 ω = {omega:.6f} rad = {math.degrees(omega):.2f}°")
    print(f"  平近点角 M0 = {M0:.6f} rad = {math.degrees(M0):.2f}°")
    print(f"  平均角速度修正 Δn = {Delta_n:.6e} rad/s")

# 如果有两个星历，对比差异
if len(c36_11_ephem) == 2:
    print("\n" + "="*80)
    print("两个星历的差异对比:")
    print("="*80)

    # 简单重新解析以获取参数
    def parse_ephem(ephem):
        line3 = ephem[2]
        numbers = re.findall(r'[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', line3)
        e = parse_rinex_float(numbers[1])
        sqrt_A = parse_rinex_float(numbers[3])
        TOE = parse_rinex_float(numbers[4]) if len(numbers) > 4 and parse_rinex_float(numbers[4]) > 1000 else 0

        line5 = ephem[4]
        numbers5 = re.findall(r'[-+]?\d+\.\d+e[-+]?\d+|[-+]?\d+\.\d+', line5)
        i0 = parse_rinex_float(numbers5[3])
        omega = parse_rinex_float(numbers5[6]) if len(numbers5) > 6 else 0

        return {'e': e, 'sqrt_A': sqrt_A, 'TOE': TOE, 'i0': i0, 'omega': omega}

    p1 = parse_ephem(c36_11_ephem[0])
    p2 = parse_ephem(c36_11_ephem[1])

    print(f"\n  TOE差异: {abs(p1['TOE'] - p2['TOE']):.0f} 秒")
    print(f"  偏心率差异: {abs(p1['e'] - p2['e']):.6e}")
    print(f"  偏心率比值: {p1['e']/p2['e']:.3f}")
    print(f"  轨道倾角差异: {abs(p1['i0'] - p2['i0'])*57.2958:.4f}°")
    print(f"  近地点幅角差异: {abs(p1['omega'] - p2['omega'])*57.2958:.2f}°")

    print("\n分析:")
    if abs(p1['e'] - p2['e']) / max(p1['e'], p2['e']) > 0.1:
        print("  ⚠️  偏心率差异超过10%，这是异常的！")
    if abs(p1['omega'] - p2['omega']) > 0.1:
        print(f"  ⚠️  近地点幅角差异{abs(p1['omega'] - p2['omega'])*57.2958:.1f}°，这会导致轨道形状完全不同！")

print("\n" + "="*80)
print("结论:")
print("="*80)
print("RINEX文件中C36在某些时刻有重复的星历记录，且参数不一致。")
print("这可能是：")
print("  1. 数据源问题（多个数据中心的星历合并）")
print("  2. 卫星机动或参数更新")
print("  3. 数据错误")
print("\n建议：")
print("  - 检查RINEX文件的来源和质量")
print("  - 在代码中添加逻辑，当发现重复星历时选择更合理的一个")
print("  - 或者只使用第一个出现的星历")
print("="*80)
