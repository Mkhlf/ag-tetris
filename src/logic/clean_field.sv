/* clean_field
 * Sequential row clearer: scans for full rows, shifts above content downward,
 * counts cleared lines, and exposes the updated field when done.
 */
`include "../GLOBAL.sv"

module clean_field (
    input   logic       clk,
    input   logic       enable,
    input   field_t     f_in,
    output  field_t     f_out,
    output  logic [2:0] lines_cleared,
    output  logic       done
  );

  typedef enum logic [1:0] {IDLE, CHECK, SHIFT, FINISH} state_t;
  state_t state = IDLE;

  integer row, col, k;
  logic row_full;
  
  field_t f_temp;

  always_ff @(posedge clk) begin
    if (!enable) begin
        state <= IDLE;
        done <= 0;
        lines_cleared <= 0;
    end else begin
        case (state)
            IDLE: begin
                f_temp <= f_in;
                row <= `FIELD_VERTICAL - 1;
                lines_cleared <= 0;
                done <= 0;
                state <= CHECK;
            end

            CHECK: begin
            if (row < 0) begin
                    state <= FINISH;
                end else begin
                    row_full = 1;
                    for (col = 0; col < `FIELD_HORIZONTAL; col++) begin
                        if (f_temp.data[row][col].data == `TETROMINO_EMPTY) begin
                            row_full = 0;
                        end
                    end

                    if (row_full) begin
                        lines_cleared <= lines_cleared + 1;
                        state <= SHIFT;
                    end else begin
                        row <= row - 1;
                    end
                end
            end

            SHIFT: begin
                for (k = `FIELD_VERTICAL - 1; k > 0; k--) begin
                    if (k <= row) begin
                        f_temp.data[k] <= f_temp.data[k-1];
                    end
                end
                for (col = 0; col < `FIELD_HORIZONTAL; col++) begin
                    f_temp.data[0][col].data <= `TETROMINO_EMPTY;
                end
                
                state <= CHECK;
            end

            FINISH: begin
                f_out <= f_temp;
                done <= 1;
            end
        endcase
    end
  end

endmodule
