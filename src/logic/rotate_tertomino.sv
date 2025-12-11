/* rotate_tetromino
 * Produces a rotated tetromino candidate (CW or CCW) and flags completion;
 * rotation wrap-around relies on 2-bit arithmetic.
 */
`include "../GLOBAL.sv"

module rotate_tetromino (
    input   logic           clk,
    input   logic           enable,
    input   logic           clockwise,
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
            if (clockwise) begin
                t_out.rotation <= t_in.rotation + 1;
            end else begin
                t_out.rotation <= t_in.rotation - 1;
            end
            success <= 1;
            done <= 1;
        end
    end

endmodule