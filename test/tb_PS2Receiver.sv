`timescale 1ns / 1ps

module tb_PS2Receiver;

    logic clk;
    logic kclk;
    logic kdata;
    logic [31:0] keycodeout;
    
    int pass_count = 0;
    int fail_count = 0;

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
        
        $display("=== PS2Receiver Testbench ===");
        $display("Testing low-level PS2 protocol reception\n");
        
        #100;
        
        // ================================================================
        // Test 1: Single Scancode
        // ================================================================
        $display("Test 1: Single Scancode (A key - 0x1C)");
        send_ps2_byte(8'h1C);
        #1000;
        if (keycodeout[7:0] == 8'h1C) begin
            $display("  PASS: Received scancode 0x1C");
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x1C, got 0x%h", keycodeout[7:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 2: Multiple Scancodes (History Buffer)
        // ================================================================
        $display("\nTest 2: Multiple Scancodes");
        send_ps2_byte(8'h23); // 'D' key
        #1000;
        if (keycodeout[7:0] == 8'h23 && keycodeout[15:8] == 8'h1C) begin
            $display("  PASS: History buffer: prev=0x1C, curr=0x23");
            pass_count++;
        end else begin
            $display("  FAIL: Expected prev=0x1C curr=0x23, got %h", keycodeout[15:0]);
            fail_count++;
        end
            
        send_ps2_byte(8'h2B); // 'F' key
        #1000;
        if (keycodeout[7:0] == 8'h2B) begin
            $display("  PASS: Received scancode 0x2B");
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x2B, got 0x%h", keycodeout[7:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 3: Break Code (F0)
        // ================================================================
        $display("\nTest 3: Break Code (F0 1C - Release A)");
        send_ps2_byte(8'hF0);
        #1000;
        send_ps2_byte(8'h1C);
        #1000;
        if (keycodeout[15:8] == 8'hF0 && keycodeout[7:0] == 8'h1C) begin
            $display("  PASS: Break code received (F0 1C)");
            pass_count++;
        end else begin
            $display("  FAIL: Break code error. Got: %h", keycodeout[15:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 4: Extended Key (E0 Prefix - Arrow Keys)
        // ================================================================
        $display("\nTest 4: Extended Key (E0 6B - Left Arrow)");
        send_ps2_byte(8'hE0);
        #1000;
        send_ps2_byte(8'h6B);
        #1000;
        if (keycodeout[15:8] == 8'hE0 && keycodeout[7:0] == 8'h6B) begin
            $display("  PASS: Extended key received (E0 6B)");
            pass_count++;
        end else begin
            $display("  FAIL: Extended key error. Got: %h", keycodeout[15:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 5: Extended Key Release (E0 F0 XX)
        // ================================================================
        $display("\nTest 5: Extended Key Release (E0 F0 6B - Release Left Arrow)");
        send_ps2_byte(8'hE0);
        #1000;
        send_ps2_byte(8'hF0);
        #1000;
        send_ps2_byte(8'h6B);
        #1000;
        if (keycodeout[23:16] == 8'hE0 && keycodeout[15:8] == 8'hF0 && keycodeout[7:0] == 8'h6B) begin
            $display("  PASS: Extended release received (E0 F0 6B)");
            pass_count++;
        end else begin
            $display("  FAIL: Extended release error. Got: %h", keycodeout[23:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 6: Space Key (0x29 - Hard Drop)
        // ================================================================
        $display("\nTest 6: Space Key (0x29 - Hard Drop)");
        send_ps2_byte(8'h29);
        #1000;
        if (keycodeout[7:0] == 8'h29) begin
            $display("  PASS: Space key received (0x29)");
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x29, got 0x%h", keycodeout[7:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 7: Left Shift Key (0x12 - Hold)
        // ================================================================
        $display("\nTest 7: Left Shift Key (0x12 - Hold)");
        send_ps2_byte(8'h12);
        #1000;
        if (keycodeout[7:0] == 8'h12) begin
            $display("  PASS: Left Shift key received (0x12)");
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x12, got 0x%h", keycodeout[7:0]);
            fail_count++;
        end
        
        // ================================================================
        // Test 8: Up Arrow (E0 75 - Rotate)
        // ================================================================
        $display("\nTest 8: Up Arrow (E0 75 - Rotate)");
        send_ps2_byte(8'hE0);
        #1000;
        send_ps2_byte(8'h75);
        #1000;
        if (keycodeout[15:8] == 8'hE0 && keycodeout[7:0] == 8'h75) begin
            $display("  PASS: Up Arrow received (E0 75)");
            pass_count++;
        end else begin
            $display("  FAIL: Expected E0 75, got %h", keycodeout[15:0]);
            fail_count++;
        end
        
        // ================================================================
        // Summary
        // ================================================================
        $display("\n=== Test Summary ===");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Simulation Finished");
        $finish;
    end

endmodule
