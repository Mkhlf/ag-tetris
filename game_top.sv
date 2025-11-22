`timescale 1ns / 1ps

module game_top(
    input  wire logic CLK100MHZ,
    input  wire logic CPU_RESETN, // Active Low
    input  wire logic PS2_CLK,
    input  wire logic PS2_DATA,
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

    // Keyboard
    logic key_left, key_right, key_down, key_rotate, key_drop;
    
    ps2_keyboard kb_inst (
        .clk(pix_clk),
        .rst(rst),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop)
    );

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

    // VGA Output
    logic [10:0] curr_x;
    logic [9:0]  curr_y;
    logic active_area;
    
    vga_out vga_inst (
        .clk(pix_clk),
        .rst(rst),
        .curr_x(curr_x),
        .curr_y(curr_y),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .active_area(active_area)
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

    // Drawing Logic
    draw_tetris draw_inst (
        .clk(pix_clk),
        .curr_x(curr_x),
        .curr_y(curr_y),
        .active_area(active_area),
        .grid(grid),
        .current_piece_type(current_piece_type),
        .current_rotation(current_rotation),
        .current_x(current_x),
        .current_y(current_y),
        .game_over(game_over),
        .sprite_addr_x(sprite_addr_x),
        .sprite_addr_y(sprite_addr_y),
        .sprite_pixel(sprite_pixel),
        .vga_r(VGA_R),
        .vga_g(VGA_G),
        .vga_b(VGA_B)
    );

endmodule
