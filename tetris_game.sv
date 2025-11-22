`timescale 1ns / 1ps

module tetris_game(
    input  wire logic clk,          // System clock (e.g. 100MHz or 25MHz)
    input  wire logic rst,
    input  wire logic tick_game,    // Game tick (e.g. 60Hz)
    input  wire logic key_left,
    input  wire logic key_right,
    input  wire logic key_down,
    input  wire logic key_rotate,
    input  wire logic key_drop,
    
    output logic [3:0] grid [0:19][0:9], // 20 rows, 10 cols. 0=Empty, 1-7=Colors
    output logic [3:0] current_piece_type,
    output logic [1:0] current_rotation,
    output logic signed [4:0] current_x, // -2 to 12
    output logic signed [5:0] current_y, // -2 to 22
    output logic game_over
    );

    // Game Parameters
    localparam ROWS = 20;
    localparam COLS = 10;

    // Piece Definitions (Standard Tetrominoes)
    // 0: I, 1: J, 2: L, 3: O, 4: S, 5: T, 6: Z
    // We need a way to represent shapes. 
    // 4x4 grid for each piece/rotation.
    
    logic [15:0] shapes [0:6][0:3]; // 7 pieces, 4 rotations, 16 bits (4x4)
    
    initial begin
        // I
        shapes[0][0] = 16'b0000_1111_0000_0000; 
        shapes[0][1] = 16'b0010_0010_0010_0010;
        shapes[0][2] = 16'b0000_1111_0000_0000;
        shapes[0][3] = 16'b0010_0010_0010_0010;
        // J
        shapes[1][0] = 16'b1000_1110_0000_0000;
        shapes[1][1] = 16'b0110_0100_0100_0000;
        shapes[1][2] = 16'b0000_1110_0010_0000;
        shapes[1][3] = 16'b0010_0010_0110_0000;
        // L
        shapes[2][0] = 16'b0010_1110_0000_0000;
        shapes[2][1] = 16'b0100_0100_0110_0000;
        shapes[2][2] = 16'b0000_1110_1000_0000;
        shapes[2][3] = 16'b1100_0100_0100_0000;
        // O
        shapes[3][0] = 16'b0110_0110_0000_0000;
        shapes[3][1] = 16'b0110_0110_0000_0000;
        shapes[3][2] = 16'b0110_0110_0000_0000;
        shapes[3][3] = 16'b0110_0110_0000_0000;
        // S
        shapes[4][0] = 16'b0110_1100_0000_0000;
        shapes[4][1] = 16'b0100_0110_0010_0000;
        shapes[4][2] = 16'b0000_0110_1100_0000;
        shapes[4][3] = 16'b1000_1100_0100_0000; // Check rotation logic later
        // T
        shapes[5][0] = 16'b0100_1110_0000_0000;
        shapes[5][1] = 16'b0100_0110_0100_0000;
        shapes[5][2] = 16'b0000_1110_0100_0000;
        shapes[5][3] = 16'b0100_1100_0100_0000;
        // Z
        shapes[6][0] = 16'b1100_0110_0000_0000;
        shapes[6][1] = 16'b0010_0110_0100_0000;
        shapes[6][2] = 16'b0000_1100_0110_0000;
        shapes[6][3] = 16'b0100_1100_1000_0000;
    end

    // State Variables
    logic [5:0] drop_timer;
    localparam DROP_SPEED = 30; // Drop every 30 ticks (0.5s at 60Hz)

    // Input Handling (Edge Detection)
    logic prev_left, prev_right, prev_rotate, prev_drop, prev_down;
    
    // Randomness (LFSR)
    logic [15:0] lfsr;
    always_ff @(posedge clk) begin
        if (rst) lfsr <= 16'hACE1;
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // Collision Detection Function
    function logic check_collision(
        input signed [4:0] px, 
        input signed [5:0] py, 
        input [1:0] prot, 
        input [3:0] ptype
    );
        logic [15:0] shape;
        int r, c;
        int grid_x, grid_y;
        
        shape = shapes[ptype][prot];
        
        for (r = 0; r < 4; r++) begin
            for (c = 0; c < 4; c++) begin
                if (shape[r*4 + c]) begin
                    grid_x = px + c;
                    grid_y = py + r;
                    
                    // Check Boundaries
                    if (grid_x < 0 || grid_x >= COLS || grid_y >= ROWS) return 1;
                    
                    // Check Grid (ignore if above board, i.e. y < 0)
                    if (grid_y >= 0 && grid[grid_y][grid_x] != 0) return 1;
                end
            end
        end
        return 0;
    endfunction

    // Game Loop
    always_ff @(posedge clk) begin
        if (rst) begin
            int i, j;
            for (i=0; i<ROWS; i++) for (j=0; j<COLS; j++) grid[i][j] <= 0;
            current_piece_type <= 0;
            current_rotation <= 0;
            current_x <= 3;
            current_y <= -2; // Start slightly above
            drop_timer <= 0;
            game_over <= 0;
            
            prev_left <= 0; prev_right <= 0; prev_rotate <= 0; prev_drop <= 0; prev_down <= 0;
        end else if (tick_game && !game_over) begin
            // Input Handling
            logic move_left, move_right, rotate, drop, soft_drop;
            move_left = key_left && !prev_left;
            move_right = key_right && !prev_right;
            rotate = key_rotate && !prev_rotate;
            drop = key_drop && !prev_drop; // Hard drop
            soft_drop = key_down; // Continuous

            prev_left <= key_left;
            prev_right <= key_right;
            prev_rotate <= key_rotate;
            prev_drop <= key_drop;
            prev_down <= key_down;

            // Movement Logic
            if (move_left) begin
                if (!check_collision(current_x - 1, current_y, current_rotation, current_piece_type))
                    current_x <= current_x - 1;
            end
            if (move_right) begin
                if (!check_collision(current_x + 1, current_y, current_rotation, current_piece_type))
                    current_x <= current_x + 1;
            end
            if (rotate) begin
                if (!check_collision(current_x, current_y, current_rotation + 1, current_piece_type))
                    current_rotation <= current_rotation + 1;
            end

            // Gravity
            if (drop_timer >= DROP_SPEED || soft_drop) begin
                drop_timer <= 0;
                if (!check_collision(current_x, current_y + 1, current_rotation, current_piece_type)) begin
                    current_y <= current_y + 1;
                end else begin
                    // Lock Piece
                    // Copy shape to grid
                    int r, c;
                    logic [15:0] shape;
                    shape = shapes[current_piece_type][current_rotation];
                    
                    for (r = 0; r < 4; r++) begin
                        for (c = 0; c < 4; c++) begin
                            if (shape[r*4 + c]) begin
                                if (current_y + r >= 0 && current_y + r < ROWS && current_x + c >= 0 && current_x + c < COLS)
                                    grid[current_y + r][current_x + c] <= current_piece_type + 1; // Store type + 1 (0 is empty)
                            end
                        end
                    end
                    
                    // Check for Line Clears (Naive implementation: check all rows)
                    // This is tricky in one cycle. We might need a "Locking" state.
                    // For simplicity, let's do it next cycle or assume it works? 
                    // Writing to array in loop is fine in SV if indices are distinct.
                    // But clearing lines requires shifting.
                    // Let's spawn new piece immediately for now, line clear is complex.
                    // TODO: Implement Line Clear properly.
                    
                    // Spawn New Piece
                    current_piece_type <= lfsr[2:0] % 7;
                    current_rotation <= 0;
                    current_x <= 3;
                    current_y <= -2;
                    
                    // Check Game Over
                    if (check_collision(3, -2, 0, lfsr[2:0] % 7)) game_over <= 1;
                end
            end else begin
                drop_timer <= drop_timer + 1;
            end
        end
    end
    
    // Line Clearing Logic (Separate process or state?)
    // For this iteration, I will skip complex line clearing to ensure basic movement works first.
    // Or I can add a simple check.
    
endmodule
