`timescale 1ns / 1ps
module tb_input_manager;

    logic clk;
    logic rst;
    logic tick_game;
    logic raw_left, raw_right, raw_down, raw_rotate, raw_drop;
    logic cmd_left, cmd_right, cmd_down, cmd_rotate, cmd_drop;

    input_manager uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .raw_left(raw_left),
        .raw_right(raw_right),
        .raw_down(raw_down),
        .raw_rotate(raw_rotate),
        .raw_drop(raw_drop),
        .cmd_left(cmd_left),
        .cmd_right(cmd_right),
        .cmd_down(cmd_down),
        .cmd_rotate(cmd_rotate),
        .cmd_drop(cmd_drop)
    );

    always #5 clk = ~clk; // 100MHz

    initial begin
        clk = 0; rst = 1; tick_game = 0;
        raw_left = 0; raw_right = 0; raw_down = 0; raw_rotate = 0; raw_drop = 0;
        
        #20 rst = 0;
        
        // Test 1: One-Shot (Rotate)
        $display("Test 1: Rotate One-Shot");
        raw_rotate = 1;
        @(posedge clk);
        #1;
        if (cmd_rotate) $display("PASS: Rotate Triggered");
        else $display("FAIL: Rotate did not trigger");
        
        @(posedge clk);
        #1;
        if (!cmd_rotate) $display("PASS: Rotate Pulse Ended");
        else $display("FAIL: Rotate Pulse too long");
        
        // Hold for a while
        repeat(10) @(posedge clk);
        if (cmd_rotate) $display("FAIL: Rotate re-triggered while holding");
        
        raw_rotate = 0;
        @(posedge clk);
        
        // Test 2: DAS (Left)
        // Test 2: DAS (Left)
        $display("Test 2: Left DAS");
        raw_left = 1;
        @(posedge clk); // Trigger edge
        #1;
        if (cmd_left) $display("PASS: Left Initial Move");
        else $display("FAIL: Left Initial Move missing");
        
        // Now pulse tick_game for DAS logic (doesn't affect initial move)
        tick_game = 1; @(posedge clk); tick_game = 0; @(posedge clk);
        
        // Wait for DAS Delay (16 frames)
        // We need to toggle tick_game
        repeat(15) begin
            tick_game = 1; @(posedge clk); tick_game = 0; @(posedge clk);
            if (cmd_left) $display("FAIL: Left triggered during delay");
        end
        
        // 16th frame
        tick_game = 1; @(posedge clk); tick_game = 0; @(posedge clk);
        
        // We need 4 more ticks for speed (DAS_SPEED = 4)
        repeat(4) begin
            tick_game = 1; @(posedge clk); tick_game = 0; @(posedge clk);
        end
        
        // Now timer should be 20. Next tick should trigger.
        tick_game = 1; @(posedge clk); 
        #1;
        if (cmd_left) $display("PASS: Left DAS Triggered");
        else $display("FAIL: Left DAS missing");
        tick_game = 0; @(posedge clk);
        
        $display("Simulation Finished");
        $finish;
    end
endmodule
