`include "../GLOBAL.sv"

module draw_tetris(
    input  wire logic clk,
    input  wire logic [10:0] curr_x,
    input  wire logic [9:0]  curr_y,
    input  wire logic active_area,
    
    // New Interface: Just the display field
    input   field_t     display,
    input  logic [31:0]    score,
    input  logic           game_over,
    input  tetromino_ctrl  t_next, // Next piece
    input  tetromino_ctrl  t_hold, // Hold piece
    input  logic           hold_used, // Whether hold was used this piece
    input  logic [3:0]     current_level, // Game level
    input  logic [7:0]     total_lines_cleared, // NEW: For level bar
    // Ghost pieces 
    input  logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y,
    input  tetromino_ctrl  t_curr, // Current piece for ghost rendering

    input  logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y,
    input  tetromino_ctrl  t_curr, // Current piece for ghost rendering
    
    // Sprite Interface
    output logic [3:0]     sprite_addr_x,
    output logic [3:0]     sprite_addr_y,
    input  logic [11:0]    sprite_pixel,
    
    // VGA Output
    output logic [3:0]     vga_r,
    output logic [3:0]     vga_g,
    output logic [3:0]     vga_b
    );

    // Constants
    localparam BLOCK_SIZE = 32;
    localparam GRID_W = `FIELD_HORIZONTAL * BLOCK_SIZE; // 320
    localparam GRID_H = `FIELD_VERTICAL_DISPLAY * BLOCK_SIZE; // 640
    
    // Centered Grid
    localparam GRID_X_START = (1280 - GRID_W) / 2; // 480
    localparam GRID_Y_START = (800 - GRID_H) / 2;  // 80
    
    // Right Sidebar (Next Piece & Score)
    localparam SIDE_X_START = GRID_X_START + GRID_W + 50;
    localparam NEXT_Y_START = GRID_Y_START;
    localparam SCORE_Y_START = NEXT_Y_START + 200;
    localparam MESSAGE_Y_START = SCORE_Y_START + 100; // Below score
    localparam LEVEL_Y_START = MESSAGE_Y_START + 50;
    
    // Left Sidebar (Hold Piece)
    localparam HOLD_X_START = GRID_X_START - 200;
    localparam HOLD_Y_START = GRID_Y_START;

    // Colors
    logic [11:0] color_map [0:7];
    initial begin
        color_map[0] = 12'h000; // Empty (Black)
        color_map[1] = 12'hF00; // I - Red
        color_map[2] = 12'h0F0; // J - Green
        color_map[3] = 12'h00F; // L - Blue
        color_map[4] = 12'hFF0; // O - Yellow
        color_map[5] = 12'hF0F; // S - Magenta
        color_map[6] = 12'h0FF; // T - Cyan
        color_map[7] = 12'hFA0; // Z - Orange
    end

    // Grid Coordinates
    logic signed [11:0] rel_x, rel_y;
    logic signed [11:0] grid_col, grid_row;
    logic [4:0] block_pixel_x, block_pixel_y;
    
    assign rel_x = curr_x - GRID_X_START;
    assign rel_y = curr_y - GRID_Y_START;
    
    assign grid_col = rel_x / BLOCK_SIZE;
    assign grid_row = rel_y / BLOCK_SIZE;
    
    assign block_pixel_x = rel_x % BLOCK_SIZE;
    assign block_pixel_y = rel_y % BLOCK_SIZE;

    // Internal variables for drawing
    logic signed [31:0] r, c;
    logic [3:0] cell_color_idx;
    logic [3:0] intensity;
    
    // Next piece rendering variables
    logic [10:0] nx;
    logic [9:0] ny;
    logic [2:0] nr, nc;
    
    // Hold piece rendering variables
    logic [10:0] hx;
    logic [9:0] hy;
    logic [2:0] hr, hc;
    
    // Level bar width (moved to module scope for synthesis)
    logic [31:0] level_bar_width;
    
    // Score Number Rendering
    logic score_pixel_on;
    draw_number score_draw (
        .curr_x(curr_x),
        .curr_y(curr_y),
        .pos_x(SIDE_X_START),
        .pos_y(SCORE_Y_START + 40), // Below label
        .number(score),
        .pixel_on(score_pixel_on)
    );
    
        .pixel_on(score_pixel_on)
    );
    
    // Level text rendering ("Level: X")
    logic level_text_pixel_on;
    logic [7:0] level_text_chars [0:15];
    logic [3:0] level_text_len;
    
    always_comb begin
        // "Level: " = 7 characters
        level_text_chars[0] = 8'h4C; // L
        level_text_chars[1] = 8'h45; // E
        level_text_chars[2] = 8'h56; // V
        level_text_chars[3] = 8'h45; // E
        level_text_chars[4] = 8'h4C; // L
        level_text_chars[5] = 8'h3A; // :
        level_text_chars[6] = 8'h20; // Space

        // Initialize remaining to spaces BEFORE conditional assignment
        level_text_chars[8] = 8'h20; level_text_chars[9] = 8'h20;
        level_text_chars[10] = 8'h20; level_text_chars[11] = 8'h20;
        level_text_chars[12] = 8'h20; level_text_chars[13] = 8'h20;
        level_text_chars[14] = 8'h20; level_text_chars[15] = 8'h20;
        
        // Convert level number to ASCII
        if (current_level < 10) begin
            level_text_chars[7] = 8'h30 + current_level; // '0' + level
            level_text_len = 8;
        end else begin
            // For levels 10-15, show as hex or two digits
            level_text_chars[7] = 8'h31; // '1'
            level_text_chars[8] = 8'h30 + (current_level - 10); // '0' + (level - 10)
            level_text_len = 9;
        end
        
        // Fill rest with spaces
        // for (int i = level_text_len; i < 16; i++) begin
        //     level_text_chars[i] = 8'h20; // Space
        // end

    end
    
    draw_string_line level_text_draw (
        .curr_x(curr_x),
        .curr_y(curr_y),
        .pos_x(SIDE_X_START),
        .pos_y(LEVEL_Y_START),
        .str_chars(level_text_chars),
        .str_len(level_text_len),
        .scale(2'd2), // Scale up level text
        .pixel_on(level_text_pixel_on)
    );

    // Output Logic
    always_comb begin
        vga_r = 0; vga_g = 0; vga_b = 0;
        sprite_addr_x = 0; sprite_addr_y = 0;
        cell_color_idx = 0;
        
        if (active_area) begin
            // 1. Draw Grid Border & Field
            if (curr_x >= GRID_X_START - 4 && curr_x < GRID_X_START + GRID_W + 4 &&
                curr_y >= GRID_Y_START - 4 && curr_y < GRID_Y_START + GRID_H + 4) begin
                
                if (curr_x < GRID_X_START || curr_x >= GRID_X_START + GRID_W ||
                    curr_y < GRID_Y_START || curr_y >= GRID_Y_START + GRID_H) begin
                    // Border
                    vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
                end else begin
                    // Inside Grid
                    cell_color_idx = 0;
                    
                    // Grid Lines (Dark Grey)
                    if (block_pixel_x == 0 || block_pixel_x == 31 || 
                        block_pixel_y == 0 || block_pixel_y == 31) begin
                        vga_r = 4'h2; vga_g = 4'h2; vga_b = 4'h2;
                    end
                    
                    // Check Grid Bounds
                    if (grid_col >= 0 && grid_col < `FIELD_HORIZONTAL &&
                        grid_row >= 0 && grid_row < `FIELD_VERTICAL_DISPLAY) begin
                        
                        // Fix: Offset by 2 to show the visible board (Rows 2 to 21)
                        // Rows 0 and 1 are the hidden spawn area.
                        if (display.data[grid_row + 2][grid_col].data != `TETROMINO_EMPTY) begin
                            cell_color_idx = display.data[grid_row + 2][grid_col].data + 1;
                        end
                        
                        // Ghost Piece Rendering (Only if cell is empty and game not over)
                        if (cell_color_idx == 0 && !game_over) begin
                            // Calculate relative position to ghost
                            // grid_row + 2 is the actual field row index
                            if ((grid_row + 2) >= ghost_y && (grid_row + 2) < ghost_y + 4 &&
                                grid_col >= t_curr.coordinate.x && grid_col < t_curr.coordinate.x + 4) begin
                                
                                if (t_curr.tetromino.data[t_curr.rotation][grid_row + 2 - ghost_y][grid_col - t_curr.coordinate.x]) begin
                                    // Draw Ghost (Grey Hollow or Solid)
                                    // Let's do a medium grey
                                    vga_r = 4'h4; vga_g = 4'h4; vga_b = 4'h4;
                                    
                                    // Optional: Sprite texture for ghost?
                                    // For now, just solid color is fine, or maybe use the sprite logic with grey color?
                                    // Let's use sprite logic to make it look like a "ghost block"
                                    sprite_addr_x = block_pixel_x[4:1];
                                    sprite_addr_y = block_pixel_y[4:1];
                                    intensity = sprite_pixel[7:4];
                                    
                                    if (intensity != 4'hF) begin
                                        vga_r = vga_r >> 1;
                                        vga_g = vga_g >> 1;
                                        vga_b = vga_b >> 1;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Render Block
                    if (cell_color_idx != 0) begin
                        sprite_addr_x = block_pixel_x[4:1];
                        sprite_addr_y = block_pixel_y[4:1];
                        intensity = sprite_pixel[7:4];
                        
                        if (game_over) begin
                            // Grey Blocks for Game Over
                            vga_r = 4'h6;
                            vga_g = 4'h6;
                            vga_b = 4'h6;
                        end else begin
                            vga_r = color_map[cell_color_idx][11:8];
                            vga_g = color_map[cell_color_idx][7:4];
                            vga_b = color_map[cell_color_idx][3:0];
                        end
                        
                        if (intensity != 4'hF) begin
                            vga_r = vga_r >> 1;
                            vga_g = vga_g >> 1;
                            vga_b = vga_b >> 1;
                        end
                    end
                end
            end
            
            // 2. Draw Next Piece (Top Right)
            else if (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 150 &&
                     curr_y >= NEXT_Y_START && curr_y < NEXT_Y_START + 150) begin
                
                // Label "NEXT"
                if (curr_y < NEXT_Y_START + 20) begin
                    vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF; // White Header
                end else begin
                    // Draw Piece
                    nx = curr_x - SIDE_X_START - 20;
                    ny = curr_y - NEXT_Y_START - 40;
                    
                    nr = ny / BLOCK_SIZE;
                    nc = nx / BLOCK_SIZE;
                    
                    if (nx >= 0 && ny >= 0 && nr < 4 && nc < 4) begin
                        if (t_next.tetromino.data[0][nr][nc]) begin
                            cell_color_idx = t_next.idx.data + 1;
                            
                            sprite_addr_x = (nx % BLOCK_SIZE) >> 1;
                            sprite_addr_y = (ny % BLOCK_SIZE) >> 1;
                            intensity = sprite_pixel[7:4];
                            
                            vga_r = color_map[cell_color_idx][11:8];
                            vga_g = color_map[cell_color_idx][7:4];
                            vga_b = color_map[cell_color_idx][3:0];
                            
                            if (intensity != 4'hF) begin
                                vga_r = vga_r >> 1;
                                vga_g = vga_g >> 1;
                                vga_b = vga_b >> 1;
                            end
                        end
                    end
                end
            end
            
            // 3. Draw Hold Piece (Top Left)
            else if (curr_x >= HOLD_X_START && curr_x < HOLD_X_START + 150 &&
                     curr_y >= HOLD_Y_START && curr_y < HOLD_Y_START + 150) begin
                
                // Label "HOLD"
                if (curr_y < HOLD_Y_START + 20) begin
                    // Header color: Cyan if available, Grey if used
                    if (hold_used) begin
                        vga_r = 4'h6; vga_g = 4'h6; vga_b = 4'h6; // Grey Header (used)
                    end else begin
                        vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'hF; // Cyan Header (available)
                    end
                end else begin
                    // Draw Held Piece (if not empty)
                    if (t_hold.idx.data != `TETROMINO_EMPTY) begin
                        hx = curr_x - HOLD_X_START - 20;
                        hy = curr_y - HOLD_Y_START - 40;
                        
                        hr = hy / BLOCK_SIZE;
                        hc = hx / BLOCK_SIZE;
                        
                        if (hx >= 0 && hy >= 0 && hr < 4 && hc < 4) begin
                            if (t_hold.tetromino.data[0][hr][hc]) begin
                                cell_color_idx = t_hold.idx.data + 1;
                                
                                sprite_addr_x = (hx % BLOCK_SIZE) >> 1;
                                sprite_addr_y = (hy % BLOCK_SIZE) >> 1;
                                intensity = sprite_pixel[7:4];
                                
                                // Grey out if hold was already used this piece
                                if (hold_used) begin
                                    vga_r = 4'h5;
                                    vga_g = 4'h5;
                                    vga_b = 4'h5;
                                end else begin
                                    vga_r = color_map[cell_color_idx][11:8];
                                    vga_g = color_map[cell_color_idx][7:4];
                                    vga_b = color_map[cell_color_idx][3:0];
                                end
                                
                                if (intensity != 4'hF) begin
                                    vga_r = vga_r >> 1;
                                    vga_g = vga_g >> 1;
                                    vga_b = vga_b >> 1;
                                end
                            end
                        end
                    end
                end
            end
            
            // 4. Draw Score (Below Next)
            else if (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 200 &&
                     curr_y >= SCORE_Y_START && curr_y < SCORE_Y_START + 100) begin
                 
                 // Label "SCORE"
                 if (curr_y < SCORE_Y_START + 20) begin
                     vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'h0; // Yellow Header
                 end else begin
                     // Draw Number
                     if (score_pixel_on) begin
                         vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
                     end
                 end
            end
            
            // 5. Draw Level (Below Message)
            else if (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 200 &&
                     curr_y >= LEVEL_Y_START && curr_y < LEVEL_Y_START + 100) begin
                 
                 // Draw "Level: X" text
                 if (curr_y < LEVEL_Y_START + 20) begin
                     if (level_text_pixel_on) begin
                         vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'hF; // Cyan text
                     end
                  end else begin
                      // Draw Level Bar (Progress to next level)
                      // Each level is 10 lines. Bar width 200px.
                      // Width = (lines % 10) * 20
                      level_bar_width = (total_lines_cleared % 10) * 20; 
                          
                      if (curr_x < SIDE_X_START + level_bar_width &&
                             curr_y >= LEVEL_Y_START + 40 && curr_y < LEVEL_Y_START + 60) begin
                             // Gradient color based on level
                             if (current_level < 5) begin
                                 vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'h0; // Green (Easy)
                             end else if (current_level < 10) begin
                                 vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'h0; // Yellow (Medium)
                             end else begin
                                 vga_r = 4'hF; vga_g = 4'h0; vga_b = 4'h0; // Red (Hard)
                             end
                         end
                    //  end
                 end
            end
            // 6. Heartbeat (Bottom Right of Grid) to indicate that we can continue the game once its is over 
            if (curr_x >= GRID_X_START + GRID_W - 10 && curr_x < GRID_X_START + GRID_W &&
                curr_y >= GRID_Y_START + GRID_H - 10 && curr_y < GRID_Y_START + GRID_H) begin
                 if (heartbeat_cnt[25] && game_over) begin
                     vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
                 end
            end
        end
    end
    
    // Heartbeat Counter
    logic [25:0] heartbeat_cnt;
    always_ff @(posedge clk) begin
        heartbeat_cnt <= heartbeat_cnt + 1;
    end

endmodule
