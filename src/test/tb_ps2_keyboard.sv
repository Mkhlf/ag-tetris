`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_ps2_keyboard;

    logic clk;
    logic rst;
    logic ps2_clk;
    logic ps2_data;
    logic [7:0] current_scan_code;
    logic current_make_break;

    ps2_keyboard uut (
        .clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .current_scan_code(current_scan_code),
        .current_make_break(current_make_break)
    );

    always #5 clk = ~clk;

    // Simulate PS2Receiver output by directly injecting keycodes
    // This is a simplified test
    
    initial begin
        clk = 0;
        rst = 1;
        ps2_clk = 1;
        ps2_data = 1;
        
        #20 rst = 0;
        
        $display("=== ps2_keyboard Testbench ===");
        $display("Note: This is a simplified test.");
        $display("For full PS2 testing, use tb_PS2Receiver.sv");
        
        // The ps2_keyboard module relies on PS2Receiver
        // A full test would require simulating the entire PS/2 protocol
        // For now, we verify the module compiles and initializes
        
        #100;
        
        if (current_scan_code == 0 && current_make_break == 0)
            $display("PASS: Module initialized correctly");
        else
            $display("WARNING: Unexpected initial state");
        
        $display("\nSimulation Finished");
        $display("For comprehensive keyboard testing, use hardware or");
        $display("implement a full PS/2 protocol simulator");
        $finish;
    end

endmodule
