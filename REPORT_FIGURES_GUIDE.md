# AG Tetris Report - Figure Documentation

## Overview

This document catalogues all available figures for the FPGA Tetris project report, mapping each to the relevant report section and describing its contents.

---

## Report Marking Criteria Reference

| Section | Max Marks | Figures Needed |
|---------|-----------|----------------|
| Introduction and Background (VGA) | 3 marks | VGA timing, sync generation |
| Design Description | 5 marks | Architecture, FSM, pipelines |
| Testing Description | 3 marks | Testbench results, simulations |
| Code Quality | 4 marks | Code excerpts (not figures) |
| Presentation and References | 3 marks | Clean formatting |
| Reflection | 2 marks | None |

---

## Available Figures

### Category 1: VGA Output Module

| Figure ID | Source | Status | Contents |
|-----------|--------|--------|----------|
| **VGA-1** | vga_out PDF | ✅ Complete | Full `vga_out` module - single image captures entire timing generator |

**What VGA-1 Contains:**
- Horizontal counter (`curr_x` generation)
- Vertical counter (`curr_y` generation)
- H-sync pulse generation logic
- V-sync pulse generation logic
- `active_area` combinational logic
- Timing parameter comparators

**Use in Report:** Section 1 - VGA Signalling Protocol (3 marks)

**Suggested Caption:** *"Figure X: VGA timing generator module (vga_out) showing horizontal and vertical counters with sync pulse generation for 1280×800 @ 60Hz output."*

---

### Category 2: Draw/Rendering Module

| Figure ID | Source | Status | Contents |
|-----------|--------|--------|----------|
| **DRAW-1** | draw_tetris PDF | ✅ Complete | Region detection logic |
| **DRAW-2** | draw_tetris PDF | ✅ Complete | Sprite output system (merged) |

**What DRAW-1 Contains (Region Detection):**
- `s1_is_grid` - Main playfield detection
- `s1_is_next` - Next piece preview area
- `s1_is_hold` - Hold piece area
- `s1_is_score` - Score display region
- `s1_is_level` - Level display region
- `s1_is_border` - Grid border detection
- Coordinate comparison logic (comparators for GRID_X_START, GRID_Y_START, etc.)

**What DRAW-2 Contains (Sprite Output):**
- `sprite_addr_x`, `sprite_addr_y` - ROM address generation
- `sprite_pixel` input from block_sprite ROM
- Color mapping logic (`color_map` ROM)
- Final `vga_r`, `vga_g`, `vga_b` output registers
- Pipeline stage registers (`s1_*`, `s2_*`, `s3_*`)

**Use in Report:** Section 2 - Design Description (pixel rendering pipeline)

**Suggested Captions:**
- *"Figure X: Region detection logic in draw_tetris showing screen area classification for grid, preview boxes, and UI elements."*
- *"Figure X: Sprite-based rendering output showing ROM addressing and color mapping pipeline."*

---

### Category 3: Game Control Module

| Figure ID | Source | Status | Contents |
|-----------|--------|--------|----------|
| **GAME-1** | game_control PDF | ⚠️ Partial | High-level overview (crowded) |

**What GAME-1 Contains (High-Level Overview):**
- All submodule instantiations visible but hard to read:
  - `gen` (generate_tetromino)
  - `rot` (rotate_tetromino)
  - `validator` (check_valid)
  - `cleaner` (clean_field)
  - `ghost` (ghost_calc)
- FSM state register (`ps`) - location unclear
- Score calculation logic - location unclear
- Many interconnecting wires (visually complex)

**Limitations:**
- Too crowded to clearly show individual components
- Cannot zoom enough to read signal names
- Submodule boundaries not clearly visible

**Use in Report:** Limited use - may need supplementary hand-drawn or tool-generated diagrams

**Suggested Caption:** *"Figure X: High-level view of game_control module showing interconnected submodules for piece generation, collision detection, rotation, and line clearing."*

---

### Category 4: Input Manager Module

| Figure ID | Source | Status | Contents |
|-----------|--------|--------|----------|
| **INPUT-1** | input_manager PDF | 📋 Needs Review | DAS implementation |

**Expected Contents (verify against your PDF):**
- `timer_left`, `timer_right`, `timer_down` - DAS delay counters
- `prev_left`, `prev_right`, etc. - Edge detection registers
- DAS_DELAY and DAS_SPEED comparators
- `cmd_*` output pulse generation
- One-shot logic for rotation/drop/hold

**Use in Report:** Section 2 - Design Description (input processing)

---

### Category 5: Top-Level Module

| Figure ID | Source | Status | Contents |
|-----------|--------|--------|----------|
| **TOP-1** | game_top PDF | ⚠️ Partial | Module instantiations (skipped - too complex) |

**What Would Be Useful to Capture (if possible):**
- Clock generation section (`clk_wiz_0`, dividers)
- CDC synchronizer chain
- Input combination (OR gates for keyboard + buttons)

---

### Category 6: Custom Diagrams (Claude-Generated)

| Figure ID | Source | Status | Contents |
|-----------|--------|--------|----------|
| **DIAG-1** | tetris_architecture.svg | ✅ Complete | System block diagram |
| **DIAG-2** | vga_timing_diagram.svg | ✅ Complete | VGA timing waveforms |
| **DIAG-3** | game_fsm_diagram.svg | ✅ Complete | Game control FSM states |

