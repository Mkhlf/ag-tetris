# Project Figures and Schematics Guide

This document catalogues the figures available for your report and explains where they fit.

## 1. VGA Output
**File**: `Schematic/VGA_inst_pics/full_vga.png`
**Description**: Shows the complete `vga_out` module including horizontal/vertical counters and sync pulse generation logic.
**Report Section**: \section{VGA Signaling and Timing Generation}

## 2. System Architecture (Top Level)
**Files**:
- `Schematic/game_top_pics/clk_section.png`: Clock generation and distribution.
- `Schematic/game_top_pics/cdc_section.png`: Clock Domain Crossing synchronizers.
**Report Section**: \subsection{Clock Architecture}

## 3. Game Logic & FSM
**Files**:
- **FSM Diagram**: `fsm_diagram.svg` (Convert to PNG/PDF for LaTeX).
- `Schematic/game_inst/highlevel.png`: Overview of `game_control` submodules.
- `Schematic/game_inst/drop_rot.png`: Detailed view of drop and rotation logic.
**Report Section**: \subsection{Game Logic}

## 4. Drawing & Rendering
**Files**:
- `Schematic/draw_inst_pics/region_detectoin.png`: Logic for detecting grid, UI, and border regions (Stage 1 Pipeline).
- `Schematic/draw_inst_pics/sprit_output.png`: Sprite ROM addressing and color mapping (Stage 2/3).
**Report Section**: \section{Design Description and Drawing Logic}

## 5. Input Processing
**Files**:
- `Schematic/input_mgr_pics/left0.png`: DAS counter logic for Left movement.
- `Schematic/input_mgr_pics/right0.png`: DAS counter logic for Right movement.
**Report Section**: \subsection{Input Processing}

## 6. Simulation & Testing
**Files**:
- `simulation_waveform.png` (To be captured by user)
- `game_photo.jpg` (To be captured by user)

---
**Note on FSM SVG**:
To use `fsm_diagram.svg` in LaTeX:
1.  Convert it to PNG/PDF using an online converter or tool like Inkscape.
2.  Save as `fsm_diagram.png` / `fsm_diagram.pdf`.
3.  The report uses `\includegraphics{fsm_diagram}` which will pick up the supported file.
