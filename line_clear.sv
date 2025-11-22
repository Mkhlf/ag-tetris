`timescale 1ns / 1ps

module line_clear(
    input  logic clk,
    input  logic rst,
    input  logic start,
    input  logic [3:0] grid_in [0:19][0:9],
    
    output logic [3:0] grid_out [0:19][0:9],
    output logic [2:0] lines_cleared, // 0 to 4
    output logic done,
    output logic busy
    );

    // Parameters
    localparam ROWS = 20;
    localparam COLS = 10;

    // States
    typedef enum logic [1:0] {
        IDLE,
        CHECK_ROW,
        SHIFT_DOWN,
        FINISH
    } state_t;

    state_t state;
    
    // Internal Variables
    integer current_row; // Row pointer (bottom up)
    integer k, c;        // Loop iterators
    logic row_full;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            lines_cleared <= 0;
            done <= 0;
            busy <= 0;
            current_row <= ROWS - 1;
            // Initialize grid_out to 0? Or keep as is?
            // Better to initialize loops
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CHECK_ROW;
                        grid_out <= grid_in; // Capture input grid
                        lines_cleared <= 0;
                        current_row <= ROWS - 1; // Start from bottom
                        busy <= 1;
                    end else begin
                        busy <= 0;
                    end
                end

                CHECK_ROW: begin
                    if (current_row < 0) begin
                        state <= FINISH;
                    end else begin
                        // Check if current_row is full
                        row_full = 1;
                        for (c = 0; c < COLS; c++) begin
                            if (grid_out[current_row][c] == 0) row_full = 0;
                        end

                        if (row_full) begin
                            state <= SHIFT_DOWN;
                            // Increment score (simple count)
                            lines_cleared <= lines_cleared + 1;
                        end else begin
                            // Move to next row up
                            current_row <= current_row - 1;
                        end
                    end
                end

                SHIFT_DOWN: begin
                    // Shift all rows above current_row down by 1
                    for (k = ROWS - 1; k > 0; k--) begin
                        if (k <= current_row) begin
                            grid_out[k] <= grid_out[k-1];
                        end
                    end
                    // Clear the top row
                    for (c = 0; c < COLS; c++) grid_out[0][c] <= 0;

                    // Return to CHECK_ROW to re-check the same row index
                    // (because the row above just dropped into this slot)
                    state <= CHECK_ROW;
                end

                FINISH: begin
                    done <= 1;
                    busy <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
