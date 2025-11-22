`timescale 1ns / 1ps

module game_top(
    input  wire logic CLK100MHZ,
    input  wire logic CPU_RESETN, // Active Low
    input  wire logic PS2_CLK,
    input  wire logic PS2_DATA,
    input  wire logic btn_l,
    input  wire logic btn_r,
    input  wire logic btn_u,
    input  wire logic btn_d,
    input  wire logic btn_c,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic VGA_HS,
    output logic VGA_VS
    );

    logic rst;
    assign rst = ~CPU_RESETN;

    // Clock Generation
    logic pix_clk; // 83.46 MHz (approx)
    logic locked;
    
    // Instantiate Clock Wizard (Assuming clk_wiz_0 exists as per README)
    // If not, we might need to use a simple divider or assume the user will add it.
    // I will instantiate it as a black box.
    clk_wiz_0 clk_gen (
        .clk_in1(CLK100MHZ),
        .clk_out1(pix_clk),
        .reset(rst),
        .locked(locked)
    );

    // Game Tick Generation (60Hz)
    // 83.46 MHz / 60 Hz ~= 1,391,000
    logic [20:0] tick_counter;
    logic tick_game;
    
    always_ff @(posedge pix_clk) begin
        if (rst) begin
            tick_counter <= 0;
            tick_game <= 0;
        end else begin
            if (tick_counter == 1391000) begin
                tick_counter <= 0;
                tick_game <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                tick_game <= 0;
            end
        end
    end

    // Keyboard & Buttons
    logic key_left_ps2, key_right_ps2, key_down_ps2, key_rotate_ps2, key_drop_ps2;
    
    ps2_keyboard kb_inst (
        .clk(pix_clk),
        .rst(rst),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .key_left(key_left_ps2),
        .key_right(key_right_ps2),
        .key_down(key_down_ps2),
        .key_rotate(key_rotate_ps2),
        .key_drop(key_drop_ps2)
    );

    // Combine Inputs
    logic key_left, key_right, key_down, key_rotate, key_drop;
    assign key_left   = key_left_ps2   | btn_l;
    assign key_right  = key_right_ps2  | btn_r;
    assign key_down   = key_down_ps2   | btn_d;
    assign key_rotate = key_rotate_ps2 | btn_u; // Up for Rotate
    assign key_drop   = key_drop_ps2   | btn_c; // Center for Drop (or Space)

    // Game Logic
    logic [3:0] grid [0:19][0:9];
    logic [3:0] current_piece_type;
    logic [1:0] current_rotation;
    logic signed [4:0] current_x;
    logic signed [5:0] current_y;
    logic game_over;

    tetris_game game_inst (
        .clk(pix_clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop),
        .grid(grid),
        .current_piece_type(current_piece_type),
        .current_rotation(current_rotation),
        .current_x(current_x),
        .current_y(current_y),
        .game_over(game_over)
    );

    // VGA Output (Raw)
    logic [10:0] curr_x_raw;
    logic [9:0]  curr_y_raw;
    logic active_area_raw;
    logic hsync_raw, vsync_raw;
    
    vga_out vga_inst (
        .clk(pix_clk),
        .rst(rst),
        .curr_x(curr_x_raw),
        .curr_y(curr_y_raw),
        .hsync(hsync_raw),
        .vsync(vsync_raw),
        .active_area(active_area_raw)
    );

    // Sprite ROM
    logic [3:0] sprite_addr_x;
    logic [3:0] sprite_addr_y;
    logic [11:0] sprite_pixel;
    
    block_sprite sprite_inst (
        .clk(pix_clk),
        .addr_x(sprite_addr_x),
        .addr_y(sprite_addr_y),
        .pixel_out(sprite_pixel)
    );

    // Drawing Logic (Raw)
    logic [3:0] vga_r_raw, vga_g_raw, vga_b_raw;

    draw_tetris draw_inst (
        .clk(pix_clk),
        .curr_x(curr_x_raw),
        .curr_y(curr_y_raw),
        .active_area(active_area_raw),
        .grid(grid),
        .current_piece_type(current_piece_type),
        .current_rotation(current_rotation),
        .current_x(current_x),
        .current_y(current_y),
        .game_over(game_over),
        .sprite_addr_x(sprite_addr_x),
        .sprite_addr_y(sprite_addr_y),
        .sprite_pixel(sprite_pixel),
        .vga_r(vga_r_raw),
        .vga_g(vga_g_raw),
        .vga_b(vga_b_raw)
    );

    // Output Pipeline (Fix Ghosting)
    // Register the renderer outputs and coordinates to stabilize per-pixel color
    // and maintain alignment between position and color
    // Note: curr_x/y are not outputs of top, but if we needed them we'd register them too.
    // We definitely need to register HSYNC/VSYNC to match the color delay.
    
    always_ff @(posedge pix_clk) begin
        VGA_R <= vga_r_raw;
        VGA_G <= vga_g_raw;
        VGA_B <= vga_b_raw;
        VGA_HS <= hsync_raw;
        VGA_VS <= vsync_raw;
    end

endmodule
