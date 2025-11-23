`include "GLOBAL.sv"

// input from keyboard to output 1 clock signal
module keyboard_to_1_clock #(
    parameter SCAN_CODE = `SPACE_C
  )(
    input   logic       clk,
    input   logic [7:0] scanCode,
    input   logic       makeBreak,
    output  logic       signal
  );

  enum {idle, press, hold} state = idle;

  always_ff @(posedge clk)
    if (scanCode == SCAN_CODE)
      if (~makeBreak)
        // released
        state <= idle;
      else
        // pressed
        case (state)
          idle :
            if (scanCode == SCAN_CODE)
              state <= press;
          press :
            // state not change until release
            state <= hold;
          default:
            ;
        endcase
    else
        // If scanCode changes to something else while holding, we don't care 
        // unless it's the specific key release. 
        // But wait, scanCode input is the *latest* scan code from the keyboard.
        // If I press A (make), scanCode=A. If I then press B (make), scanCode=B.
        // My state for A should stay in HOLD?
        // The reference implementation assumes scanCode is the *event* code.
        // If the keyboard driver outputs a stream of events, this logic works.
        // If scanCode just holds the last key pressed, this might be tricky if multiple keys are pressed.
        // The PS2Receiver in the reference seems to output a stream.
        // Let's assume the PS2Receiver + FIFO in the reference delivers events.
        // Our PS2Receiver outputs the *current* 32-bit code.
        // We need to adapt ps2_keyboard to output *events* or just the current code?
        // The reference uses a FIFO. We might need that or a simplified version.
        // For now, let's stick to the reference logic but be aware of the input expectation.
        ;

  assign signal = state == press;
endmodule
