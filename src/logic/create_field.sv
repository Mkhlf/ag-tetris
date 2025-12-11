/* create_field
 * Combines the settled field with the active tetromino to yield a display
 * snapshot without mutating the stored field.
 */
`include "../GLOBAL.sv"

module create_field (
    input   tetromino_ctrl  t_ctrl,
    input   field_t         f,
    output  field_t         f_out
  );

  logic [1:0] currRotation;
  assign currRotation = t_ctrl.rotation;

  integer signed i, j;
  integer signed tx, ty;

  always_comb begin
    f_out = f;
    
    for (i = 0; i < 4; ++i) begin
      for (j = 0; j < 4; ++j) begin
        if (t_ctrl.tetromino.data[currRotation][i][j] == 1) begin
          tx = t_ctrl.coordinate.x + j;
          ty = t_ctrl.coordinate.y + i;

          if (tx >= 0 && tx < `FIELD_HORIZONTAL &&
              ty >= 0 && ty < `FIELD_VERTICAL) begin
            f_out.data[ty][tx] = t_ctrl.idx;
          end
        end
      end
    end
  end
endmodule
