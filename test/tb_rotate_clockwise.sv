`timescale 1ns / 1ps
`include "../GLOBAL.sv"

// NOTE: This testbench tests rotate_clockwise.sv which is marked as
// "not used in the project" but kept for reference. The actual project
// uses rotate_tetromino.sv with wall kick support.

module tb_rotate_clockwise;

    logic clk;
    logic enable;
    logic success;
    logic done;
    tetromino_ctrl t_in;
    tetromino_ctrl t_out;

    rotate_clockwise uut (
        .clk(clk),
        .enable(enable),
        .t_in(t_in),
        .t_out(t_out),
        .success(success),
        .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        enable = 0;
        t_in.idx.data = `TETROMINO_EMPTY;
        t_in.rotation = 0;
        t_in.coordinate.x = 0;
        t_in.coordinate.y = 0;
        t_in.tetromino.data = '{default: '{default: 4'b0000}};

        #20;
        
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
        
        enable = 1;
        @(posedge clk);
        #1; // Wait for output to settle after clock edge
        
        if (done && success) begin
            if (t_out.rotation == 1)
                $display("PASS: Rotation updated correctly (0 -> 1)");
            else
                $display("FAIL: Expected rotation 1, got %d", t_out.rotation);
                
            if (t_out.idx.data == `TETROMINO_I_IDX)
                $display("PASS: Piece index preserved");
            else
                $display("FAIL: Piece index changed");
        end else begin
             $display("FAIL: Module did not assert done/success");
        end
        
        enable = 0;
        @(posedge clk);
        
        // Test rotation wrap-around
        $display("\nTest 2: Rotation Wrap-around");
        t_in.rotation = 3;
        enable = 1;
        @(posedge clk);
        #1;
        
        if (t_out.rotation == 0)
            $display("PASS: Rotation wraps (3 -> 0)");
        else
            $display("FAIL: Expected rotation 0, got %d", t_out.rotation);
            
        enable = 0;
        @(posedge clk);
        
        // Test O-piece (should remain same)
        $display("\nTest 3: O-Piece (No Rotation Change)");
        t_in.idx.data = `TETROMINO_O_IDX;
        t_in.rotation = 0;
        t_in.tetromino.data[0] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        t_in.tetromino.data[1] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        t_in.tetromino.data[2] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        t_in.tetromino.data[3] = {4'b0000, 4'b0110, 4'b0110, 4'b0000};
        
        enable = 1;
        @(posedge clk);
        #1;
        
        if (t_out.rotation == 1)
            $display("PASS: O-piece rotation incremented");
        else
            $display("FAIL: O-piece rotation error");
            
        enable = 0;
        @(posedge clk);
        
        // Test T-piece multiple rotations
        $display("\nTest 4: T-Piece Full Rotation Cycle");
        t_in.idx.data = `TETROMINO_T_IDX;
        t_in.tetromino.data[0] = {4'b0100, 4'b1110, 4'b0000, 4'b0000};
        t_in.tetromino.data[1] = {4'b0100, 4'b1100, 4'b0100, 4'b0000};
        t_in.tetromino.data[2] = {4'b0000, 4'b1110, 4'b0100, 4'b0000};
        t_in.tetromino.data[3] = {4'b0100, 4'b0110, 4'b0100, 4'b0000};
        
        for (int i = 0; i < 4; i++) begin
            t_in.rotation = i;
            enable = 1;
            @(posedge clk);
            #1;
            
            if (t_out.rotation == (i + 1) % 4)
                $display("PASS: Rotation %d -> %d", i, (i + 1) % 4);
            else
                $display("FAIL: Expected %d, got %d", (i + 1) % 4, t_out.rotation);
                
            enable = 0;
            @(posedge clk);
        end
        
        $display("\nSimulation Finished");
        $finish;
    end

endmodule
