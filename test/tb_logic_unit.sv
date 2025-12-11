`timescale 1ns / 1ps
`include "GLOBAL.sv"

/* tb_logic_unit
 * Unit tests for check_valid, create_field, and clean_field primitives.
 */
module tb_logic_unit;

    logic clk;
    logic rst;
    
    tetromino_ctrl t_check;
    field_t f_check;
    logic isValid;
    
    tetromino_ctrl t_create;
    field_t f_base;
    field_t f_created;
    
    logic clean_enable;
    field_t f_dirty;
    field_t f_clean_out;
    logic [2:0] lines_cleared;
    logic clean_done;

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

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        clean_enable = 0;
        
        f_check.data = '1;
        f_base.data = '1;
        f_dirty.data = '1;
        
        #20 rst = 0;
        
        $display("--- Starting Logic Unit Tests ---");
        
        $display("Test 1: Check Valid");
        
        t_check.idx.data = `TETROMINO_T_IDX;
        t_check.tetromino.data[0] = {4'b0100, 4'b1110, 4'b0000, 4'b0000};
        t_check.rotation = 0;
        
        // Case 1.1: Valid Position (Center)
        t_check.coordinate.x = 5;
        t_check.coordinate.y = 5;
        #1;
        if (isValid) $display("PASS: Valid Position");
        else $display("FAIL: Valid Position reported invalid");
        
        t_check.coordinate.x = -2;
        #1;
        if (!isValid) $display("PASS: OOB Left");
        else $display("FAIL: OOB Left reported valid");
        
        f_check.data[5][5].data = `TETROMINO_I_IDX;
        t_check.coordinate.x = 5;
        t_check.coordinate.y = 5;
        f_check.data[5][6].data = `TETROMINO_I_IDX; 
        #1;
        if (!isValid) $display("PASS: Collision");
        else $display("FAIL: Collision reported valid");
        
        $display("Test 2: Create Field");
        
        t_create = t_check;
        t_create.coordinate.x = 0;
        t_create.coordinate.y = 0;
        f_base.data = '1;
        
        #1;
        if (f_created.data[0][1].data == `TETROMINO_T_IDX &&
            f_created.data[1][0].data == `TETROMINO_T_IDX) 
            $display("PASS: Field Merge");
        else 
            $display("FAIL: Field Merge incorrect");

        $display("Test 3: Clean Field");
        
        for (int c=0; c<`FIELD_HORIZONTAL; c++) begin
            f_dirty.data[20][c].data = `TETROMINO_I_IDX;
        end
        f_dirty.data[19][0].data = `TETROMINO_O_IDX;
        
        clean_enable = 1;
        @(posedge clk);
        
        wait(clean_done);
        @(posedge clk);
        clean_enable = 0;
        
        if (lines_cleared == 1) $display("PASS: 1 Line Cleared");
        else $display("FAIL: Expected 1 line, got %d", lines_cleared);
        
        if (f_clean_out.data[20][0].data == `TETROMINO_O_IDX) 
            $display("PASS: Row Shifted");
        else 
            $display("FAIL: Row Shift incorrect. Data[20][0] = %h", f_clean_out.data[20][0].data);
            
        $finish;
    end

endmodule
