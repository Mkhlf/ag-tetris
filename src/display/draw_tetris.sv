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
    input  logic [3:0]     current_level, // Game level
    
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
    
    // Sidebar (Next Piece & Score)
    localparam SIDE_X_START = GRID_X_START + GRID_W + 50;
    localparam NEXT_Y_START = GRID_Y_START;
    localparam SCORE_Y_START = NEXT_Y_START + 200;
    localparam LEVEL_Y_START = SCORE_Y_START + 150;

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
                    
                    // Check Grid Bounds
                    if (grid_col >= 0 && grid_col < `FIELD_HORIZONTAL &&
                        grid_row >= 0 && grid_row < `FIELD_VERTICAL_DISPLAY) begin
                        
                        // Fix: Offset by 2 to show the visible board (Rows 2 to 21)
                        // Rows 0 and 1 are the hidden spawn area.
                        if (display.data[grid_row + 2][grid_col].data != `TETROMINO_EMPTY) begin
                            cell_color_idx = display.data[grid_row + 2][grid_col].data + 1;
                        end
                    end
                    
                    // Render Block
                    if (cell_color_idx != 0) begin
                        // Sprite Address
                        sprite_addr_x = block_pixel_x[4:1];
                        sprite_addr_y = block_pixel_y[4:1];
                        
                        // Apply texture
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
            
            // 2. Draw Next Piece (Top Right)
            else if (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 150 &&
                     curr_y >= NEXT_Y_START && curr_y < NEXT_Y_START + 150) begin
                
                // Label "NEXT" (Simple Box for now)
                if (curr_y < NEXT_Y_START + 20) begin
                    vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF; // White Header
                end else begin
                    // Draw Piece - now using module-level variables
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
            
            // 3. Draw Score (Below Next)
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
            
            // 4. Draw Level (Below Score)
            else if (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 200 &&
                     curr_y >= LEVEL_Y_START && curr_y < LEVEL_Y_START + 100) begin
                 
                 // Label "LEVEL"
                 if (curr_y < LEVEL_Y_START + 20) begin
                     vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'hF; // Cyan Header
                 end else begin
                     // Draw Level Bar (16 segments, one per level)
                     int level_bar_width;
                     level_bar_width = (current_level + 1) * 10; // Each level = 10 pixels
                     
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
                 end
            end
        end
    end
    
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
    
    // Sidebar (Next Piece & Score)
    localparam SIDE_X_START = GRID_X_START + GRID_W + 50;
    localparam NEXT_Y_START = GRID_Y_START;
    localparam SCORE_Y_START = NEXT_Y_START + 200;

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
                    
                    // Check Grid Bounds
                    if (grid_col >= 0 && grid_col < `FIELD_HORIZONTAL &&
                        grid_row >= 0 && grid_row < `FIELD_VERTICAL_DISPLAY) begin
                        
                        // Fix: Offset by 2 to show the visible board (Rows 2 to 21)
                        // Rows 0 and 1 are the hidden spawn area.
                        if (display.data[grid_row + 2][grid_col].data != `TETROMINO_EMPTY) begin
                            cell_color_idx = display.data[grid_row + 2][grid_col].data + 1;
                        end
                    end
                    
                    // Render Block
                    if (cell_color_idx != 0) begin
                        // Sprite Address
                        sprite_addr_x = block_pixel_x[4:1];
                        sprite_addr_y = block_pixel_y[4:1];
                        
                        // Apply texture
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
            
            // 2. Draw Next Piece (Top Right)
            else if (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 150 &&
                     curr_y >= NEXT_Y_START && curr_y < NEXT_Y_START + 150) begin
                
                // Label "NEXT" (Simple Box for now)
                if (curr_y < NEXT_Y_START + 20) begin
                    vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF; // White Header
                end else begin
                    // Draw Piece - now using module-level variables
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
            
            // 3. Draw Score (Below Next)
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
        end
    end

endmodule
