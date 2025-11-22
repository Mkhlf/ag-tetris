# CS256 Class Project

The VGA output consists of three 4-bit outputs for red, green, and blue pixel intensity plus two control pulse signals for horizonatal and vertical syncing. In each clock cycle a single pixel output is produced, so to draw a complete frame of pixels takes width×height clock cycles. In traditional CRT displays, a single cathode ray was deflected across the screen to produce individual lit points on the phosphor screen, scanning from top-left, across to complete the first row, followed by starting from the left again to produce the second row, and so on, to the bottom right of the screen. Since it takes time for the beam to be moved from the right side to the left, and top to bottom, there are extra cycles where no visible pixels are produced.

To generate the required control pulses and output coloured pixels to the screen, we need to build two timers, one horizontal and the other vertical. We will then use these to determine the active pixel area of the screen and what should be drawn at each location.

![vga timing diagram](./vgatiming.svg "VGA Timing")

## VGA Sync Signals
1. Click *Create New Project* and *Next*. Give the project a name and click *Next*. Select RTL Project and check *Do not specify sources at this time*, click *Next*. Select the correct board as in previous lab exercises. Click *Next*, then *Finish*. You have set up a blank project and should now see the design window as in previous labs.
2. Go to *File | Add Sources…*
3. Select *Add or create design sources* and click *Next*.
4. Click *Create file*, and give it a name `vga_out`, ensuring the file type is set to SystemVerilog, click *Finish*.
5. Create an input port named `clk`, and 5 output ports: 4-bit `pix_r`, `pix_g`, `pix_b`, and 1-bit `hsync` and `vsync`.
6. You need to declare two internal signals to  represent the counters: 11-bit `hcount`, and 10-bit `vcount`.
7. Use an always_ff block to make `hcount` count up to `1679` and wrap around.
8. Each time `hcount` wraps around, it should increment `vcount` which should itself wrap around after reaching `827`. This can be achieved in a single always block with the `vcount` statements only occurring in the case when `hcount` is at its maximum.
9. Now using assign statements set the `hsync` output to be 0 when hcount is between `0` and `135` inclusive (and 1 otherwise), and `vsync` to be 1 when `vcount` is between `0` and `2` inclusive (and 0 otherwise). (Note this differs from the below diagram as `hcount` is active low for this specific resolution)

These pulses will tell the VGA display what resolution is to be displayed and control the required circuitry in the display to do so.

![vga waveform diagram](./vgawaveform.png "VGA Waveform")

# Outputing Pixels
Now, we want to draw something on the display. This will require us to set the `pix_r`, `pix_g`, and `pix_b` outputs to colour values only during the visible portion of the screen. First, we will simply set the whole screen to a single colour, selectable by switches on the board.

You will need to add extra input ports to enable the switches on the board to set the colour (2, 3, or 4 switches per colour channel would work).

![vga controller diagram](./vgacontroller.svg "VGA Controller")

1. To draw a single colour across the whole frame, we just need to set the pixel outputs to some value during the visible region of the display. The visible region horizontally is between `336` and `1615` inclusive, and vertically between `27` and `826` inclusive.
2. Use an assign statement to assign the red, green and blue pixel outputs to your switch input values only during pixel counts within this range, and set them to 0 at all other times.
3. Now, rather than test the circuit on the board initially, we will use a testbench.
4. Add a new SystemVerilog testbench source (*Add Sources…, Add or Create Simulation Sources*). Create the new file, but add no ports. Instantiate your module within it, and use an always block to generate an oscillating clock. If your design uses input ports to set the colour, set these to some value. This is all that is needed for this module.
5. You should now be able to expand the Simulation section in the sidebar and Run Simulation, Run Behavioral Simulation.
6. You can add the internal signals from your module by right clicking the module instance name (probably uut) in the scopes window and choosing *Add to Wave Window*.
7. Restart the simulation using the double back arrow, then run for a limited time by pressing the play button with a T.
8. Use the timed simulation to run it for long enough to check that your counters and pulses are correctly generated. You should see `hcount` go up to `1679` then back to zero, each time increasing `vcount` until it reaches `827` and wraps back around. The other pulses should be as per the specification above.

