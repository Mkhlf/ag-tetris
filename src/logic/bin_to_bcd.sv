/* bin_to_bcd
 * Converts a binary input to packed BCD digits via the double-dabble method.
 */
`include "../GLOBAL.sv"

module bin_to_bcd #(
    parameter BINARY_WIDTH = 16,
    parameter BCD_DIGITS = 5
)(
    input  logic [BINARY_WIDTH-1:0] binary,
    output logic [3:0]               bcd [BCD_DIGITS-1:0]
);
    integer i, j;
    logic [BINARY_WIDTH + BCD_DIGITS*4 - 1:0] shift_reg;
    
    always_comb begin
        shift_reg = {{(BCD_DIGITS*4){1'b0}}, binary};
        
        for (i = 0; i < BINARY_WIDTH; i = i + 1) begin
            for (j = 0; j < BCD_DIGITS; j = j + 1) begin
                if (shift_reg[BINARY_WIDTH + j*4 +: 4] >= 5)
                    shift_reg[BINARY_WIDTH + j*4 +: 4] = shift_reg[BINARY_WIDTH + j*4 +: 4] + 3;
            end
            shift_reg = shift_reg << 1;
        end
        
        for (j = 0; j < BCD_DIGITS; j = j + 1) begin
            bcd[j] = shift_reg[BINARY_WIDTH + j*4 +: 4];
        end
    end
endmodule