# AG Tetris Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [General Project Structure](#general-project-structure)
3. [Module Architecture](#module-architecture)
4. [Core Modules - Detailed Description](#core-modules---detailed-description)
   - [Top Level Module](#top-level-module)
   - [Input Processing Modules](#input-processing-modules)
   - [Game Logic Modules](#game-logic-modules)
   - [Display Modules](#display-modules)
5. [Sprite System](#sprite-system)
6. [Data Structures and Types](#data-structures-and-types)
7. [Clock Architecture](#clock-architecture)
8. [Module Interconnections](#module-interconnections)

---

## Project Overview

AG Tetris is a hardware implementation of the classic Tetris game written in SystemVerilog for FPGA deployment. The project implements a complete Tetris game with modern features including:
- 7-bag randomization system
- Wall kick mechanics for advanced piece rotation
- Ghost piece preview
- Hold functionality
- Next piece preview
- Score tracking with level progression
- DAS (Delayed Auto Shift) for smooth controls
- Both keyboard (PS/2) and button input support
- VGA display output at 1280x800 resolution
- 7-segment display for debugging

---

## General Project Structure

```
ag-tetris/
├── game_top.sv                 # Top-level module
└── src/
    ├── GLOBAL.sv               # Global definitions and constants
    ├── input/                  # Input processing modules
    │   ├── ps2_keyboard.sv     # PS/2 keyboard interface
    │   ├── PS2Receiver.sv      # Low-level PS/2 protocol handler
    │   ├── input_manager.sv    # Input processing with DAS
    │   └── debouncer.sv        # Button debouncing
    ├── logic/                  # Game logic modules
    │   ├── game_control.sv     # Main game state machine
    │   ├── generate_tetromino.sv # 7-bag randomizer
    │   ├── check_valid.sv      # Collision detection
    │   ├── clean_field.sv      # Line clearing logic
    │   ├── create_field.sv     # Field manipulation
    │   ├── rotate_tetromino.sv # Rotation with wall kicks
    │   ├── rotate_clockwise.sv # Basic rotation logic
    │   ├── ghost_calc.sv       # Ghost piece calculation
    │   ├── spin_detector.sv    # T-spin detection
    │   └── bin_to_bcd.sv       # Binary to BCD conversion
    └── display/                # Display output modules
        ├── vga_out.sv          # VGA timing generator
        ├── draw_tetris.sv      # Main rendering engine
        ├── block_sprite.sv     # Sprite ROM for blocks
        ├── draw_number.sv      # Number rendering
        ├── draw_string.sv      # Text rendering
        └── seg7_key_display.sv # 7-segment display driver
```

---

## Module Architecture

The project follows a hierarchical modular architecture with clear separation of concerns:

1. **Top Level**: Orchestrates all subsystems and handles clock generation
2. **Input Layer**: Processes user inputs from multiple sources
3. **Logic Layer**: Implements game mechanics and state management
4. **Display Layer**: Handles all visual output including VGA and 7-segment

---

## Core Modules - Detailed Description

### Top Level Module

#### `game_top` (game_top.sv)

**Purpose**: Main system integration module that connects all subsystems and manages clock domains.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| CLK100MHZ | Input | 1 | 100MHz system clock |
| CPU_RESETN | Input | 1 | Active-low reset signal |
| PS2_CLK | Input | 1 | PS/2 keyboard clock line |
| PS2_DATA | Input | 1 | PS/2 keyboard data line |
| btn_l/r/u/d/c | Input | 1 each | Physical button inputs |
| VGA_R/G/B | Output | 4 each | VGA color signals |
| VGA_HS/VS | Output | 1 each | VGA sync signals |
| LED[1:0] | Output | 2 | Debug LEDs for PS/2 status |
| SEG[6:0] | Output | 7 | 7-segment display segments |
| AN[7:0] | Output | 8 | 7-segment anode control |
| DP | Output | 1 | 7-segment decimal point |

**Importance**: 
- Generates all required clock domains (83.46MHz pixel, 50MHz PS/2, 25MHz game)
- Implements Clock Domain Crossing (CDC) between game logic and display
- Manages input from both keyboard and buttons with priority handling
- Implements watchdog timer for stuck key detection
- Coordinates all subsystems for proper game operation

---

### Input Processing Modules

#### `ps2_keyboard` (src/input/ps2_keyboard.sv)

**Purpose**: Processes PS/2 keyboard scan codes and generates key events.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | 50MHz clock |
| rst | Input | 1 | Reset signal |
| ps2_clk | Input | 1 | PS/2 clock from keyboard |
| ps2_data | Input | 1 | PS/2 data from keyboard |
| current_scan_code | Output | 8 | Current key scan code |
| current_make_break | Output | 1 | 1=press, 0=release |
| key_event_valid | Output | 1 | Pulse when event occurs |

**Importance**: 
- Decodes PS/2 protocol including extended scan codes
- Provides make/break detection for proper key state tracking
- Extends event pulses for reliable CDC

#### `PS2Receiver` (src/input/PS2Receiver.sv)

**Purpose**: Low-level PS/2 protocol receiver handling bit-level communication.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | System clock |
| kclk | Input | 1 | PS/2 clock |
| kdata | Input | 1 | PS/2 data |
| keycodeout | Output | 32 | 4-byte scan code buffer |

**Importance**: 
- Handles PS/2 protocol timing and framing
- Buffers multi-byte scan codes
- Provides clean interface to higher-level decoder

#### `input_manager` (src/input/input_manager.sv)

**Purpose**: Processes raw inputs and implements DAS (Delayed Auto Shift) for smooth controls.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Game clock (25MHz) |
| rst | Input | 1 | Reset signal |
| tick_game | Input | 1 | 60Hz game tick |
| raw_left/right/down | Input | 1 each | Raw movement inputs |
| raw_rotate_cw/ccw | Input | 1 each | Raw rotation inputs |
| raw_drop | Input | 1 | Raw hard drop input |
| raw_hold | Input | 1 | Raw hold input |
| cmd_* | Output | 1 each | Processed command pulses |

**Importance**: 
- Implements modern Tetris controls with DAS
- Provides one-shot behavior for rotations and special moves
- Configurable repeat delays for optimal gameplay feel
- Essential for responsive and predictable controls

#### `debouncer` / `debouncer_btn` (src/input/debouncer.sv)

**Purpose**: Removes mechanical bounce from physical button inputs.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Clock signal |
| I0/I1 | Input | 1 each | Raw button inputs |
| O0/O1 | Output | 1 each | Debounced outputs |

**Importance**: 
- Prevents false triggers from mechanical switches
- Configurable timing for different button types
- Critical for reliable physical controls

---

### Game Logic Modules

#### `game_control` (src/logic/game_control.sv)

**Purpose**: Main game state machine implementing all Tetris mechanics.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Game clock |
| rst | Input | 1 | Reset |
| tick_game | Input | 1 | 60Hz tick |
| key_* | Input | 1 each | Processed input commands |
| key_drop_held | Input | 1 | Drop lockout detection |
| display | Output | field_t | Playing field data |
| score | Output | 32 | Current score |
| game_over | Output | 1 | Game over flag |
| t_next_disp | Output | tetromino_ctrl | Next piece |
| t_hold_disp | Output | tetromino_ctrl | Held piece |
| hold_used_out | Output | 1 | Hold availability |
| current_level_out | Output | 4 | Current level |
| ghost_y | Output | signed | Ghost piece Y position |
| t_curr_out | Output | tetromino_ctrl | Current piece |
| total_lines_cleared_out | Output | 8 | Total lines cleared |

**States**:
- GEN: Generate new piece
- IDLE: Wait for input
- MOVE_LEFT/RIGHT: Horizontal movement
- ROTATE: Piece rotation with wall kicks
- DOWN: Soft drop
- HARD_DROP: Instant drop
- HOLD/HOLD_SWAP: Piece holding
- CLEAN: Line clearing
- GAME_OVER_STATE: End game
- DROP_LOCKOUT: Prevent drop spam

**Importance**: 
- Core game logic implementation
- Manages piece spawning, movement, and placement
- Implements scoring and level progression
- Handles special mechanics (hold, T-spins, wall kicks)
- Coordinates all game state transitions

#### `generate_tetromino` (src/logic/generate_tetromino.sv)

**Purpose**: Implements 7-bag randomization for fair piece distribution.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Clock |
| rst | Input | 1 | Reset |
| enable | Input | 1 | Generate trigger |
| t_out | Output | tetromino_ctrl | Generated piece |
| t_next_out | Output | tetromino_ctrl | Next piece preview |

**Importance**: 
- Ensures each piece appears exactly once per bag
- Prevents long droughts of specific pieces
- Uses LFSR for pseudo-random selection
- Critical for balanced gameplay

#### `check_valid` (src/logic/check_valid.sv)

**Purpose**: Validates piece positions for collision detection.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| t_ctrl | Input | tetromino_ctrl | Piece to check |
| f | Input | field_t | Current field state |
| isValid | Output | 1 | Validity flag |

**Importance**: 
- Prevents illegal piece placements
- Checks boundary violations
- Detects collisions with placed pieces
- Essential for game integrity

#### `clean_field` (src/logic/clean_field.sv)

**Purpose**: Detects and clears completed lines.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Clock |
| enable | Input | 1 | Start cleaning |
| f_in | Input | field_t | Field before cleaning |
| f_out | Output | field_t | Field after cleaning |
| lines_cleared | Output | 3 | Number of lines cleared |
| done | Output | 1 | Operation complete |

**Importance**: 
- Implements line clearing mechanics
- Handles multiple simultaneous line clears
- Updates field after clearing
- Provides cleared line count for scoring

#### `rotate_tetromino` (src/logic/rotate_tetromino.sv)

**Purpose**: Implements SRS (Super Rotation System) wall kicks.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| t_in | Input | tetromino_ctrl | Piece to rotate |
| f | Input | field_t | Current field |
| cw | Input | 1 | Clockwise rotation flag |
| t_out | Output | tetromino_ctrl | Rotated piece |
| success | Output | 1 | Rotation success flag |
| is_tspin | Output | 1 | T-spin detection |

**Importance**: 
- Enables advanced rotation techniques
- Implements standard SRS kick tables
- Allows pieces to rotate in tight spaces
- Detects T-spins for bonus scoring

#### `ghost_calc` (src/logic/ghost_calc.sv)

**Purpose**: Calculates ghost piece position for landing preview.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| t_ctrl | Input | tetromino_ctrl | Current piece |
| field | Input | field_t | Current field |
| ghost_y | Output | signed | Ghost Y position |

**Importance**: 
- Shows where piece will land
- Essential for precise placement
- Improves gameplay visibility

---

### Display Modules

#### `vga_out` (src/display/vga_out.sv)

**Purpose**: Generates VGA timing signals for 1280x800 display.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Pixel clock (83.46MHz) |
| rst | Input | 1 | Reset |
| curr_x | Output | 11 | Current X coordinate |
| curr_y | Output | 10 | Current Y coordinate |
| hsync | Output | 1 | Horizontal sync |
| vsync | Output | 1 | Vertical sync |
| active_area | Output | 1 | Visible area flag |

**Timing Parameters**:
- Resolution: 1280x800
- H Total: 1680 pixels
- V Total: 828 lines
- H Sync: 0-135 (active low)
- V Sync: 0-2 (active high)
- Visible: H[336-1615], V[27-826]

**Importance**: 
- Generates precise VGA timing
- Provides pixel coordinates for rendering
- Ensures monitor compatibility

#### `draw_tetris` (src/display/draw_tetris.sv)

**Purpose**: Main rendering engine that draws all game elements.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Pixel clock |
| rst | Input | 1 | Reset |
| curr_x/y | Input | 11/10 | Current pixel position |
| active_area | Input | 1 | Visible area flag |
| hsync/vsync_in | Input | 1 each | Input sync signals |
| display | Input | field_t | Game field |
| score | Input | 32 | Current score |
| game_over | Input | 1 | Game over flag |
| t_next/hold/curr | Input | tetromino_ctrl | Piece data |
| ghost_y | Input | signed | Ghost position |
| sprite_addr_x/y | Output | 4 each | Sprite ROM address |
| sprite_pixel | Input | 12 | Sprite pixel data |
| vga_r/g/b | Output | 4 each | Color output |
| hsync/vsync_out | Output | 1 each | Output sync signals |

**Rendering Features**:
- 3-stage pipeline for performance
- Grid rendering with borders
- Ghost piece with transparency
- Next/Hold piece preview boxes
- Score and level display
- Animated heartbeat indicator
- Level progress bar
- Game over overlay

**Importance**: 
- Central rendering system
- Implements visual effects and animations
- Manages sprite-based block rendering
- Provides complete game visualization

#### `block_sprite` (src/display/block_sprite.sv)

**Purpose**: ROM-based sprite storage for tetromino blocks.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | Clock |
| addr_x | Input | 4 | X address (0-15) |
| addr_y | Input | 4 | Y address (0-15) |
| pixel_out | Output | 12 | RGB pixel data |

**Importance**: 
- Stores 16x16 pixel block texture
- Provides beveled appearance
- Enables consistent block rendering

#### `draw_number` / `draw_string` (src/display/)

**Purpose**: Text and number rendering utilities.

**Ports**: Various depending on specific rendering needs.

**Importance**: 
- Displays score and level information
- Renders game messages
- Provides readable text output

#### `seg7_key_display` (src/display/seg7_key_display.sv)

**Purpose**: Debug display showing keyboard input on 7-segment display.

**Ports**:
| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| clk | Input | 1 | 100MHz clock |
| rst | Input | 1 | Reset |
| scan_code | Input | 8 | Current scan code |
| key_valid | Input | 1 | Key event flag |
| key_* | Input | 1 each | Key states |
| SEG/AN/DP | Output | Various | 7-segment control |

**Importance**: 
- Provides real-time input debugging
- Shows scan codes and key states
- Essential for troubleshooting input issues

---

## Sprite System

The sprite system is a critical component that provides visually appealing block rendering:

### Architecture
1. **Sprite ROM**: 16x16 pixel texture stored in `block_sprite` module
2. **Texture Design**: Beveled edges for 3D appearance
   - Dark grey border (outer edge)
   - Light grey border (inner edge)  
   - White center (main body)
3. **Color Tinting**: Base sprite is greyscale, tinted per piece type
4. **Pipeline Integration**: Sprite lookups occur in rendering pipeline stage 2

### Block Colors
The system uses a vibrant color scheme optimized for visibility:
- **I-piece**: Cyan (0x0FF)
- **J-piece**: Blue (0x00F)
- **L-piece**: Orange (0xF80)
- **O-piece**: Yellow (0xFF0)
- **S-piece**: Green (0x0F0)
- **T-piece**: Magenta (0xF0F)
- **Z-piece**: Red (0xF00)

### Sprite Usage Flow
1. `draw_tetris` calculates which block to render
2. Sprite coordinates are computed from pixel position
3. `block_sprite` ROM is accessed with 2-cycle latency
4. Retrieved pixel is tinted based on piece type
5. Final color is output through VGA

### Performance Optimization
- Single sprite ROM shared for all blocks
- Pipelined access prevents stalls
- Pre-scaled addressing (32x32 per block)
- Color tinting done in combinational logic

---

## Data Structures and Types

### Core Types (defined in GLOBAL.sv)

#### `tetromino_t`
```systemverilog
typedef struct packed {
    logic [0:3][0:3][0:3] data;
} tetromino_t;
```
- Stores all 4 rotations of a piece
- 4x4 grid per rotation
- Binary representation (1=filled, 0=empty)

#### `field_t`
```systemverilog
typedef struct packed {
    tetromino_idx_t [0:21][0:9] data;
} field_t;
```
- Complete playing field
- 22 rows (2 hidden for spawning)
- 10 columns
- Stores piece type per cell

#### `tetromino_ctrl`
```systemverilog
typedef struct packed {
    tetromino_t     tetromino;
    tetromino_idx_t idx;
    logic [1:0]     rotation;
    coor_t          coordinate;
} tetromino_ctrl;
```
- Complete piece state
- Shape, type, rotation, position
- Used for active and preview pieces

#### `coor_t`
```systemverilog
typedef struct packed {
    logic signed [4:0] x;
    logic signed [4:0] y;
} coor_t;
```
- Signed coordinates for boundary handling
- Supports negative positions during rotation

---

## Clock Architecture

The system uses multiple clock domains for optimal performance:

### Clock Domains
1. **100MHz**: System clock
   - 7-segment display
   - Clock generation

2. **83.46MHz**: Pixel clock
   - VGA timing generation
   - Display rendering pipeline
   - Sprite ROM access

3. **50MHz**: PS/2 clock
   - Keyboard communication
   - Scan code processing

4. **25MHz**: Game clock
   - Game logic
   - Input processing
   - State machines

5. **60Hz**: Game tick
   - Gravity timing
   - DAS timing
   - Animation updates

### Clock Domain Crossing (CDC)
- **PS/2 → Game**: Extended pulses with synchronizers
- **Game → Display**: Frame-synchronized updates
- Prevents metastability and data corruption
- Reduces CDC overhead via frame sync

---

## Module Interconnections

### Data Flow
1. **Input Path**:
   ```
   PS/2 Keyboard → PS2Receiver → ps2_keyboard → CDC → input_manager → game_control
   Buttons → debouncer → input_manager → game_control
   ```

2. **Game Logic Path**:
   ```
   game_control ↔ generate_tetromino
              ↔ check_valid
              ↔ clean_field
              ↔ rotate_tetromino
              ↔ ghost_calc
   ```

3. **Display Path**:
   ```
   game_control → CDC → draw_tetris → sprite_rom → VGA output
                                   → vga_out ↗
   ```

### Control Flow
- **Reset**: Synchronous active-high reset throughout
- **Enable Signals**: Used for module activation
- **Done Flags**: Indicate operation completion
- **Valid Signals**: Mark data availability

### Critical Paths
1. **Input Latency**: ~2-3 frames from keypress to action
2. **Display Latency**: 1 frame via frame sync
3. **Game Logic**: Single cycle operations where possible
4. **Sprite Access**: 2-cycle pipelined

---

## Summary

The AG Tetris project demonstrates a sophisticated hardware implementation of Tetris with modern features. The modular architecture ensures maintainability while the careful clock domain management and pipelining provide excellent performance. The sprite system delivers appealing visuals while the comprehensive input system supports multiple control methods. Together, these systems create a responsive and feature-complete gaming experience suitable for FPGA deployment.
