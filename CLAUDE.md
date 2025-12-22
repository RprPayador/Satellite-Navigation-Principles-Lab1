# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GNSS (Global Navigation Satellite System) satellite orbit calculation and visualization project. It computes satellite positions from RINEX navigation files and visualizes their trajectories using MATLAB.

**Supported Systems**: GPS (G系列) and BeiDou (C系列/北斗)

## Build and Run Commands

### C++ Orbit Calculator

**Compile**:
```bash
g++ -o main.exe main.cpp -std=c++11
```

**Run**:
```bash
./main.exe
```

**Input**: RINEX navigation file `brdm3350.19p` (must be in same directory)
**Output**: `coordinates.txt` containing computed satellite positions

### MATLAB Visualization

**All Satellites Interactive View**:
```matlab
all_satellites_fixed()
```
- Displays all satellites with interactive checkboxes
- Includes scrollable satellite selection panel
- Shows 3D trajectories with Earth sphere

**Single Satellite Analysis**:
```matlab
% Edit line 116 in single_satellite.m to change target
target_sat = 'C01';  % or 'G01', 'C10', etc.
```
Then run the script to generate:
- 3D orbit trajectory
- Altitude vs. time plot
- Velocity and TOE analysis
- XY plane projection

## Code Architecture

### C++ Components ([main.cpp](main.cpp))

**Core Data Structures**:

1. **`struct TOC`** (lines 39-47): Time of Clock reference
   - Stores year, month, day, hour, minute, second

2. **`struct Point3D`** (lines 50-54): 3D coordinates
   - Stores X, Y, Z in ECEF (Earth-Centered Earth-Fixed) frame

3. **`class Ephemery`** (lines 58-155): Single epoch ephemeris data
   - Contains all Keplerian orbit parameters from RINEX
   - **Key method**: `calc_coordinate(double t)` (lines 94-154)
     - Implements standard GNSS orbit calculation algorithm
     - Handles GPS/BeiDou time offset (14 seconds for BeiDou on line 98)
     - Uses iterative solution for eccentric anomaly (lines 115-117)
     - Applies perturbation corrections for u, r, i
     - Returns ECEF coordinates

4. **`class Satellite`** (lines 158-167): Per-satellite container
   - Stores multiple ephemeris records
   - Tracks computed coordinates and timestamps

**Orbit Calculation Algorithm** (in `Ephemery::calc_coordinate`):
```
Step 1: Compute mean angular velocity (n)
Step 2: Calculate mean anomaly (M) at time t
Step 3: Solve Kepler's equation iteratively for eccentric anomaly (E)
Step 4: Compute true anomaly (f)
Step 5: Calculate argument of latitude (u)
Step 6: Calculate satellite radius (r)
Step 7: Apply perturbation corrections (delta_u, delta_r, delta_i)
Step 8: Correct u, r, i values
Step 9: Compute position in orbital plane
Step 10: Calculate longitude of ascending node (L)
Step 11: Transform to ECEF coordinates
```

**Key Constants**:
- `GM = 3.986005e14` (m³/s²): Earth's gravitational parameter
- `omega_e = 7.2921151467e-5` (rad/s): Earth's rotation rate

