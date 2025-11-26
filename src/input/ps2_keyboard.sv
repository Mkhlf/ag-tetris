`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// PS2 Keyboard Controller
// Processes raw PS2 scan codes and provides make/break status for each key event.
// Handles both normal and extended (E0-prefixed) scan codes.
//////////////////////////////////////////////////////////////////////////////////

module ps2_keyboard(
    input  wire logic clk,
    input  wire logic rst,
    input  wire logic ps2_clk,
    input  wire logic ps2_data,
    output logic [7:0] current_scan_code,
    output logic       current_make_break, // 1 = Make (Press), 0 = Break (Release)
    output logic       key_event_valid     // Pulse high for one cycle when a valid key event occurs
    );

    logic [31:0] keycode;
    logic [31:0] prev_keycode;

    PS2Receiver ps2_rx (
        .clk(clk),
        .kclk(ps2_clk),
        .kdata(ps2_data),
        .keycodeout(keycode)
    );

    // Extract bytes from keycode buffer
    logic [7:0] new_byte;
    logic [7:0] prev_byte;
    logic [7:0] prev_prev_byte;
    
    assign new_byte = keycode[7:0];
    assign prev_byte = keycode[15:8];
    assign prev_prev_byte = keycode[23:16];

    always_ff @(posedge clk) begin
        if (rst) begin
            current_scan_code <= 8'h00;
            current_make_break <= 1'b0;
            key_event_valid <= 1'b0;
            prev_keycode <= 32'h0;
        end else begin
            // Default: no event this cycle
            key_event_valid <= 1'b0;
            
            // Check if keycode buffer has changed
            if (keycode != prev_keycode) begin
                prev_keycode <= keycode;
                
                // Skip if we just received a prefix byte (E0 or F0)
                if (new_byte == 8'hE0 || new_byte == 8'hF0) begin
                    // Prefix received, wait for actual scan code
                    key_event_valid <= 1'b0;
                end
                // Extended key release: E0 F0 XX
                else if (prev_byte == 8'hF0 && prev_prev_byte == 8'hE0) begin
                    current_make_break <= 1'b0;  // Release
                    current_scan_code <= new_byte;
                    key_event_valid <= 1'b1;
                end
                // Normal key release: F0 XX
                else if (prev_byte == 8'hF0) begin
                    current_make_break <= 1'b0;  // Release
                    current_scan_code <= new_byte;
                    key_event_valid <= 1'b1;
                end
                // Extended key press: E0 XX (but not E0 F0)
                else if (prev_byte == 8'hE0) begin
                    current_make_break <= 1'b1;  // Press
                    current_scan_code <= new_byte;
                    key_event_valid <= 1'b1;
                end
                // Normal key press: just XX (not E0, not F0, and prev wasn't F0)
                else begin
                    current_make_break <= 1'b1;  // Press
                    current_scan_code <= new_byte;
                    key_event_valid <= 1'b1;
                end
            end
        end
    end

endmodule
