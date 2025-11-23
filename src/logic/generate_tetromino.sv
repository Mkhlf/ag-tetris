`include "../GLOBAL.sv"

module generate_tetromino (
    input   logic           clk,
    input   logic           rst,
    input   logic           enable,
    output  tetromino_ctrl  t_out,
    output  tetromino_ctrl  t_next_out // Optional: Next piece preview
  );

  logic [15:0] lfsr;
  logic [2:0]  rand_idx;

  // LFSR for randomness
  always_ff @(posedge clk) begin
    if (rst) begin
        lfsr <= 16'hACE1;
    end else begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
  end

  assign rand_idx = lfsr[2:0] % `NUMBER_OF_TETROMINO;

  // Tetromino Definitions
  tetromino_t shapes [0:6];
  
  initial begin
    // I
    shapes[`TETROMINO_I_IDX].data[0] = {4'b0000, 4'b1111, 4'b0000, 4'b0000};
    shapes[`TETROMINO_I_IDX].data[1] = {4'b0010, 4'b0010, 4'b0010, 4'b0010};
    shapes[`TETROMINO_I_IDX].data[2] = {4'b0000, 4'b1111, 4'b0000, 4'b0000};
    shapes[`TETROMINO_I_IDX].data[3] = {4'b0010, 4'b0010, 4'b0010, 4'b0010};
    // J
    shapes[`TETROMINO_J_IDX].data[0] = {4'b1000, 4'b1110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_J_IDX].data[1] = {4'b0110, 4'b0100, 4'b0100, 4'b0000};
    shapes[`TETROMINO_J_IDX].data[2] = {4'b0000, 4'b1110, 4'b0010, 4'b0000};
    shapes[`TETROMINO_J_IDX].data[3] = {4'b0010, 4'b0010, 4'b0110, 4'b0000};
    // L
    shapes[`TETROMINO_L_IDX].data[0] = {4'b0010, 4'b1110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_L_IDX].data[1] = {4'b0100, 4'b0100, 4'b0110, 4'b0000};
    shapes[`TETROMINO_L_IDX].data[2] = {4'b0000, 4'b1110, 4'b1000, 4'b0000};
    shapes[`TETROMINO_L_IDX].data[3] = {4'b1100, 4'b0100, 4'b0100, 4'b0000};
    // O
    shapes[`TETROMINO_O_IDX].data[0] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_O_IDX].data[1] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_O_IDX].data[2] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_O_IDX].data[3] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
    // S
    shapes[`TETROMINO_S_IDX].data[0] = {4'b0110, 4'b1100, 4'b0000, 4'b0000};
    shapes[`TETROMINO_S_IDX].data[1] = {4'b0100, 4'b0110, 4'b0010, 4'b0000};
    shapes[`TETROMINO_S_IDX].data[2] = {4'b0000, 4'b0110, 4'b1100, 4'b0000};
    shapes[`TETROMINO_S_IDX].data[3] = {4'b1000, 4'b1100, 4'b0100, 4'b0000};
    // T
    shapes[`TETROMINO_T_IDX].data[0] = {4'b0100, 4'b1110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_T_IDX].data[1] = {4'b0100, 4'b0110, 4'b0100, 4'b0000};
    shapes[`TETROMINO_T_IDX].data[2] = {4'b0000, 4'b1110, 4'b0100, 4'b0000};
    shapes[`TETROMINO_T_IDX].data[3] = {4'b0100, 4'b1100, 4'b0100, 4'b0000};
    // Z
    shapes[`TETROMINO_Z_IDX].data[0] = {4'b1100, 4'b0110, 4'b0000, 4'b0000};
    shapes[`TETROMINO_Z_IDX].data[1] = {4'b0010, 4'b0110, 4'b0100, 4'b0000};
    shapes[`TETROMINO_Z_IDX].data[2] = {4'b0000, 4'b1100, 4'b0110, 4'b0000};
    shapes[`TETROMINO_Z_IDX].data[3] = {4'b0100, 4'b1100, 4'b1000, 4'b0000};
  end

  always_ff @(posedge clk) begin
    if (rst) begin
        // Initialize Current to Empty
        t_out.idx.data <= `TETROMINO_EMPTY;
        t_out.rotation <= 0;
        t_out.coordinate.x <= 3;
        t_out.coordinate.y <= 0;
        t_out.tetromino.data <= '0; // No shape
        
        // Initialize Next to a random piece (based on initial LFSR)
        t_next_out.idx.data <= rand_idx;
        t_next_out.tetromino <= shapes[rand_idx];
        t_next_out.rotation <= 0;
        t_next_out.coordinate.x <= 3;
        t_next_out.coordinate.y <= 0;
        
    end else if (enable) begin
        // Shift Next to Current
        t_out <= t_next_out;
        
        // Generate New Next
        t_next_out.idx.data <= rand_idx;
        t_next_out.tetromino <= shapes[rand_idx];
        t_next_out.rotation <= 0;
        t_next_out.coordinate.x <= 3;
        t_next_out.coordinate.y <= 0;
    end
  end

endmodule
