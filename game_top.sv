`include "src/GLOBAL.sv"

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
    output logic VGA_VS,
    output logic [1:0] LED // Debug LEDs
    );

    logic rst;
    assign rst = ~CPU_RESETN;
    
    // Debug LEDs - PS/2 Hardware Signals
    // NOTE: PS/2 uses pull-ups, so lines are HIGH when idle/disconnected
    // With keyboard active (typing), you'll see flickering/blinking
    // LED[0] = PS2_CLK (will flicker when keyboard sends data)
    // LED[1] = PS2_DATA (will change based on transmitted bits)
    assign LED[0] = PS2_CLK;
    assign LED[1] = PS2_DATA;

    // Clock Generation
    logic pix_clk; // 83.46 MHz (approx)
    logic locked;
    
    // Instantiate Clock Wizard
    clk_wiz_0 clk_gen (
        .clk_in1(CLK100MHZ),
        .clk_out1(pix_clk),
        .reset(rst),
        .locked(locked)
    );

    // PS2 Clock Generation (50 MHz) - Better for PS2 protocol timing
    // Divide 100MHz by 2
    logic ps2_clk_50mhz;
    always_ff @(posedge CLK100MHZ) begin
        if (rst) ps2_clk_50mhz <= 0;
        else ps2_clk_50mhz <= ~ps2_clk_50mhz;
    end

    // Game Clock Generation (25 MHz)
    // Divide 100MHz by 4
    logic [1:0] clk_div;
    logic game_clk;
    
    always_ff @(posedge CLK100MHZ) begin
        if (rst) clk_div <= 0;
        else clk_div <= clk_div + 1;
    end
    assign game_clk = clk_div[1]; // 25 MHz

    // Game Tick Generation (60Hz)
    // 25 MHz / 60 Hz ~= 416,666
    logic [18:0] tick_counter;
    logic tick_game;
    
    always_ff @(posedge game_clk) begin
        if (rst) begin
            tick_counter <= 0;
            tick_game <= 0;
        end else begin
            if (tick_counter == 416666) begin
                tick_counter <= 0;
                tick_game <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                tick_game <= 0;
            end
        end
    end

    // ========================================================================
    // PS2 Keyboard Input (50MHz domain)
    // ========================================================================
    logic [7:0] scan_code_50;
    logic make_break_50;
    logic key_event_valid_50;
    
    ps2_keyboard kb_inst (
        .clk(ps2_clk_50mhz),
        .rst(rst),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .current_scan_code(scan_code_50),
        .current_make_break(make_break_50),
        .key_event_valid(key_event_valid_50)
    );
    
    // ========================================================================
    // CDC: Clock Domain Crossing from 50MHz to 25MHz (game_clk)
    // ========================================================================
    // Synchronize key_event_valid pulse to game_clk domain
    logic key_event_sync1, key_event_sync2, key_event_sync3;
    logic key_event_pulse;
    
    always_ff @(posedge game_clk) begin
        if (rst) begin
            key_event_sync1 <= 0;
            key_event_sync2 <= 0;
            key_event_sync3 <= 0;
        end else begin
            key_event_sync1 <= key_event_valid_50;
            key_event_sync2 <= key_event_sync1;
            key_event_sync3 <= key_event_sync2;
        end
    end
    
    // Detect rising edge in game_clk domain
    assign key_event_pulse = key_event_sync2 & ~key_event_sync3;
    
    // Latch scan_code and make_break when event detected
    // (These signals are stable when key_event_valid is high)
    logic [7:0] scan_code;
    logic make_break;
    
    always_ff @(posedge game_clk) begin
        if (rst) begin
            scan_code <= 8'h00;
            make_break <= 1'b0;
        end else if (key_event_pulse) begin
            scan_code <= scan_code_50;
            make_break <= make_break_50;
        end
    end
    
    // ========================================================================
    // Decode Raw Levels (Held State) - Now in game_clk domain
    // ========================================================================
    logic raw_left_kb, raw_right_kb, raw_down_kb, raw_rotate_kb, raw_drop_kb, raw_hold_kb;
    
    always_ff @(posedge game_clk) begin
        if (rst) begin
            raw_left_kb <= 0; raw_right_kb <= 0; raw_down_kb <= 0;
            raw_rotate_kb <= 0; raw_drop_kb <= 0; raw_hold_kb <= 0;
        end else if (key_event_pulse) begin
            // Update state based on scan code event
            case (scan_code)
                `LEFT_ARROW_C:  raw_left_kb   <= make_break;
                `RIGHT_ARROW_C: raw_right_kb  <= make_break;
                `DOWN_ARROW_C:  raw_down_kb   <= make_break;
                `UP_ARROW_C:    raw_rotate_kb <= make_break;
                `SPACE_C:       raw_drop_kb   <= make_break;
                `LSHIFT_C:      raw_hold_kb   <= make_break;
                default: ; // No change for other keys
            endcase
        end
    end

    // Debounce Buttons (use separate debouncer for buttons, different timing)
    logic btn_l_db, btn_r_db, btn_u_db, btn_d_db, btn_c_db;
    logic unused_db;
    
    // Button debouncer with longer timing for mechanical buttons
    debouncer_btn db_lr (
        .clk(game_clk),
        .I0(btn_l), .I1(btn_r),
        .O0(btn_l_db), .O1(btn_r_db)
    );
    
    debouncer_btn db_ud (
        .clk(game_clk),
        .I0(btn_u), .I1(btn_d),
        .O0(btn_u_db), .O1(btn_d_db)
    );
    
    debouncer_btn db_c (
        .clk(game_clk),
        .I0(btn_c), .I1(1'b0),
        .O0(btn_c_db), .O1(unused_db)
    );

    // Combine with Buttons (Active High)
    logic raw_left, raw_right, raw_down, raw_rotate, raw_drop, raw_hold;
    assign raw_left   = raw_left_kb   | btn_l_db;
    assign raw_right  = raw_right_kb  | btn_r_db;
    assign raw_down   = raw_down_kb   | btn_d_db;
    assign raw_rotate = raw_rotate_kb | btn_u_db;
    assign raw_drop   = raw_drop_kb   | btn_c_db;
    assign raw_hold   = raw_hold_kb;  // Hold only via keyboard (no button)

    // Input Manager (DAS & One-Shot)
    logic key_left, key_right, key_down, key_rotate, key_drop, key_hold;
    
    input_manager input_mgr (
        .clk(game_clk),
        .rst(rst),
        .tick_game(tick_game),
        .raw_left(raw_left),
        .raw_right(raw_right),
        .raw_down(raw_down),
        .raw_rotate(raw_rotate),
        .raw_drop(raw_drop),
        .raw_hold(raw_hold),
        .cmd_left(key_left),
        .cmd_right(key_right),
        .cmd_down(key_down),
        .cmd_rotate(key_rotate),
        .cmd_drop(key_drop),
        .cmd_hold(key_hold)
    );

    // Game Logic
    field_t display_field;
    logic [31:0] score;
    logic game_over;
    tetromino_ctrl t_next; // Next piece signal
    tetromino_ctrl t_hold; // Hold piece signal
    logic hold_used;       // Hold was used this piece
    logic [3:0] current_level;
    logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y;
    tetromino_ctrl t_curr;
    
    game_control game_inst (
        .clk(game_clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop),
        .key_hold(key_hold),
        .key_drop_held(raw_drop), // Connect raw state for lockout
        .display(display_field),
        .score(score),
        .game_over(game_over),
        .t_next_disp(t_next),
        .t_hold_disp(t_hold),
        .hold_used_out(hold_used),
        .current_level_out(current_level),
        .ghost_y(ghost_y),
        .t_curr_out(t_curr)
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
        .display(display_field),
        .score(score),
        .game_over(game_over),
        .t_next(t_next),
        .t_hold(t_hold),
        .hold_used(hold_used),
        .current_level(current_level),
        .ghost_y(ghost_y),
        .t_curr(t_curr),
        .sprite_addr_x(sprite_addr_x),
        .sprite_addr_y(sprite_addr_y),
        .sprite_pixel(sprite_pixel),
        .vga_r(vga_r_raw),
        .vga_g(vga_g_raw),
        .vga_b(vga_b_raw)
    );

    // Output Pipeline (Fix Ghosting)
    always_ff @(posedge pix_clk) begin
        VGA_R <= vga_r_raw;
        VGA_G <= vga_g_raw;
        VGA_B <= vga_b_raw;
        VGA_HS <= hsync_raw;
        VGA_VS <= vsync_raw;
    end

endmodule

// ============================================================================
// Button Debouncer (longer timing for mechanical buttons)
// ============================================================================
module debouncer_btn(
    input clk,
    input I0,
    input I1,
    output reg O0,
    output reg O1
    );
    
    // Use larger counter for button debouncing (~10ms at 25MHz)
    reg [17:0] cnt0, cnt1;
    reg Iv0 = 0, Iv1 = 0;
    
    localparam CNT_MAX = 250000; // ~10ms at 25MHz

always @(posedge clk) begin
    // Debounce I0
    if (I0 == Iv0) begin
        if (cnt0 == CNT_MAX) 
            O0 <= I0;
        else 
            cnt0 <= cnt0 + 1;
    end else begin
        cnt0 <= 18'b0;
        Iv0 <= I0;
    end
    
    // Debounce I1
    if (I1 == Iv1) begin
        if (cnt1 == CNT_MAX) 
            O1 <= I1;
        else 
            cnt1 <= cnt1 + 1;
    end else begin
        cnt1 <= 18'b0;
        Iv1 <= I1;
    end
end
    
endmodule
