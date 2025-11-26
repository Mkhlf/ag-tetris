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
    output logic [1:0] LED,     // Debug LEDs
    // 7-Segment Display
    output logic [6:0] SEG,     // Segment pattern (active low)
    output logic [7:0] AN,      // Anode select (active low)
    output logic       DP       // Decimal point (active low)
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
    // Note: key_event_valid_50 is now extended to 4 cycles (80ns) to ensure capture
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
    
    // Synchronize scan_code and make_break (they're stable during extended pulse)
    logic [7:0] scan_code_sync1, scan_code_sync2;
    logic make_break_sync1, make_break_sync2;
    
    always_ff @(posedge game_clk) begin
        if (rst) begin
            scan_code_sync1 <= 8'h00;
            scan_code_sync2 <= 8'h00;
            make_break_sync1 <= 1'b0;
            make_break_sync2 <= 1'b0;
        end else begin
            scan_code_sync1 <= scan_code_50;
            scan_code_sync2 <= scan_code_sync1;
            make_break_sync1 <= make_break_50;
            make_break_sync2 <= make_break_sync1;
        end
    end
    
    // For 7-segment display use
    logic [7:0] scan_code;
    logic make_break;
    assign scan_code = scan_code_sync2;
    assign make_break = make_break_sync2;
    
    // ========================================================================
    // Decode Raw Levels (Held State) - Now in game_clk domain
    // ========================================================================
    logic raw_left_kb, raw_right_kb, raw_down_kb, raw_rotate_cw_kb, raw_rotate_ccw_kb, raw_drop_kb, raw_hold_kb;
    
    always_ff @(posedge game_clk) begin
        if (rst) begin
            raw_left_kb <= 0; raw_right_kb <= 0; raw_down_kb <= 0;
            raw_rotate_cw_kb <= 0; raw_rotate_ccw_kb <= 0; raw_drop_kb <= 0; raw_hold_kb <= 0;
        end else if (key_event_pulse) begin
            // Use synchronized values - they're stable when pulse fires
            case (scan_code_sync2)
                `LEFT_ARROW_C:  raw_left_kb   <= make_break_sync2;
                `RIGHT_ARROW_C: raw_right_kb  <= make_break_sync2;
                `DOWN_ARROW_C:  raw_down_kb   <= make_break_sync2;
                `UP_ARROW_C:    raw_rotate_cw_kb <= make_break_sync2;
                `X_KEY_C:       raw_rotate_cw_kb <= make_break_sync2;
                `Z_KEY_C:       raw_rotate_ccw_kb <= make_break_sync2;
                `SPACE_C:       raw_drop_kb   <= make_break_sync2;
                `LSHIFT_C:      raw_hold_kb   <= make_break_sync2;
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
    logic raw_left, raw_right, raw_down, raw_rotate_cw, raw_rotate_ccw, raw_drop, raw_hold;
    assign raw_left   = raw_left_kb   | btn_l_db;
    assign raw_right  = raw_right_kb  | btn_r_db;
    assign raw_down   = raw_down_kb   | btn_d_db;
    assign raw_rotate_cw = raw_rotate_cw_kb | btn_u_db;
    assign raw_rotate_ccw = raw_rotate_ccw_kb;
    assign raw_drop   = raw_drop_kb   | btn_c_db;
    assign raw_hold   = raw_hold_kb;  // Hold only via keyboard (no button)

    // Input Manager (DAS & One-Shot)
    logic key_left, key_right, key_down, key_rotate_cw, key_rotate_ccw, key_drop, key_hold;
    
    input_manager input_mgr (
        .clk(game_clk),
        .rst(rst),
        .tick_game(tick_game),
        .raw_left(raw_left),
        .raw_right(raw_right),
        .raw_down(raw_down),
        .raw_rotate_cw(raw_rotate_cw),
        .raw_rotate_ccw(raw_rotate_ccw),
        .raw_drop(raw_drop),
        .raw_hold(raw_hold),
        .cmd_left(key_left),
        .cmd_right(key_right),
        .cmd_down(key_down),
        .cmd_rotate_cw(key_rotate_cw),
        .cmd_rotate_ccw(key_rotate_ccw),
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
    logic [7:0] total_lines_cleared; // NEW: For level bar
    
    game_control game_inst (
        .clk(game_clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate_cw(key_rotate_cw),
        .key_rotate_ccw(key_rotate_ccw),
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
        .t_curr_out(t_curr),
        .total_lines_cleared_out(total_lines_cleared)
    );


    // ========================================================================
    // CDC: Game State Synchronization (game_clk → pix_clk)
    // ========================================================================
    field_t display_field_sync;
    logic [31:0] score_sync;
    logic game_over_sync;
    tetromino_ctrl t_next_sync, t_hold_sync, t_curr_sync;
    logic hold_used_sync;
    logic [3:0] current_level_sync;
    logic [7:0] total_lines_cleared_sync;
    logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y_sync;

    // Double-register synchronizer for multi-bit buses
    always_ff @(posedge pix_clk) begin
        if (rst) begin
            display_field_sync <= '0;
            score_sync <= 0;
            game_over_sync <= 0;
            t_next_sync <= '0;
            t_hold_sync <= '0;
            t_curr_sync <= '0;
            hold_used_sync <= 0;
            current_level_sync <= 0;
            total_lines_cleared_sync <= 0;
            ghost_y_sync <= 0;
        end else begin
            display_field_sync <= display_field;
            score_sync <= score;
            game_over_sync <= game_over;
            t_next_sync <= t_next;
            t_hold_sync <= t_hold;
            t_curr_sync <= t_curr;
            hold_used_sync <= hold_used;
            current_level_sync <= current_level;
            total_lines_cleared_sync <= total_lines_cleared;
            ghost_y_sync <= ghost_y;
        end
    end

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
    logic hsync_pipelined, vsync_pipelined;

    draw_tetris draw_inst (
    .clk(pix_clk),
    .curr_x(curr_x_raw),
    .curr_y(curr_y_raw),
    .active_area(active_area_raw),
    .hsync_in(hsync_raw),
    .vsync_in(vsync_raw),

    .display(display_field_sync),        // ← Use synchronized
    .score(score_sync),                  // ← Use synchronized
    .game_over(game_over_sync),          // ← Use synchronized
    .t_next(t_next_sync),                // ← Use synchronized
    .t_hold(t_hold_sync),                // ← Use synchronized
    .hold_used(hold_used_sync),          // ← Use synchronized
    .current_level(current_level_sync),  // ← Use synchronized
    .total_lines_cleared(total_lines_cleared_sync), // ← Use synchronized
    .ghost_y(ghost_y_sync),              // ← Use synchronized
    .t_curr(t_curr_sync),                // ← Use synchronized

    .sprite_addr_x(sprite_addr_x),
    .sprite_addr_y(sprite_addr_y),
    .sprite_pixel(sprite_pixel),

    .vga_r(vga_r_raw),
    .vga_g(vga_g_raw),
    .vga_b(vga_b_raw),
    
    .hsync_out(hsync_pipelined),
    .vsync_out(vsync_pipelined)
);

    // Output Pipeline (Final Stage)
    // We keep this stage for clean output timing, effectively making it a 4-stage pipeline.
    always_ff @(posedge pix_clk) begin
        VGA_R <= vga_r_raw;
        VGA_G <= vga_g_raw;
        VGA_B <= vga_b_raw;
        VGA_HS <= hsync_pipelined;
        VGA_VS <= vsync_pipelined;
    end

    // ========================================================================
    // 7-Segment Display for Keyboard Input Visualization
    // ========================================================================
    seg7_key_display seg7_inst (
        .clk(CLK100MHZ),
        .rst(rst),
        .scan_code(scan_code),
        .key_valid(key_event_pulse),
        .key_left(raw_left),
        .key_right(raw_right),
        .key_down(raw_down),
        .key_rotate_cw(raw_rotate_cw),
        .key_rotate_ccw(raw_rotate_ccw),
        .key_drop(raw_drop),
        .key_hold(raw_hold),
        .SEG(SEG),
        .AN(AN),
        .DP(DP)
    );

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
