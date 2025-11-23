`ifndef GLOBAL_VH_
`define GLOBAL_VH_

// PS2 KEYBOARD SCAN CODE
`define SPACE_C         8'h29
`define ESC_C           8'h76

`define X_KEY_C         8'h22
`define Z_KEY_C         8'h1A
`define N_KEY_C         8'h31

`define LEFT_ARROW_C    8'h6B
`define DOWN_ARROW_C    8'h72
`define RIGHT_ARROW_C   8'h74
`define UP_ARROW_C      8'h75 

// FIELD
`define FIELD_HORIZONTAL        10
`define FIELD_VERTICAL_DISPLAY  20
`define FIELD_VERTICAL          22  // additional 2 blocks for spawning

`define FIELD_HORIZONTAL_WIDTH  $clog2(`FIELD_HORIZONTAL - 1)
`define FIELD_VERTICAL_WIDTH    $clog2(`FIELD_VERTICAL - 1)


// TETROMINO TYPE
`define NUMBER_OF_TETROMINO 7

`define TETROMINO_I_IDX     3'b000
`define TETROMINO_J_IDX     3'b001
`define TETROMINO_L_IDX     3'b010
`define TETROMINO_O_IDX     3'b011
`define TETROMINO_S_IDX     3'b100
`define TETROMINO_T_IDX     3'b101
`define TETROMINO_Z_IDX     3'b110
`define TETROMINO_EMPTY     3'b111

// TETROMINO AND ALL OF ITS ROTATION
// [rotation][row][column]
typedef struct packed {
          logic [0:3][0:3][0:3] data;
        } tetromino_t;

// COLOR TYPE (color_mapper for more detail)
`define C_BLACK     4'b0000
`define C_FREE1     4'b0001
`define C_FREE2     4'b0010
`define C_FREE3     4'b0011
`define C_FREE4     4'b0100
`define C_FREE5     4'b0101
`define C_FREE6     4'b0110
`define C_FREE7     4'b0111
`define COLOR_I     4'b1000
`define COLOR_J     4'b1001
`define COLOR_L     4'b1010
`define COLOR_O     4'b1011
`define COLOR_S     4'b1100
`define COLOR_T     4'b1101
`define COLOR_Z     4'b1110
`define C_WHITE     4'b1111

`define C_BORDER    `C_BLACK
`define C_EMPTY     `C_WHITE

`define C_BORDER_FULL     24'h00_00_00  // black
`define C_EMPTY_FULL      24'hb2_b2_b2  // darker grey
`define C_BLOCK_BORDER    24'h66_66_66  // lighter grey

typedef struct packed {
          logic [3:0] data;
        } color_t;

// TETROMINO COLOR ALWAYS HAS START BIT 1,
// CAN BE USED TO IDENTIFY TETROMINO
typedef struct packed {
          logic [2:0] data;
        } tetromino_idx_t;

// COORDINATE OF TETROMINO
typedef struct packed {
          logic signed [`FIELD_HORIZONTAL_WIDTH : 0]    x;
          logic signed [`FIELD_VERTICAL_WIDTH : 0]      y;
        } coor_t;

// FIELD DISPLAY
typedef struct packed {
          tetromino_idx_t [0 : `FIELD_VERTICAL - 1][0 : `FIELD_HORIZONTAL - 1] data;
        } field_t;

// CONTROLING TETROMINO
typedef struct packed {
          tetromino_t         tetromino;
          tetromino_idx_t     idx;
          logic [1:0]         rotation; // spawn rotation
          coor_t              coordinate;
} tetromino_ctrl;

// DRAWING START AND END COORDINATE, INCLUSIVE START, EXCLUSIVE END
`define BLOCK_PIXEL 32
`define FIELD_START_X 200
`define FIELD_END_X (`FIELD_START_X + `FIELD_HORIZONTAL*`BLOCK_PIXEL)

`define FIELD_START_Y 40
`define FIELD_END_Y (`FIELD_START_Y + `FIELD_VERTICAL_DISPLAY*`BLOCK_PIXEL)

`define FIELD_BORDER_THICKNESS 8
`define FIELD_BORDER_START_X (`FIELD_START_X - `FIELD_BORDER_THICKNESS)
`define FIELD_BORDER_END_X (`FIELD_END_X + `FIELD_BORDER_THICKNESS)

`define FIELD_BORDER_START_Y (`FIELD_START_Y - `FIELD_BORDER_THICKNESS)
`define FIELD_BORDER_END_Y (`FIELD_END_Y + `FIELD_BORDER_THICKNESS)

`endif
