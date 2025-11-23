`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_logic_unit;

    // Signals
    logic clk;
    logic rst;
    
    // --- Check Valid Signals ---
    tetromino_ctrl t_check;
    field_t f_check;
    logic isValid;
    
    // --- Create Field Signals ---
    tetromino_ctrl t_create;
    field_t f_base;
    field_t f_created;
    
    // --- Clean Field Signals ---
    logic clean_enable;
    field_t f_dirty;
    field_t f_clean_out;
    logic [2:0] lines_cleared;
    logic clean_done;

    // Instantiation
    check_valid u_check (
        .t_ctrl(t_check),
        .f(f_check),
        .isValid(isValid)
    );
    
    create_field u_create (
        .t_ctrl(t_create),
        .f(f_base),
        .f_out(f_created)
    );
    
    clean_field u_clean (
        .clk(clk),
        .enable(clean_enable),
        .f_in(f_dirty),
        .f_out(f_clean_out),
        .lines_cleared(lines_cleared),
        .done(clean_done)
    );

    // Clock
    always #5 clk = ~clk;

    // Test Logic
    initial begin
        clk = 0;
        rst = 1;
        clean_enable = 0;
        
        // Initialize Fields
        // Initialize Fields
        f_check.data = '1;
        f_base.data = '1;
        f_dirty.data = '1;
        
        #20 rst = 0;
        
        $display("--- Starting Logic Unit Tests ---");
        
        // ==========================================
        // Test 1: Check Valid (Bounds & Collision)
        // ==========================================
        $display("Test 1: Check Valid");
        
        // Setup Piece (T-Shape)
        t_check.idx.data = `TETROMINO_T_IDX;
        t_check.tetromino.data[0] = {4'b0100, 4'b1110, 4'b0000, 4'b0000}; // Rotation 0
        t_check.rotation = 0;
        
        // Case 1.1: Valid Position (Center)
        t_check.coordinate.x = 5;
        t_check.coordinate.y = 5;
        #1;
        if (isValid) $display("PASS: Valid Position");
        else $display("FAIL: Valid Position reported invalid");
        
        // Case 1.2: Out of Bounds (Left)
        t_check.coordinate.x = -2; // Too far left
        #1;
        if (!isValid) $display("PASS: OOB Left");
        else $display("FAIL: OOB Left reported valid");
        
        // Case 1.3: Collision with Block
        f_check.data[5][5].data = `TETROMINO_I_IDX; // Place block at (5,5)
        t_check.coordinate.x = 5;
        t_check.coordinate.y = 5;
        // T-shape at (5,5) covers (6,5), (5,6), (6,6), (7,6).
        // Wait, shape is:
        // . 1 . .
        // 1 1 1 .
        // (5,5) is top-left of 4x4 box.
        // Row 0: . 1 . . -> (6,5)
        // Row 1: 1 1 1 . -> (5,6), (6,6), (7,6)
        // If we place block at (6,5), it should collide.
        f_check.data[5][6].data = `TETROMINO_I_IDX; 
        #1;
        if (!isValid) $display("PASS: Collision");
        else $display("FAIL: Collision reported valid");
        
        // ==========================================
        // Test 2: Create Field (Merging)
        // ==========================================
        $display("Test 2: Create Field");
        
        t_create = t_check;
        t_create.coordinate.x = 0;
        t_create.coordinate.y = 0;
        f_base.data = '1;
        
        #1;
        // Expect T-shape at top-left
        // (1,0), (0,1), (1,1), (2,1)
        if (f_created.data[0][1].data == `TETROMINO_T_IDX &&
            f_created.data[1][0].data == `TETROMINO_T_IDX) 
            $display("PASS: Field Merge");
        else 
            $display("FAIL: Field Merge incorrect");

        // ==========================================
        // Test 3: Clean Field (Line Clear)
        // ==========================================
        $display("Test 3: Clean Field");
        
        // Setup: Fill row 20 (second from bottom) completely
        for (int c=0; c<`FIELD_HORIZONTAL; c++) begin
            f_dirty.data[20][c].data = `TETROMINO_I_IDX;
        end
        // Add some blocks on row 19 (should shift down)
        f_dirty.data[19][0].data = `TETROMINO_O_IDX;
        
        // Start Clean
        clean_enable = 1;
        @(posedge clk);
        
        // Wait for done
        wait(clean_done);
        @(posedge clk);
        clean_enable = 0;
        
        // Verify
        if (lines_cleared == 1) $display("PASS: 1 Line Cleared");
        else $display("FAIL: Expected 1 line, got %d", lines_cleared);
        
        // Check Shift: Row 20 should now contain what was in Row 19 (O at col 0)
        // Wait, row 21 (bottom) was empty?
        // If row 20 is cleared, row 19 moves to 20.
        // Row 21 stays 21?
        // clean_field iterates from bottom (`FIELD_VERTICAL-1 = 21).
        // If 21 is empty, it stays.
        // If 20 is full, it clears.
        // 19 moves to 20.
        if (f_clean_out.data[20][0].data == `TETROMINO_O_IDX) 
            $display("PASS: Row Shifted");
        else 
            $display("FAIL: Row Shift incorrect. Data[20][0] = %h", f_clean_out.data[20][0].data);
            
        $finish;
    end

endmodule
