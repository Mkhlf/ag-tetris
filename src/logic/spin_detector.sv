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
    // Center position (all 3-wide pieces have center at bounding box (1,1))
    logic signed [`FIELD_HORIZONTAL_WIDTH:0] cx;
    logic signed [`FIELD_VERTICAL_WIDTH:0] cy;
    
    assign cx = t_ctrl.coordinate.x + 1;
    assign cy = t_ctrl.coordinate.y + 1;

    // Helper function to check if a position is blocked
    function automatic logic is_blocked(
        input logic signed [`FIELD_HORIZONTAL_WIDTH:0] x,
        input logic signed [`FIELD_VERTICAL_WIDTH:0] y
    );
        if (x < 0 || x >= `FIELD_HORIZONTAL || y < 0 || y >= `FIELD_VERTICAL)
            return 1'b1;
        else
            return (f.data[y][x] != `TETROMINO_EMPTY);
    endfunction
    
    always_comb begin
        is_t_spin = 0;
        is_t_spin_mini = 0;
        is_s_spin = 0;
        is_z_spin = 0;
        is_j_spin = 0;
        is_l_spin = 0;
        is_i_spin = 0;
        
        if (last_move_was_rotation) begin
            case (t_ctrl.idx.data)
                `TETROMINO_T_IDX: begin
                    logic [3:0] corners_filled;
                    logic [1:0] front_corners_filled;
                    
                    // Check corners around CENTER (not bounding box corner)
                    corners_filled[0] = is_blocked(cx - 1, cy - 1);
                    corners_filled[1] = is_blocked(cx + 1, cy - 1);
                    corners_filled[2] = is_blocked(cx - 1, cy + 1);
                    corners_filled[3] = is_blocked(cx + 1, cy + 1);
                    
                    case (t_ctrl.rotation)
                        2'b00: front_corners_filled = corners_filled[1:0];
                        2'b01: front_corners_filled = {corners_filled[1], corners_filled[3]};
                        2'b10: front_corners_filled = corners_filled[3:2];
                        2'b11: front_corners_filled = {corners_filled[0], corners_filled[2]};
                    endcase
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        if (front_corners_filled == 2'b11) begin
                            is_t_spin = 1;
                        end else begin
                            is_t_spin_mini = 1;
                        end
                    end
                end
                
                `TETROMINO_S_IDX: begin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(cx - 1, cy - 1);
                    corners_filled[1] = is_blocked(cx + 1, cy - 1);
                    corners_filled[2] = is_blocked(cx - 1, cy + 1);
                    corners_filled[3] = is_blocked(cx + 1, cy + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_s_spin = 1;
                    end
                end
                
                `TETROMINO_Z_IDX: begin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(cx - 1, cy - 1);
                    corners_filled[1] = is_blocked(cx + 1, cy - 1);
                    corners_filled[2] = is_blocked(cx - 1, cy + 1);
                    corners_filled[3] = is_blocked(cx + 1, cy + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_z_spin = 1;
                    end
                end
                
                `TETROMINO_J_IDX: begin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(cx - 1, cy - 1);
                    corners_filled[1] = is_blocked(cx + 1, cy - 1);
                    corners_filled[2] = is_blocked(cx - 1, cy + 1);
                    corners_filled[3] = is_blocked(cx + 1, cy + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_j_spin = 1;
                    end
                end
                
                `TETROMINO_L_IDX: begin
                    logic [3:0] corners_filled;
                    corners_filled[0] = is_blocked(cx - 1, cy - 1);
                    corners_filled[1] = is_blocked(cx + 1, cy - 1);
                    corners_filled[2] = is_blocked(cx - 1, cy + 1);
                    corners_filled[3] = is_blocked(cx + 1, cy + 1);
                    
                    if ((corners_filled[0] + corners_filled[1] + corners_filled[2] + corners_filled[3]) >= 3) begin
                        is_l_spin = 1;
                    end
                end
                
                `TETROMINO_I_IDX: begin
                    if (kick_used > 0) begin
                        is_i_spin = 1;
                    end
                end
            endcase
        end
    end
endmodule