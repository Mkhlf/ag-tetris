`timescale 1ns / 1ps

module ps2_keyboard(
    input  wire logic clk,
    input  wire logic rst,
    input  wire logic ps2_clk,
    input  wire logic ps2_data,
    output logic key_left,
    output logic key_right,
    output logic key_down,
    output logic key_rotate, // Up Arrow or Z
    output logic key_drop    // Space
    );

    logic [31:0] keycode;
    logic [31:0] prev_keycode;

    PS2Receiver ps2_rx (
        .clk(clk),
        .kclk(ps2_clk),
        .kdata(ps2_data),
        .keycodeout(keycode)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            key_left <= 0;
            key_right <= 0;
            key_down <= 0;
            key_rotate <= 0;
            key_drop <= 0;
            prev_keycode <= 0;
        end else begin
            if (keycode != prev_keycode) begin
                prev_keycode <= keycode;
                
                // Decode Logic
                // keycode[7:0] is the newest byte
                // keycode[15:8] is the previous byte
                // keycode[23:16] is the byte before that
                
                // Extended Keys (Arrows)
                // Press: E0 XX
                // Release: E0 F0 XX
                
                // Normal Keys (Space)
                // Press: XX
                // Release: F0 XX
                
                logic [7:0] new_byte;
                logic [7:0] prev_byte;
                logic [7:0] prev_prev_byte;
                
                new_byte = keycode[7:0];
                prev_byte = keycode[15:8];
                prev_prev_byte = keycode[23:16];
                
                // Check for Release (F0 XX or E0 F0 XX)
                if (prev_byte == 8'hF0) begin
                    // Normal Release
                    case (new_byte)
                        8'h29: key_drop <= 0; // Space
                        8'h1C: key_left <= 0; // A
                        8'h23: key_right <= 0; // D
                        8'h1B: key_down <= 0; // S
                        8'h1D: key_rotate <= 0; // W
                    endcase
                    
                    // Extended Release (E0 F0 XX)
                    if (prev_prev_byte == 8'hE0) begin
                        case (new_byte)
                            8'h6B: key_left <= 0; // Left Arrow
                            8'h74: key_right <= 0; // Right Arrow
                            8'h72: key_down <= 0; // Down Arrow
                            8'h75: key_rotate <= 0; // Up Arrow
                        endcase
                    end
                end
                // Check for Press (Not F0)
                else if (new_byte != 8'hF0 && new_byte != 8'hE0) begin
                    // Extended Press (E0 XX)
                    if (prev_byte == 8'hE0) begin
                        case (new_byte)
                            8'h6B: key_left <= 1; // Left Arrow
                            8'h74: key_right <= 1; // Right Arrow
                            8'h72: key_down <= 1; // Down Arrow
                            8'h75: key_rotate <= 1; // Up Arrow
                        endcase
                    end
                    // Normal Press (XX)
                    else begin
                        case (new_byte)
                            8'h29: key_drop <= 1; // Space
                            8'h1C: key_left <= 1; // A
                            8'h23: key_right <= 1; // D
                            8'h1B: key_down <= 1; // S
                            8'h1D: key_rotate <= 1; // W
                        endcase
                    end
                end
            end
        end
    end

endmodule
