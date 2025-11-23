`timescale 1ns / 1ps

module input_synchronizer(
    input  wire logic clk,
    input  wire logic in_signal,
    output logic out_pulse
    );

    typedef enum logic [1:0] {
        IDLE,
        PRESS,
        HOLD
    } state_t;

    state_t state = IDLE;

    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                out_pulse <= 0;
                if (in_signal) begin
                    state <= PRESS;
                    out_pulse <= 1;
                end
            end

            PRESS: begin
                out_pulse <= 0;
                if (in_signal) begin
                    state <= HOLD;
                end else begin
                    state <= IDLE;
                end
            end

            HOLD: begin
                out_pulse <= 0;
                if (!in_signal) begin
                    state <= IDLE;
                end
            end
        endcase
    end

endmodule
