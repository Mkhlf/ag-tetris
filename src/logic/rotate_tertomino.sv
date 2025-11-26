`include "../GLOBAL.sv"

module rotate_tetromino (
    input   logic           clk,
    input   logic           enable,
    input   logic           clockwise,      // 1 = CW, 0 = CCW
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
            // Rotate based on direction
            if (clockwise) begin
                t_out.rotation <= t_in.rotation + 1;  // CW: 0→1→2→3→0
            end else begin
                t_out.rotation <= t_in.rotation - 1;  // CCW: 0→3→2→1→0
            end
            success <= 1;
            done <= 1;
        end
    end

endmodule