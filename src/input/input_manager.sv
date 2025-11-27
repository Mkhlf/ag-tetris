`include "../GLOBAL.sv"

module input_manager (
    input  logic clk,
    input  logic rst,
    input  logic tick_game, // 60Hz tick
    
    // Raw Inputs (Level)
    input  logic raw_left,
    input  logic raw_right,
    input  logic raw_down,
    input  logic raw_rotate_cw,
    input  logic raw_rotate_ccw,
    input  logic raw_drop,
    input  logic raw_hold,
    
    // Processed Outputs
    output logic cmd_left,   // Pulse (DAS)
    output logic cmd_right,  // Pulse (DAS)
    output logic cmd_down,   // Pulse (DAS or continuous?)
    output logic cmd_rotate_cw, // Pulse (One-shot)
    output logic cmd_rotate_ccw, // Pulse (One-shot)
    output logic cmd_drop,   // Pulse (One-shot)
    output logic cmd_hold    // Pulse (One-shot)
  );

  // Parameters for DAS (Delayed Auto Shift) - modern Tetris feel
  localparam DAS_DELAY = 6; // Frames before auto-repeat
  localparam DAS_SPEED = 2;  // Frames between repeats
  localparam SOFT_DROP_SPEED = 0;  // 0 = every frame (instant)
  
  // Timers and edge detectors
  logic [5:0] timer_left, timer_right, timer_down;
  logic prev_left, prev_right, prev_down, prev_rotate_cw, prev_rotate_ccw, prev_drop, prev_hold;
  
  always_ff @(posedge clk) begin
    if (rst) begin
        cmd_left <= 0; cmd_right <= 0; cmd_down <= 0;
        cmd_rotate_cw <= 0; cmd_rotate_ccw <= 0; cmd_drop <= 0; cmd_hold <= 0;
        timer_left <= 0; timer_right <= 0; timer_down <= 0;
        prev_left <= 0; prev_right <= 0; prev_down <= 0;
        prev_rotate_cw <= 0; prev_rotate_ccw <= 0; prev_drop <= 0; prev_hold <= 0;
    end else begin
        // Default low
        cmd_left <= 0;
        cmd_right <= 0;
        cmd_down <= 0;
        cmd_rotate_cw <= 0;
        cmd_rotate_ccw <= 0;
        cmd_drop <= 0;
        cmd_hold <= 0;
        
        // --- LEFT ---
        if (raw_left) begin
            if (!prev_left) begin
                // Initial Press
                cmd_left <= 1;
                timer_left <= 0;
            end else if (tick_game) begin
                // Holding
                if (timer_left < DAS_DELAY) begin
                    timer_left <= timer_left + 1;
                end else begin
                    // Auto Repeat
                    if (timer_left >= DAS_DELAY + DAS_SPEED) begin
                        cmd_left <= 1;
                        timer_left <= DAS_DELAY; // Reset to delay base
                    end else begin
                        timer_left <= timer_left + 1;
                    end
                end
            end
        end else begin
            timer_left <= 0;
        end
        prev_left <= raw_left;
        
        // --- RIGHT ---
        if (raw_right) begin
            if (!prev_right) begin
                cmd_right <= 1;
                timer_right <= 0;
            end else if (tick_game) begin
                if (timer_right < DAS_DELAY) begin
                    timer_right <= timer_right + 1;
                end else begin
                    if (timer_right >= DAS_DELAY + DAS_SPEED) begin
                        cmd_right <= 1;
                        timer_right <= DAS_DELAY;
                    end else begin
                        timer_right <= timer_right + 1;
                    end
                end
            end
        end else begin
            timer_right <= 0;
        end
        prev_right <= raw_right;
        
        if (raw_down) begin
            if (!prev_down) begin
                cmd_down <= 1;
                timer_down <= 0;
            end else if (tick_game) begin
                if (timer_down >= SOFT_DROP_SPEED) begin
                    cmd_down <= 1;
                    timer_down <= 0;
                end else begin
                    timer_down <= timer_down + 1;
                end
            end
        end else begin
            timer_down <= 0;
        end
        prev_down <= raw_down;
        
        // --- ROTATE CW (One Shot) ---
        if (raw_rotate_cw && !prev_rotate_cw) begin
            cmd_rotate_cw <= 1;
        end
        prev_rotate_cw <= raw_rotate_cw;

        // --- ROTATE CCW (One Shot) ---
        if (raw_rotate_ccw && !prev_rotate_ccw) begin
            cmd_rotate_ccw <= 1;
        end
        prev_rotate_ccw <= raw_rotate_ccw;
        
        // --- DROP (One Shot) ---
        if (raw_drop && !prev_drop) begin
            cmd_drop <= 1;
        end
        prev_drop <= raw_drop;
        
        // --- HOLD (One Shot) ---
        if (raw_hold && !prev_hold) begin
            cmd_hold <= 1;
        end
        prev_hold <= raw_hold;
    end
  end

endmodule
