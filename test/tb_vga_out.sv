`timescale 1ns / 1ps

module tb_vga_out;

    logic clk;
    logic rst;
    logic [10:0] curr_x;
    logic [9:0] curr_y;
    logic hsync;
    logic vsync;
    logic active_area;

    vga_out uut (
        .clk(clk),
        .rst(rst),
        .curr_x(curr_x),
        .curr_y(curr_y),
        .hsync(hsync),
        .vsync(vsync),
        .active_area(active_area)
    );

    // Clock Generation (83.46 MHz approx period 12ns)
    initial begin
        clk = 0;
        forever #6 clk = ~clk;
    end

    initial begin
        rst = 1;
        #100;
        rst = 0;
        
        // Run for a few frames
        #20000000; // 20ms (approx 1 frame at 60Hz is 16ms)
        
        $finish;
    end

endmodule
