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

    // Task to send a PS/2 byte (Copied from tb_PS2Receiver with 5us delays)
    task send_ps2_byte(input [7:0] data);
        integer i;
        logic parity;
        begin
            parity = ^data; // Odd parity
            
            // Start bit
            ps2_data = 0;
            #5000 ps2_clk = 0;
            #5000 ps2_clk = 1;
            
            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                ps2_data = data[i];
                #5000 ps2_clk = 0;
                #5000 ps2_clk = 1;
            end
            
            // Parity bit
            ps2_data = parity;
            #5000 ps2_clk = 0;
            #5000 ps2_clk = 1;
            
            // Stop bit
            ps2_data = 1;
            #5000 ps2_clk = 0;
            #5000 ps2_clk = 1;
            
            #20000; // Wait between bytes
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        ps2_clk = 1;
        ps2_data = 1;
        
        #20 rst = 0;
        
        $display("=== ps2_keyboard Testbench ===");
        
        #100;
        
        // Test 1: Make Code (Press 'A' - 0x1C)
        $display("Test 1: Press 'A' (0x1C)");
        send_ps2_byte(8'h1C);
        #1000;
        
        if (current_scan_code == 8'h1C && current_make_break == 1)
            $display("PASS: Key Press Detected (Code: %h, State: Make)", current_scan_code);
        else
            $display("FAIL: Expected 0x1C Make, got %h %b", current_scan_code, current_make_break);
            
        // Test 2: Break Code (Release 'A' - F0 1C)
        $display("\nTest 2: Release 'A' (F0 1C)");
        send_ps2_byte(8'hF0);
        #1000;
        // Intermediate state: F0 received, waiting for next byte. 
        // Logic might hold previous state or clear.
        // Our logic: if (new_byte == 8'hF0) -> do nothing (wait).
        
        send_ps2_byte(8'h1C);
        #1000;
        
        if (current_scan_code == 8'h1C && current_make_break == 0)
            $display("PASS: Key Release Detected (Code: %h, State: Break)", current_scan_code);
        else
            $display("FAIL: Expected 0x1C Break, got %h %b", current_scan_code, current_make_break);
        
        $display("\nSimulation Finished");
        $finish;
    end

endmodule
