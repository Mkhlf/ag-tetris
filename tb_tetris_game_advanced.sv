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
        .game_over(game_over)
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
        logic [1:0] initial_rot;
        initial_rot = current_rotation;
        press_key("ROTATE");
        if (current_rotation !== (initial_rot + 1) % 4) 
            $error("FAIL: Rotation. Expected %0d, Got %0d", (initial_rot + 1) % 4, current_rotation);
        else
            $display("PASS: Rotation successful");

        $display("Test 6: Hard Drop and Lock");
        // Drop to bottom
        press_key("DROP");
        
        // Should be at bottom now.
        // Wait one tick for lock logic to process (since we set drop_timer to max, next tick locks)
        trigger_tick;
        
        // Now it should have locked and respawned.
        if (current_y == -2) $display("PASS: Hard drop locked and respawned");
        else $error("FAIL: Hard drop did not respawn immediately. Y=%0d", current_y);
        
        // Skip soft drop test since we did hard drop
        /*
        $display("WARNING: Hard Drop logic might be missing in RTL. Testing Soft Drop (Down key) instead.");
        
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
        while (current_y < 22) begin // 22 is arbitrary large number, should reset to -2 on spawn
             key_down = 1;
             trigger_tick;
             if (current_y == -2) break; // Respawned
        end
        key_down = 0;
        */
        
        $display("Test 7: Piece Locked");
        // Previous piece should have locked at bottom.
        // Check bottom row (19) for some blocks.
        // Since we don't know exact x/shape, check range 0-9.
        int c;
        int found;
        found = 0;
        for (c=0; c<10; c++) begin
            if (grid[19][c] != 0) found++;
        end
        
        if (found > 0) $display("PASS: Found %0d blocks in row 19", found);
        else $error("FAIL: No blocks found in row 19 after lock");

        $display("=== Tests Completed ===");
        $finish;
    end

endmodule
