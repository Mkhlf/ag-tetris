`include "../GLOBAL.sv"

module game_control (
    input   logic           clk,
    input   logic           rst,
    input   logic           tick_game,
    
    // Inputs (Single Pulse)
    input   logic           key_left,
    input   logic           key_right,
    input   logic           key_down,
    input   logic           key_rotate_cw,
    input   logic           key_rotate_ccw,
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
    output  tetromino_ctrl  t_curr_out,
    
    output  logic [7:0]     total_lines_cleared_out // Exposed for level bar
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
  logic [7:0] total_lines_cleared;
  logic [3:0] consecutive_clears;
  
  field_t f_curr, f_disp, f_cleaned;
  
  logic valid;
  logic rotate_done, rotate_success;
  logic clean_done;
  logic [2:0] lines_cleared;
  
  // Rotation & Kick System
  logic [2:0] kick_attempt;
  logic rotate_direction;
  logic [1:0] rotation_from;
  logic last_move_was_rotation;  // NEW: Track if last lock was from rotation
  logic [2:0] kick_used;         // NEW: Which kick succeeded (0-4)
  
  // Spin Detection
  logic is_t_spin;
  logic is_t_spin_mini;
  logic is_s_spin;
  logic is_z_spin;
  logic is_j_spin;
  logic is_l_spin;
  logic is_i_spin;
  
  // Level & Speed Logic
  logic [3:0] current_level;
  logic [31:0] drop_speed_frames;
  
  always_comb begin
      current_level = total_lines_cleared / 10;
      if (current_level >= 15) current_level = 15; // MAX_LEVEL 
      
    case (current_level)
        0:  drop_speed_frames = 40;   
        1:  drop_speed_frames = 37;   
        2:  drop_speed_frames = 34;   
        3:  drop_speed_frames = 30;   
        4:  drop_speed_frames = 26;   
        5:  drop_speed_frames = 21;   
        6:  drop_speed_frames = 15;   
        7:  drop_speed_frames = 12;   
        8:  drop_speed_frames = 8;
        9:  drop_speed_frames = 6;
        10: drop_speed_frames = 5;
        11: drop_speed_frames = 5;
        12: drop_speed_frames = 5;
        13: drop_speed_frames = 4;
        14: drop_speed_frames = 3;
        15: drop_speed_frames = 2;    
        default: drop_speed_frames = 2; // Impossible mode!
    endcase
  end
  
  // =================================================================
  // SRS KICK TABLES
  // =================================================================
  
  localparam kick_offset_t JLSTZ_KICKS_CW[4][5] = '{
      '{'{3'sd0, 3'sd0}, '{-3'sd1, 3'sd0}, '{-3'sd1, 3'sd1}, '{3'sd0, -3'sd2}, '{-3'sd1, -3'sd2}},
      '{'{3'sd0, 3'sd0}, '{3'sd1, 3'sd0}, '{3'sd1, -3'sd1}, '{3'sd0, 3'sd2}, '{3'sd1, 3'sd2}},
      '{'{3'sd0, 3'sd0}, '{3'sd1, 3'sd0}, '{3'sd1, 3'sd1}, '{3'sd0, -3'sd2}, '{3'sd1, -3'sd2}},
      '{'{3'sd0, 3'sd0}, '{-3'sd1, 3'sd0}, '{-3'sd1, -3'sd1}, '{3'sd0, 3'sd2}, '{-3'sd1, 3'sd2}}
  };
  
  localparam kick_offset_t JLSTZ_KICKS_CCW[4][5] = '{
      '{'{3'sd0, 3'sd0}, '{3'sd1, 3'sd0}, '{3'sd1, 3'sd1}, '{3'sd0, -3'sd2}, '{3'sd1, -3'sd2}},
      '{'{3'sd0, 3'sd0}, '{-3'sd1, 3'sd0}, '{-3'sd1, -3'sd1}, '{3'sd0, 3'sd2}, '{-3'sd1, 3'sd2}},
      '{'{3'sd0, 3'sd0}, '{-3'sd1, 3'sd0}, '{-3'sd1, 3'sd1}, '{3'sd0, -3'sd2}, '{-3'sd1, -3'sd2}},
      '{'{3'sd0, 3'sd0}, '{3'sd1, 3'sd0}, '{3'sd1, -3'sd1}, '{3'sd0, 3'sd2}, '{3'sd1, 3'sd2}}
  };
  
  localparam kick_offset_t I_KICKS_CW[4][5] = '{
      '{'{3'sd0, 3'sd0}, '{-3'sd2, 3'sd0}, '{3'sd1, 3'sd0}, '{-3'sd2, -3'sd1}, '{3'sd1, 3'sd2}},
      '{'{3'sd0, 3'sd0}, '{-3'sd1, 3'sd0}, '{3'sd2, 3'sd0}, '{-3'sd1, 3'sd2}, '{3'sd2, -3'sd1}},
      '{'{3'sd0, 3'sd0}, '{3'sd2, 3'sd0}, '{-3'sd1, 3'sd0}, '{3'sd2, 3'sd1}, '{-3'sd1, -3'sd2}},
      '{'{3'sd0, 3'sd0}, '{3'sd1, 3'sd0}, '{-3'sd2, 3'sd0}, '{3'sd1, -3'sd2}, '{-3'sd2, 3'sd1}}
  };
  
  localparam kick_offset_t I_KICKS_CCW[4][5] = '{
      '{'{3'sd0, 3'sd0}, '{-3'sd1, 3'sd0}, '{3'sd2, 3'sd0}, '{-3'sd1, 3'sd2}, '{3'sd2, -3'sd1}},
      '{'{3'sd0, 3'sd0}, '{3'sd2, 3'sd0}, '{-3'sd1, 3'sd0}, '{3'sd2, 3'sd1}, '{-3'sd1, -3'sd2}},
      '{'{3'sd0, 3'sd0}, '{3'sd1, 3'sd0}, '{-3'sd2, 3'sd0}, '{3'sd1, -3'sd2}, '{-3'sd2, 3'sd1}},
      '{'{3'sd0, 3'sd0}, '{-3'sd2, 3'sd0}, '{3'sd1, 3'sd0}, '{-3'sd2, -3'sd1}, '{3'sd1, 3'sd2}}
  };
  
  kick_offset_t current_kick;
  always_comb begin
      current_kick = '{3'sd0, 3'sd0};
      
      if (ps == ROTATE) begin
          case (t_curr.idx.data)
              `TETROMINO_I_IDX: begin
                  if (rotate_direction)
                      current_kick = I_KICKS_CW[rotation_from][kick_attempt];
                  else
                      current_kick = I_KICKS_CCW[rotation_from][kick_attempt];
              end
              `TETROMINO_O_IDX: begin
                  current_kick = '{3'sd0, 3'sd0};
              end
              default: begin
                  if (rotate_direction)
                      current_kick = JLSTZ_KICKS_CW[rotation_from][kick_attempt];
                  else
                      current_kick = JLSTZ_KICKS_CCW[rotation_from][kick_attempt];
              end
          endcase
      end
  end
  
  // =================================================================
  // SPIN DETECTION LOGIC
  // =================================================================
  // Checks if piece is surrounded by blocks/walls (3-corner rule for T-spins)
  // =================================================================
  
  spin_detector spin_detect (
      .t_ctrl(t_curr),
      .f(f_curr),
      .last_move_was_rotation(last_move_was_rotation),
      .kick_used(kick_used),
      .is_t_spin(is_t_spin),
      .is_t_spin_mini(is_t_spin_mini),
      .is_s_spin(is_s_spin),
      .is_z_spin(is_z_spin),
      .is_j_spin(is_j_spin),
      .is_l_spin(is_l_spin),
      .is_i_spin(is_i_spin)
  );
  
  // Timers
  integer drop_timer;
  integer lock_timer; // NEW: Lock delay timer
  
  localparam LOCK_DELAY_MAX = 30; // ~0.5s at 60Hz
  
  // Submodules
  generate_tetromino gen (
    .clk(clk),
    .rst(rst),
    .enable(ps == GEN || ps == WARMUP),
    .t_out(t_gen),
    .t_next_out(t_gen_next)
  );
  
  tetromino_ctrl t_rotated;
  rotate_tetromino rot (
    .clk(clk),
    .enable(ps == ROTATE && kick_attempt == 0),
    .clockwise(rotate_direction),
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
  assign total_lines_cleared_out = total_lines_cleared;
  
  // Candidate Logic for Validation
  always_comb begin
    t_check = t_curr;
    case (ps)
        GEN_WAIT: t_check = t_gen;
        MOVE_LEFT: t_check.coordinate.x = t_curr.coordinate.x - 1;
        MOVE_RIGHT: t_check.coordinate.x = t_curr.coordinate.x + 1;
        DOWN: t_check.coordinate.y = t_curr.coordinate.y + 1;
        HARD_DROP: t_check.coordinate.y = t_curr.coordinate.y + 1;
            IDLE: t_check.coordinate.y = t_curr.coordinate.y + 1; 
        ROTATE: begin
            t_check = t_rotated;
            t_check.coordinate.x = t_rotated.coordinate.x + current_kick.x;
            t_check.coordinate.y = t_rotated.coordinate.y + current_kick.y;
        end
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
            else if (key_rotate_cw || key_rotate_ccw) ns = ROTATE;
            else if (key_left) ns = MOVE_LEFT;
            else if (key_right) ns = MOVE_RIGHT;
            else if (drop_timer >= drop_speed_frames || key_down) ns = DOWN;
            // Lock Delay Logic: If on ground (!valid) and timer expired -> Lock
            else if (!valid && lock_timer >= LOCK_DELAY_MAX) ns = CLEAN;
        end
        
        MOVE_LEFT: ns = IDLE;
        MOVE_RIGHT: ns = IDLE;
        
        ROTATE: begin
            if (kick_attempt == 0 && !rotate_done) begin
                ns = ROTATE;
            end else if (valid) begin
                ns = IDLE;
            end else if (kick_attempt < 4) begin
                ns = ROTATE;
            end else begin
                ns = IDLE;
            end
        end
        
        DOWN: begin
            if (valid) begin
                ns = IDLE;
            end else begin
                ns = IDLE;
            end
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
  
  // =================================================================
  // SCORING WITH SPINS
  // =================================================================
  logic [11:0] base_score_raw;
  logic [4:0]  level_mult;
  logic [15:0] base_total;
  logic [9:0]  streak_bonus;
  logic [15:0] spin_bonus;
  logic [15:0] points_to_add;
  
  always_comb begin
      // Base line clear scores (NES style)
      case (lines_cleared)
          3'd1: base_score_raw = 12'd40;
          3'd2: base_score_raw = 12'd100;
          3'd3: base_score_raw = 12'd300;
          3'd4: base_score_raw = 12'd1200;  // Tetris!
          default: base_score_raw = 12'd0;
      endcase
      
      level_mult = (current_level < 15) ? (current_level + 1) : 5'd16;
      base_total = base_score_raw * level_mult;
      
      // Streak bonus
      if (lines_cleared != 0 && consecutive_clears > 0) begin
          if (consecutive_clears >= 5)
              streak_bonus = 10'd500;
          else
              streak_bonus = consecutive_clears * 10'd100;
      end else begin
          streak_bonus = 10'd0;
      end
      
      // =================================================================
      // SPIN BONUSES (Modern Tetris Guidelines)
      // =================================================================
      spin_bonus = 16'd0;
      
      // T-Spin scoring (most valuable)
      if (is_t_spin && !is_t_spin_mini) begin
          case (lines_cleared)
              3'd0: spin_bonus = 16'd400 * level_mult;   // T-Spin no lines
              3'd1: spin_bonus = 16'd800 * level_mult;   // T-Spin Single
              3'd2: spin_bonus = 16'd1200 * level_mult;  // T-Spin Double
              3'd3: spin_bonus = 16'd1600 * level_mult;  // T-Spin Triple
              default: spin_bonus = 16'd0;
          endcase
      end 
      // T-Spin Mini (less valuable)
      else if (is_t_spin_mini) begin
          case (lines_cleared)
              3'd0: spin_bonus = 16'd100 * level_mult;   // Mini T-Spin no lines
              3'd1: spin_bonus = 16'd200 * level_mult;   // Mini T-Spin Single
              default: spin_bonus = 16'd0;
          endcase
      end
      // S/Z-Spin scoring (moderate bonus)
      else if (is_s_spin || is_z_spin) begin
          case (lines_cleared)
              3'd1: spin_bonus = 16'd400 * level_mult;
              3'd2: spin_bonus = 16'd800 * level_mult;
              3'd3: spin_bonus = 16'd1200 * level_mult;
              default: spin_bonus = 16'd0;
          endcase
      end
      // J/L-Spin scoring (moderate bonus)
      else if (is_j_spin || is_l_spin) begin
          case (lines_cleared)
              3'd1: spin_bonus = 16'd400 * level_mult;
              3'd2: spin_bonus = 16'd800 * level_mult;
              3'd3: spin_bonus = 16'd1200 * level_mult;
              default: spin_bonus = 16'd0;
          endcase
      end
      // I-Spin (rare, moderate bonus)
      else if (is_i_spin) begin
          case (lines_cleared)
              3'd1: spin_bonus = 16'd400 * level_mult;
              3'd2: spin_bonus = 16'd800 * level_mult;
              3'd4: spin_bonus = 16'd1600 * level_mult;  // I-Spin Tetris
              default: spin_bonus = 16'd0;
          endcase
      end
      
      // Total points
      points_to_add = base_total + streak_bonus + spin_bonus;
  end

  // BCD Conversion
  logic [3:0] bcd_digits[4:0];
  bin_to_bcd #(
      .BINARY_WIDTH(16),
      .BCD_DIGITS(5)
  ) bcd_converter (
      .binary(points_to_add),
      .bcd(bcd_digits)
  );

  logic [3:0] bcd_ones, bcd_tens, bcd_hundreds, bcd_thousands, bcd_tenthousands;
  always_comb begin
      bcd_ones = bcd_digits[0];
      bcd_tens = bcd_digits[1];
      bcd_hundreds = bcd_digits[2];
      bcd_thousands = bcd_digits[3];
      bcd_tenthousands = bcd_digits[4];
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
        kick_attempt <= 0;
        rotate_direction <= 1;
        rotation_from <= 0;
        last_move_was_rotation <= 0;
        kick_used <= 0;
        lock_timer <= 0;
    end else begin
        ps <= ns;
        
        // Timer Logic
        // if (tick_game) begin
        //     if (ps == IDLE) drop_timer <= drop_timer + 1;
        // end

        // Timer Logic
        if (tick_game) begin
            if (ps == IDLE) begin
                if (valid) begin
                    drop_timer <= drop_timer + 1;
                end
                
                // Lock timer: increment when on ground, reset when in air
                if (!valid) begin
                    if (lock_timer < LOCK_DELAY_MAX)
                        lock_timer <= lock_timer + 1;
                end else begin
                    lock_timer <= 0;
                end
            end
        end

        if (ps == DOWN || ps == GEN) drop_timer <= 0;

        // Data Path Updates
        case (ps)
            IDLE: begin
                kick_attempt <= 0;
                if (key_rotate_cw) begin
                    rotate_direction <= 1;
                    rotation_from <= t_curr.rotation;
                end else if (key_rotate_ccw) begin
                    rotate_direction <= 0;
                    rotation_from <= t_curr.rotation;
                end
                
                // Clear last move flag if moving left/right/down
                if (key_left || key_right || key_down) begin
                    last_move_was_rotation <= 0;
                end

                // Lock piece when timer expires (right before transitioning to CLEAN)
                if (ns == CLEAN) begin
                    f_curr <= f_disp;
                end
            end
            
            
            GEN_WAIT: begin
                t_curr <= t_gen;
                lock_timer <= 0;
            end
            
            DROP_LOCKOUT: begin
                hold_used <= 0;
                // Flags are now cleared by msg_timer
            end
            
            MOVE_LEFT: begin
                if (valid) begin
                    t_curr.coordinate.x <= t_curr.coordinate.x - 1;
                    last_move_was_rotation <= 0;  // Movement cancels rotation flag
                    lock_timer <= 0; // Reset lock timer on successful move
                end
            end
            
            MOVE_RIGHT: begin
                if (valid) begin
                    t_curr.coordinate.x <= t_curr.coordinate.x + 1;
                    last_move_was_rotation <= 0;  // Movement cancels rotation flag
                    lock_timer <= 0; // Reset lock timer on successful move
                end
            end
            
            ROTATE: begin
                if (kick_attempt == 0) begin
                    if (rotate_done) begin
                        if (valid) begin
                            t_curr <= t_check;
                            kick_attempt <= 0;
                            last_move_was_rotation <= 1;  // Mark as rotation move
                            kick_used <= 0;  // No kick needed
                            lock_timer <= 0; // Reset lock timer
                        end else begin
                            kick_attempt <= 1;
                        end
                    end
                end else begin
                    if (valid) begin
                        t_curr <= t_check;
                        kick_attempt <= 0;
                        last_move_was_rotation <= 1;  // Mark as rotation move
                        kick_used <= kick_attempt;  // Record which kick worked
                        lock_timer <= 0; // Reset lock timer
                    end else if (kick_attempt < 4) begin
                        kick_attempt <= kick_attempt + 1;
                    end else begin
                        kick_attempt <= 0;
                        last_move_was_rotation <= 0;  // Rotation failed
                    end
                end
            end
            
            DOWN: begin
                if (valid) begin
                    t_curr.coordinate.y <= t_curr.coordinate.y + 1;
                    last_move_was_rotation <= 0;  // Down movement cancels rotation
                    lock_timer <= 0; // Reset lock timer on successful move
                end
            end
            
            HARD_DROP: begin
                if (valid) begin
                    t_curr.coordinate.y <= t_curr.coordinate.y + 1;
                end else begin
                    f_curr <= f_disp;
                    // Hard drop cancels rotation flag (debatable - you can change this)
                    last_move_was_rotation <= 0;
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
                last_move_was_rotation <= 0;
                
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
                last_move_was_rotation <= 0;
            end
            
            CLEAN: begin
                if (clean_done) begin
                    f_curr <= f_cleaned;
                    
                    if (lines_cleared != 0) begin
                        total_lines_cleared <= total_lines_cleared + lines_cleared;
                    end
                    
                    if (lines_cleared != 0) begin
                        if (consecutive_clears < 15) 
                            consecutive_clears <= consecutive_clears + 1;
                    end else begin
                        consecutive_clears <= 0;
                    end
                
                    
                    // BCD Addition
                    if (lines_cleared != 0) begin
                        automatic logic [3:0] new_ones, new_tens, new_hundreds, new_thousands, new_tenthousands;
                        automatic logic c0, c1, c2, c3, c4;
                        
                        new_ones = score[3:0] + bcd_ones;
                        if (new_ones >= 10) begin
                            score[3:0] <= new_ones - 10;
                            c0 = 1;
                        end else begin
                            score[3:0] <= new_ones;
                            c0 = 0;
                        end
                        
                        new_tens = score[7:4] + bcd_tens + c0;
                        if (new_tens >= 10) begin
                            score[7:4] <= new_tens - 10;
                            c1 = 1;
                        end else begin
                            score[7:4] <= new_tens;
                            c1 = 0;
                        end
                        
                        new_hundreds = score[11:8] + bcd_hundreds + c1;
                        if (new_hundreds >= 10) begin
                            score[11:8] <= new_hundreds - 10;
                            c2 = 1;
                        end else begin
                            score[11:8] <= new_hundreds;
                            c2 = 0;
                        end
                        
                        new_thousands = score[15:12] + bcd_thousands + c2;
                        if (new_thousands >= 10) begin
                            score[15:12] <= new_thousands - 10;
                            c3 = 1;
                        end else begin
                            score[15:12] <= new_thousands;
                            c3 = 0;
                        end
                        
                        new_tenthousands = score[19:16] + bcd_tenthousands + c3;
                        if (new_tenthousands >= 10) begin
                            score[19:16] <= new_tenthousands - 10;
                            c4 = 1;
                        end else begin
                            score[19:16] <= new_tenthousands;
                            c4 = 0;
                        end
                        
                        if (c4) begin
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
                kick_attempt <= 0;
                last_move_was_rotation <= 0;
                kick_used <= 0;
            end
        endcase
    end
  end

endmodule