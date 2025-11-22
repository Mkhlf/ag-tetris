`timescale 1ns / 1ps

module vga_out(
    input  wire logic clk,       // 25.175 MHz or similar for 640x480 (actually 25MHz is fine for 640x480@60Hz industry standard, but 83.46MHz was mentioned in README for a different res? 
                                 // Wait, README says 83.46MHz for "specific VGA resolution". 
                                 // Standard 640x480 @ 60Hz uses ~25.175 MHz pixel clock.
                                 // 800x600 @ 72Hz uses ~50 MHz.
                                 // 1280x1024 @ 60Hz uses ~108 MHz.
                                 // The README mentions 83.46 MHz. Let's check the README again.
                                 // README says: "pixel rate... for this specific VGA resolution and frame rate is 83.46 MHz."
                                 // And "visible region horizontally is between 336 and 1615". That's 1280 pixels wide.
                                 // "vertically between 27 and 826". That's 800 pixels high.
                                 // So it's 1280x800? Or 1280x720?
                                 // Let's stick to the README's implied resolution if possible, OR just use standard 640x480 for simplicity if the user didn't strictly enforce the README's specific resolution.
                                 // However, the README gives specific counts: hcount max 1679, vcount max 827.
                                 // Visible H: 336 to 1615 (width = 1280).
                                 // Visible V: 27 to 826 (height = 800).
                                 // So it is 1280x800.
                                 // I should probably implement what the README asks for to be safe, or standard 640x480 if I want to be sure it works on most monitors easily.
                                 // But the user said "we want to implment a tetris game see the @[report.pdf]... as well as we would like to use keyboard input".
                                 // The user didn't explicitly say "follow the README's VGA specs exactly".
                                 // BUT, the README is likely the assignment spec.
                                 // I will implement the resolution described in the README: 1280x800 (approx).
                                 // H Max: 1679 (0-1679 -> 1680 total)
                                 // V Max: 827 (0-827 -> 828 total)
                                 // H Sync: 0-135 low.
                                 // V Sync: 0-2 high (wait, README says "vsync to be 1 when vcount is between 0 and 2 inclusive (and 0 otherwise)").
                                 // Visible H: 336-1615.
                                 // Visible V: 27-826.
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
