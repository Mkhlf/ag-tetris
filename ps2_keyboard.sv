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

    // Synchronize PS/2 inputs
    logic [1:0] ps2_clk_sync;
    logic [1:0] ps2_data_sync;

    always_ff @(posedge clk) begin
        ps2_clk_sync  <= {ps2_clk_sync[0], ps2_clk};
        ps2_data_sync <= {ps2_data_sync[0], ps2_data};
    end

    logic ps2_clk_negedge;
    assign ps2_clk_negedge = (ps2_clk_sync[1] && !ps2_clk_sync[0]);

    // Shift register for data
    logic [10:0] shift_reg;
    logic [3:0]  bit_count;
    logic [7:0]  scancode;
    logic        scancode_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            bit_count <= 0;
            scancode_ready <= 0;
            scancode <= 0;
        end else if (ps2_clk_negedge) begin
            shift_reg <= {ps2_data_sync[1], shift_reg[10:1]};
            if (bit_count == 10) begin
                bit_count <= 0;
                // Check start bit (0), stop bit (1), parity (odd) - skipping strict checks for simplicity
                scancode <= shift_reg[8:1];
                scancode_ready <= 1;
            end else begin
                bit_count <= bit_count + 1;
                scancode_ready <= 0;
            end
        end else begin
            scancode_ready <= 0;
        end
    end

    // Key State Logic
    // We need to handle break codes (F0 followed by key code) to know when key is released.
    // Simple approach: Toggle on press, or just pulse? 
    // For movement, we usually want continuous or press-event.
    // Let's implement a simple state machine to track press/release.

    typedef enum logic [1:0] {IDLE, BREAK, EXTENDED} state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            key_left <= 0;
            key_right <= 0;
            key_down <= 0;
            key_rotate <= 0;
            key_drop <= 0;
        end else if (scancode_ready) begin
            case (state)
                IDLE: begin
                    if (scancode == 8'hF0) begin
                        state <= BREAK;
                    end else if (scancode == 8'hE0) begin
                        state <= EXTENDED;
                    end else begin
                        // Make code processing
                        case (scancode)
                            8'h1C: key_left   <= 1; // A (using WASD or Arrows?) Let's use Arrows mostly, but A is 1C
                            8'h1B: key_down   <= 1; // S
                            8'h23: key_right  <= 1; // D
                            8'h1D: key_rotate <= 1; // W
                            8'h29: key_drop   <= 1; // Space
                            // Arrow keys are extended usually, handled in EXTENDED state
                        endcase
                    end
                end
                EXTENDED: begin
                    if (scancode == 8'hF0) begin
                        state <= BREAK; // Break of extended key
                    end else begin
                        // Extended Make code
                        case (scancode)
                            8'h6B: key_left   <= 1; // Left Arrow
                            8'h74: key_right  <= 1; // Right Arrow
                            8'h72: key_down   <= 1; // Down Arrow
                            8'h75: key_rotate <= 1; // Up Arrow
                        endcase
                        state <= IDLE;
                    end
                end
                BREAK: begin
                    // Break code received, next is the key code to clear
                    // If we were in EXTENDED before F0, we might need to handle that, but usually F0 comes after E0?
                    // Actually: E0 F0 XX is break of extended. F0 XX is break of normal.
                    // My state machine is a bit simple. 
                    // Let's just clear the key if we see its code after F0.
                    case (scancode)
                        8'h1C: key_left   <= 0;
                        8'h1B: key_down   <= 0;
                        8'h23: key_right  <= 0;
                        8'h1D: key_rotate <= 0;
                        8'h29: key_drop   <= 0;
                        8'h6B: key_left   <= 0;
                        8'h74: key_right  <= 0;
                        8'h72: key_down   <= 0;
                        8'h75: key_rotate <= 0;
                    endcase
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
