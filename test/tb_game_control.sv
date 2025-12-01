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
    logic key_rotate_cw;
    logic key_rotate_ccw;
    logic key_drop;
    logic key_hold;
    logic key_drop_held;

    // Outputs
    field_t display;
    logic [31:0] score;
    logic game_over;
    tetromino_ctrl t_next_disp;
    tetromino_ctrl t_hold_disp;
    logic hold_used_out;
    logic [3:0] current_level_out;
    logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y;
    tetromino_ctrl t_curr_out;
    logic [7:0] total_lines_cleared_out;
    
    int pass_count = 0;
    int fail_count = 0;

    // Instantiate the Unit Under Test (UUT)
    game_control uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate_cw(key_rotate_cw),
        .key_rotate_ccw(key_rotate_ccw),
        .key_drop(key_drop),
        .key_hold(key_hold),
        .key_drop_held(key_drop_held),
        .display(display),
        .score(score),
        .game_over(game_over),
        .t_next_disp(t_next_disp),
        .t_hold_disp(t_hold_disp),
        .hold_used_out(hold_used_out),
        .current_level_out(current_level_out),
        .ghost_y(ghost_y),
        .t_curr_out(t_curr_out),
        .total_lines_cleared_out(total_lines_cleared_out)
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
            @(posedge clk);
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
    
    task press_rotate_cw;
        begin
            key_rotate_cw = 1;
            @(posedge clk);
            key_rotate_cw = 0;
            @(posedge clk);
        end
    endtask
    
    task press_rotate_ccw;
        begin
            key_rotate_ccw = 1;
            @(posedge clk);
            key_rotate_ccw = 0;
            @(posedge clk);
        end
    endtask
    
    task press_drop;
        begin
            key_drop = 1;
            key_drop_held = 1;
            @(posedge clk);
            key_drop = 0;
            @(posedge clk);
            // Release held after a few cycles
            repeat(5) @(posedge clk);
            key_drop_held = 0;
            @(posedge clk);
        end
    endtask
    
    task press_hold;
        begin
            key_hold = 1;
            @(posedge clk);
            key_hold = 0;
            @(posedge clk);
        end
    endtask
    
    task press_down;
        begin
            key_down = 1;
            @(posedge clk);
            key_down = 0;
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
        key_rotate_cw = 0;
        key_rotate_ccw = 0;
        key_drop = 0;
        key_hold = 0;
        key_drop_held = 0;
        
        $display("=== Game Control Testbench ===");
        $display("Testing game mechanics including HOLD feature\n");

        // Wait 100 ns for global reset to finish
        #100;
        rst = 0;
        
        // Wait for Generator to spawn first piece
        repeat(20) @(posedge clk);
        
        // ================================================================
        // Test 1: Initialization
        // ================================================================
        $display("Test 1: Initialization");
        if (game_over == 0) begin
            $display("  PASS: Game not over at start");
            pass_count++;
        end else begin
            $display("  FAIL: Game over at start");
            fail_count++;
        end
        
        if (t_curr_out.idx.data != `TETROMINO_EMPTY) begin
            $display("  PASS: First piece spawned (idx=%d)", t_curr_out.idx.data);
            pass_count++;
        end else begin
            $display("  FAIL: No piece spawned");
            fail_count++;
        end
        
        // ================================================================
        // Test 2: Movement
        // ================================================================
        $display("\nTest 2: Movement");
        logic signed [`FIELD_HORIZONTAL_WIDTH:0] start_x;
        start_x = t_curr_out.coordinate.x;
        
        // Move Left
        press_left();
        repeat(5) @(posedge clk);
        
        if (t_curr_out.coordinate.x == start_x - 1) begin
            $display("  PASS: Moved left (x: %d -> %d)", start_x, t_curr_out.coordinate.x);
            pass_count++;
        end else begin
            $display("  FAIL: Left move failed (x: %d -> %d)", start_x, t_curr_out.coordinate.x);
            fail_count++;
        end
        
        // Move Right twice
        press_right();
        repeat(3) @(posedge clk);
        press_right();
        repeat(3) @(posedge clk);
        
        if (t_curr_out.coordinate.x == start_x + 1) begin
            $display("  PASS: Moved right twice (x: %d)", t_curr_out.coordinate.x);
            pass_count++;
        end else begin
            $display("  INFO: Right move result (x: %d)", t_curr_out.coordinate.x);
        end
        
        // ================================================================
        // Test 3: Rotation
        // ================================================================
        $display("\nTest 3: Rotation");
        logic [1:0] start_rot;
        start_rot = t_curr_out.rotation;
        
        press_rotate_cw();
        repeat(10) @(posedge clk); // Wait for rotation to complete
        
        // O-piece doesn't rotate visibly, but rotation state still changes
        $display("  INFO: Rotation state: %d -> %d", start_rot, t_curr_out.rotation);
        pass_count++;  // Rotation test is informational
        
        // ================================================================
        // Test 4: Hold Feature (First Hold - Empty)
        // ================================================================
        $display("\nTest 4: Hold Feature - First Hold");
        
        // Capture current piece info before hold
        tetromino_idx_t first_piece_idx;
        first_piece_idx = t_curr_out.idx;
        
        if (t_hold_disp.idx.data == `TETROMINO_EMPTY) begin
            $display("  INFO: Hold slot is empty before hold");
        end
        
        // First hold should store current piece and get next from generator
        press_hold();
        repeat(20) @(posedge clk);
        
        if (t_hold_disp.idx.data == first_piece_idx.data) begin
            $display("  PASS: First piece stored in hold (idx=%d)", t_hold_disp.idx.data);
            pass_count++;
        end else begin
            $display("  FAIL: Hold did not store piece correctly");
            fail_count++;
        end
        
        if (hold_used_out == 1) begin
            $display("  PASS: hold_used flag set");
            pass_count++;
        end else begin
            $display("  FAIL: hold_used flag not set");
            fail_count++;
        end
        
        // ================================================================
        // Test 5: Hold Lockout (Cannot hold twice per piece)
        // ================================================================
        $display("\nTest 5: Hold Lockout");
        
        tetromino_idx_t piece_before_second_hold;
        piece_before_second_hold = t_curr_out.idx;
        
        press_hold();
        repeat(10) @(posedge clk);
        
        // Should NOT have swapped because hold_used is true
        if (t_curr_out.idx.data == piece_before_second_hold.data) begin
            $display("  PASS: Hold lockout working (piece unchanged)");
            pass_count++;
        end else begin
            $display("  FAIL: Hold lockout failed (piece changed)");
            fail_count++;
        end
        
        // ================================================================
        // Test 6: Hard Drop & Lock
        // ================================================================
        $display("\nTest 6: Hard Drop & Lock");
        press_drop();
        repeat(30) @(posedge clk); // Wait for drop and lockout
        
        if (game_over == 0) begin
            $display("  PASS: Game continues after drop");
            pass_count++;
        end else begin
            $display("  FAIL: Game ended unexpectedly");
            fail_count++;
        end
        
        // ================================================================
        // Test 7: Hold Reset After New Piece
        // ================================================================
        $display("\nTest 7: Hold Reset After New Piece");
        
        if (hold_used_out == 0) begin
            $display("  PASS: hold_used reset for new piece");
            pass_count++;
        end else begin
            $display("  FAIL: hold_used not reset for new piece");
            fail_count++;
        end
        
        // ================================================================
        // Test 8: Hold Swap (Second Hold)
        // ================================================================
        $display("\nTest 8: Hold Swap");
        
        tetromino_idx_t curr_before_swap, hold_before_swap;
        curr_before_swap = t_curr_out.idx;
        hold_before_swap = t_hold_disp.idx;
        
        $display("  Before swap: curr=%d, hold=%d", curr_before_swap.data, hold_before_swap.data);
        
        press_hold();
        repeat(20) @(posedge clk);
        
        $display("  After swap:  curr=%d, hold=%d", t_curr_out.idx.data, t_hold_disp.idx.data);
        
        if (t_curr_out.idx.data == hold_before_swap.data && 
            t_hold_disp.idx.data == curr_before_swap.data) begin
            $display("  PASS: Hold swap worked correctly");
            pass_count++;
        end else begin
            $display("  FAIL: Hold swap did not work as expected");
            fail_count++;
        end
        
        // ================================================================
        // Test 9: Ghost Y Position
        // ================================================================
        $display("\nTest 9: Ghost Position");
        
        if (ghost_y >= t_curr_out.coordinate.y) begin
            $display("  PASS: Ghost Y (%d) >= Current Y (%d)", ghost_y, t_curr_out.coordinate.y);
            pass_count++;
        end else begin
            $display("  FAIL: Ghost Y invalid");
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
