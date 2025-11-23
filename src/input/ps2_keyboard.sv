`timescale 1ns / 1ps

module ps2_keyboard(
    input  wire logic clk,
    input  wire logic rst,
    input  wire logic ps2_clk,
    input  wire logic ps2_data,
    output logic [7:0] current_scan_code,
    output logic       current_make_break // 1 = Make (Press), 0 = Break (Release)
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
            current_scan_code <= 0;
            current_make_break <= 0;
            prev_keycode <= 0;
        end else begin
            if (keycode != prev_keycode) begin
                prev_keycode <= keycode;
                
                logic [7:0] new_byte;
                logic [7:0] prev_byte;
                logic [7:0] prev_prev_byte;
                
                new_byte = keycode[7:0];
                prev_byte = keycode[15:8];
                prev_prev_byte = keycode[23:16];
                
                // Determine Make/Break and Scan Code
                if (prev_byte == 8'hF0) begin
                    // Normal Release (F0 XX)
                    current_make_break <= 0;
                    current_scan_code <= new_byte;
                end else if (new_byte == 8'hF0) begin
                    // Break prefix received, wait for next byte
                end else begin
                    // Check for Extended Release (E0 F0 XX)
                    if (prev_byte == 8'hF0 && prev_prev_byte == 8'hE0) begin
                        current_make_break <= 0;
                        current_scan_code <= new_byte;
                    end
                    // Check for Extended Press (E0 XX)
                    else if (prev_byte == 8'hE0 && new_byte != 8'hF0) begin
                        current_make_break <= 1;
                        current_scan_code <= new_byte;
                    end
                    // Normal Press (XX)
                    else if (new_byte != 8'hE0 && new_byte != 8'hF0 && prev_byte != 8'hF0) begin
                        current_make_break <= 1;
                        current_scan_code <= new_byte;
                    end
                end
            end
        end
    end

endmodule
