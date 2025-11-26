`include "../GLOBAL.sv"

module game_control (
    input   logic           clk,
    input   logic           rst,
    input   logic           tick_game, // 60Hz tick
    
    // Inputs (Single Pulse)
    input   logic           key_left,
    input   logic           key_right,
    input   logic           key_down,
    input   logic           key_rotate,
    input   logic           key_drop,
    input   logic           key_hold,
    input   logic           key_drop_held,
    
    output  field_t         display,
    output  logic [31:0]    score,
    output  logic           game_over,
    output  tetromino_ctrl  t_next_disp,
    output  tetromino_ctrl  t_hold_disp,
    output  logic           hold_used_out,
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
  tetromino_ctrl t_check;
  tetromino_ctrl t_hold;
  tetromino_ctrl t_hold_old;
  logic hold_used;
  logic hold_empty;
  
  // Scoring & Level Tracking
  logic [7:0] total_lines_cleared;  // Total lines for level calculation
  logic [3:0] consecutive_clears;   // Streak counter (0-15)
  
  field_t f_curr, f_disp, f_cleaned;
  
  logic valid;
  logic rotate_done, rotate_success;
  logic clean_done;
  logic [2:0] lines_cleared;
  
  // Level & Speed Logic
  logic [3:0] current_level;
  logic [31:0] drop_speed_frames;
  
  always_comb begin
      // NES-style leveling: 10 lines per level
      current_level = total_lines_cleared / 10;
      if (current_level > 15) current_level = 15;
      
      // NES-inspired speed curve
      case (current_level)
          0: drop_speed_frames = 48;
          1: drop_speed_frames = 43;
          2: drop_speed_frames = 38;
          3: drop_speed_frames = 33;
          4: drop_speed_frames = 28;
          5: drop_speed_frames = 23;
          6: drop_speed_frames = 18;
          7: drop_speed_frames = 13;
          8: drop_speed_frames = 8;
          9: drop_speed_frames = 6;
          10: drop_speed_frames = 5;
          11: drop_speed_frames = 5;
          12: drop_speed_frames = 5;
          13: drop_speed_frames = 4;
          14: drop_speed_frames = 4;
          15: drop_speed_frames = 3;
          default: drop_speed_frames = 3;
      endcase
  end
  
  // Timers
  integer drop_timer;
  
  // Submodules
  generate_tetromino gen (
    .clk(clk),
    .rst(rst),
    .enable(ps == GEN || ps == WARMUP),
    .t_out(t_gen),
    .t_next_out(t_gen_next)
  );
  
  tetromino_ctrl t_rotated;
  rotate_clockwise rot (
    .clk(clk),
    .enable(ps == ROTATE),
    .t_in(t_curr),
    .t_out(t_rotated),
    .success(rotate_success),
    .done(rotate_done)
  );
  
  check_valid validator (
    .t_ctrl(t_check),
    .f(f_curr),
    .isValid(valid)
  );
  
  create_field merger (
    .t_ctrl(t_curr),
    .f(f_curr),
    .f_out(f_disp)
  );
  
  clean_field cleaner (
    .clk(clk),
    .enable(ps == CLEAN),
    .f_in(f_curr),
    .f_out(f_cleaned),
    .lines_cleared(lines_cleared),
    .done(clean_done)
  );

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
    t_check = t_curr;
    case (ps)
        GEN_WAIT: t_check = t_gen;
        MOVE_LEFT: t_check.coordinate.x = t_curr.coordinate.x - 1;
        MOVE_RIGHT: t_check.coordinate.x = t_curr.coordinate.x + 1;
        DOWN: t_check.coordinate.y = t_curr.coordinate.y + 1;
        HARD_DROP: t_check.coordinate.y = t_curr.coordinate.y + 1;
        ROTATE: t_check = t_rotated;
        HOLD_SWAP: begin
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
        GEN: ns = GEN_WAIT;
        
        GEN_WAIT: begin
            if (valid) ns = IDLE;
            else ns = GAME_OVER_STATE;
        end
        
        IDLE: begin
            if (key_drop) ns = HARD_DROP;
            else if (key_hold && !hold_used) ns = HOLD;
            else if (key_rotate) ns = ROTATE;
            else if (key_left) ns = MOVE_LEFT;
            else if (key_right) ns = MOVE_RIGHT;
            else if (drop_timer >= drop_speed_frames || key_down) ns = DOWN;
        end
        
        MOVE_LEFT: ns = IDLE;
        MOVE_RIGHT: ns = IDLE;
        
        ROTATE: begin
            if (rotate_done) ns = IDLE;
        end
        
        DOWN: begin
            if (valid) ns = IDLE;
            else ns = CLEAN;
        end
        
        HARD_DROP: begin
            if (valid) ns = HARD_DROP;
            else ns = CLEAN;
        end
        
        HOLD: begin
            if (hold_empty) ns = GEN;
            else ns = HOLD_SWAP;
        end
        
        HOLD_SWAP: begin
            if (valid) ns = IDLE;
            else ns = GAME_OVER_STATE;
        end
        
        CLEAN: begin
            if (clean_done) ns = DROP_LOCKOUT;
        end
        
        GAME_OVER_STATE: begin
            if (key_drop) ns = RESET_GAME;
        end
        
        RESET_GAME: ns = WARMUP;
        WARMUP: ns = GEN;
        
        DROP_LOCKOUT: begin
            if (!key_drop_held) ns = GEN;
        end
    endcase
  end
  
  // =====================================================================
  // NES-STYLE SCORING COMPUTATION (Combinational)
  // =====================================================================
  // Formula: base_score × (level + 1) + streak_bonus
  //
  // Base scores (NES Tetris):
  //   Single: 40 points
  //   Double: 100 points
  //   Triple: 300 points
  //   Tetris: 1200 points (BIG reward!)
  //
  // Streak bonus: consecutive_clears × 100 (capped at 500)
  // =====================================================================
  
  logic [11:0] base_score_raw;    // Base score before level multiply
  logic [4:0]  level_mult;        // (level + 1)
  logic [15:0] base_total;        // base × level
  logic [9:0]  streak_bonus;      // Streak bonus points
  logic [15:0] points_to_add;     // Total points to add
  
  always_comb begin
      // NES base scores
      case (lines_cleared)
          3'd1: base_score_raw = 12'd40;
          3'd2: base_score_raw = 12'd100;
          3'd3: base_score_raw = 12'd300;
          3'd4: base_score_raw = 12'd1200;  // TETRIS!
          default: base_score_raw = 12'd0;
      endcase
      
      // Level multiplier (current_level + 1)
      level_mult = (current_level < 15) ? (current_level + 1) : 5'd16;
      
      // Multiply base by level
      base_total = base_score_raw * level_mult;
      
      // Streak bonus: +100 per consecutive clear, capped at +500
      if (lines_cleared != 0 && consecutive_clears > 0) begin
          if (consecutive_clears >= 5)
              streak_bonus = 10'd500;  // Cap at 500
          else
              streak_bonus = consecutive_clears * 10'd100;
      end else begin
          streak_bonus = 10'd0;
      end
      
      // Total points to add this clear
      points_to_add = base_total + streak_bonus;
  end
  
  // State Update & Data Path
  always_ff @(posedge clk) begin
    if (rst) begin
        ps <= WARMUP;
        f_curr.data <= '1;
        t_curr.idx.data <= `TETROMINO_EMPTY;
        t_curr.tetromino.data <= '0;
        t_hold.idx.data <= `TETROMINO_EMPTY;
        t_hold.tetromino.data <= '0;
        t_hold_old.idx.data <= `TETROMINO_EMPTY;
        t_hold_old.tetromino.data <= '0;
        hold_empty <= 1;
        hold_used <= 0;
        total_lines_cleared <= 0;
        consecutive_clears <= 0;
        score <= 0;
        game_over <= 0;
        drop_timer <= 0;
    end else begin
        ps <= ns;
        
        // Timer Logic
        if (tick_game) begin
            if (ps == IDLE) drop_timer <= drop_timer + 1;
        end
        if (ps == DOWN || ps == GEN) drop_timer <= 0;
        
        // Data Path Updates
        case (ps)
            GEN_WAIT: begin
                t_curr <= t_gen;
            end
            
            DROP_LOCKOUT: begin
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
                    f_curr <= f_disp;
                end
            end
            
            HARD_DROP: begin
                if (valid) begin
                    t_curr.coordinate.y <= t_curr.coordinate.y + 1;
                end else begin
                    f_curr <= f_disp;
                end
            end
            
            HOLD: begin
                t_hold_old <= t_hold;
                t_hold.idx <= t_curr.idx;
                t_hold.tetromino <= t_curr.tetromino;
                t_hold.rotation <= 0;
                t_hold.coordinate.x <= 3;
                t_hold.coordinate.y <= 0;
                hold_used <= 1;
                
                if (hold_empty) begin
                    hold_empty <= 0;
                end
            end
            
            HOLD_SWAP: begin
                t_curr.idx <= t_hold_old.idx;
                t_curr.tetromino <= t_hold_old.tetromino;
                t_curr.rotation <= 0;
                t_curr.coordinate.x <= 3;
                t_curr.coordinate.y <= 0;
            end
            
            CLEAN: begin
                if (clean_done) begin
                    f_curr <= f_cleaned;
                    
                    // Update total lines cleared
                    if (lines_cleared != 0) begin
                        total_lines_cleared <= total_lines_cleared + lines_cleared;
                    end
                    
                    // Update consecutive clears counter
                    if (lines_cleared != 0) begin
                        if (consecutive_clears < 15) 
                            consecutive_clears <= consecutive_clears + 1;
                    end else begin
                        consecutive_clears <= 0;  // Reset on empty clear
                    end
                    
                    // ====================================================
                    // BCD Score Addition
                    // Add points_to_add (binary) to score (BCD)
                    // Max value: 1200 × 16 + 500 = 19,700
                    // ====================================================
                    if (lines_cleared != 0) begin
                        // Convert binary points to BCD and add
                        // We'll do this digit by digit with carry propagation
                        logic [15:0] points_remaining;
                        logic [3:0] digit_value;
                        logic [3:0] new_digit;
                        logic carry;
                        
                        points_remaining = points_to_add;
                        
                        // Ones digit: score[3:0]
                        digit_value = points_remaining % 10;
                        points_remaining = points_remaining / 10;
                        new_digit = score[3:0] + digit_value;
                        if (new_digit >= 10) begin
                            score[3:0] <= new_digit - 10;
                            carry = 1;
                        end else begin
                            score[3:0] <= new_digit;
                            carry = 0;
                        end
                        
                        // Tens digit: score[7:4]
                        digit_value = (points_remaining % 10) + carry;
                        points_remaining = points_remaining / 10;
                        new_digit = score[7:4] + digit_value;
                        if (new_digit >= 10) begin
                            score[7:4] <= new_digit - 10;
                            carry = 1;
                        end else begin
                            score[7:4] <= new_digit;
                            carry = 0;
                        end
                        
                        // Hundreds digit: score[11:8]
                        digit_value = (points_remaining % 10) + carry;
                        points_remaining = points_remaining / 10;
                        new_digit = score[11:8] + digit_value;
                        if (new_digit >= 10) begin
                            score[11:8] <= new_digit - 10;
                            carry = 1;
                        end else begin
                            score[11:8] <= new_digit;
                            carry = 0;
                        end
                        
                        // Thousands digit: score[15:12]
                        digit_value = (points_remaining % 10) + carry;
                        points_remaining = points_remaining / 10;
                        new_digit = score[15:12] + digit_value;
                        if (new_digit >= 10) begin
                            score[15:12] <= new_digit - 10;
                            carry = 1;
                        end else begin
                            score[15:12] <= new_digit;
                            carry = 0;
                        end
                        
                        // Ten-thousands digit: score[19:16]
                        digit_value = (points_remaining % 10) + carry;
                        points_remaining = points_remaining / 10;
                        new_digit = score[19:16] + digit_value;
                        if (new_digit >= 10) begin
                            score[19:16] <= new_digit - 10;
                            carry = 1;
                        end else begin
                            score[19:16] <= new_digit;
                            carry = 0;
                        end
                        
                        // Hundred-thousands and beyond (carry propagation)
                        if (carry) begin
                            if (score[23:20] == 9) begin
                                score[23:20] <= 0;
                                if (score[27:24] == 9) begin
                                    score[27:24] <= 0;
                                    score[31:28] <= score[31:28] + 1;
                                end else begin
                                    score[27:24] <= score[27:24] + 1;
                                end
                            end else begin
                                score[23:20] <= score[23:20] + 1;
                            end
                        end
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
                total_lines_cleared <= 0;
                consecutive_clears <= 0;
                score <= 0;
                game_over <= 0;
            end
        endcase
    end
  end

endmodule