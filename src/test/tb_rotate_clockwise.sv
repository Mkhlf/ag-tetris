`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_rotate_clockwise;

    tetromino_ctrl t_in;
    tetromino_ctrl t_out;

    rotate_clockwise uut (
        .t_in(t_in),
        .t_out(t_out)
    );

    initial begin
        $display("=== Testing Rotate Clockwise ===\n");
        
        // Test I-piece rotation
        $display("Test 1: I-Piece Rotation");
        t_in.idx.data = `TETROMINO_I_IDX;
        t_in.rotation = 0;
        t_in.coordinate.x = 5;
        t_in.coordinate.y = 5;
        
        // I-piece shape for rotation 0
        t_in.tetromino.data[0] = {4'b0000, 4'b1111, 4'b0000, 4'b0000};
        t_in.tetromino.data[1] = {4'b0010, 4'b0010, 4'b0010, 4'b0010};
        t_in.tetromino.data[2] = {4'b0000, 4'b0000, 4'b1111, 4'b0000};
        t_in.tetromino.data[3] = {4'b0100, 4'b0100, 4'b0100, 4'b0100};
        
        #1;
        if (t_out.rotation == 1)
            $display("PASS: Rotation updated correctly (0 -> 1)");
        else
            $display("FAIL: Expected rotation 1, got %d", t_out.rotation);
            
        if (t_out.idx.data == `TETROMINO_I_IDX)
            $display("PASS: Piece index preserved");
        else
            $display("FAIL: Piece index changed");
        
        // Test rotation wrap-around
        $display("\nTest 2: Rotation Wrap-around");
        t_in.rotation = 3;
        #1;
        if (t_out.rotation == 0)
            $display("PASS: Rotation wraps (3 -> 0)");
        else
            $display("FAIL: Expected rotation 0, got %d", t_out.rotation);
        
        // Test O-piece (should remain same)
        $display("\nTest 3: O-Piece (No Rotation Change)");
        t_in.idx.data = `TETROMINO_O_IDX;
        t_in.rotation = 0;
        t_in.tetromino.data[0] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        t_in.tetromino.data[1] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        t_in.tetromino.data[2] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        t_in.tetromino.data[3] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        
        #1;
        if (t_out.rotation == 1)
            $display("PASS: O-piece rotation incremented");
        else
            $display("FAIL: O-piece rotation error");
        
        // Test T-piece multiple rotations
        $display("\nTest 4: T-Piece Full Rotation Cycle");
        t_in.idx.data = `TETROMINO_T_IDX;
        t_in.tetromino.data[0] = {4'b0100, 4'b1110, 4'b0000, 4'b0000};
        t_in.tetromino.data[1] = {4'b0100, 4'b1100, 4'b0100, 4'b0000};
        t_in.tetromino.data[2] = {4'b0000, 4'b1110, 4'b0100, 4'b0000};
        t_in.tetromino.data[3] = {4'b0100, 4'b0110, 4'b0100, 4'b0000};
        
        for (int i = 0; i < 4; i++) begin
            t_in.rotation = i;
            #1;
            if (t_out.rotation == (i + 1) % 4)
                $display("PASS: Rotation %d -> %d", i, (i + 1) % 4);
            else
                $display("FAIL: Expected %d, got %d", (i + 1) % 4, t_out.rotation);
        end
        
        $display("\nSimulation Finished");
        $finish;
    end

endmodule