**What DIAG-1 Contains (Architecture):**
- All major modules in hierarchical layout
- Input Layer: PS2Receiver, ps2_keyboard, debouncer_btn, input_manager
- Game Logic Layer: game_control with submodules
- Display Layer: vga_out, draw_tetris, block_sprite, seg7_key_display
- Clock domains color-coded (83.46MHz, 50MHz, 25MHz)
- CDC crossing points highlighted
- Data bus widths annotated
- Design statistics (1098 cells, 41 I/O, 2203 nets)

**What DIAG-2 Contains (VGA Timing):**
- Horizontal timing waveform (hsync, active area)
- Vertical timing waveform (vsync, active area)
- All timing parameters labeled:
  - H: 1280 visible, 72 front porch, 128 sync, 328 back porch
  - V: 800 visible, 3 front porch, 6 sync, 14 back porch
- Pixel clock calculation (83.46 MHz)
- Refresh rate derivation (~56.1 Hz)

**What DIAG-3 Contains (FSM):**
- All 11+ states with transitions:
  - GEN → IDLE → MOVE_LEFT/RIGHT/ROTATE/DOWN/HARD_DROP/HOLD
  - CLEAN → DROP_LOCKOUT → GEN
  - GAME_OVER_STATE → RESET_GAME
- Transition conditions labeled
- State types color-coded

**Use in Report:** These supplement/replace hard-to-read Vivado schematics

---

## Recommended Figure Placement in Report

### Section 1: VGA Signalling Protocol (3 marks)

| Order | Figure | Purpose |
|-------|--------|---------|
| 1 | **DIAG-2** (VGA Timing Diagram) | Explain VGA protocol timing |
| 2 | **VGA-1** (vga_out schematic) | Show actual implementation |

**Narrative Flow:**
1. Introduce VGA protocol with timing diagram
2. Explain sync pulse generation
3. Show schematic proving implementation matches theory

---

### Section 2: Design Description (5 marks)

| Order | Figure | Purpose |
|-------|--------|---------|
| 1 | **DIAG-1** (Architecture) | System overview |
| 2 | **DIAG-3** (FSM Diagram) | Game logic states |
| 3 | **GAME-1** (game_control overview) | Actual implementation (with caveat about complexity) |
| 4 | **DRAW-1** (Region Detection) | Screen rendering approach |
| 5 | **DRAW-2** (Sprite Output) | Pixel generation pipeline |
| 6 | **INPUT-1** (Input Manager) | DAS implementation |

**Narrative Flow:**
1. Present high-level architecture
2. Explain game FSM with clean diagram
3. Reference actual schematic for verification
4. Describe rendering pipeline
5. Explain input handling with DAS

---

### Section 3: Testing Description (3 marks)

| Order | Figure | Purpose |
|-------|--------|---------|
| 1 | Simulation waveforms | Testbench results |
| 2 | Photos of working hardware | Physical verification |

**Note:** You may need to capture additional simulation screenshots from Vivado

---

## Figure Gaps & Recommendations

### Missing/Weak Areas:

| Gap | Impact | Solution |
|-----|--------|----------|
| game_control detail | Cannot show FSM implementation clearly | Use DIAG-3 (FSM diagram) as primary, reference schematic |
| Clock generation | Missing clock architecture visual | Describe in text, or try to capture from game_top |
| CDC synchronizers | Important for design discussion | Describe in text with code excerpt |
| Testbench results | Needed for testing section | Capture from Vivado simulation |

### Recommended Actions:

1. **Use custom diagrams (DIAG-1, DIAG-2, DIAG-3) as PRIMARY figures** - they're cleaner and more readable

2. **Use Vivado schematics as SUPPORTING evidence** - "The implementation matches the design as shown in Figure X"

3. **For game_control:** Write "Due to the complexity of the synthesized design (1098 cells), a simplified FSM diagram is provided in Figure X, with the full schematic available in Appendix Y"

4. **Add code excerpts** for areas where schematics are unclear (FSM state definitions, DAS parameters, VGA timing constants)

---

## Quick Reference: Figure Filenames

```
Vivado Exports:
├── vga_out.pdf          → VGA-1
├── draw_tetris.pdf      → DRAW-1, DRAW-2
├── game_control.pdf     → GAME-1
├── input_manager.pdf    → INPUT-1
└── game_top.pdf         → TOP-1 (not used)

Custom Diagrams:
├── tetris_architecture.svg    → DIAG-1
├── vga_timing_diagram.svg     → DIAG-2
└── game_fsm_diagram.svg       → DIAG-3
```

---

## Suggested Figure Captions (Copy-Paste Ready)

```
Figure 1: VGA timing diagram showing horizontal and vertical sync pulse 
generation for 1280×800 resolution at approximately 60Hz refresh rate.

Figure 2: VGA timing generator module (vga_out) implementing the timing 
parameters shown in Figure 1.

Figure 3: Top-level system architecture showing the three main layers: 
input processing, game logic, and display output with clock domain crossings.

Figure 4: Game control finite state machine with 11 states handling piece 
generation, movement, rotation with wall kicks, and line clearing.

Figure 5: High-level synthesis view of game_control module showing 
interconnected submodules.

Figure 6: Region detection logic in the rendering pipeline, classifying 
screen coordinates into playfield, preview boxes, and UI elements.

Figure 7: Sprite-based block rendering system showing ROM addressing and 
color mapping for the final VGA output.

Figure 8: Input manager DAS (Delayed Auto Shift) implementation providing 
responsive controls with configurable repeat timing.
```

---

## Total Figure Count

| Type | Count | Status |
|------|-------|--------|
| Vivado Schematics | 4-5 | Partial coverage |
| Custom Diagrams | 3 | Complete |
| **Total Available** | **7-8** | Sufficient for report |

This should provide adequate visual support for all marked sections of the report.
