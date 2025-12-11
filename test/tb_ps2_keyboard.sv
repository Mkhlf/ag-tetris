`timescale 1ns / 1ps
`include "GLOBAL.sv"

/* tb_ps2_keyboard
 * Feeds ps2_keyboard with make/break sequences and checks decoded events.
 */
module tb_ps2_keyboard;

    logic clk;
    logic rst;
    logic ps2_clk;
    logic ps2_data;
    logic [7:0] current_scan_code;
    logic current_make_break;
    logic key_event_valid;

    ps2_keyboard uut (
        .clk(clk),
        .rst(rst),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .current_scan_code(current_scan_code),
        .current_make_break(current_make_break),
        .key_event_valid(key_event_valid)
    );

    always #5 clk = ~clk;
    
    int pass_count = 0;
    int fail_count = 0;

    task send_ps2_byte(input [7:0] data);
        integer i;
        logic parity;
        begin
            parity = ^data;
            
            ps2_data = 0;
            #20000 ps2_clk = 0;
            #20000 ps2_clk = 1;
            
            for (i = 0; i < 8; i = i + 1) begin
                ps2_data = data[i];
                #20000 ps2_clk = 0;
                #20000 ps2_clk = 1;
            end
            
            ps2_data = parity;
            #20000 ps2_clk = 0;
            #20000 ps2_clk = 1;
            
            ps2_data = 1;
            #20000 ps2_clk = 0;
            #20000 ps2_clk = 1;
            
            #50000; // Wait between bytes
        end
    endtask
    
    task wait_for_event;
        begin
            repeat(10000) begin
                @(posedge clk);
                if (key_event_valid) begin
                    repeat(10) @(posedge clk);
                    return;
                end
            end
            $display("WARNING: Timeout waiting for key_event_valid");
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        ps2_clk = 1;
        ps2_data = 1;
        
        #20 rst = 0;
        
        $display("=== ps2_keyboard Testbench ===");
        $display("Testing PS2 keyboard interface with key_event_valid pulse\n");
        
        #100;
        
        // Test 1: Make Code (Press 'A' - 0x1C)
        $display("Test 1: Press 'A' (0x1C)");
        send_ps2_byte(8'h1C);
        wait_for_event();
        
        if (current_scan_code == 8'h1C && current_make_break == 1) begin
            $display("  PASS: Key Press Detected (Code: %h, State: Make)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x1C Make, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
            
        // Test 2: Break Code (Release 'A' - F0 1C)
        $display("\nTest 2: Release 'A' (F0 1C)");
        send_ps2_byte(8'hF0);
        #5000; // F0 prefix should NOT generate event
        
        send_ps2_byte(8'h1C);
        wait_for_event();
        
        if (current_scan_code == 8'h1C && current_make_break == 0) begin
            $display("  PASS: Key Release Detected (Code: %h, State: Break)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x1C Break, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
        
        // Test 3: Extended Key Press (Left Arrow - E0 6B)
        $display("\nTest 3: Press Left Arrow (E0 6B)");
        send_ps2_byte(8'hE0);
        #5000; // E0 prefix should NOT generate event alone
        
        send_ps2_byte(8'h6B);
        wait_for_event();
        
        if (current_scan_code == 8'h6B && current_make_break == 1) begin
            $display("  PASS: Extended Key Press (Left Arrow: %h, Make)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x6B Make, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
        
        // Test 4: Extended Key Release (Left Arrow - E0 F0 6B)
        $display("\nTest 4: Release Left Arrow (E0 F0 6B)");
        send_ps2_byte(8'hE0);
        #5000;
        send_ps2_byte(8'hF0);
        #5000;
        send_ps2_byte(8'h6B);
        wait_for_event();
        
        if (current_scan_code == 8'h6B && current_make_break == 0) begin
            $display("  PASS: Extended Key Release (Left Arrow: %h, Break)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x6B Break, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
        
        // Test 5: Left Shift Key (Used for Hold) - 0x12
        $display("\nTest 5: Press Left Shift (0x12) - Hold Key");
        send_ps2_byte(8'h12);
        wait_for_event();
        
        if (current_scan_code == 8'h12 && current_make_break == 1) begin
            $display("  PASS: Left Shift Press (Code: %h, State: Make)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x12 Make, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
        
        // Test 6: Space Key (Hard Drop) - 0x29
        $display("\nTest 6: Press Space (0x29) - Hard Drop");
        send_ps2_byte(8'h29);
        wait_for_event();
        
        if (current_scan_code == 8'h29 && current_make_break == 1) begin
            $display("  PASS: Space Press (Code: %h, State: Make)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x29 Make, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
        
        // Test 7: Up Arrow (Rotate) - E0 75
        $display("\nTest 7: Press Up Arrow (E0 75) - Rotate");
        send_ps2_byte(8'hE0);
        #5000;
        send_ps2_byte(8'h75);
        wait_for_event();
        
        if (current_scan_code == 8'h75 && current_make_break == 1) begin
            $display("  PASS: Up Arrow Press (Code: %h, State: Make)", current_scan_code);
            pass_count++;
        end else begin
            $display("  FAIL: Expected 0x75 Make, got %h %b", current_scan_code, current_make_break);
            fail_count++;
        end
        
        $display("\n=== Test Summary ===");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Simulation Finished");
        $finish;
    end

endmodule
