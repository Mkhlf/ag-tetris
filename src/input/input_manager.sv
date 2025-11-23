`include "../GLOBAL.sv"

module input_manager (
    input  logic clk,
    input  logic rst,
    input  logic tick_game, // 60Hz tick
    
    // Raw Inputs (Level)
    input  logic raw_left,
    input  logic raw_right,
    input  logic raw_down,
    input  logic raw_rotate,
    input  logic raw_drop,
    
    // Processed Outputs
    output logic cmd_left,   // Pulse (DAS)
    output logic cmd_right,  // Pulse (DAS)
    output logic cmd_down,   // Pulse (DAS or continuous?)
    output logic cmd_rotate, // Pulse (One-shot)
    output logic cmd_drop    // Pulse (One-shot)
  );

  // Parameters for DAS (Delayed Auto Shift)
  localparam DAS_DELAY = 16; // Frames before auto-repeat
  localparam DAS_SPEED = 4;  // Frames between repeats
  
  // Helper: Edge Detector + DAS
  // For Left/Right/Down
  
  logic [5:0] timer_left, timer_right, timer_down;
  logic prev_left, prev_right, prev_down, prev_rotate, prev_drop;
  
  always_ff @(posedge clk) begin
    if (rst) begin
        cmd_left <= 0; cmd_right <= 0; cmd_down <= 0;
        cmd_rotate <= 0; cmd_drop <= 0;
        timer_left <= 0; timer_right <= 0; timer_down <= 0;
        prev_left <= 0; prev_right <= 0; prev_down <= 0;
        prev_rotate <= 0; prev_drop <= 0;
    end else begin
        // Default low
        cmd_left <= 0;
        cmd_right <= 0;
        cmd_down <= 0;
        cmd_rotate <= 0;
        cmd_drop <= 0;
        
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
        
        // --- DOWN ---
        // Down usually has faster DAS or just continuous
        if (raw_down) begin
            if (!prev_down) begin
                cmd_down <= 1;
                timer_down <= 0;
            end else if (tick_game) begin
                // Fast repeat for down (e.g., every 2 frames)
                if (timer_down >= 2) begin
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
        
        // --- ROTATE (One Shot) ---
        if (raw_rotate && !prev_rotate) begin
            cmd_rotate <= 1;
        end
        prev_rotate <= raw_rotate;
        
        // --- DROP (One Shot) ---
        if (raw_drop && !prev_drop) begin
            cmd_drop <= 1;
        end
        prev_drop <= raw_drop;
    end
  end

endmodule
