`timescale 1ns / 1ps
// vga_out: generates timing for 1280x800-style raster per README counts,
// producing hsync/vsync, active-area flag, and visible coordinates.
module vga_out(
    input  wire logic clk,
    input  wire logic rst,
    output logic [10:0] curr_x, // 0-1279
    output logic [9:0]  curr_y, // 0-799
    output logic hsync,
    output logic vsync,
    output logic active_area    // High when in visible area
    );

    // Counters
    logic [10:0] hcount;
    logic [9:0]  vcount;

    // Parameters from README
    localparam H_MAX = 1679;
    localparam V_MAX = 827;
    
    localparam H_SYNC_END = 135;
    localparam V_SYNC_END = 2;

    localparam H_VIS_START = 336;
    localparam H_VIS_END   = 1615;
    localparam V_VIS_START = 27;
    localparam V_VIS_END   = 826;

    always_ff @(posedge clk) begin
        if (rst) begin
            hcount <= 0;
            vcount <= 0;
        end else begin
            if (hcount == H_MAX) begin
                hcount <= 0;
                if (vcount == V_MAX) begin
                    vcount <= 0;
                end else begin
                    vcount <= vcount + 1;
                end
            end else begin
                hcount <= hcount + 1;
            end
        end
    end

    // Sync signals
    // README: hsync 0 when hcount 0-135, else 1. (Active Low)
    assign hsync = ~(hcount <= H_SYNC_END);
    
    // README: vsync 1 when vcount 0-2, else 0. (Active High)
    assign vsync = (vcount <= V_SYNC_END);

    // Active Area
    assign active_area = (hcount >= H_VIS_START && hcount <= H_VIS_END) &&
                         (vcount >= V_VIS_START && vcount <= V_VIS_END);

    // Current X and Y (relative to visible area)
    always_comb begin
        if (active_area) begin
            curr_x = hcount - H_VIS_START;
            curr_y = vcount - V_VIS_START;
        end else begin
            curr_x = 0;
            curr_y = 0;
        end
    end

endmodule
