`timescale 1ns / 1ps

module tb_tetris_game_advanced;

    // Signals
    logic clk;
    logic rst;
    logic tick_game;
    logic key_left, key_right, key_down, key_rotate, key_drop;
    
    logic [3:0] grid [0:19][0:9];
    logic [3:0] current_piece_type;
    logic [1:0] current_rotation;
    logic signed [4:0] current_x;
    logic signed [5:0] current_y;
    logic [31:0] score;
    logic game_over;

    // Instantiate UUT
    tetris_game uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop),
        .grid(grid),
        .current_piece_type(current_piece_type),
        .current_rotation(current_rotation),
        .current_x(current_x),
        .current_y(current_y),
        .game_over(game_over),
        .score(score)
    );

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Game Tick Generation (Simulated fast tick for testing)
    // We will manually trigger ticks in tasks to have precise control
    initial tick_game = 0;

    // Helper Tasks
    task trigger_tick;
        begin
            @(posedge clk);
            tick_game = 1;
            @(posedge clk);
            tick_game = 0;
            @(posedge clk); // Wait a bit
        end
    endtask

    task press_key(input string key);
        begin
            @(posedge clk);
            case (key)
                "LEFT": key_left = 1;
                "RIGHT": key_right = 1;
                "DOWN": key_down = 1;
                "ROTATE": key_rotate = 1;
                "DROP": key_drop = 1;
            endcase
            
            // Hold key for multiple cycles to ensure it is captured
            repeat(10) @(posedge clk);
            
            trigger_tick; // Input is processed on tick
            @(posedge clk);
            key_left = 0; key_right = 0; key_down = 0; key_rotate = 0; key_drop = 0;
            @(posedge clk);
        end
    endtask

    task check_pos(input int expected_x, input int expected_y, input string msg);
        begin
            if (current_x !== expected_x || current_y !== expected_y) begin
                $error("FAIL: %s. Expected (%0d, %0d), Got (%0d, %0d)", msg, expected_x, expected_y, current_x, current_y);
            end else begin
                $display("PASS: %s. Pos (%0d, %0d)", msg, current_x, current_y);
            end
        end
    endtask

    task check_grid_occupied(input int r, input int c, input string msg);
        begin
            if (grid[r][c] == 0) begin
                $error("FAIL: %s. Grid[%0d][%0d] should be occupied.", msg, r, c);
            end else begin
                $display("PASS: %s. Grid[%0d][%0d] is occupied.", msg, r, c);
            end
        end
    endtask

    // Main Test Process
    initial begin
        // Initialize
        rst = 1;
        key_left = 0; key_right = 0; key_down = 0; key_rotate = 0; key_drop = 0;
        #100;
        rst = 0;
        @(posedge clk);
        
        $display("=== Starting Advanced Tetris Tests ===");

        // Wait for spawn
        // Spawn happens on first tick or after reset? 
        // Logic: if (rst) ... else if (tick) ...
        // Need a tick to start?
        trigger_tick;
        
        $display("Test 1: Initial Spawn");
        // Expect x=3, y=-2 (as per code)
        check_pos(3, -2, "Initial Spawn Position");

        $display("Test 2: Gravity");
        // Wait for drop timer (30 ticks)
        repeat(30) trigger_tick;
        check_pos(3, -1, "Piece should drop after 30 ticks");

        $display("Test 3: Move Right");
        press_key("RIGHT");
        check_pos(4, -1, "Piece moved right");

        $display("Test 4: Move Left");
        press_key("LEFT");
        check_pos(3, -1, "Piece moved left");

        $display("Test 5: Rotation");
        // Current piece is random (LFSR). Let's see if rotation changes state.
        // We can't predict exact shape easily without forcing seed, but we can check rotation index.
        begin
            logic [1:0] initial_rot;
            initial_rot = current_rotation;
            press_key("ROTATE");
            if (current_rotation !== (initial_rot + 1) % 4) 
                $error("FAIL: Rotation. Expected %0d, Got %0d", (initial_rot + 1) % 4, current_rotation);
            else
                $display("PASS: Rotation successful");
        end

        $display("Test 6: Hard Drop and Lock");
        // Drop to bottom
        press_key("DROP");
        
        // Wait for hard drop to complete (it takes 1 cycle per row)
        repeat(25) @(posedge clk);
        
        // Should be at bottom now.
        // Wait one tick for lock logic to process (since we set drop_timer to max, next tick locks)
        trigger_tick;
        
        // Now it should have locked and respawned.
        if (current_y == -2) $display("PASS: Hard drop locked and respawned");
        else $error("FAIL: Hard drop did not respawn immediately. Y=%0d", current_y);
        
        // Skip soft drop test since we did hard drop
        /*
        $display("Testing Soft Drop (Down key) skipped as Hard Drop is verified.");
        */
        
        // Let's use Soft Drop to speed it up
        // We need to hold DOWN.
        key_down = 1;
        repeat(25) trigger_tick; // Should drop 25 times
        key_down = 0;
        
        // Check if deep in board
        if (current_y > 10) $display("PASS: Soft drop worked, Y=%0d", current_y);
        else $error("FAIL: Soft drop failed, Y=%0d", current_y);

        // Continue until lock
        // Bottom is row 19.
        // We need to reach collision.
        // Wait for lock and potential line clear (max 20 cycles for clear)
        repeat(30) @(posedge clk);
        
        // Check if piece is locked
        // We can check grid content
        // Piece was T (type 5), rotation 0.
        // Center was (3, 18) before lock? No, we dropped to bottom.
        // Bottom is row 19.
        // T shape at rot 0:
        // . X . .
        // X X X .
        // . . . .
        // . . . .
        // If (x,y) is top-left of 4x4 box.
        // We need to find where it landed.
        
        // Just check that row 19 is not empty
        begin
            int c;
            int found;
            found = 0;
            for (c = 0; c < 10; c++) begin
                if (grid[19][c] != 0) found = 1;
            end
            
            if (found) $display("PASS: Found blocks in row 19");
            else $error("FAIL: No blocks found in row 19 after lock");
        end
        
        $display("Test 8: Line Clear");
        begin
            int c;
            // Manually fill row 19 completely to test clearing
            // We need to wait for spawn first
            repeat(5) trigger_tick;
            
            // Force grid state: Fill row 19
            for (c=0; c<10; c++) uut.grid[19][c] = 1;
            
            // Drop a piece to trigger lock and subsequent clear check
            press_key("DROP");
            repeat(25) @(posedge clk); // Wait for drop
            trigger_tick; // Lock
            
            // Wait for clear (30 cycles)
            repeat(30) @(posedge clk);
            
            // Check Score (Should be at least 1 if line cleared)
            if (score > 0) $display("PASS: Score updated to %0d", score);
            else $error("FAIL: Score not updated");
        end
        
        $display("=== Tests Completed ===");
        $finish;
    end

endmodule
