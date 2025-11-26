`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_rotate_tetromino;

    logic clk;
    logic enable;
    logic clockwise;
    logic success;
    logic done;
    tetromino_ctrl t_in;
    tetromino_ctrl t_out;

    rotate_tetromino uut (
        .clk(clk),
        .enable(enable),
        .clockwise(clockwise),
        .t_in(t_in),
        .t_out(t_out),
        .success(success),
        .done(done)
    );

    // 100 MHz equivalent
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        enable = 0;
        clockwise = 1'b1;
        t_in.idx.data = `TETROMINO_T_IDX;
        t_in.rotation = 0;
        t_in.coordinate.x = 3;
        t_in.coordinate.y = 0;
        t_in.tetromino.data = '{default: '{default: 4'b0000}};

        #20;

        $display("=== Testing rotate_tetromino CW/CCW ===");

        // CW: 0 -> 1
        $display("Test 1: CW 0 -> 1");
        t_in.rotation = 0;
        clockwise = 1'b1;
        enable = 1;
        @(posedge clk);
        #1;
        if (done && success && t_out.rotation == 1)
            $display("PASS: CW rotation 0 -> 1");
        else
            $display("FAIL: CW expected 1, got %0d", t_out.rotation);

        enable = 0;
        @(posedge clk);

        // CW wrap: 3 -> 0
        $display("Test 2: CW wrap 3 -> 0");
        t_in.rotation = 3;
        clockwise = 1'b1;
        enable = 1;
        @(posedge clk);
        #1;
        if (done && success && t_out.rotation == 0)
            $display("PASS: CW rotation 3 -> 0");
        else
            $display("FAIL: CW expected 0, got %0d", t_out.rotation);

        enable = 0;
        @(posedge clk);

        // CCW: 0 -> 3
        $display("Test 3: CCW 0 -> 3");
        t_in.rotation = 0;
        clockwise = 1'b0;
        enable = 1;
        @(posedge clk);
        #1;
        if (done && success && t_out.rotation == 3)
            $display("PASS: CCW rotation 0 -> 3");
        else
            $display("FAIL: CCW expected 3, got %0d", t_out.rotation);

        enable = 0;
        @(posedge clk);

        // CCW wrap: 1 -> 0
        $display("Test 4: CCW 1 -> 0");
        t_in.rotation = 1;
        clockwise = 1'b0;
        enable = 1;
        @(posedge clk);
        #1;
        if (done && success && t_out.rotation == 0)
            $display("PASS: CCW rotation 1 -> 0");
        else
            $display("FAIL: CCW expected 0, got %0d", t_out.rotation);

        $display("Simulation finished");
        $finish;
    end

endmodule


