`include "../GLOBAL.sv"

// Simple 8x8 bitmap font for ASCII characters
// Only includes characters we need: A-Z, 0-9, -, space
module draw_string (
    input  logic [10:0] curr_x,
    input  logic [9:0]  curr_y,
    input  logic [10:0] pos_x,
    input  logic [9:0]  pos_y,
    input  logic [7:0]  char_code,  // ASCII character code
    output logic        pixel_on
);

    // 8x8 font ROM - each character is 8 bytes (8 bits wide, 8 rows tall)
    // Format: 8 rows of 8 bits each
    logic [63:0] font_data;
    
    always_comb begin
        case (char_code)
            // Space
            8'h20: font_data = 64'h0000000000000000;
            // Numbers
            8'h30: font_data = 64'h3C666E7666663C00; // 0
            8'h31: font_data = 64'h1818181818181800; // 1
            8'h32: font_data = 64'h3C060C1830607E00; // 2
            8'h33: font_data = 64'h3C06061C06063C00; // 3
            8'h34: font_data = 64'h060E1E667F060600; // 4
            8'h35: font_data = 64'h7E607C0606663C00; // 5
            8'h36: font_data = 64'h3C60607C66663C00; // 6
            8'h37: font_data = 64'h7E060C1818181800; // 7
            8'h38: font_data = 64'h3C66663C66663C00; // 8
            8'h39: font_data = 64'h3C66663E06063C00; // 9
            // Letters
            8'h41: font_data = 64'h3C66667E66666600; // A
            8'h42: font_data = 64'h7C66667C66667C00; // B
            8'h43: font_data = 64'h3C66606060663C00; // C
            8'h44: font_data = 64'h786C6666666C7800; // D
            8'h45: font_data = 64'h7E60607860607E00; // E
            8'h46: font_data = 64'h7E60607860606000; // F
            8'h47: font_data = 64'h3C66606E66663C00; // G
            8'h48: font_data = 64'h6666667E66666600; // H
            8'h49: font_data = 64'h3C18181818183C00; // I
            8'h4A: font_data = 64'h1E0C0C0C6C6C3800; // J
            8'h4B: font_data = 64'h666C7870786C6600; // K
            8'h4C: font_data = 64'h6060606060607E00; // L
            8'h4D: font_data = 64'h63777F6B63636300; // M
            8'h4E: font_data = 64'h66767E7E6E666600; // N
            8'h4F: font_data = 64'h3C66666666663C00; // O
            8'h50: font_data = 64'h7C66667C60606000; // P
            8'h51: font_data = 64'h3C66666E6C663A00; // Q
            8'h52: font_data = 64'h7C66667C786C6600; // R
            8'h53: font_data = 64'h3C60603C06063C00; // S
            8'h54: font_data = 64'h7E18181818181800; // T
            8'h55: font_data = 64'h6666666666663C00; // U
            8'h56: font_data = 64'h66666666663C1800; // V
            8'h57: font_data = 64'h63636B7F77636300; // W
            8'h58: font_data = 64'h66663C183C666600; // X
            8'h59: font_data = 64'h6666663C18181800; // Y
            8'h5A: font_data = 64'h7E060C1830607E00; // Z
            // Hyphen
            8'h2D: font_data = 64'h0000007E00000000; // -
            // Colon
            8'h3A: font_data = 64'h0000180000180000; // :
            default: font_data = 64'h0000000000000000;
        endcase
    end
    
    // Character dimensions
    localparam CHAR_W = 8;
    localparam CHAR_H = 8;
    localparam CHAR_SPACING = 1;
    
    logic [10:0] rel_x, rel_y;
    logic [2:0] pixel_x, pixel_y;
    
    assign rel_x = curr_x - pos_x;
    assign rel_y = curr_y - pos_y;
    
    assign pixel_x = rel_x[2:0];
    assign pixel_y = rel_y[2:0];
    
    always_comb begin
        pixel_on = 0;
        if (rel_x >= 0 && rel_x < CHAR_W && 
            rel_y >= 0 && rel_y < CHAR_H) begin
            // Font data is stored row-major, MSB first
            // Row pixel_y, bit (7 - pixel_x)
            if (font_data[63 - (pixel_y * 8 + (7 - pixel_x))]) begin
                pixel_on = 1;
            end
        end
    end

endmodule

// Helper module to draw a string of characters
module draw_string_line (
    input  logic [10:0] curr_x,
    input  logic [9:0]  curr_y,
    input  logic [10:0] pos_x,
    input  logic [9:0]  pos_y,
    input  logic [7:0]  str_chars [0:15],  // Up to 16 characters
    input  logic [3:0]  str_len,            // Actual string length
    output logic        pixel_on
);

    localparam CHAR_W = 8;
    localparam CHAR_SPACING = 1;
    localparam CHAR_TOTAL_W = CHAR_W + CHAR_SPACING;
    
    logic [10:0] rel_x, rel_y;
    logic [3:0] char_idx;
    logic [7:0] current_char;
    logic char_pixel_on;
    
    assign rel_x = curr_x - pos_x;
    assign rel_y = curr_y - pos_y;
    
    // Determine which character we're in
    assign char_idx = rel_x / CHAR_TOTAL_W;
    
    // Get the character code for this position
    always_comb begin
        if (char_idx < str_len) begin
            current_char = str_chars[char_idx];
        end else begin
            current_char = 8'h20; // Space
        end
    end
    
    // Calculate position within character
    logic [10:0] char_pos_x;
    assign char_pos_x = pos_x + (char_idx * CHAR_TOTAL_W);
    
    draw_string char_draw (
        .curr_x(curr_x),
        .curr_y(curr_y),
        .pos_x(char_pos_x),
        .pos_y(pos_y),
        .char_code(current_char),
        .pixel_on(char_pixel_on)
    );
    
    assign pixel_on = char_pixel_on;

endmodule

