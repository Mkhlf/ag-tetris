/* ghost_calc
 * Computes the ghost landing row by scanning downward until collision.
 */
`include "../GLOBAL.sv"

module ghost_calc (
    input   tetromino_ctrl  t_curr,
    input   field_t         f,
    output  logic signed [`FIELD_VERTICAL_WIDTH : 0] ghost_y
  );

  logic isValid;
  integer offset;
  
  logic [1:0] currRotation;
  assign currRotation = t_curr.rotation;
  
  integer i, j;
  integer tx, ty;
  logic collision;

  always_comb begin
    ghost_y = t_curr.coordinate.y; // Default to current position
    
    // Iterate downwards from current position
    // Max drop is FIELD_VERTICAL (22)
    for (offset = 1; offset < `FIELD_VERTICAL; offset++) begin
        // Check if t_curr moved down by 'offset' is valid
        collision = 0;
        
        for (i = 0; i < 4; i++) begin
            for (j = 0; j < 4; j++) begin
                if (t_curr.tetromino.data[currRotation][i][j]) begin
                    tx = t_curr.coordinate.x + j;
                    ty = t_curr.coordinate.y + i + offset;
                    
                    // Check Bounds
                    if (tx < 0 || tx >= `FIELD_HORIZONTAL || ty >= `FIELD_VERTICAL) begin
                        collision = 1;
                    end
                    // Check Field Collision
                    else if (ty >= 0 && f.data[ty][tx].data != `TETROMINO_EMPTY) begin
                        collision = 1;
                    end
                end
            end
        end
        
        if (collision) begin
            // If collision at 'offset', then 'offset-1' was the last valid position
            // But we are looking for the position *before* collision.
            // So ghost_y = t_curr.y + (offset - 1)
            ghost_y = t_curr.coordinate.y + (offset - 1);
            break; 
        end else begin
            // If no collision, this position is valid. Keep searching.
            ghost_y = t_curr.coordinate.y + offset;
        end
    end
  end

endmodule
