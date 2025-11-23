`timescale 1ns / 1ps

module tetris_game(
    input  wire logic clk,
    input  wire logic rst,
    input  wire logic tick_game,
    input  wire logic key_left,
    input  wire logic key_right,
    input  wire logic key_down,
    input  wire logic key_rotate,
    input  wire logic key_drop,
    
    output logic [3:0] grid [0:19][0:9],
    output logic [3:0] current_piece_type,
    output logic [1:0] current_rotation,
    output logic signed [4:0] current_x,
    output logic signed [5:0] current_y,
    output logic game_over,
    output logic [31:0] score
    );

    // Game Parameters
    localparam ROWS = 20;
    localparam COLS = 10;
    localparam DROP_SPEED = 30;

    // Piece Definitions
    logic [15:0] shapes [0:6][0:3];
    initial begin
        // I
        shapes[0][0] = 16'b0000_1111_0000_0000; shapes[0][1] = 16'b0010_0010_0010_0010;
        shapes[0][2] = 16'b0000_1111_0000_0000; shapes[0][3] = 16'b0010_0010_0010_0010;
        // J
        shapes[1][0] = 16'b1000_1110_0000_0000; shapes[1][1] = 16'b0110_0100_0100_0000;
        shapes[1][2] = 16'b0000_1110_0010_0000; shapes[1][3] = 16'b0010_0010_0110_0000;
        // L
        shapes[2][0] = 16'b0010_1110_0000_0000; shapes[2][1] = 16'b0100_0100_0110_0000;
        shapes[2][2] = 16'b0000_1110_1000_0000; shapes[2][3] = 16'b1100_0100_0100_0000;
        // O
        shapes[3][0] = 16'b0110_0110_0000_0000; shapes[3][1] = 16'b0110_0110_0000_0000;
        shapes[3][2] = 16'b0110_0110_0000_0000; shapes[3][3] = 16'b0110_0110_0000_0000;
        // S
        shapes[4][0] = 16'b0110_1100_0000_0000; shapes[4][1] = 16'b0100_0110_0010_0000;
        shapes[4][2] = 16'b0000_0110_1100_0000; shapes[4][3] = 16'b1000_1100_0100_0000;
        // T
        shapes[5][0] = 16'b0100_1110_0000_0000; shapes[5][1] = 16'b0100_0110_0100_0000;
        shapes[5][2] = 16'b0000_1110_0100_0000; shapes[5][3] = 16'b0100_1100_0100_0000;
        // Z
        shapes[6][0] = 16'b1100_0110_0000_0000; shapes[6][1] = 16'b0010_0110_0100_0000;
        shapes[6][2] = 16'b0000_1100_0110_0000; shapes[6][3] = 16'b0100_1100_1000_0000;
    end

    // State Machine
    typedef enum logic [2:0] {
        SPAWN,
        PLAY,
        HARD_DROP,
        LOCK,
        CLEAR_LINES,
        GAME_OVER_STATE
    } state_t;
    
    state_t state;
    logic [5:0] drop_timer;
    
    // Line Clearing Integration
    logic lc_start, lc_done, lc_busy;
    logic [3:0] lc_grid_out [0:19][0:9];
    logic [2:0] lc_lines_cleared;
    
    line_clear lc_inst (
        .clk(clk),
        .rst(rst),
        .start(lc_start),
        .grid_in(grid),
        .grid_out(lc_grid_out),
        .lines_cleared(lc_lines_cleared),
        .done(lc_done),
        .busy(lc_busy)
    );

    // Input Handling
    logic prev_left, prev_right, prev_rotate, prev_drop, prev_down;
    logic pending_left, pending_right, pending_rotate, pending_drop;
    
    // Randomness
    logic [15:0] lfsr;
    always_ff @(posedge clk) begin
        if (rst) lfsr <= 16'hACE1;
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // Collision Detection
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
                    if (grid_x < 0 || grid_x >= COLS || grid_y >= ROWS) return 1;
                    if (grid_y >= 0 && grid[grid_y][grid_x] != 0) return 1;
                end
            end
        end
        return 0;
    endfunction

    // Main Game Logic
    always_ff @(posedge clk) begin
        if (rst) begin
            int i, j;
            for (i=0; i<ROWS; i++) for (j=0; j<COLS; j++) grid[i][j] <= 0;
            current_piece_type <= 0;
            current_rotation <= 0;
            current_x <= 3;
            current_y <= -2;
            drop_timer <= 0;
            game_over <= 0;
            state <= SPAWN;
            score <= 0;
            lc_start <= 0;
            prev_left <= 0; prev_right <= 0; prev_rotate <= 0; prev_drop <= 0; prev_down <= 0;
            pending_left <= 0; pending_right <= 0; pending_rotate <= 0; pending_drop <= 0;
        end else begin
            // Input Edge Detection & Latching
            logic move_left, move_right, rotate, drop, soft_drop;
            
            // Detect edges
            if (key_left && !prev_left) pending_left <= 1;
            if (key_right && !prev_right) pending_right <= 1;
            if (key_rotate && !prev_rotate) pending_rotate <= 1;
            if (key_drop && !prev_drop) pending_drop <= 1;
            
            soft_drop = key_down; // Continuous
            
            prev_left <= key_left;
            prev_right <= key_right;
            prev_rotate <= key_rotate;
            prev_drop <= key_drop;
            prev_down <= key_down;
            
            // Default control signals
            lc_start <= 0;

            case (state)
                SPAWN: begin
                    current_piece_type <= lfsr[2:0] % 7;
                    current_rotation <= 0;
                    current_x <= 3;
                    current_y <= -2;
                    drop_timer <= 0;
                    
                    // Clear pending inputs on spawn to prevent accidental moves
                    pending_left <= 0; pending_right <= 0; pending_rotate <= 0; pending_drop <= 0;
                    
                    // Check immediate collision (Stack Full)
                    if (check_collision(3, -2, 0, lfsr[2:0] % 7)) begin
                        state <= GAME_OVER_STATE;
                        game_over <= 1;
                    end else begin
                        state <= PLAY;
                    end
                end

                PLAY: begin
                    // Priority Logic: Drop > Rotate > Left > Right > Gravity
                    // Only process ONE action per cycle to reduce timing path
                    
                    if (pending_drop) begin
                        state <= HARD_DROP;
                        pending_drop <= 0;
                    end else if (pending_rotate) begin
                        if (!check_collision(current_x, current_y, current_rotation + 1, current_piece_type))
                            current_rotation <= current_rotation + 1;
                        pending_rotate <= 0;
                    end else if (pending_left) begin
                        if (!check_collision(current_x - 1, current_y, current_rotation, current_piece_type))
                            current_x <= current_x - 1;
                        pending_left <= 0;
                    end else if (pending_right) begin
                        if (!check_collision(current_x + 1, current_y, current_rotation, current_piece_type))
                            current_x <= current_x + 1;
                        pending_right <= 0;
                    end else begin
                        // Gravity (runs if no other input processed this cycle, or parallel?)
                        // Let's run gravity in parallel or as default.
                        // If we run it here, it might conflict with movement if we are not careful.
                        // But since we use 'else', it's mutually exclusive.
                        // This means if you spam keys, gravity might pause?
                        // No, gravity should be independent.
                        // BUT, to fix timing, we want to avoid checking collision for gravity AND movement in same cycle.
                        // Let's use the 'tick_game' to force gravity.
                        
                        if (tick_game || (drop_timer >= DROP_SPEED) || soft_drop) begin
                            // Soft drop is fast gravity
                            // If soft_drop, we increment timer fast or just drop?
                            // Let's use a counter for soft drop too to avoid too fast.
                            
                            // Simple Gravity Logic
                            if (drop_timer >= DROP_SPEED || (soft_drop && tick_game)) begin
                                drop_timer <= 0;
                                if (!check_collision(current_x, current_y + 1, current_rotation, current_piece_type)) begin
                                    current_y <= current_y + 1;
                                end else begin
                                    state <= LOCK;
                                end
                            end else begin
                                if (tick_game) drop_timer <= drop_timer + 1;
                            end
                        end
                    end
                end

                HARD_DROP: begin
                    // Move down 1 row per cycle until collision
                    if (!check_collision(current_x, current_y + 1, current_rotation, current_piece_type)) begin
                        current_y <= current_y + 1;
                    end else begin
                        state <= LOCK;
                    end
                end

                LOCK: begin
                    // Write piece to grid
                    int r, c;
                    logic [15:0] shape;
                    shape = shapes[current_piece_type][current_rotation];
                    
                    for (r = 0; r < 4; r++) begin
                        for (c = 0; c < 4; c++) begin
                            if (shape[r*4 + c]) begin
                                if (current_y + r >= 0 && current_y + r < ROWS && current_x + c >= 0 && current_x + c < COLS)
                                    grid[current_y + r][current_x + c] <= current_piece_type + 1;
                                
                                // Check Game Over (Locking above board)
                                if (current_y + r < 0) begin
                                    game_over <= 1;
                                    state <= GAME_OVER_STATE;
                                end
                            end
                        end
                    end
                    
                    if (!game_over) begin
                        state <= CLEAR_LINES;
                        lc_start <= 1; // Trigger line clear module
                    end
                end

                CLEAR_LINES: begin
                    if (lc_done) begin
                        grid <= lc_grid_out; // Update grid with cleared lines
                        score <= score + lc_lines_cleared; // Update score
                        state <= SPAWN;
                    end
                end

                GAME_OVER_STATE: begin
                    // Do nothing, wait for reset
                    game_over <= 1;
                end
            endcase
        end
    end

endmodule
