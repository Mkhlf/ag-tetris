`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_debug_start;

    logic clk;
    logic rst;
    logic tick_game;
    logic key_left, key_right, key_down, key_rotate, key_drop;
    
    // Outputs
    field_t display;
    logic [31:0] score;
    logic game_over;
    tetromino_ctrl t_next_disp;
    logic [3:0] current_level_out;
    
    // Instantiate game_control
    game_control uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop),
        .display(display),
        .score(score),
        .game_over(game_over),
        .t_next_disp(t_next_disp),
        .current_level_out(current_level_out)
    );
    
    always #5 clk = ~clk; // 100MHz

    // Helper to count bits set in tetromino
    function integer count_bits(input tetromino_t t);
        integer i, j, k;
        count_bits = 0;
        for (i=0; i<4; i++)
            for (j=0; j<4; j++)
                for (k=0; k<4; k++)
                    if (t.data[i][j][k]) count_bits++;
    endfunction

    initial begin
        clk = 0; rst = 1; tick_game = 0;
        key_left=0; key_right=0; key_down=0; key_rotate=0; key_drop=0;
        
        $display("=== START DEBUG TRACE ===");
        
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset Released at %t", $time);
        
        // Monitor State and Pieces
        repeat(20) begin
            @(posedge clk);
            #1; // Wait for update
            $display("Time: %t | State: %d | t_curr bits: %d | t_next bits: %d | t_curr idx: %d", 
                     $time, uut.ps, count_bits(uut.t_curr.tetromino), count_bits(t_next_disp.tetromino), uut.t_curr.idx.data);
            
            // Check for single dot
            if (count_bits(uut.t_curr.tetromino) == 1) 
                $display("ERROR: t_curr has exactly 1 bit set! (Single Dot)");
                
            if (uut.t_curr.idx.data == 0 && count_bits(uut.t_curr.tetromino) > 0)
                $display("INFO: Red Piece (I) Active. Bits: %d", count_bits(uut.t_curr.tetromino));
                
            // Print Field Spawn Area
            $display("Field Spawn Area (Rows 0-3, Cols 2-7):");
            for (int r=0; r<4; r++) begin
                $write("Row %0d: ", r);
                for (int c=2; c<8; c++) begin
                    $write("%0d ", display.data[r][c].data);
                end
                $write("\n");
            end
        end
        
        $display("=== END DEBUG TRACE ===");
        $finish;
    end

endmodule
