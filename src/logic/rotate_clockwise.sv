`include "../GLOBAL.sv"

module rotate_clockwise (
    input   logic           clk,
    input   logic           enable,
    input   tetromino_ctrl  t_in,
    output  tetromino_ctrl  t_out,
    output  logic           success,
    output  logic           done
  );

  // Simplified rotation logic: Just try to rotate.
  // If we wanted wall kicks, we'd try multiple offsets.
  // For now, we just return the rotated piece and let game_control check validity.
  
  always_ff @(posedge clk) begin
    if (!enable) begin
        done <= 0;
        success <= 0;
    end else begin
        t_out <= t_in;
        t_out.rotation <= t_in.rotation + 1; // 2-bit overflow handles 3->0
        success <= 1; // Always "succeeds" in generating a candidate
        done <= 1;
    end
  end

endmodule
