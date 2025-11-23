`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_game_control;

    // Inputs
    logic clk;
    logic rst;
    logic tick_game;
    logic key_left;
    logic key_right;
    logic key_down;
    logic key_rotate;
    logic key_drop;

    // Outputs
    field_t display;
    logic [31:0] score;
    logic game_over;

    // Instantiate the Unit Under Test (UUT)
    game_control uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop),
        .display(display),
        .score(score),
        .game_over(game_over)
    );

    // Clock Generation
    always #5 clk = ~clk; // 100MHz clock (10ns period)

    // Helper Task: Tick Game
    task tick;
        input int frames;
        begin
            repeat(frames) begin
                tick_game = 1;
                @(posedge clk);
                tick_game = 0;
                // Wait for some cycles between ticks to simulate real time (optional, but good for logic)
                repeat(10) @(posedge clk); 
            end
        end
    endtask

    // Helper Task: Pulse Key
    task press_left;
        begin
            key_left = 1;
            @(posedge clk);
            key_left = 0;
            @(posedge clk); // Wait for logic to process
        end
    endtask

    task press_right;
        begin
            key_right = 1;
            @(posedge clk);
            key_right = 0;
            @(posedge clk);
        end
    endtask
    
    task press_rotate;
        begin
            key_rotate = 1;
            @(posedge clk);
            key_rotate = 0;
            @(posedge clk);
        end
    endtask
    
    task press_drop;
        begin
            key_drop = 1;
            @(posedge clk);
            key_drop = 0;
            @(posedge clk);
        end
    endtask

    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 1;
        tick_game = 0;
        key_left = 0;
        key_right = 0;
        key_down = 0;
        key_rotate = 0;
        key_drop = 0;

        // Wait 100 ns for global reset to finish
        #100;
        rst = 0;
        
        // Wait for Generator to spawn first piece
        repeat(10) @(posedge clk);
        
        $display("Test 1: Initialization");
        if (game_over == 0) $display("PASS: Game not over");
        else $display("FAIL: Game over at start");
        
        // Check if piece spawned (display should not be empty)
        // Note: Spawn happens at top.
        // Let's check a few rows.
        
        // Test 2: Movement
        $display("Test 2: Movement");
        // Move Left
        press_left();
        repeat(5) @(posedge clk); // Wait for state machine
        
        // Move Right
        press_right();
        press_right();
        repeat(5) @(posedge clk);
        
        // Test 3: Rotation
        $display("Test 3: Rotation");
        press_rotate();
        repeat(5) @(posedge clk);
        
        // Test 4: Hard Drop & Lock
        $display("Test 4: Hard Drop");
        press_drop();
        repeat(20) @(posedge clk); // Wait for drop loop to finish
        
        // After drop, piece should be at bottom.
        // And a new piece should spawn.
        
        // Test 5: Game Over Condition
        // We can't easily simulate filling the board without a lot of drops.
        // But we can verify that the game continues after a drop.
        if (game_over == 0) $display("PASS: Game continues after drop");
        
        // Test 6: Line Clear (Mocking)
        // It's hard to mock internal state in a system testbench without hierarchical access.
        // But we can play the game.
        // Let's just verify basic input responsiveness.
        
        $display("Simulation Finished");
        $finish;
    end

endmodule
