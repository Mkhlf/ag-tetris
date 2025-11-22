`timescale 1ns / 1ps

module tb_tetris_game;

    logic clk;
    logic rst;
    logic tick_game;
    logic key_left, key_right, key_down, key_rotate, key_drop;
    
    logic [3:0] grid [0:19][0:9];
    logic [3:0] current_piece_type;
    logic [1:0] current_rotation;
    logic signed [4:0] current_x;
    logic signed [5:0] current_y;
    logic game_over;

    tetris_game uut (
        .clk(clk),
        .rst(rst),
        .tick_game(tick_game),
        .key_left(key_left),
        .key_right(key_right),
        .key_down(key_down),
        .key_rotate(key_rotate),
        .key_drop(key_drop),
        .grid(grid),
        .current_piece_type(current_piece_type),
        .current_rotation(current_rotation),
        .current_x(current_x),
        .current_y(current_y),
        .game_over(game_over)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Game Tick Generation
    initial begin
        tick_game = 0;
        forever begin
            #1000; // Wait some time
            @(posedge clk);
            tick_game = 1;
            @(posedge clk);
            tick_game = 0;
        end
    end

    initial begin
        rst = 1;
        key_left = 0; key_right = 0; key_down = 0; key_rotate = 0; key_drop = 0;
        #100;
        rst = 0;
        
        // Wait for piece to spawn
        #2000;
        
        // Move Right
        key_right = 1;
        #2000; // Wait for tick
        key_right = 0;
        
        // Move Left
        #2000;
        key_left = 1;
        #2000;
        key_left = 0;
        
        // Rotate
        #2000;
        key_rotate = 1;
        #2000;
        key_rotate = 0;
        
        // Drop
        #2000;
        key_drop = 1;
        #2000;
        key_drop = 0;
        
        #50000;
        $finish;
    end

endmodule
