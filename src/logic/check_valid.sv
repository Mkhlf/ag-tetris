/* check_valid
 * Combinational gatekeeper: returns 1 only when the candidate tetromino
 * stays inside the field and does not overlap placed blocks.
 */
`include "../GLOBAL.sv"

module check_valid (
    input   tetromino_ctrl  t_ctrl,
    input   field_t         f,
    output  logic           isValid
  );

  logic [1:0] currRotation;
  assign currRotation = t_ctrl.rotation;

  integer signed i, j;
  integer signed tx, ty;

  always_comb begin
    isValid = 1'b1;
    for (i = 0; i < 4; ++i) begin
      for (j = 0; j < 4; ++j) begin
        if (t_ctrl.tetromino.data[currRotation][i][j] == 1) begin
          tx = t_ctrl.coordinate.x + j;
          ty = t_ctrl.coordinate.y + i;

          if (tx < 0 || tx >= `FIELD_HORIZONTAL ||
              ty < 0 || ty >= `FIELD_VERTICAL) begin
            isValid = 1'b0;
          end
          else begin
             if (f.data[ty][tx].data != `TETROMINO_EMPTY) begin
                isValid = 1'b0;
             end
          end
        end
      end
    end
  end
endmodule