## Creating the Clock
To run this design on the board, we will need a clock signal at the correct pixel rate, which for this specific VGA resolution and frame rate is 83.46 MHz. The on-board clock runs at 100 MHz, so we will use the Clock Wizard IP to generate this clock.

1. In the left pane, select IP Catalog
2. Search for Clocking Wizard and double click it.
3. Under the Output Clocks tab, activate `clk1_out` and set the requested clock frequency to 83.46 MHz. Uncheck the reset and locked options, and click OK.
4. The wizard will not achieve the exact requested frequency, but it will be close enough to work.
5. Click Generate. The `clk_wiz_0` module will now be included under your design hierarchy.
6. In the Sources pane, you will see `clk_wiz_0`. Change from the Hierarchy Tab to the IP Sources tab. Under `clk_wiz_0`, select Instation Template and double click it, and open the file. Now you can copy the instantion into your `vga_out` module and connect the signals.
7. Connect its input to the main clock input and its output to a new internal wire called `pixclk`.
8. You now need to ensure that all your synchronous always blocks use `pixclk` rather than the `clk` input.

## Testing on the Board
1. Go to *File | Add Sources…* and select *Add or create constraints*.
2. Click *Add Files* and navigate to the saved constraints file as before. Select it and ensure *Copy constraints files into project* is checked. Click *Finish*.
3. In the *Sources* pane, navigate to *Constraints* and double-click the newly added file to open.
4. You will need to uncomment the lines under VGA Connector and set the signal names to match those in your top level module.
5. You will also need to uncomment the clock input lines and any switches you have used, and give the correct signal names.
6. Implement your design and test it on the board.

## Visible Pixel Counter
The VGA controller above uses counters that covered both the visible and invisible parts of the screen. Since we will only be drawing objects in the visible part of the screen, we want to produce counters that indicate the pixel currently being drawn.

1. In your `vga_out` module, add two outputs `curr_x` and `curr_y` that indicate the current visible pixel being drawn. These should count from `0` to `1279` and `0` to `799` respectively, correctly aligned with the valid region of your image (i.e. where pixel values are output). You might run these counters to count only during the visible part using a separate always block with similar logic to `hcount` and `vcount` output or using an offset counter. It is important that these counters correspond to the actual position being drawn, so the first visible pixel has `curr_x=0` and `curr_y=0`, and the last has `curr_x=1279` and `curr_y=799`. Check that these align with the overall counters using a testbench.
2. Remove the clock divider instance out of this module, and replace `pix_clk` with `clk` in all the always blocks.
3. Create a new top-level module called `game_top` with the same ports as `vga_out` (but without `curr_x` and `curr_y`) and instantiate your `vga_out` module inside it. Instantiate the clock divider and connect its output to the `vga_out` clock input using a wire.
4. Ensure your constraint file pin mappings are still valid for this top module.
5. Now you will use a combinational always block to draw a coloured rectangle on a different coloured background. To do this use the `curr_x` and `curr_y` values produced by vga_out, and set the RGB inputs of `vga_out` to a different colour depending on whether they are in the range `520<x<760` and `300<y<500` or not.
6. Right click the module Verilog file in the sources tab and select *Set as Top*
7. Test this on the board and you should see a rectangle in the centre of the screen.

How this works is as follows: The `vga_out` module generates the necessary control signals for the VGA output, while also telling the top level module what pixel it is currently drawing (remember it is drawing one pixel per clock cycle in raster scan order). The always block you have designed looks at what pixel is being drawn and decides what colour it should be, supplying the required colour to the `vga_out` module to output to the screen. This basic structure can be extended to build your game, starting with the logic below.

## Drawing Logic Module
We will now build a module that takes a coordinate position for an object and uses that to draw it on screen at the indicated position. It will also draw a border around the screen. This module knows what pixel is being drawn due to the x and y position it receives from `vga_out`. It knows the position of an object by its `x` and `y` position. Knowing its size, you can then decide whether the current `x` and `y` coordinates are part of this object or not and hence which colour to draw.

