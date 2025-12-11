/* rotate_clockwise
 * Reference helper that advances rotation clockwise and flags completion;
 * caller is responsible for validity and kicks.
 */
`include "../GLOBAL.sv"

module rotate_clockwise (
    input   logic           clk,
    input   logic           enable,
    input   tetromino_ctrl  t_in,
    output  tetromino_ctrl  t_out,
    output  logic           success,
    output  logic           done
  );

  always_ff @(posedge clk) begin
    if (!enable) begin
        done <= 0;
        success <= 0;
    end else begin
        t_out <= t_in;
        t_out.rotation <= t_in.rotation + 1;
        success <= 1;
        done <= 1;
    end
  end

endmodule
