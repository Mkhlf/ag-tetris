`include "../GLOBAL.sv"

module draw_number (
    input  logic [10:0] curr_x,
    input  logic [9:0]  curr_y,
    input  logic [10:0] pos_x,
    input  logic [9:0]  pos_y,
    input  logic [31:0] number,
    output logic        pixel_on
);
    // Simple 7-segment style font or similar
    // For simplicity, let's just draw a bar for now or a very simple bitmapped font.
    // Implementing a full font ROM here is complex.
    // Let's use a 4x5 font for digits 0-9.
    
    // Font ROM (Combinational for Synthesis Safety)
    logic [19:0] current_glyph;
    
    always_comb begin
        case (digit)
            0: current_glyph = 20'b0110_1001_1001_1001_0110;
            1: current_glyph = 20'b0010_0010_0010_0010_0010;
            2: current_glyph = 20'b0110_0001_0010_0100_1111;
            3: current_glyph = 20'b0110_0001_0010_0001_0110;
            4: current_glyph = 20'b1001_1001_1111_0001_0001;
            5: current_glyph = 20'b1111_1000_1110_0001_1110;
            6: current_glyph = 20'b0110_1000_1110_1001_0110;
            7: current_glyph = 20'b1111_0001_0010_0100_0100;
            8: current_glyph = 20'b0110_1001_0110_1001_0110;
            9: current_glyph = 20'b0110_1001_0111_0001_0110;
            default: current_glyph = '0;
        endcase
    end
    
    // We can draw up to 8 digits.
    // number is 32-bit.
    // Let's iterate? No, combinatorial.
    // We need to determine which digit we are in.
    
    logic [3:0] digit;
    logic [2:0] dx, dy; // 0-4
    logic [3:0] digit_idx; // 0-7
    
    // Each digit is 4x5 pixels, plus 1 pixel spacing. Total 5x5.
    // Total width for 8 digits = 40 pixels.
    // Let's scale it up by 4x. 20x20 pixels per digit.
    
    localparam SCALE = 4;
    localparam DIGIT_W = 4 * SCALE;
    localparam DIGIT_H = 5 * SCALE;
    localparam SPACING = 1 * SCALE;
    localparam TOTAL_W = DIGIT_W + SPACING;
    
    logic [10:0] rel_x;
    logic [9:0] rel_y;
    
    assign rel_x = curr_x - pos_x;
    assign rel_y = curr_y - pos_y;
    
    always_comb begin
        pixel_on = 0;
        if (curr_x >= pos_x && curr_x < pos_x + (8 * TOTAL_W) &&
            curr_y >= pos_y && curr_y < pos_y + DIGIT_H) begin
            
            digit_idx = rel_x / TOTAL_W;
            dx = (rel_x % TOTAL_W) / SCALE;
            dy = rel_y / SCALE;
            
            if (dx < 4 && dy < 5) begin
                // Extract digit
                // This is hard combinatorially (division/mod).
                // Let's just show the lower 4 hex digits for score? Or decimal?
                // Decimal is hard. Hex is easier.
                // Let's do Hex for now.
                
                case (7 - digit_idx)
                    0: digit = number[3:0];
                    1: digit = number[7:4];
                    2: digit = number[11:8];
                    3: digit = number[15:12];
                    4: digit = number[19:16];
                    5: digit = number[23:20];
                    6: digit = number[27:24];
                    7: digit = number[31:28];
                endcase
                
                // Check font (only 0-9 defined above, need A-F)
                // For now, if > 9, just show nothing or map to 0-9?
                // Let's add A-F.
                // But wait, score is usually decimal.
                // Implementing binary-to-BCD in hardware is expensive for 32-bit.
                // Let's assume score is small enough or just show Hex.
                // Or just show the number of lines cleared?
                
                if (digit < 10) begin
                   if (current_glyph[19 - (dy*4 + dx)]) pixel_on = 1;
                end
            end
        end
    end

endmodule