1. Remove the combinational always block code for drawing a rectangle from game_top.
2. Create a new Verilog module called `drawcon` which takes `blkpos_x` and `blkpos_y` position inputs, `draw_x` and `draw_y` current pixel position inputs,  and produces `r`, `g`, and `b` values. The widths of these signals should match those of `vga_out`.
3. Create internal 4-bit RGB signals called `bg_r`, `bg_g`, and `bg_b` that will hold the background colour components.
4. Create a combinational always block that uses the `draw_x` and `draw_y` inputs to draw a white border within 10 pixels of the edge of the screen, and a colour of your choice elsewhere, similar to what you did to draw the block above. You should detect when `draw_x` and `draw_y` are in the border range and set the `bg_r`, `bg_g`, `bg_b` signals to white (all 1s), and if not, then set to the background colour.
5. Create internal 4-bit RGB signals called `blk_r`, `blk_g`, and `blk_b`.
6. Create another combinational always block that uses the `blkpos_x` and `blkpos_y` inputs and sets `blk_r`, `blk_g`, and `blk_b` to a bright colour when `draw_x` is between `blkpos_x` and `blkpos_x+32`, and `draw_y` is between `blkpos_y` and `blkpos_y+32`.
7. Now you need to combine the foreground and background. Whenever `blk_r,g,b` are non-zero assign them to the RGB outputs, else, assign `bg_r,g,b` to the outputs.
8. All logic in drawcon should be combinational.
9. Instantiate this module in `game_top` and connect its RGB outputs and `draw_x` and `draw_y` inputs to `vga_out`.
10. Game logic will sit in the `game_top` module, and only needs to run as fast as the whole screen refreshes. Hence, we will need a slower clock. Instantiate another clock divider targeting as low a frequency as allowed. Use a counter to further divide this down to around 60Hz. Connect this to an internal wire that you will use as your clock for logic in this module.
11. Add ports to `game_top` for the four directional buttons (and the centre one) on the Nexys A7-100T board.
12. In a synchronous always block using the slow clock in `game_top`, reset the block position to the centre of the screen whenever the centre button is pressed. When one of the directional buttons is pressed, add or subtract 4 to the relevant `blkpos` coordinate.
13. Add some logic to check that you cannot hit the edge of the border you drew above.
14. Check you have updated the required constraints for the extra inputs and test on the board.

You should now be able to move a small block around the screen and avoid collisions with the edges. This sort of logic can be put into a game logic module that maintains the state of individual components in the game, with the draw module deciding when to draw based on these and the current `x` and `y` positions.

![game top module diagram](./game_top.png "Game Top Module")

## Assessment

The first component of the class project assessment will be a **demo** on **Monday 1st December**, during the regular lecture slot. You will be marked out of 20 based on the following criteria:

| Criteria	| Max Marks |
| ---       | ---       |
| User control of a moving object on screen with respect for screen boundaries | 5 |
| A map or multiple objects and interactions between them, e.g. collisions | 5 |
| Extra features like using other board inputs/outputs | 4 |
| Use of sprites from a memory block | 4 |
| Marks for creative design ideas | 2 |

The second component of the class project assessment is an **individual written report** (not this is not to be done in pairs). This report is due on **Thursday 11th December**. The report should describe the design you developed. Start from describing the VGA signalling protocol, how you built circuits to generate the correct sync pulses and pixel values. How you then determined current pixel coordinates, how you drew objects on screen, and the logic behind your game. You should also discuss how you tested your design. Your report should be written in a formal manner, and include excerpts of code where this would assist discussion. Screen captures may also be useful. Include all your Verilog code in an appendix, clearly stating what each source file is for. Do not paste screenshots of code – if you want syntax highlighting use an online syntax highlighting tool. The report should conclude with a reflective section about what you liked and disliked about the project, what you learned or couldn't understand, and suggestions for improvement in the future.

 This report will be marked according to the following criteria:

| Criteria | Maximum Marks |
| ---      | ---           |
| Introduction and Background discussion on displays/VGA | 3 marks |
| Design description | 5 marks |
| Testing description | 3 marks |
| Code quality | 4 marks |
| Presentation and references | 3 marks |
| Reflection section | 2 marks |

The two component marks will be combined to produce the class project mark out of 40.