`timescale 1ns / 1ps
`include "../GLOBAL.sv"

module tb_debug_start;

    logic clk;
    logic rst;
    logic tick_game;
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
    
    // Get piece name from index
    function string get_piece_name(input [2:0] idx);
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

    initial begin
        clk = 0; rst = 1; tick_game = 0;
        key_left=0; key_right=0; key_down=0; key_rotate=0; key_drop=0;
        key_hold=0; key_drop_held=0;
        
        $display("=== START DEBUG TRACE ===");
        $display("Includes HOLD feature debugging\n");
        
        repeat(5) @(posedge clk);
        rst = 0;
        $display("Reset Released at %t", $time);
        
        // Monitor State and Pieces
        repeat(20) begin
            @(posedge clk);
            #1; // Wait for update
            $display("Time: %t | State: %s | Current: %s | Next: %s | Hold: %s | HoldUsed: %b", 
                     $time, 
                     uut.ps.name(),
                     get_piece_name(t_curr_out.idx.data),
                     get_piece_name(t_next_disp.idx.data),
                     get_piece_name(t_hold_disp.idx.data),
                     hold_used_out);
            
            // Check for single dot
            if (count_bits(t_curr_out.tetromino) == 1) 
                $display("ERROR: t_curr has exactly 1 bit set! (Single Dot)");
            
            // Debug position and ghost
            $display("  Position: (%d, %d) | Ghost Y: %d | Rotation: %d", 
                     t_curr_out.coordinate.x, t_curr_out.coordinate.y,
                     ghost_y, t_curr_out.rotation);
        end
        
        // Test Hold
        $display("\n=== Testing HOLD ===");
        key_hold = 1;
        @(posedge clk);
        key_hold = 0;
        
        repeat(10) begin
            @(posedge clk);
            #1;
            $display("Time: %t | State: %s | Current: %s | Hold: %s | HoldUsed: %b", 
                     $time, 
                     uut.ps.name(),
                     get_piece_name(t_curr_out.idx.data),
                     get_piece_name(t_hold_disp.idx.data),
                     hold_used_out);
        end
        
        $display("\n=== END DEBUG TRACE ===");
        $finish;
    end

endmodule
