`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// PS2 Signal Debouncer
// Based on Digilent Nexys-A7-100T-Keyboard reference implementation
// Uses fast debouncing (~20 cycles) suitable for PS2 protocol timing
//////////////////////////////////////////////////////////////////////////////////

module debouncer(
    input clk,
    input I0,
    input I1,
    output reg O0,
    output reg O1
    );
    
    // Use 5-bit counters for fast PS2 debouncing (~20 cycles)
    // At 50MHz: 20 cycles = 400ns, well within PS2 timing requirements
    reg [4:0] cnt0, cnt1;
    reg Iv0 = 0, Iv1 = 0;
    
    localparam CNT_MAX = 19; // Fast debounce for PS2 signals

always @(posedge clk) begin
    // Debounce I0
    if (I0 == Iv0) begin
        if (cnt0 == CNT_MAX) 
            O0 <= I0;
        else 
            cnt0 <= cnt0 + 1;
    end else begin
        cnt0 <= 5'b00000;
        Iv0 <= I0;
    end
    
    // Debounce I1
    if (I1 == Iv1) begin
        if (cnt1 == CNT_MAX) 
            O1 <= I1;
        else 
            cnt1 <= cnt1 + 1;
    end else begin
        cnt1 <= 5'b00000;
        Iv1 <= I1;
    end
end
    
endmodule
