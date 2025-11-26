`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_input_manager;

    logic clk;
    logic rst;
    logic tick_game;
    logic raw_left, raw_right, raw_down, raw_rotate, raw_drop, raw_hold;
    logic cmd_left, cmd_right, cmd_down, cmd_rotate, cmd_drop, cmd_hold;
    
    int pass_count = 0;
    int fail_count = 0;

    input_manager uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .raw_left(raw_left),
        .raw_right(raw_right),
        .raw_down(raw_down),
        .raw_rotate(raw_rotate),
        .raw_drop(raw_drop),
        .raw_hold(raw_hold),
        .cmd_left(cmd_left),
        .cmd_right(cmd_right),
        .cmd_down(cmd_down),
        .cmd_rotate(cmd_rotate),
        .cmd_drop(cmd_drop),
        .cmd_hold(cmd_hold)
    );

    always #5 clk = ~clk; // 100MHz

    initial begin
        clk = 0; rst = 1; tick_game = 0;
        raw_left = 0; raw_right = 0; raw_down = 0; 
        raw_rotate = 0; raw_drop = 0; raw_hold = 0;
        
        $display("=== Input Manager Testbench ===");
        $display("Testing DAS and One-Shot behavior\n");
        
        #20 rst = 0;
        
        // ================================================================
        // Test 1: Rotate One-Shot
        // ================================================================
        $display("Test 1: Rotate One-Shot");
        @(negedge clk);  // Setup time before clock edge
        raw_rotate = 1;
        @(posedge clk);
        #1;
        if (cmd_rotate) begin
            $display("  PASS: Rotate Triggered on press");
            pass_count++;
        end else begin
            $display("  FAIL: Rotate did not trigger");
            fail_count++;
        end
        
        @(posedge clk);
        #1;
        if (!cmd_rotate) begin
            $display("  PASS: Rotate Pulse Ended after one cycle");
            pass_count++;
        end else begin
            $display("  FAIL: Rotate Pulse lasted too long");
            fail_count++;
        end
        
        // Hold for a while - should NOT re-trigger
        repeat(10) @(posedge clk);
        if (!cmd_rotate) begin
            $display("  PASS: Rotate did not re-trigger while holding");
            pass_count++;
        end else begin
            $display("  FAIL: Rotate re-triggered while holding");
            fail_count++;
        end
        
        @(negedge clk);
        raw_rotate = 0;
        @(posedge clk);
        
        // ================================================================
        // Test 2: Drop One-Shot
        // ================================================================
        $display("\nTest 2: Drop One-Shot");
        @(negedge clk);  // Setup time before clock edge
        raw_drop = 1;
        @(posedge clk);
        #1;
        if (cmd_drop) begin
            $display("  PASS: Drop Triggered on press");
            pass_count++;
        end else begin
            $display("  FAIL: Drop did not trigger");
            fail_count++;
        end
        
        @(posedge clk);
        #1;
        if (!cmd_drop) begin
            $display("  PASS: Drop Pulse Ended");
            pass_count++;
        end else begin
            $display("  FAIL: Drop Pulse lasted too long");
            fail_count++;
        end
        
        @(negedge clk);
        raw_drop = 0;
        @(posedge clk);
        
        // ================================================================
        // Test 3: Hold One-Shot (NEW)
        // ================================================================
        $display("\nTest 3: Hold One-Shot");
        @(negedge clk);  // Setup time before clock edge
        raw_hold = 1;
        @(posedge clk);
        #1;
        if (cmd_hold) begin
            $display("  PASS: Hold Triggered on press");
            pass_count++;
        end else begin
            $display("  FAIL: Hold did not trigger");
            fail_count++;
        end
        
        @(posedge clk);
        #1;
        if (!cmd_hold) begin
            $display("  PASS: Hold Pulse Ended after one cycle");
            pass_count++;
        end else begin
            $display("  FAIL: Hold Pulse lasted too long");
            fail_count++;
        end
        
        // Hold should NOT re-trigger while key is held
        repeat(10) @(posedge clk);
        if (!cmd_hold) begin
            $display("  PASS: Hold did not re-trigger while holding");
            pass_count++;
        end else begin
            $display("  FAIL: Hold re-triggered while holding");
            fail_count++;
        end
        
        @(negedge clk);
        raw_hold = 0;
        @(posedge clk);
        
        // Release and press again
        @(negedge clk);
        raw_hold = 1;
        @(posedge clk);
        #1;
        if (cmd_hold) begin
            $display("  PASS: Hold Triggered again after release");
            pass_count++;
        end else begin
            $display("  FAIL: Hold did not trigger after release");
            fail_count++;
        end
        @(negedge clk);
        raw_hold = 0;
        @(posedge clk);
        
        // ================================================================
        // Test 4: DAS (Left) - Classic Tetris Feel
        // ================================================================
        $display("\nTest 4: Left DAS (Delayed Auto Shift)");
        @(negedge clk);  // Setup time
        raw_left = 1;
        @(posedge clk); // Trigger edge
        #1;
        if (cmd_left) begin
            $display("  PASS: Left Initial Move on press");
            pass_count++;
        end else begin
            $display("  FAIL: Left Initial Move missing. cmd_left=%b", cmd_left);
            fail_count++;
        end
        
        // Wait for DAS Delay (16 frames at 60Hz)
        repeat(15) begin
            tick_game = 1; @(posedge clk); 
            tick_game = 0; @(posedge clk);
        end
        
        // After 15 ticks, should NOT trigger yet
        #1;
        if (!cmd_left) begin
            $display("  PASS: No trigger during DAS delay (15 frames)");
            pass_count++;
        end else begin
            $display("  FAIL: Premature trigger during DAS delay");
            fail_count++;
        end
        
        // 16th frame - starts counting repeat speed
        tick_game = 1; @(posedge clk); 
        tick_game = 0; @(posedge clk);
        
        // Need 6 more ticks for DAS_SPEED (classic feel = 6 frames)
        repeat(5) begin
            tick_game = 1; @(posedge clk); 
            tick_game = 0; @(posedge clk);
        end
        
        // Next tick should trigger auto-repeat
        tick_game = 1; 
        @(posedge clk); 
        @(negedge clk);
        
        if (cmd_left) begin
            $display("  PASS: Left DAS Auto-Repeat Triggered");
            pass_count++;
        end else begin
            $display("  FAIL: Left DAS missing after delay+speed");
            fail_count++;
        end
        
        tick_game = 0; 
        raw_left = 0;
        @(posedge clk);
        
        // ================================================================
        // Test 5: Down Fast Repeat
        // ================================================================
        $display("\nTest 5: Down Fast Repeat (Soft Drop)");
        @(negedge clk);  // Setup time
        raw_down = 1;
        @(posedge clk);
        #1;
        if (cmd_down) begin
            $display("  PASS: Down Initial trigger");
            pass_count++;
        end else begin
            $display("  FAIL: Down Initial missing");
            fail_count++;
        end
        
        // Down has fast repeat (every 2 frames)
        tick_game = 1; @(posedge clk); tick_game = 0; @(posedge clk);
        tick_game = 1; @(posedge clk); tick_game = 0; @(posedge clk);
        tick_game = 1; @(posedge clk); 
        #1;
        
        if (cmd_down) begin
            $display("  PASS: Down Fast Repeat working (every ~2 frames)");
            pass_count++;
        end else begin
            $display("  FAIL: Down Fast Repeat missing");
            fail_count++;
        end
        
        tick_game = 0;
        raw_down = 0;
        @(posedge clk);
        
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
