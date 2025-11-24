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

  tetromino_t current_shape;
  
  // 7-Bag Logic
  logic [6:0] bag;
  logic [2:0] selected_idx;
  logic [6:0] next_bag;
  
  // Linear Probe to find available piece
  always_comb begin
    // Default
    selected_idx = 0;
    
    // Check 7 positions starting from rand_idx
    if (bag[rand_idx]) selected_idx = rand_idx;
    else if (bag[(rand_idx + 1) % 7]) selected_idx = (rand_idx + 1) % 7;
    else if (bag[(rand_idx + 2) % 7]) selected_idx = (rand_idx + 2) % 7;
    else if (bag[(rand_idx + 3) % 7]) selected_idx = (rand_idx + 3) % 7;
    else if (bag[(rand_idx + 4) % 7]) selected_idx = (rand_idx + 4) % 7;
    else if (bag[(rand_idx + 5) % 7]) selected_idx = (rand_idx + 5) % 7;
    else if (bag[(rand_idx + 6) % 7]) selected_idx = (rand_idx + 6) % 7;
    
    // Calculate next bag state
    // Clear the selected bit
    next_bag = bag & ~(1 << selected_idx);
    
    // If bag becomes empty, refill immediately for next time
    if (next_bag == 0) next_bag = 7'b1111111;
  end

  // Update current_shape based on selected_idx (not rand_idx)
  always_comb begin
    case (selected_idx)
        `TETROMINO_I_IDX: begin
            current_shape.data[0] = {4'b0000, 4'b1111, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0010, 4'b0010, 4'b0010, 4'b0010};
            current_shape.data[2] = {4'b0000, 4'b1111, 4'b0000, 4'b0000};
            current_shape.data[3] = {4'b0010, 4'b0010, 4'b0010, 4'b0010};
        end
        `TETROMINO_J_IDX: begin
            current_shape.data[0] = {4'b1000, 4'b1110, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0110, 4'b0100, 4'b0100, 4'b0000};
            current_shape.data[2] = {4'b0000, 4'b1110, 4'b0010, 4'b0000};
            current_shape.data[3] = {4'b0010, 4'b0010, 4'b0110, 4'b0000};
        end
        `TETROMINO_L_IDX: begin
            current_shape.data[0] = {4'b0010, 4'b1110, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0100, 4'b0100, 4'b0110, 4'b0000};
            current_shape.data[2] = {4'b0000, 4'b1110, 4'b1000, 4'b0000};
            current_shape.data[3] = {4'b1100, 4'b0100, 4'b0100, 4'b0000};
        end
        `TETROMINO_O_IDX: begin
            current_shape.data[0] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
            current_shape.data[2] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
            current_shape.data[3] = {4'b0110, 4'b0110, 4'b0000, 4'b0000};
        end
        `TETROMINO_S_IDX: begin
            current_shape.data[0] = {4'b0110, 4'b1100, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0100, 4'b0110, 4'b0010, 4'b0000};
            current_shape.data[2] = {4'b0000, 4'b0110, 4'b1100, 4'b0000};
            current_shape.data[3] = {4'b1000, 4'b1100, 4'b0100, 4'b0000};
        end
        `TETROMINO_T_IDX: begin
            current_shape.data[0] = {4'b0100, 4'b1110, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0100, 4'b0110, 4'b0100, 4'b0000};
            current_shape.data[2] = {4'b0000, 4'b1110, 4'b0100, 4'b0000};
            current_shape.data[3] = {4'b0100, 4'b1100, 4'b0100, 4'b0000};
        end
        `TETROMINO_Z_IDX: begin
            current_shape.data[0] = {4'b1100, 4'b0110, 4'b0000, 4'b0000};
            current_shape.data[1] = {4'b0010, 4'b0110, 4'b0100, 4'b0000};
            current_shape.data[2] = {4'b0000, 4'b1100, 4'b0110, 4'b0000};
            current_shape.data[3] = {4'b0100, 4'b1100, 4'b1000, 4'b0000};
        end
        default: current_shape = '0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (rst) begin
        bag <= 7'b1111111;
        
        // Initialize Current to Empty
        t_out.idx.data <= `TETROMINO_EMPTY;
        t_out.rotation <= 0;
        t_out.coordinate.x <= 3;
        t_out.coordinate.y <= 0;
        t_out.tetromino.data <= '0; // No shape
        
        // Initialize Next (Wait for Warmup to pick valid)
        // But we can pick one now using default bag
        // Actually, let's just init to empty and let Warmup handle it.
        // But Warmup expects t_next to be valid after GEN.
        // So we should init t_next to SOMETHING.
        // Let's use the logic.
        // But bag update happens on clock.
        // On reset, we can't easily pick a random one and update bag same cycle without complex logic.
        // The Warmup phase will run 'enable' once.
        // So on Reset, just set t_next to Empty or a default.
        // Warmup will overwrite it.
        t_next_out.idx.data <= 0; // Default I
        t_next_out.tetromino <= '0;
        t_next_out.rotation <= 0;
        t_next_out.coordinate.x <= 3;
        t_next_out.coordinate.y <= 0;
        
    end else if (enable) begin
        // Shift Next to Current
        t_out <= t_next_out;
        
        // Generate New Next
        t_next_out.idx.data <= selected_idx;
        t_next_out.tetromino <= current_shape;
        t_next_out.rotation <= 0;
        t_next_out.coordinate.x <= 3;
        t_next_out.coordinate.y <= 0;
        
        // Update Bag
        bag <= next_bag;
    end
  end

endmodule
