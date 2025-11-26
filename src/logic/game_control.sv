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
    input   logic           key_hold,   // Hold Piece Pulse
    input   logic           key_drop_held, // Raw state for lockout
    
    output  field_t         display,
    output  logic [31:0]    score,
    output  logic           game_over,
    output  tetromino_ctrl  t_next_disp,
    output  tetromino_ctrl  t_hold_disp,  // Hold piece for display
    output  logic           hold_used_out, // Whether hold was used this piece
    output  logic [3:0]     current_level_out,
    output  logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y,
    output  tetromino_ctrl  t_curr_out
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
    HOLD,
    HOLD_SWAP,
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
  tetromino_ctrl t_hold;  // Held piece
  tetromino_ctrl t_hold_old; // Temp storage for swap
  logic hold_used;        // Can only hold once per piece placement
  logic hold_empty;       // Whether hold slot is empty
  
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
      // Level increases every 1000 points (10 lines)
      // Score is BCD. Thousands digit is score[15:12]. Ten-thousands is score[19:16].
      current_level = score[15:12] + (score[19:16] * 10); 
      if (current_level > 15) current_level = 15;
       // Speed: 40 frames (faster start) -> 5 frames (fast)
       if (current_level * 2 >= 35) drop_speed_frames = 5;
       else drop_speed_frames = 40 - (current_level * 2);
  end
  
  // Timers
  integer drop_timer;
  
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

  // Ghost Calculation
  ghost_calc ghost (
    .t_curr(t_curr),
    .f(f_curr),
    .ghost_y(ghost_y)
  );

  assign t_curr_out = t_curr;
  assign display = f_disp;
  assign t_next_disp = t_gen_next;
  assign t_hold_disp = t_hold;
  assign hold_used_out = hold_used;
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
        HOLD_SWAP: begin
            // After swapping, validate the old held piece at spawn position
            t_check = t_hold_old;
            t_check.coordinate.x = 3;
            t_check.coordinate.y = 0;
            t_check.rotation = 0;
        end
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
            else if (key_hold && !hold_used) ns = HOLD;
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
        
        HOLD: begin
            // If hold is empty, just store current and get new piece
            // If hold has a piece, swap them
            if (hold_empty) ns = GEN;
            else ns = HOLD_SWAP;
        end
        
        HOLD_SWAP: begin
            // After swap, validate the swapped piece
            if (valid) ns = IDLE;
            else ns = GAME_OVER_STATE; // Rare: swapped piece doesn't fit
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
            if (!key_drop_held) ns = GEN;
        end
    endcase
  end
  
  // State Update & Data Path
  always_ff @(posedge clk) begin
    if (rst) begin
        ps <= WARMUP;
        f_curr.data <= '1; // Initialize to all 1s (TETROMINO_EMPTY = 3'b111)
        t_curr.idx.data <= `TETROMINO_EMPTY;
        t_curr.tetromino.data <= '0;
        t_hold.idx.data <= `TETROMINO_EMPTY;
        t_hold.tetromino.data <= '0;
        t_hold_old.idx.data <= `TETROMINO_EMPTY;
        t_hold_old.tetromino.data <= '0;
        hold_empty <= 1;
        hold_used <= 0;
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
                // Note: hold_used is reset in DROP_LOCKOUT, not here
                // This allows hold to work correctly when coming from HOLD->GEN->GEN_WAIT
            end
            
            DROP_LOCKOUT: begin
                // Reset hold_used when piece is placed (ready for next piece)
                hold_used <= 0;
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
            
            HOLD: begin
                // Save old held piece for swap (if not empty)
                t_hold_old <= t_hold;
                
                // Store current piece in hold (reset rotation and position)
                t_hold.idx <= t_curr.idx;
                t_hold.tetromino <= t_curr.tetromino;
                t_hold.rotation <= 0;
                t_hold.coordinate.x <= 3;
                t_hold.coordinate.y <= 0;
                hold_used <= 1;
                
                if (hold_empty) begin
                    hold_empty <= 0;
                    // Will transition to GEN to get new piece
                end
                // If not empty, will transition to HOLD_SWAP
            end
            
            HOLD_SWAP: begin
                // Load the OLD held piece as current (from temp storage)
                t_curr.idx <= t_hold_old.idx;
                t_curr.tetromino <= t_hold_old.tetromino;
                t_curr.rotation <= 0;
                t_curr.coordinate.x <= 3;
                t_curr.coordinate.y <= 0;
            end
            
            CLEAN: begin
                if (clean_done) begin
                    f_curr <= f_cleaned;
                    // BCD Score Update (Add lines_cleared * 100)
                    // score[11:8] is hundreds digit
                    // We only add 1, 2, 3, or 4 to hundreds.
                    if (score[11:8] + lines_cleared > 9) begin
                        score[11:8] <= score[11:8] + lines_cleared - 10;
                        // Carry to thousands
                        if (score[15:12] == 9) begin
                            score[15:12] <= 0;
                            // Carry to ten-thousands
                            if (score[19:16] == 9) begin
                                score[19:16] <= 0;
                                score[23:20] <= score[23:20] + 1;
                            end else begin
                                score[19:16] <= score[19:16] + 1;
                            end
                        end else begin
                            score[15:12] <= score[15:12] + 1;
                        end
                    end else begin
                        score[11:8] <= score[11:8] + lines_cleared;
                    end
                end
            end
            
            GAME_OVER_STATE: begin
                game_over <= 1;
            end
            
            RESET_GAME: begin
                f_curr.data <= '1;
                t_hold.idx.data <= `TETROMINO_EMPTY;
                t_hold.tetromino.data <= '0;
                hold_empty <= 1;
                hold_used <= 0;
                score <= 0;
                game_over <= 0;
            end
        endcase
    end
  end

endmodule
