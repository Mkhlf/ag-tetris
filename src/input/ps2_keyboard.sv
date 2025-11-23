    // New Interface for Refactored Input System
    // We need to output the raw scan code and a make/break signal
    // The PS2Receiver outputs a 32-bit code.
    // We need to parse it to find the relevant byte and make/break status.
    
    // Output signals for the new modules
    output logic [7:0] current_scan_code,
    output logic       current_make_break // 1 = Make (Press), 0 = Break (Release)
    );

    logic [31:0] keycode;
    logic [31:0] prev_keycode;

    PS2Receiver ps2_rx (
        .clk(clk),
        .kclk(ps2_clk),
        .kdata(ps2_data),
        .keycodeout(keycode)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            current_scan_code <= 0;
            current_make_break <= 0;
            prev_keycode <= 0;
        end else begin
            if (keycode != prev_keycode) begin
                prev_keycode <= keycode;
                
                logic [7:0] new_byte;
                logic [7:0] prev_byte;
                logic [7:0] prev_prev_byte;
                
                new_byte = keycode[7:0];
                prev_byte = keycode[15:8];
                prev_prev_byte = keycode[23:16];
                
                // Determine Make/Break and Scan Code
                if (prev_byte == 8'hF0) begin
                    // Normal Release
                    current_make_break <= 0;
                    current_scan_code <= new_byte;
                end else if (new_byte == 8'hF0) begin
                    // Just the break prefix, wait for next byte?
                    // PS2Receiver shifts in. If we see F0 as new_byte, the *next* cycle will have the code.
                    // But this block triggers on `keycode != prev_keycode`.
                    // So we only see complete shifts?
                    // No, PS2Receiver shifts bits.
                    // Let's look at PS2Receiver again. It shifts bytes.
                    // If we receive F0, we need to know it's a break.
                    // The logic above `prev_byte == 8'hF0` handles the case where F0 was received *previously*.
                    // But `keycode` updates byte by byte.
                    // So:
                    // 1. Receive F0. keycode ends in F0.
                    // 2. Receive Code. keycode ends in Code, prev byte is F0. -> Release.
                    
                    // What if we receive E0?
                    // 1. Receive E0.
                    // 2. Receive Code. keycode ends in Code, prev is E0. -> Extended Press.
                    
                    // What if E0 F0 Code?
                    // 1. E0
                    // 2. F0 (prev E0)
                    // 3. Code (prev F0, prevprev E0) -> Extended Release.
                end else begin
                    // Not F0.
                    
                    // Check for Extended Release (E0 F0 XX)
                    if (prev_byte == 8'hF0 && prev_prev_byte == 8'hE0) begin
                        current_make_break <= 0;
                        current_scan_code <= new_byte;
                    end
                    // Check for Extended Press (E0 XX)
                    else if (prev_byte == 8'hE0 && new_byte != 8'hF0) begin
                        current_make_break <= 1;
                        current_scan_code <= new_byte;
                    end
                    // Normal Press (XX)
                    else if (new_byte != 8'hE0 && new_byte != 8'hF0 && prev_byte != 8'hF0) begin
                        current_make_break <= 1;
                        current_scan_code <= new_byte;
                    end
                end
            end
        end
    end

    // Legacy outputs (optional, or remove if we fully switch)
    // For now, let's keep the module interface clean and remove the old logic.
    // But wait, game_top expects key_left, etc.
    // We should probably update game_top to instantiate the new keyboard_to_1_clock modules
    // and use this module just to drive them.
    // So I will remove the old outputs from the port list in the replacement?
    // The tool instruction says "Replace the decoding logic".
    // I should probably change the port list too.
    // Let's do a full file replacement to be safe and clean.

