`timescale 1ns / 1ps
// block_sprite: 16x16 ROM-backed sprite for a beveled block tile, returning
// a 12-bit RGB pixel for the requested x/y address.
module block_sprite(
    input  wire logic clk,
    input  wire logic [3:0] addr_x, // 0-15
    input  wire logic [3:0] addr_y, // 0-15
    output logic [11:0] pixel_out   // 12-bit RGB
    );

    (* rom_style = "block" *) logic [11:0] rom [0:255];

    initial begin
        int i, j;
        for (i = 0; i < 16; i++) begin
            for (j = 0; j < 16; j++) begin
                if (i == 0 || i == 15 || j == 0 || j == 15)
                    rom[i*16 + j] = 12'h888; // Grey Border
                else if (i == 1 || i == 14 || j == 1 || j == 14)
                    rom[i*16 + j] = 12'hAAA; // Lighter Border
                else
                    rom[i*16 + j] = 12'hFFF; // White Center
            end
        end
    end

    always_ff @(posedge clk) begin
        pixel_out <= rom[{addr_y, addr_x}];
    end

endmodule
