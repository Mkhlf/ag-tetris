`timescale 1ns / 1ps

module draw_tetris(
    input  wire logic clk,
    input  wire logic [10:0] curr_x,
    input  wire logic [9:0]  curr_y,
    input  wire logic active_area,
    input  wire logic [3:0] grid [0:19][0:9],
    input  wire logic [3:0] current_piece_type,
    input  wire logic [1:0] current_rotation,
    input  wire logic signed [4:0] current_x,
    input  wire logic signed [5:0] current_y,
    input  wire logic game_over,
    
    // Sprite Interface
    output logic [3:0] sprite_addr_x,
    output logic [3:0] sprite_addr_y,
    input  wire logic [11:0] sprite_pixel,
    
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b
    );

    // Screen Layout
    // Block Size: 32x32 pixels (Scaled up from 16x16 sprite? Or just use 16x16?)
    // 1280x800 screen.
    // Grid: 10x20.
    // If block is 32x32: Grid is 320x640.
    // Center it.
    // Screen Center X: 640. Grid Start X: 640 - 160 = 480.
    // Screen Center Y: 400. Grid Start Y: 400 - 320 = 80.
    
    localparam BLOCK_SIZE = 32;
    localparam GRID_X_START = 480;
    localparam GRID_Y_START = 80;
    localparam GRID_W = 320;
    localparam GRID_H = 640;

    // Colors
    logic [11:0] color_map [0:7];
    initial begin
        color_map[0] = 12'h000; // Empty (Black)
        color_map[1] = 12'hF00; // I - Red (Actually Cyan usually, but let's use Red)
        color_map[2] = 12'h0F0; // J - Green
        color_map[3] = 12'h00F; // L - Blue
        color_map[4] = 12'hFF0; // O - Yellow
        color_map[5] = 12'hF0F; // S - Magenta
        color_map[6] = 12'h0FF; // T - Cyan
        color_map[7] = 12'hFA0; // Z - Orange
    end

    // Shape definitions (Copy from game logic for rendering current piece)
    logic [15:0] shapes [0:6][0:3];
    initial begin
        // Same shapes as tetris_game.sv
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
        shapes[4][3] = 16'b1000_1100_0100_0000;
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

    // Coordinate Transformation
    logic signed [11:0] rel_x, rel_y;
    assign rel_x = curr_x - GRID_X_START;
    assign rel_y = curr_y - GRID_Y_START;
    
    logic [4:0] grid_col;
    logic [5:0] grid_row;
    assign grid_col = rel_x / BLOCK_SIZE;
    assign grid_row = rel_y / BLOCK_SIZE;
    
    logic [4:0] block_pixel_x;
    logic [4:0] block_pixel_y;
    assign block_pixel_x = rel_x % BLOCK_SIZE;
    assign block_pixel_y = rel_y % BLOCK_SIZE;
    
    // Sprite Address (Scale 32x32 down to 16x16: divide by 2)
    assign sprite_addr_x = block_pixel_x[4:1];
    assign sprite_addr_y = block_pixel_y[4:1];

    // Determine Pixel Color
    logic [3:0] cell_color_idx;
    logic is_current_piece;
    
    always_comb begin
        cell_color_idx = 0;
        is_current_piece = 0;
        
        if (curr_x >= GRID_X_START && curr_x < GRID_X_START + GRID_W &&
            curr_y >= GRID_Y_START && curr_y < GRID_Y_START + GRID_H) begin
            
            // Check Grid
            if (grid[grid_row][grid_col] != 0) begin
                cell_color_idx = grid[grid_row][grid_col];
            end
            
            // Check Current Piece
            // Calculate relative position to current piece
            // (grid_col - current_x)
            // (grid_row - current_y)
            // Check if within 0..3
            if (grid_col >= current_x && grid_col < current_x + 4 &&
                grid_row >= current_y && grid_row < current_y + 4) begin
                
                int r, c;
                r = grid_row - current_y;
                c = grid_col - current_x;
                
                if (shapes[current_piece_type][current_rotation][r*4 + c]) begin
                    cell_color_idx = current_piece_type + 1;
                    is_current_piece = 1;
                end
            end
        end
    end

    // Output Logic
    always_comb begin
        if (!active_area) begin
            vga_r = 0; vga_g = 0; vga_b = 0;
        end else begin
            if (curr_x >= GRID_X_START - 2 && curr_x < GRID_X_START + GRID_W + 2 &&
                curr_y >= GRID_Y_START - 2 && curr_y < GRID_Y_START + GRID_H + 2 &&
                !(curr_x >= GRID_X_START && curr_x < GRID_X_START + GRID_W &&
                  curr_y >= GRID_Y_START && curr_y < GRID_Y_START + GRID_H)) begin
                // Border (White)
                vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'hF;
            end else if (cell_color_idx != 0) begin
                // Draw Block with Sprite Texture
                // Multiply sprite pixel (white/grey) with color
                // Simple modulation: (Sprite * Color) >> 4 ?
                // Or just use Sprite brightness to scale Color.
                // Sprite is 12-bit RGB (4,4,4).
                // Let's just take the Green component of sprite as intensity (since it's greyscale).
                logic [3:0] intensity;
                intensity = sprite_pixel[7:4];
                
                // Modulate
                vga_r = (color_map[cell_color_idx][11:8] & intensity); // Simple AND for tint? No, that's bad.
                // Let's just use the sprite if it's not white?
                // Actually, let's just return the solid color for now to be safe, 
                // OR use the sprite pixel directly if we had colored sprites.
                // But we have one grey sprite.
                // Let's just output the color map value.
                vga_r = color_map[cell_color_idx][11:8];
                vga_g = color_map[cell_color_idx][7:4];
                vga_b = color_map[cell_color_idx][3:0];
                
                // Apply texture (simple darkening for borders)
                if (intensity != 4'hF) begin
                    vga_r = vga_r >> 1;
                    vga_g = vga_g >> 1;
                    vga_b = vga_b >> 1;
                end
            end else begin
                // Background (Black)
                vga_r = 0; vga_g = 0; vga_b = 0;
            end
        end
    end

endmodule
