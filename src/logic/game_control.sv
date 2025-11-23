`include "../GLOBAL.sv"

module game_control (
    input   logic           clk,
    input   logic           rst,
    input   logic           tick_game, // 60Hz tick
    
    // Inputs (Single Pulse)
    input   logic           key_left,
    input   logic           key_right,
    input   logic           key_down,   // Soft Drop (Continuous or Pulse?) - usually continuous for soft drop
    input   logic           key_rotate, // Pulse
    input   logic           key_drop,   // Hard Drop Pulse
    
    output  field_t         display,
    output  logic [31:0]    score,
    output  logic           game_over,
    output  tetromino_ctrl  t_next_disp,
    output  logic [3:0]     current_level_out
  );

  // States
  typedef enum logic [3:0] {
    GEN,
    GEN_WAIT,
    IDLE,
    MOVE_LEFT,
    MOVE_RIGHT,
    ROTATE,
    DOWN,
    HARD_DROP,
    CLEAN,
    GAME_OVER_STATE,
    RESET_GAME,
    WARMUP,
    DROP_LOCKOUT
  } state_t;
  
  state_t ps, ns;
  
  // Internal Signals
  tetromino_ctrl t_curr, t_curr_cand, t_gen, t_gen_next;
  tetromino_ctrl t_check; // Candidate for validation
  
  field_t f_curr, f_disp, f_cleaned;
  
  logic valid;
  logic rotate_done, rotate_success;
  logic clean_done;
  logic [2:0] lines_cleared;
  
  // Level & Speed Logic
  logic [3:0] current_level;
  logic [31:0] drop_speed_frames;
  
  always_comb begin
      // Level increases every 10 lines (approx 1000 score / 100)
      // Or just use score / 1000? The user code had score / 10 which is very fast leveling.
      // Let's stick to the previous logic: score / 10 (assuming score is lines * 10? No, lines * 100).
      // So score / 1000 = 1 level per 10 lines.
      current_level = (score / 1000); 
      if (current_level > 15) current_level = 15;
            // Speed: 40 frames (faster start) -> 5 frames (fast)
       // 40 - (level * 2)
       if (current_level * 2 >= 35) drop_speed_frames = 5;
       else drop_speed_frames = 40 - (current_level * 2);
  end
  
  // Timers
  integer drop_timer;
  // localparam DROP_SPEED removed in favor of dynamic speed
  
  // Submodules
  
  // Generator
  generate_tetromino gen (
    .clk(clk),
    .rst(rst),
    .enable(ps == GEN || ps == WARMUP),
    .t_out(t_gen),
    .t_next_out(t_gen_next)
  );
  
  // Rotation
  tetromino_ctrl t_rotated;
  rotate_clockwise rot (
    .clk(clk),
    .enable(ps == ROTATE),
    .t_in(t_curr),
    .t_out(t_rotated),
    .success(rotate_success),
    .done(rotate_done)
  );
  
  // Validation
  check_valid validator (
    .t_ctrl(t_check),
    .f(f_curr),
    .isValid(valid)
  );
  
  // Field Creation (Merging Piece)
  create_field merger (
    .t_ctrl(t_curr),
    .f(f_curr),
    .f_out(f_disp)
  );
  
  // Cleaning
  clean_field cleaner (
    .clk(clk),
    .enable(ps == CLEAN),
    .f_in(f_curr),
    .f_out(f_cleaned),
    .lines_cleared(lines_cleared),
    .done(clean_done)
  );
  
  assign display = f_disp;
  assign t_next_disp = t_gen_next;
  assign current_level_out = current_level;
  
  // Candidate Logic for Validation
  always_comb begin
    t_check = t_curr; // Default
    case (ps)
        GEN_WAIT: t_check = t_gen; // Check the generated piece
        MOVE_LEFT: t_check.coordinate.x = t_curr.coordinate.x - 1;
        MOVE_RIGHT: t_check.coordinate.x = t_curr.coordinate.x + 1;
        DOWN: t_check.coordinate.y = t_curr.coordinate.y + 1;
        HARD_DROP: t_check.coordinate.y = t_curr.coordinate.y + 1;
        ROTATE: t_check = t_rotated; // Use output of rotator
        default: t_check = t_curr;
    endcase
  end

  // FSM Next State Logic
  always_comb begin
    ns = ps;
    case (ps)
        GEN: begin
            ns = GEN_WAIT;
        end
        
        GEN_WAIT: begin
            // t_gen is now stable
            if (valid) ns = IDLE;
            else ns = GAME_OVER_STATE;
        end
        
        IDLE: begin
            if (key_drop) ns = HARD_DROP;
            else if (key_rotate) ns = ROTATE;
            else if (key_left) ns = MOVE_LEFT;
            else if (key_right) ns = MOVE_RIGHT;
            // Fix: key_down is already a pulse from input_manager, don't AND with tick_game again
            // Dynamic speed based on level
            else if (drop_timer >= drop_speed_frames || key_down) ns = DOWN;
        end
        
        MOVE_LEFT: ns = IDLE;
        MOVE_RIGHT: ns = IDLE;
        
        ROTATE: begin
            if (rotate_done) ns = IDLE;
        end
        
        DOWN: begin
            if (valid) ns = IDLE;
            else ns = CLEAN; // Lock and Clean
        end
        
        HARD_DROP: begin
            // If valid, we moved down. Loop back to HARD_DROP to keep moving.
            // If invalid, we hit bottom. Go to CLEAN.
            if (valid) ns = HARD_DROP;
            else ns = CLEAN;
        end
        
        CLEAN: begin
            if (clean_done) ns = DROP_LOCKOUT;
        end
        
        GAME_OVER_STATE: begin
            // Restart on Middle Button (key_drop)
            if (key_drop) begin
                ns = RESET_GAME;
            end
        end
        
        RESET_GAME: begin
            ns = WARMUP;
        end
        
        WARMUP: begin
            ns = GEN;
        end
        
        DROP_LOCKOUT: begin
            if (!key_drop) ns = GEN;
        end
    endcase
  end
  
  // State Update & Data Path
  always_ff @(posedge clk) begin
    if (rst) begin
        ps <= GEN;
        f_curr.data <= '1; // Initialize to all 1s (TETROMINO_EMPTY = 3'b111)
        t_curr.idx.data <= `TETROMINO_EMPTY;
        t_curr.tetromino.data <= '0;
        score <= 0;
        game_over <= 0;
        drop_timer <= 0;
    end else begin
        ps <= ns;
        
        // Timer Logic
        if (tick_game) begin
            if (ps == IDLE) drop_timer <= drop_timer + 1;
        end
        if (ps == DOWN || ps == GEN) drop_timer <= 0; // Reset on drop or spawn
        
        // Data Path Updates
        case (ps)
            GEN_WAIT: begin
                t_curr <= t_gen;
            end
            
            MOVE_LEFT: begin
                if (valid) t_curr.coordinate.x <= t_curr.coordinate.x - 1;
            end
            
            MOVE_RIGHT: begin
                if (valid) t_curr.coordinate.x <= t_curr.coordinate.x + 1;
            end
            
            ROTATE: begin
                if (rotate_done && valid) t_curr <= t_rotated;
            end
            
            DOWN: begin
                if (valid) begin
                    t_curr.coordinate.y <= t_curr.coordinate.y + 1;
                end else begin
                    // Lock happens implicitly by NOT updating t_curr 
                    // and merging it into f_curr via create_field logic?
                    // No, create_field creates f_disp (visual only).
                    // We need to bake t_curr into f_curr.
                    // But wait, create_field does exactly that: f_out = f + t.
                    // So if we set f_curr <= f_disp (which is f_curr + t_curr), we lock it.
                    f_curr <= f_disp; 
                end
            end
            
            HARD_DROP: begin
                if (valid) begin
                    t_curr.coordinate.y <= t_curr.coordinate.y + 1;
                end else begin
                    f_curr <= f_disp; // Lock
                end
            end
            
            CLEAN: begin
                if (clean_done) begin
                    f_curr <= f_cleaned;
                    score <= score + (lines_cleared * 100); // Simple scoring
                end
            end
            
            GAME_OVER_STATE: begin
                game_over <= 1;
            end
            
            RESET_GAME: begin
                f_curr.data <= '1;
                score <= 0;
                game_over <= 0;
            end
        endcase
    end
  end

endmodule
