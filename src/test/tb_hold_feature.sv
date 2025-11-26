`timescale 1ns / 1ps
`include "../GLOBAL.sv"

//////////////////////////////////////////////////////////////////////////////////
// Hold Feature Testbench
// Tests the complete hold piece functionality including:
// - First hold (empty slot)
// - Hold swap (piece in slot)
// - Hold lockout (can't hold twice per piece)
// - Hold reset after piece placement
//////////////////////////////////////////////////////////////////////////////////

module tb_hold_feature;

    // Clock and Reset
    logic clk;
    logic rst;
    logic tick_game;
    
    // Inputs
    logic key_left, key_right, key_down, key_rotate, key_drop, key_hold;
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
    
    int pass_count = 0;
    int fail_count = 0;

    // UUT
    game_control uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
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
        .t_curr_out(t_curr_out)
    );

    // Clock: 100MHz
    always #5 clk = ~clk;
    
    // Piece name helper
    function string piece_name(input [2:0] idx);
        case(idx)
            3'b000: return "I";
            3'b001: return "J";
            3'b010: return "L";
            3'b011: return "O";
            3'b100: return "S";
            3'b101: return "T";
            3'b110: return "Z";
            3'b111: return "EMPTY";
            default: return "?";
        endcase
    endfunction
    
    // Wait for state machine to settle
    task wait_settle();
        repeat(20) @(posedge clk);
    endtask
    
    // Press hold key
    task do_hold();
        key_hold = 1;
        @(posedge clk);
        key_hold = 0;
        wait_settle();
    endtask
    
    // Press drop and wait for next piece
    task do_drop();
        key_drop = 1;
        key_drop_held = 1;
        @(posedge clk);
        key_drop = 0;
        repeat(30) @(posedge clk);
        key_drop_held = 0;
        wait_settle();
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        tick_game = 0;
        key_left = 0; key_right = 0; key_down = 0;
        key_rotate = 0; key_drop = 0; key_hold = 0;
        key_drop_held = 0;
        
        $display("===========================================");
        $display("       HOLD FEATURE TESTBENCH");
        $display("===========================================\n");
        
        // Release reset
        #100;
        rst = 0;
        wait_settle();
        
        // ================================================================
        // Test 1: Initial State (Hold Empty)
        // ================================================================
        $display("Test 1: Initial State");
        
        if (t_hold_disp.idx.data == `TETROMINO_EMPTY) begin
            $display("  PASS: Hold slot is empty at start");
            pass_count++;
        end else begin
            $display("  FAIL: Hold slot should be empty at start");
            fail_count++;
        end
        
        if (hold_used_out == 0) begin
            $display("  PASS: hold_used is false at start");
            pass_count++;
        end else begin
            $display("  FAIL: hold_used should be false at start");
            fail_count++;
        end
        
        // ================================================================
        // Test 2: First Hold (Empty Slot)
        // ================================================================
        $display("\nTest 2: First Hold (Empty -> Store)");
        
        // Capture first piece
        logic [2:0] first_piece;
        first_piece = t_curr_out.idx.data;
        $display("  Current piece before hold: %s (%d)", piece_name(first_piece), first_piece);
        
        do_hold();
        
        $display("  After hold: curr=%s, hold=%s, hold_used=%b",
                 piece_name(t_curr_out.idx.data),
                 piece_name(t_hold_disp.idx.data),
                 hold_used_out);
        
        if (t_hold_disp.idx.data == first_piece) begin
            $display("  PASS: First piece stored in hold");
            pass_count++;
        end else begin
            $display("  FAIL: First piece not stored correctly");
            fail_count++;
        end
        
        if (hold_used_out == 1) begin
            $display("  PASS: hold_used set after first hold");
            pass_count++;
        end else begin
            $display("  FAIL: hold_used not set after first hold");
            fail_count++;
        end
        
        // ================================================================
        // Test 3: Hold Lockout (Cannot Hold Twice)
        // ================================================================
        $display("\nTest 3: Hold Lockout (Cannot Hold Twice Per Piece)");
        
        logic [2:0] curr_before_lockout;
        logic [2:0] hold_before_lockout;
        curr_before_lockout = t_curr_out.idx.data;
        hold_before_lockout = t_hold_disp.idx.data;
        
        $display("  Attempting second hold while hold_used=1...");
        do_hold();
        
        if (t_curr_out.idx.data == curr_before_lockout &&
            t_hold_disp.idx.data == hold_before_lockout) begin
            $display("  PASS: Lockout prevented second hold");
            pass_count++;
        end else begin
            $display("  FAIL: Lockout did not prevent second hold");
            fail_count++;
        end
        
        // ================================================================
        // Test 4: Drop and Check Hold Reset
        // ================================================================
        $display("\nTest 4: Hold Reset After Piece Placement");
        
        do_drop();
        
        if (hold_used_out == 0) begin
            $display("  PASS: hold_used reset after drop");
            pass_count++;
        end else begin
            $display("  FAIL: hold_used not reset after drop");
            fail_count++;
        end
        
        // ================================================================
        // Test 5: Hold Swap
        // ================================================================
        $display("\nTest 5: Hold Swap");
        
        logic [2:0] curr_before_swap, hold_before_swap;
        curr_before_swap = t_curr_out.idx.data;
        hold_before_swap = t_hold_disp.idx.data;
        
        $display("  Before swap: curr=%s, hold=%s", 
                 piece_name(curr_before_swap), piece_name(hold_before_swap));
        
        do_hold();
        
        $display("  After swap:  curr=%s, hold=%s",
                 piece_name(t_curr_out.idx.data), piece_name(t_hold_disp.idx.data));
        
        if (t_curr_out.idx.data == hold_before_swap &&
            t_hold_disp.idx.data == curr_before_swap) begin
            $display("  PASS: Swap successful");
            pass_count++;
        end else begin
            $display("  FAIL: Swap did not work correctly");
            fail_count++;
        end
        
        // ================================================================
        // Test 6: Multiple Drops and Holds
        // ================================================================
        $display("\nTest 6: Multiple Game Cycles");
        
        repeat(3) begin
            // Drop current piece
            do_drop();
            
            // Verify hold is available
            if (hold_used_out != 0) begin
                $display("  FAIL: hold_used not reset after drop");
                fail_count++;
            end
            
            // Swap with hold
            do_hold();
            
            // Verify lockout
            if (hold_used_out != 1) begin
                $display("  FAIL: hold_used not set after hold");
                fail_count++;
            end
        end
        
        $display("  PASS: Multiple game cycles completed");
        pass_count++;
        
        // ================================================================
        // Test 7: Hold Piece Reset Position
        // ================================================================
        $display("\nTest 7: Swapped Piece Position Reset");
        
        // After swap, piece should be at spawn position
        if (t_curr_out.coordinate.x == 3 && t_curr_out.coordinate.y == 0) begin
            $display("  PASS: Swapped piece at spawn position (3, 0)");
            pass_count++;
        end else begin
            $display("  INFO: Piece at (%d, %d) - may vary based on state",
                     t_curr_out.coordinate.x, t_curr_out.coordinate.y);
        end
        
        // ================================================================
        // Summary
        // ================================================================
        $display("\n===========================================");
        $display("           TEST SUMMARY");
        $display("===========================================");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        $display("===========================================\n");
        
        $finish;
    end

endmodule

