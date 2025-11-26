`include "../GLOBAL.sv"

module spin_detector (
    input   tetromino_ctrl  t_ctrl,
    input   field_t         f,
    input   logic           last_move_was_rotation,
    input   logic [2:0]     kick_used,
    
    output  logic           is_t_spin,
    output  logic           is_t_spin_mini,
    output  logic           is_s_spin,
    output  logic           is_z_spin,
    output  logic           is_j_spin,
    output  logic           is_l_spin,
    output  logic           is_i_spin
);

    // Helper function to check if a position is blocked
    function automatic logic is_blocked(
        input logic signed [`FIELD_HORIZONTAL_WIDTH:0] x,
        input logic signed [`FIELD_VERTICAL_WIDTH:0] y
    );
        // Out of bounds or filled cell = blocked
        if (x < 0 || x >= `FIELD_HORIZONTAL_SIZE || y < 0 || y >= `FIELD_VERTICAL_SIZE)
            return 1'b1;
        else
            return (f.data[y][x] != `TETROMINO_EMPTY);
    endfunction
    
    // T-Spin Detection (3-corner rule)
    always_comb begin
        is_t_spin = 0;
        is_t_spin_mini = 0;
        is_s_spin = 0;
        is_z_spin = 0;
        is_j_spin = 0;
        is_l_spin = 0;
        is_i_spin = 0;
        
        // Only check for spins if last move was a rotation
        if (last_move_was_rotation) begin
            case (t_ctrl.idx.data)
                `TETROMINO_T_IDX: begin
                    // T-Spin: Check 4 corners around T-piece center
                    // For T-piece at rotation 0 (pointing up), corners are:
                    // (x-1,y-1) (x+1,y-1)
                    //     (center)
                    // (x-1,y+1) (x+1,y+1)
                    
                    logic [3:0] corners_filled;
                    logic [1:0] front_corners_filled;  // The two corners in front
                    
                    corners_filled[0] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y - 1);
                    corners_filled[1] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y - 1);
                    corners_filled[2] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y + 1);
                    corners_filled[3] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y + 1);
                    
                    // Front corners depend on rotation
                    case (t_ctrl.rotation)
                        2'b00: front_corners_filled = corners_filled[1:0];  // Top corners (pointing up)
                        2'b01: front_corners_filled = {corners_filled[1], corners_filled[3]};  // Right corners
                        2'b10: front_corners_filled = corners_filled[3:2];  // Bottom corners (pointing down)
                        2'b11: front_corners_filled = {corners_filled[0], corners_filled[2]};  // Left corners
                    endcase
                    
                    // T-Spin: 3 or 4 corners filled
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        // Full T-Spin: Both front corners filled
                        if (front_corners_filled == 2'b11) begin
                            is_t_spin = 1;
                        end
                        // Mini T-Spin: Not both front corners filled
                        else begin
                            is_t_spin_mini = 1;
                        end
                    end
                end
                
                `TETROMINO_S_IDX: begin
                    // S-Spin: Similar logic, 3+ corners filled
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y - 1);
                    corners_filled[1] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y - 1);
                    corners_filled[2] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y + 1);
                    corners_filled[3] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_s_spin = 1;
                    end
                end
                
                `TETROMINO_Z_IDX: begin
                    // Z-Spin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y - 1);
                    corners_filled[1] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y - 1);
                    corners_filled[2] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y + 1);
                    corners_filled[3] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_z_spin = 1;
                    end
                end
                
                `TETROMINO_J_IDX: begin
                    // J-Spin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y - 1);
                    corners_filled[1] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y - 1);
                    corners_filled[2] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y + 1);
                    corners_filled[3] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_j_spin = 1;
                    end
                end
                
                `TETROMINO_L_IDX: begin
                    // L-Spin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y - 1);
                    cornespin_detectorrs_filled[1] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y - 1);
                    corners_filled[2] = is_blocked(t_ctrl.coordinate.x - 1, t_ctrl.coordinate.y + 1);
                    corners_filled[3] = is_blocked(t_ctrl.coordinate.x + 1, t_ctrl.coordinate.y + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_l_spin = 1;
                    end
                end
                
                `TETROMINO_I_IDX: begin
                    // I-Spin: Requires wall kick (kick_used > 0)
                    if (kick_used > 0) begin
                        is_i_spin = 1;
                    end
                end
            endcase
        end
    end

endmodule