**Main Program Flow** ([main.cpp:170-346](main.cpp#L170-L346)):
1. Parse RINEX header (find "END OF HEADER")
2. Read ephemeris records for G and C satellites
3. Group ephemeris by PRN
4. For each satellite, compute positions at 5-minute intervals (0-86400s)
5. Select closest ephemeris for each time point
6. Write results to `coordinates.txt`

### MATLAB Visualization

**[all_satellites.m](all_satellites.m)**: Multi-satellite interactive viewer
- Reads `coordinates.txt`
- Creates scrollable checkbox panel for satellite selection
- Plots all trajectories in 3D with Earth sphere
- Color-coded by satellite with legend

**[single_satellite.m](single_satellite.m)**: Detailed single-satellite analysis
- Target satellite configurable on line 116
- Generates 3 subplots:
  1. 3D orbit with time-colored trajectory
  2. Altitude variation over time
  3. Velocity and TOE time difference analysis
- Outputs XY plane projection
- Saves PNG with filename `{PRN}_satellite_orbit.png`

## File Structure

### Input Files
- `brdm3350.19p`: RINEX 3 navigation file (broadcast ephemeris, day 335 of 2019)
- `WUM0MGXFIN_20193350000_01D_15M_ORB.SP3`: SP3 precise orbit file (reference data)

### Source Code
- `main.cpp`: C++ orbit calculator
- `all_satellites.m`: Multi-satellite visualization
- `single_satellite.m`: Single satellite analysis
- `untitled.m`, `untitled2.m`: Development/testing scripts

### Output Files
- `coordinates.txt`: Computed positions in format:
  ```
  PRN    t(GNSS TIME)/s    X/m    Y/m    Z/m    toe/s
  ```
- `*_satellite_orbit.png`: Generated trajectory plots

## Important Implementation Details

### RINEX Parsing

**String to Double Conversion** ([main.cpp:13-35](main.cpp#L13-L35)):
- Function `rinex_str_to_double()` handles RINEX's Fortran-style notation
- Replaces 'D' or 'd' with 'E' for scientific notation
- Critical for parsing ephemeris parameters

**Ephemeris Record Format**:
- Line 1: PRN, TOC (year, month, day, hour, min, sec), af0, af1, af2
- Lines 2-8: 28 additional parameters (4 per line)
- Parsing happens at [main.cpp:194-226](main.cpp#L194-L226)

### Time System Handling

**BeiDou Time Offset**:
- BeiDou system time differs from GPS time by 14 seconds
- Applied at [main.cpp:98](main.cpp#L98) when satellite PRN starts with 'C'

**Week Crossover**:
- Handled at [main.cpp:103-104](main.cpp#L103-L104)
- Adjusts `tk` if exceeds ±302400 seconds (half week)

**Ephemeris Validity**:
- Warning issued if time difference from TOE exceeds 7200s (2 hours)
- Check at [main.cpp:325-329](main.cpp#L325-L329)

### Coordinate Systems

**ECEF (Earth-Centered Earth-Fixed)**:
- Output coordinates are in ECEF frame
- X-axis points to Greenwich meridian
- Z-axis points to North Pole
- Rotates with Earth

**Typical Orbit Altitudes**:
- GPS: ~20,200 km above Earth surface
- BeiDou MEO: ~21,500 km above Earth surface
- BeiDou IGSO/GEO: higher altitudes

## Debugging Features

**C36 Satellite Debug Output** ([main.cpp:278-314](main.cpp#L278-L314)):
- Special debug block for satellite C36 at t=41400s
- Prints all ephemeris parameters
- Outputs calculated coordinates
- Program exits after printing (remove `return 0;` on line 314 to disable)

**Ephemeris Selection Warnings**:
- Warns when selected ephemeris is >2 hours from computation time
- Helps identify potential accuracy issues

## Common Development Tasks

### Add Support for New Satellite System

1. Modify condition at [main.cpp:195](main.cpp#L195) to include new system prefix (e.g., 'E' for Galileo)
2. Update time offset logic at [main.cpp:97-102](main.cpp#L97-L102) if needed
3. Verify constants (GM, omega_e) are correct for the system
4. Update MATLAB scripts to handle new PRN prefix

### Change Computation Time Interval

Modify line 265:
```cpp
for(double t = 0; t <= 86400; t += 300.0)  // Change 300.0 to desired interval in seconds
```

### Modify Output Format

Edit the output section at [main.cpp:331-333](main.cpp#L331-L333):
```cpp
outfile << fixed << setprecision(8);  // Adjust precision
outfile << ... // Add/remove columns
```

### Visualize Specific Satellites in MATLAB

**Method 1 - Edit source**:
Change line 116 in `single_satellite.m`:
```matlab
target_sat = 'G01';  % Change to desired PRN
```

**Method 2 - Pass parameter** (requires minor modification):
Add function signature and parameter to script

## Known Issues and Considerations

1. **Debug code active**: Remove lines 278-314 in main.cpp to compute all satellites (currently exits after C36 at t=41400)

2. **Ephemeris selection**: Uses closest TOE regardless of validity period. Consider adding strict 2-hour cutoff.

3. **Memory efficiency**: All coordinates stored in memory before writing. For long time series, consider streaming output.

4. **RINEX version**: Code assumes RINEX 3 format. May need adjustment for RINEX 2.

5. **MATLAB data reading**: `single_satellite.m` uses flexible regex parsing to handle various spacing in output file.

## Constants and Parameters

### Physical Constants
- Earth GM: 3.986005e14 m³/s²
- Earth rotation rate: 7.2921151467e-5 rad/s
- Earth radius (for visualization): 6,371,000 m

### Computational Parameters
- Kepler equation iterations: 10 (usually sufficient for convergence)
- Default time step: 300 seconds (5 minutes)
- Time range: 0-86400 seconds (one day)
- Ephemeris validity threshold: 7200 seconds (2 hours)

## Dependencies

### C++
- Standard library only (no external dependencies)
- Compiler: g++ with C++11 support
- Uses: `<iostream>`, `<cmath>`, `<vector>`, `<unordered_map>`, `<fstream>`, `<sstream>`

### MATLAB
- Core MATLAB (no special toolboxes required)
- Functions used: `plot3`, `surf`, `scatter3`, `textscan`, `regexp`
- Tested with figure UI controls (`uicontrol`, `uipanel`)
