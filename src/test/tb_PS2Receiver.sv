`timescale 1ns / 1ps

module tb_PS2Receiver;

    logic clk;
    logic kclk;
    logic kdata;
    logic [31:0] keycodeout;

    PS2Receiver uut (
        .clk(clk),
        .kclk(kclk),
        .kdata(kdata),
        .keycodeout(keycodeout)
    );

    always #5 clk = ~clk;

    // Task to send a PS/2 byte
    task send_ps2_byte(input [7:0] data);
        integer i;
        logic parity;
        begin
            parity = ^data; // Odd parity
            
            // Start bit
            kdata = 0;
            #20000 kclk = 0;
            #20000 kclk = 1;
            
            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                kdata = data[i];
                #20000 kclk = 0;
                #20000 kclk = 1;
            end
            
            // Parity bit
            kdata = parity;
            #20000 kclk = 0;
            #20000 kclk = 1;
            
            // Stop bit
            kdata = 1;
            #20000 kclk = 0;
            #20000 kclk = 1;
            
            #50000; // Wait between bytes
        end
    endtask

    initial begin
        clk = 0;
        kclk = 1;
        kdata = 1;
        
        #100;
        
        $display("=== Test 1: Single Scancode ===");
        send_ps2_byte(8'h1C); // 'A' key
        #1000;
        if (keycodeout[7:0] == 8'h1C)
            $display("PASS: Received scancode 0x1C");
        else
            $display("FAIL: Expected 0x1C, got 0x%h", keycodeout[7:0]);
        
        $display("\n=== Test 2: Multiple Scancodes ===");
        send_ps2_byte(8'h23); // 'D' key
        #1000;
        if (keycodeout[7:0] == 8'h23)
            $display("PASS: Received scancode 0x23");
        else
            $display("FAIL: Expected 0x23, got 0x%h", keycodeout[7:0]);
            
        send_ps2_byte(8'h2B); // 'F' key
        #1000;
        if (keycodeout[7:0] == 8'h2B)
            $display("PASS: Received scancode 0x2B");
        else
            $display("FAIL: Expected 0x2B, got 0x%h", keycodeout[7:0]);
        
        $display("\n=== Test 3: Break Code (F0) ===");
        send_ps2_byte(8'hF0);
        #1000;
        send_ps2_byte(8'h1C);
        #1000;
        if (keycodeout[15:8] == 8'hF0 && keycodeout[7:0] == 8'h1C)
            $display("PASS: Break code received correctly");
        else
            $display("FAIL: Break code error. Got: %h", keycodeout[15:0]);
        
        $display("\nSimulation Finished");
        $finish;
    end

endmodule
