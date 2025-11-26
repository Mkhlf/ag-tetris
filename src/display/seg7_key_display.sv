`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 7-Segment Display for Keyboard Input Visualization
// Shows which Tetris control key is currently pressed:
//   - "L" for Left Arrow
//   - "r" for Right Arrow  
//   - "d" for Down Arrow
//   - "U" for Up Arrow (Rotate)
//   - "H" for Hold (Left Shift)
//   - "S" for Space (Hard Drop)
//   - "----" when no key pressed
//
// Uses 4 digits to show key name and scan code
//////////////////////////////////////////////////////////////////////////////////

module seg7_key_display(
    input  logic        clk,           // System clock (100MHz)
    input  logic        rst,
    
    // Current key state
    input  logic [7:0]  scan_code,     // Current scan code
    input  logic        key_valid,     // Key is valid (pressed)
    
    // Active key indicators (directly from game)
    input  logic        key_left,
    input  logic        key_right,
    input  logic        key_down,
    input  logic        key_rotate,
    input  logic        key_drop,
    input  logic        key_hold,
    
    // 7-Segment outputs
    output logic [6:0]  SEG,           // Segment pattern (active low)
    output logic [7:0]  AN,            // Anode select (active low)
    output logic        DP             // Decimal point (active low)
);

    // Clock divider for multiplexing (need ~1kHz refresh rate)
    // 100MHz / 2^17 ≈ 763 Hz
    logic [19:0] clk_div;
    logic [2:0] digit_sel;
    
    always_ff @(posedge clk) begin
        if (rst)
            clk_div <= 0;
        else
            clk_div <= clk_div + 1;
    end
    
    assign digit_sel = clk_div[19:17];
    
    // Determine what to display based on active key
    // Priority: Drop > Hold > Rotate > Left > Right > Down
    logic [3:0] display_char [0:7];  // Character for each digit
    
    // Character encoding for 7-segment (active low)
    // Segments: gfedcba
    function logic [6:0] char_to_seg(input [3:0] c);
        case (c)
            // Numbers
            4'h0: return 7'b1000000; // 0
            4'h1: return 7'b1111001; // 1
            4'h2: return 7'b0100100; // 2
            4'h3: return 7'b0110000; // 3
            4'h4: return 7'b0011001; // 4
            4'h5: return 7'b0010010; // 5
            4'h6: return 7'b0000010; // 6
            4'h7: return 7'b1111000; // 7
            4'h8: return 7'b0000000; // 8
            4'h9: return 7'b0010000; // 9
            4'hA: return 7'b0001000; // A
            4'hB: return 7'b0000011; // b
            4'hC: return 7'b1000110; // C
            4'hD: return 7'b0100001; // d
            4'hE: return 7'b0000110; // E
            4'hF: return 7'b0001110; // F
            default: return 7'b1111111; // blank
        endcase
    endfunction
    
    // Special characters for key names
    localparam [6:0] SEG_L = 7'b1000111; // L
    localparam [6:0] SEG_r = 7'b0101111; // r (lowercase)
    localparam [6:0] SEG_d = 7'b0100001; // d (lowercase)
    localparam [6:0] SEG_U = 7'b1000001; // U
    localparam [6:0] SEG_H = 7'b0001001; // H
    localparam [6:0] SEG_S = 7'b0010010; // S (same as 5)
    localparam [6:0] SEG_P = 7'b0001100; // P
    localparam [6:0] SEG_o = 7'b0100011; // o (lowercase)
    localparam [6:0] SEG_t = 7'b0000111; // t (lowercase)
    localparam [6:0] SEG_n = 7'b0101011; // n (lowercase)
    localparam [6:0] SEG_DASH = 7'b0111111; // -
    localparam [6:0] SEG_BLANK = 7'b1111111; // blank
    
    // What to display on each digit
    logic [6:0] seg_data [0:7];
    
    always_comb begin
        // Default: show dashes (no key)
        seg_data[7] = SEG_DASH;  // Leftmost
        seg_data[6] = SEG_DASH;
        seg_data[5] = SEG_DASH;
        seg_data[4] = SEG_DASH;
        seg_data[3] = SEG_BLANK;
        seg_data[2] = SEG_BLANK;
        seg_data[1] = SEG_BLANK;
        seg_data[0] = SEG_BLANK; // Rightmost
        
        // Show key name on left 4 digits, scan code on right 2 digits
        if (key_drop) begin
            // "droP" for drop/space
            seg_data[7] = SEG_d;
            seg_data[6] = SEG_r;
            seg_data[5] = SEG_o;
            seg_data[4] = SEG_P;
            // Scan code 0x29
            seg_data[1] = 7'b0100100; // 2
            seg_data[0] = 7'b0010000; // 9
        end
        else if (key_hold) begin
            // "HoLd" for hold
            seg_data[7] = SEG_H;
            seg_data[6] = SEG_o;
            seg_data[5] = SEG_L;
            seg_data[4] = SEG_d;
            // Scan code 0x12
            seg_data[1] = 7'b1111001; // 1
            seg_data[0] = 7'b0100100; // 2
        end
        else if (key_rotate) begin
            // "rotE" for rotate (up arrow)
            seg_data[7] = SEG_r;
            seg_data[6] = SEG_o;
            seg_data[5] = SEG_t;
            seg_data[4] = 7'b0000110; // E
            // Scan code 0x75
            seg_data[1] = 7'b1111000; // 7
            seg_data[0] = 7'b0010010; // 5
        end
        else if (key_left) begin
            // "LEFt" for left
            seg_data[7] = SEG_L;
            seg_data[6] = 7'b0000110; // E
            seg_data[5] = 7'b0001110; // F
            seg_data[4] = SEG_t;
            // Scan code 0x6B
            seg_data[1] = 7'b0000010; // 6
            seg_data[0] = 7'b0000011; // b
        end
        else if (key_right) begin
            // "rGHt" for right
            seg_data[7] = SEG_r;
            seg_data[6] = 7'b1000010; // G (approximation)
            seg_data[5] = SEG_H;
            seg_data[4] = SEG_t;
            // Scan code 0x74
            seg_data[1] = 7'b1111000; // 7
            seg_data[0] = 7'b0011001; // 4
        end
        else if (key_down) begin
            // "doUn" for down
            seg_data[7] = SEG_d;
            seg_data[6] = SEG_o;
            seg_data[5] = SEG_U;
            seg_data[4] = SEG_n;
            // Scan code 0x72
            seg_data[1] = 7'b1111000; // 7
            seg_data[0] = 7'b0100100; // 2
        end
    end
    
    // Multiplex outputs
    always_comb begin
        // All anodes off by default
        AN = 8'b11111111;
        SEG = SEG_BLANK;
        DP = 1'b1; // DP off
        
        // Enable selected digit
        AN[digit_sel] = 1'b0;
        SEG = seg_data[digit_sel];
        
        // Add decimal point between key name and scan code
        if (digit_sel == 4)
            DP = 1'b0;
    end

endmodule

