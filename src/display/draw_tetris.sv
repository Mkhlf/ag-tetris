`include "../GLOBAL.sv"

module draw_tetris(
    input  wire logic clk,
    input  wire logic [10:0] curr_x,
    input  wire logic [9:0]  curr_y,
    input  wire logic active_area,
    input  wire logic hsync_in,
    input  wire logic vsync_in,
    
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
    
    // Sprite Interface
    output logic [3:0]     sprite_addr_x,
    output logic [3:0]     sprite_addr_y,
    input  logic [11:0]    sprite_pixel,
    
    // VGA Output
    output logic [3:0]     vga_r,
    output logic [3:0]     vga_g,
    output logic [3:0]     vga_b,
    output logic           hsync_out,
    output logic           vsync_out
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

    // Colors - Vibrant scheme for black background
    logic [11:0] color_map [0:7];
    initial begin
        color_map[0] = 12'h000; // Empty (Black)
        color_map[1] = 12'h0FF; // I - Cyan
        color_map[2] = 12'h00F; // J - Blue
        color_map[3] = 12'hF80; // L - Orange
        color_map[4] = 12'hFF0; // O - Yellow
        color_map[5] = 12'h0F0; // S - Green
        color_map[6] = 12'hF0F; // T - Magenta
        color_map[7] = 12'hF00; // Z - Red
    end

    // ======================================================================================
    // PIPELINE STAGE 1: Coordinate Calculation & Region Detection
    // ======================================================================================
    
    // Stage 1 Registers
    logic s1_active_area;
    logic s1_hsync, s1_vsync;
    logic [10:0] s1_curr_x;
    logic [9:0]  s1_curr_y;
    
    // Regions
    logic s1_is_grid;
    logic s1_is_border;
    logic s1_is_next;
    logic s1_is_hold;
    logic s1_is_score;
    logic s1_is_level;
    logic s1_is_heartbeat;
    
    // Grid Coordinates
    logic signed [11:0] s1_rel_x, s1_rel_y;
    logic signed [11:0] s1_grid_col, s1_grid_row;
    logic [4:0] s1_block_pixel_x, s1_block_pixel_y;
    
    // Sidebar relative coords
    logic [10:0] s1_next_rel_x, s1_hold_rel_x;
    logic [9:0]  s1_next_rel_y, s1_hold_rel_y;
    
    always_ff @(posedge clk) begin
        // Pass-through control signals
        s1_active_area <= active_area;
        s1_hsync <= hsync_in;
        s1_vsync <= vsync_in;
        s1_curr_x <= curr_x;
        s1_curr_y <= curr_y;
        
        // Calculate Relative Coordinates
        s1_rel_x <= curr_x - GRID_X_START;
        s1_rel_y <= curr_y - GRID_Y_START;
        
        // Calculate Grid Indices
        s1_grid_col <= (curr_x - GRID_X_START) / BLOCK_SIZE;
        s1_grid_row <= (curr_y - GRID_Y_START) / BLOCK_SIZE;
        s1_block_pixel_x <= (curr_x - GRID_X_START) % BLOCK_SIZE;
        s1_block_pixel_y <= (curr_y - GRID_Y_START) % BLOCK_SIZE;
        
        // Region Detection
        s1_is_grid <= (curr_x >= GRID_X_START && curr_x < GRID_X_START + GRID_W &&
                       curr_y >= GRID_Y_START && curr_y < GRID_Y_START + GRID_H);
                       
        s1_is_border <= (curr_x >= GRID_X_START - 4 && curr_x < GRID_X_START + GRID_W + 4 &&
                         curr_y >= GRID_Y_START - 4 && curr_y < GRID_Y_START + GRID_H + 4) &&
                        !(curr_x >= GRID_X_START && curr_x < GRID_X_START + GRID_W &&
                          curr_y >= GRID_Y_START && curr_y < GRID_Y_START + GRID_H);
                          
        s1_is_next <= (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 150 &&
                       curr_y >= NEXT_Y_START && curr_y < NEXT_Y_START + 150);
                       
        s1_is_hold <= (curr_x >= HOLD_X_START && curr_x < HOLD_X_START + 150 &&
                       curr_y >= HOLD_Y_START && curr_y < HOLD_Y_START + 150);
                       
        s1_is_score <= (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 200 &&
                        curr_y >= SCORE_Y_START && curr_y < SCORE_Y_START + 100);
                        
        s1_is_level <= (curr_x >= SIDE_X_START && curr_x < SIDE_X_START + 200 &&
                        curr_y >= LEVEL_Y_START && curr_y < LEVEL_Y_START + 100);
                        
        s1_is_heartbeat <= (curr_x >= GRID_X_START + GRID_W - 10 && curr_x < GRID_X_START + GRID_W &&
                            curr_y >= GRID_Y_START + GRID_H - 10 && curr_y < GRID_Y_START + GRID_H);
                            
        // Relative coords for sidebars
        s1_next_rel_x <= curr_x - SIDE_X_START;
        s1_next_rel_y <= curr_y - NEXT_Y_START;
        s1_hold_rel_x <= curr_x - HOLD_X_START;
        s1_hold_rel_y <= curr_y - HOLD_Y_START;
    end

    // ======================================================================================
    // PIPELINE STAGE 1.5: Text Rendering Input Registers
    // ======================================================================================
    logic s1a_active_area;
    logic [10:0] s1a_curr_x;
    logic [9:0] s1a_curr_y;
    
    always_ff @(posedge clk) begin
        s1a_active_area <= s1_active_area;
        s1a_curr_x <= s1_curr_x;
        s1a_curr_y <= s1_curr_y;
    end


    // Helper signals for Stage 2 logic
    logic score_pixel_on;
    logic level_text_pixel_on;

    // Score Number
    draw_number score_draw (
        .curr_x(s1a_curr_x),
        .curr_y(s1a_curr_y),
        .pos_x(SIDE_X_START),
        .pos_y(SCORE_Y_START + 40),
        .number(score),
        .pixel_on(score_pixel_on)  // ← Outputs this signal
    );

    // Level Text
    logic [7:0] level_text_chars [0:15];
    logic [3:0] level_text_len;

    always_comb begin
        level_text_chars[0] = 8'h4C; // L
        level_text_chars[1] = 8'h45; // E
        level_text_chars[2] = 8'h56; // V
        level_text_chars[3] = 8'h45; // E
        level_text_chars[4] = 8'h4C; // L
        level_text_chars[5] = 8'h3A; // :
        level_text_chars[6] = 8'h20; // Space
        
        level_text_chars[8] = 8'h20; level_text_chars[9] = 8'h20;
        level_text_chars[10] = 8'h20; level_text_chars[11] = 8'h20;
        level_text_chars[12] = 8'h20; level_text_chars[13] = 8'h20;
        level_text_chars[14] = 8'h20; level_text_chars[15] = 8'h20;
        
        if (current_level < 10) begin
            level_text_chars[7] = 8'h30 + current_level;
            level_text_len = 8;
        end else begin
            level_text_chars[7] = 8'h31;
            level_text_chars[8] = 8'h30 + (current_level - 10);
            level_text_len = 9;
        end
    end


    draw_string_line level_text_draw (
        .curr_x(s1a_curr_x),
        .curr_y(s1a_curr_y),
        .pos_x(SIDE_X_START),
        .pos_y(LEVEL_Y_START),
        .str_chars(level_text_chars),
        .str_len(level_text_len),
        .scale(2'd2),
        .pixel_on(level_text_pixel_on)  // ← Outputs this signal
    );

    // 


    // ======================================================================================
    // PIPELINE STAGE 1.75: Text Rendering Output Registers
    // ======================================================================================
    logic s1b_score_pixel_on;
    logic s1b_level_text_pixel_on;

    always_ff @(posedge clk) begin
        s1b_score_pixel_on <= score_pixel_on;
        s1b_level_text_pixel_on <= level_text_pixel_on;
    end

    // ======================================================================================
    // PIPELINE STAGE 2: Data Access & Logic
    // ======================================================================================
    
    // Stage 2 Registers
    logic s2_active_area;
    logic s2_hsync, s2_vsync;
    
    // Region Flags
    logic s2_is_border;
    logic s2_is_grid;
    logic s2_is_next;
    logic s2_is_hold;
    logic s2_is_score;
    logic s2_is_level;
    logic s2_is_heartbeat;
    logic s2_is_grid_line;
    logic s2_is_ghost;
    
    // Visual Data
    logic [3:0] s2_cell_color_idx;
    logic [3:0] s2_sprite_addr_x;
    logic [3:0] s2_sprite_addr_y;
    
    // Text/UI Pixels
    logic s2_score_pixel;
    logic s2_level_text_pixel;
    logic s2_level_bar_pixel;
    logic [3:0] s2_level_bar_color_idx;
    logic s2_heartbeat_pixel;
    logic s2_level_bar_border;
    
    // Headers
    logic s2_next_header;
    logic s2_hold_header;
    logic s2_score_header;
    logic s2_level_header;
    logic s2_hold_used_header;

    // Heartbeat Counter
    logic [25:0] heartbeat_cnt;
    always_ff @(posedge clk) begin
        heartbeat_cnt <= heartbeat_cnt + 1;
    end

    // Stage 2 Logic Block
    always_ff @(posedge clk) begin
        // Pass-through control signals
        s2_active_area <= s1_active_area;
        s2_hsync <= s1_hsync;
        s2_vsync <= s1_vsync;
        
        // Pass through all region flags
        s2_is_border <= s1_is_border;
        s2_is_grid <= s1_is_grid;
        s2_is_next <= s1_is_next;
        s2_is_hold <= s1_is_hold;
        s2_is_score <= s1_is_score;
        s2_is_level <= s1_is_level;
        s2_is_heartbeat <= s1_is_heartbeat;
        
        // Defaults
        s2_cell_color_idx <= 0;
        s2_sprite_addr_x <= 0;
        s2_sprite_addr_y <= 0;
        s2_is_ghost <= 0;
        s2_is_grid_line <= 0;
        s2_level_bar_border <= 0;
        
        s2_next_header <= 0;
        s2_hold_header <= 0;
        s2_score_header <= 0;
        s2_level_header <= 0;
        s2_hold_used_header <= 0;
        s2_score_pixel <= 0;
        s2_level_text_pixel <= 0;
        s2_level_bar_pixel <= 0;
        s2_heartbeat_pixel <= 0;

        if (s1_curr_x >= SIDE_X_START - 2 && s1_curr_x < SIDE_X_START + 202 &&
            s1_curr_y >= LEVEL_Y_START + 38 && s1_curr_y < LEVEL_Y_START + 62) begin
            
            if (s1_curr_x < SIDE_X_START || s1_curr_x >= SIDE_X_START + 200 ||
                s1_curr_y < LEVEL_Y_START + 40 || s1_curr_y >= LEVEL_Y_START + 60) begin
                s2_level_bar_border <= 1;
            end
        end

        
        // 1. Grid Logic
        if (s1_is_grid) begin
            // Grid Lines Detection
            if (s1_block_pixel_x == 0 || s1_block_pixel_x == 31 || 
                s1_block_pixel_y == 0 || s1_block_pixel_y == 31) begin
                s2_is_grid_line <= 1;
            end
            
            // Check Grid Bounds & Data
            if (s1_grid_col >= 0 && s1_grid_col < `FIELD_HORIZONTAL &&
                s1_grid_row >= 0 && s1_grid_row < `FIELD_VERTICAL_DISPLAY) begin
                
                // Main Block
                if (display.data[s1_grid_row + 2][s1_grid_col].data != `TETROMINO_EMPTY) begin
                    s2_cell_color_idx <= display.data[s1_grid_row + 2][s1_grid_col].data + 1;
                    s2_sprite_addr_x <= s1_block_pixel_x[4:1];
                    s2_sprite_addr_y <= s1_block_pixel_y[4:1];
                end
                // Ghost Piece
                else if (!game_over) begin
                    if ((s1_grid_row + 2) >= ghost_y && (s1_grid_row + 2) < ghost_y + 4 &&
                        s1_grid_col >= t_curr.coordinate.x && s1_grid_col < t_curr.coordinate.x + 4) begin
                        
                        if (t_curr.tetromino.data[t_curr.rotation][s1_grid_row + 2 - ghost_y][s1_grid_col - t_curr.coordinate.x]) begin
                            s2_is_ghost <= 1;
                            s2_sprite_addr_x <= s1_block_pixel_x[4:1];
                            s2_sprite_addr_y <= s1_block_pixel_y[4:1];
                        end
                    end
                end
            end
        end
        
        // 2. Next Piece Logic
        else if (s1_is_next) begin
            if (s1_next_rel_y < 20) begin
                s2_next_header <= 1;
            end else begin
                // Draw Piece
                automatic logic [10:0] nx = s1_next_rel_x - 20;
                automatic logic [9:0] ny = s1_next_rel_y - 40;
                automatic logic [2:0] nr = ny / BLOCK_SIZE;
                automatic logic [2:0] nc = nx / BLOCK_SIZE;
                
                if (nx < 128 && ny < 128 && nr < 4 && nc < 4) begin
                    if (t_next.tetromino.data[0][nr][nc]) begin
                        s2_cell_color_idx <= t_next.idx.data + 1;
                        s2_sprite_addr_x <= (nx % BLOCK_SIZE) >> 1;
                        s2_sprite_addr_y <= (ny % BLOCK_SIZE) >> 1;
                    end
                end
            end
        end
        
        // 3. Hold Piece Logic
        else if (s1_is_hold) begin
            if (s1_hold_rel_y < 20) begin
                s2_hold_header <= 1;
                s2_hold_used_header <= hold_used;
            end else begin
                if (t_hold.idx.data != `TETROMINO_EMPTY) begin
                    automatic logic [10:0] hx = s1_hold_rel_x - 20;
                    automatic logic [9:0] hy = s1_hold_rel_y - 40;
                    automatic logic [2:0] hr = hy / BLOCK_SIZE;
                    automatic logic [2:0] hc = hx / BLOCK_SIZE;
                    
                    if (hx < 128 && hy < 128 && hr < 4 && hc < 4) begin
                        if (t_hold.tetromino.data[0][hr][hc]) begin
                            s2_cell_color_idx <= t_hold.idx.data + 1;
                            s2_sprite_addr_x <= (hx % BLOCK_SIZE) >> 1;
                            s2_sprite_addr_y <= (hy % BLOCK_SIZE) >> 1;
                        end
                    end
                end
            end
        end
        
        // 4. Score Logic
        else if (s1_is_score) begin
            if (s1_curr_y < SCORE_Y_START + 20) begin
                s2_score_header <= 1;
            end
            s2_score_pixel <= s1b_score_pixel_on;  // ← NEW: From buffered register
        end

        // 5. Level Logic
        else if (s1_is_level) begin
            if (s1_curr_y < LEVEL_Y_START + 20) begin
                s2_level_header <= 1;
            end
            
            s2_level_text_pixel <= s1b_level_text_pixel_on;  // ← NEW: From buffered registeron;
            
            // // Level Bar Border (2px wide white border)
            // if (s1_curr_x >= SIDE_X_START - 2 && s1_curr_x < SIDE_X_START + 202 &&
            //     s1_curr_y >= LEVEL_Y_START + 38 && s1_curr_y < LEVEL_Y_START + 62) begin
                
            //     if (s1_curr_x < SIDE_X_START || s1_curr_x >= SIDE_X_START + 200 ||
            //         s1_curr_y < LEVEL_Y_START + 40 || s1_curr_y >= LEVEL_Y_START + 60) begin
            //         s2_level_bar_border <= 1;
            //     end
            // end
            
            // Level Bar
            if (s1_curr_x >= SIDE_X_START && s1_curr_x < SIDE_X_START + ((total_lines_cleared % 10) * 20) &&
                s1_curr_y >= LEVEL_Y_START + 40 && s1_curr_y < LEVEL_Y_START + 60) begin
                s2_level_bar_pixel <= 1;
                if (current_level < 5) s2_level_bar_color_idx <= 0;
                else if (current_level < 10) s2_level_bar_color_idx <= 1;
                else s2_level_bar_color_idx <= 2;
            end
        end
        
        // 6. Heartbeat
        if (s1_is_heartbeat && heartbeat_cnt[25] && game_over) begin
            s2_heartbeat_pixel <= 1;
        end
    end

    // ======================================================================================
    // PIPELINE STAGE 3: Sprite Lookup Alignment
    // ======================================================================================
    
    // Stage 3 intermediate for sprite lookup
    logic [3:0] s3_sprite_addr_x;
    logic [3:0] s3_sprite_addr_y;
    
    // Output sprite address for ROM lookup (1 cycle before color mapping)
    always_ff @(posedge clk) begin
        sprite_addr_x <= s2_sprite_addr_x;
        sprite_addr_y <= s2_sprite_addr_y;
        
        // Also pass these to next stage for alignment
        s3_sprite_addr_x <= s2_sprite_addr_x;
        s3_sprite_addr_y <= s2_sprite_addr_y;
    end
    
    // Stage 3 Registers (aligned with sprite_pixel output)
    logic s3_active_area;
    logic s3_hsync, s3_vsync;
    logic s3_is_border;
    logic s3_is_grid;
    logic s3_is_grid_line;
    logic s3_is_ghost;
    logic s3_is_next;
    logic s3_is_hold;
    logic [3:0] s3_cell_color_idx;
    logic s3_next_header;
    logic s3_hold_header;
    logic s3_hold_used_header;
    logic s3_score_header;
    logic s3_score_pixel;
    logic s3_level_header;
    logic s3_level_text_pixel;
    logic s3_level_bar_pixel;
    logic [3:0] s3_level_bar_color_idx;
    logic s3_heartbeat_pixel;
    logic s3_level_bar_border;
    
    always_ff @(posedge clk) begin
        // Pass through all flags
        s3_active_area <= s2_active_area;
        s3_hsync <= s2_hsync;
        s3_vsync <= s2_vsync;
        s3_is_border <= s2_is_border;
        s3_is_grid <= s2_is_grid;
        s3_is_grid_line <= s2_is_grid_line;
        s3_is_ghost <= s2_is_ghost;
        s3_is_next <= s2_is_next;
        s3_is_hold <= s2_is_hold;
        s3_cell_color_idx <= s2_cell_color_idx;
        s3_next_header <= s2_next_header;
        s3_hold_header <= s2_hold_header;
        s3_hold_used_header <= s2_hold_used_header;
        s3_score_header <= s2_score_header;
        s3_score_pixel <= s2_score_pixel;
        s3_level_header <= s2_level_header;
        s3_level_text_pixel <= s2_level_text_pixel;
        s3_level_bar_pixel <= s2_level_bar_pixel;
        s3_level_bar_color_idx <= s2_level_bar_color_idx;
        s3_heartbeat_pixel <= s2_heartbeat_pixel;
        s3_level_bar_border <= s2_level_bar_border;
    end

    // ======================================================================================
    // PIPELINE STAGE 4: Color Mapping & Final Output
    // ======================================================================================
    
    always_ff @(posedge clk) begin
        hsync_out <= s3_hsync;
        vsync_out <= s3_vsync;
        
        // Default: BLACK background
        vga_r <= 4'h0;
        vga_g <= 4'h0;
        vga_b <= 4'h0;
        
        if (s3_active_area) begin
            // 1. Grid Border - White
            if (s3_is_border) begin
                vga_r <= 4'hC; vga_g <= 4'hC; vga_b <= 4'hC;
            end
            
            // 2. Grid Lines - Dark Grey
            else if (s3_is_grid_line) begin
                vga_r <= 4'h3; vga_g <= 4'h3; vga_b <= 4'h3;
            end
            
            // 3. Grid Content (Blocks and Ghost)
            else if (s3_is_grid && (s3_cell_color_idx != 0 || s3_is_ghost)) begin
                automatic logic [3:0] r, g, b;
                automatic logic [3:0] inten = sprite_pixel[7:4];
                
                if (s3_is_ghost) begin
                    // Ghost piece - Semi-transparent white
                    r = 4'h5; g = 4'h5; b = 4'h5;
                end else begin
                    // Normal block rendering
                    if (game_over) begin
                        // Grey out blocks when game over
                        r = 4'h4; g = 4'h4; b = 4'h4;
                    end else begin
                        r = color_map[s3_cell_color_idx][11:8];
                        g = color_map[s3_cell_color_idx][7:4];
                        b = color_map[s3_cell_color_idx][3:0];
                    end
                end
                
                // Apply sprite shading
                if (inten != 4'hF) begin
                    vga_r <= r >> 1;
                    vga_g <= g >> 1;
                    vga_b <= b >> 1;
                end else begin
                    vga_r <= r;
                    vga_g <= g;
                    vga_b <= b;
                end
            end
            
            // 4. Next Piece Header - Bright White
            else if (s3_next_header) begin
                vga_r <= 4'hF; vga_g <= 4'hF; vga_b <= 4'hF;
            end
            // Next Piece Blocks
            else if (s3_is_next && s3_cell_color_idx != 0) begin
                automatic logic [3:0] r, g, b;
                automatic logic [3:0] inten = sprite_pixel[7:4];
                
                r = color_map[s3_cell_color_idx][11:8];
                g = color_map[s3_cell_color_idx][7:4];
                b = color_map[s3_cell_color_idx][3:0];
                
                if (inten != 4'hF) begin
                    vga_r <= r >> 1; vga_g <= g >> 1; vga_b <= b >> 1;
                end else begin
                    vga_r <= r; vga_g <= g; vga_b <= b;
                end
            end
            
            // 5. Hold Piece Header
            else if (s3_hold_header) begin
                if (s3_hold_used_header) begin
                    // Grayed out when used
                    vga_r <= 4'h5; vga_g <= 4'h5; vga_b <= 4'h5;
                end else begin
                    // Bright cyan when available
                    vga_r <= 4'h0; vga_g <= 4'hE; vga_b <= 4'hE;
                end
            end
            // Hold Piece Blocks
            else if (s3_is_hold && s3_cell_color_idx != 0) begin
                automatic logic [3:0] r, g, b;
                automatic logic [3:0] inten = sprite_pixel[7:4];
                
                if (hold_used) begin 
                    // Dim when used
                    r = 4'h4; g = 4'h4; b = 4'h4;
                end else begin
                    r = color_map[s3_cell_color_idx][11:8];
                    g = color_map[s3_cell_color_idx][7:4];
                    b = color_map[s3_cell_color_idx][3:0];
                end
                
                if (inten != 4'hF) begin
                    vga_r <= r >> 1; vga_g <= g >> 1; vga_b <= b >> 1;
                end else begin
                    vga_r <= r; vga_g <= g; vga_b <= b;
                end
            end
            
            // 6. Score Header - Yellow/Gold
            else if (s3_score_header) begin
                vga_r <= 4'hF; vga_g <= 4'hC; vga_b <= 4'h0;
            end
            // Score Numbers - White
            else if (s3_score_pixel) begin
                vga_r <= 4'hF; vga_g <= 4'hF; vga_b <= 4'hF;
            end
            
            // 7. Level Text - Cyan
            else if (s3_level_header && s3_level_text_pixel) begin
                vga_r <= 4'h0; vga_g <= 4'hD; vga_b <= 4'hD;
            end
            // Level Bar Border - Light grey
            else if (s3_level_bar_border) begin
                vga_r <= 4'h8; vga_g <= 4'h8; vga_b <= 4'h8;
            end
            // Level Bar - Gradient based on level
            else if (s3_level_bar_pixel) begin
                case (s3_level_bar_color_idx)
                    0: begin vga_r <= 4'h0; vga_g <= 4'hE; vga_b <= 4'h0; end  // Bright Green (easy)
                    1: begin vga_r <= 4'hF; vga_g <= 4'hC; vga_b <= 4'h0; end  // Orange (medium)
                    2: begin vga_r <= 4'hF; vga_g <= 4'h0; vga_b <= 4'h0; end  // Red (hard)
                    default: begin vga_r <= 4'h0; vga_g <= 4'hE; vga_b <= 4'h0; end
                endcase
            end
            
            // 8. Heartbeat - Blinking white when game over
            else if (s3_heartbeat_pixel) begin
                vga_r <= 4'hF; vga_g <= 4'hF; vga_b <= 4'hF;
            end
        end
        // Outside active area, stays black (default)
    end

endmodule