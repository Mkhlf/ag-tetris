`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_generate_tetromino;

    logic clk;
    logic rst;
    logic enable;
    tetromino_ctrl t_curr_out;
    tetromino_ctrl t_next_out;
    logic done;

    generate_tetromino uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .t_curr(t_curr_out),
        .t_next(t_next_out),
        .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        enable = 0;
        
        #20 rst = 0;
        
        $display("=== Test 1: Initial Generation ===");
        enable = 1;
        @(posedge clk);
        wait(done);
        @(posedge clk);
        
        if (t_curr_out.idx.data >= `TETROMINO_I_IDX && t_curr_out.idx.data <= `TETROMINO_Z_IDX)
            $display("PASS: Current piece index valid: %d", t_curr_out.idx.data);
        else
            $display("FAIL: Invalid current piece index: %d", t_curr_out.idx.data);
            
        if (t_next_out.idx.data >= `TETROMINO_I_IDX && t_next_out.idx.data <= `TETROMINO_Z_IDX)
            $display("PASS: Next piece index valid: %d", t_next_out.idx.data);
        else
            $display("FAIL: Invalid next piece index: %d", t_next_out.idx.data);
        
        enable = 0;
        @(posedge clk);
        
        $display("\n=== Test 2: Sequential Generation ===");
        logic [2:0] prev_idx;
        prev_idx = t_curr_out.idx.data;
        
        // Generate 10 pieces and verify they're all valid
        for (int i = 0; i < 10; i++) begin
            enable = 1;
            @(posedge clk);
            wait(done);
            @(posedge clk);
            enable = 0;
            @(posedge clk);
            
            if (t_curr_out.idx.data >= `TETROMINO_I_IDX && t_curr_out.idx.data <= `TETROMINO_Z_IDX)
                $display("PASS: Piece %d - Valid index: %d", i, t_curr_out.idx.data);
            else
                $display("FAIL: Piece %d - Invalid index: %d", i, t_curr_out.idx.data);
        end
        
        $display("\n=== Test 3: Verify Tetromino Data ===");
        // Check that generated piece has valid shape data
        logic has_blocks;
        has_blocks = 0;
        for (int rot = 0; rot < 4; rot++) begin
            for (int r = 0; r < 4; r++) begin
                for (int c = 0; c < 4; c++) begin
                    if (t_curr_out.tetromino.data[rot][r][c])
                        has_blocks = 1;
                end
            end
        end
        
        if (has_blocks)
            $display("PASS: Generated piece has valid shape data");
        else
            $display("FAIL: Generated piece has no blocks");
        
        $display("\nSimulation Finished");
        $finish;
    end

endmodule
