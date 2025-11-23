`timescale 1ns / 1ps

module block_sprite(
    input  wire logic clk,
    input  wire logic [3:0] addr_x, // 0-15
    input  wire logic [3:0] addr_y, // 0-15
    output logic [11:0] pixel_out   // 12-bit RGB
    );

    // 16x16 sprite = 256 pixels.
    // We can use a case statement or a 1D array.
    
    // Simple "Bevelled" block design
    // Border: Darker
    // Center: Lighter
    
    // Let's make a generic white/grey block, and we can tint it in the draw module.
    // Or just return a single color and let draw module decide color?
    // The requirement says "Use of sprites from a memory block".
    // Usually this implies the sprite has texture.
    // Let's store a texture.
    
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
