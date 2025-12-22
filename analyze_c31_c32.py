import math

with open('brdm3350.19p', 'r') as f:
    lines = f.readlines()

# 提取C31和C32所有星历的关键参数
for prn_target in ['C31', 'C32']:
    ephems = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith(prn_target):
            params = []
            for j in range(1, 8):
                if i+j < len(lines):
                    row = lines[i+j]
                    for k in range(4):
                        start = 4 + k*19
                        end = start + 19
                        if end <= len(row):
                            val = row[start:end].strip().replace('D','E').replace('d','E')
                            try:
                                params.append(float(val))
                            except:
                                params.append(0.0)
            if len(params) >= 17:
                toe = params[8]
                M0 = params[3]
                omega = params[14]
                Omega0 = params[10]
                sqrt_a = params[7]
                ephems.append({'toe':toe, 'M0':M0, 'omega':omega, 'Omega0':Omega0, 'sqrt_a':sqrt_a})
            i += 8
        else:
            i += 1

    print(f'\n=== {prn_target} 星历参数 ===')
    print('TOE(s)     M0(rad)     omega(rad)   Omega0(rad)  sqrt_A')
    for e in ephems:
        mark = ''
        if e['sqrt_a'] > 6000:
            mark = ' *** 异常sqrt_A!'
        print(f"{e['toe']:8.0f}  {e['M0']:10.4f}  {e['omega']:10.4f}  {e['Omega0']:10.4f}  {e['sqrt_a']:.2f}{mark}")
