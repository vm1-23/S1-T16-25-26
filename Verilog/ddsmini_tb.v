`timescale 1ns/1ps
module tb_smart_irrigation_auto;

    // --- System Clocks & Reset ---
    reg clk = 0;
    reg rst_n = 0;
    reg clk_1hz = 0; // 1-second clock pulse

    // --- Sensor Inputs ---
    reg flow_pulse_raw = 0;
    reg moisture_dry = 0;
    reg rain = 0;

    // --- Control Inputs ---
    reg auto_cycle_start = 0;
    reg [1:0] user_select_manual = 0; // NEW: For admin tasks
    reg reset_user = 0;
    reg quota_wr = 0;
    reg [5:0] quota_set = 0; // WIDTH is 6
    reg manual_override = 0;

    // --- System Outputs ---
    wire valve_on;
    wire [3:0] quota_exceeded;
    wire [5:0] usage_out; // WIDTH is 6
    wire [5:0] quota_out; // WIDTH is 6
    wire flow_boost_on;
    wire sequencer_active;
    wire [1:0] current_zone;

    // Instantiate DUT (Design Under Test)
    smart_irrigation #(
        .NUM_USERS(4),
        .WIDTH(6),          // <-- UPDATED
        .DEBOUNCE_WIDTH(3)  // Override to 3 (requires 2^3=8 clock stable time)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .clk_1hz(clk_1hz), // <-- NEW
        .flow_pulse_raw(flow_pulse_raw),
        .moisture_dry(moisture_dry),
        .rain(rain),
        .auto_cycle_start(auto_cycle_start), // <-- NEW
        .user_select_manual(user_select_manual), // <-- NEW
        .reset_user(reset_user),
        .quota_wr(quota_wr),
        .quota_set(quota_set),
        .manual_override(manual_override),
        .valve_on(valve_on),
        .quota_exceeded(quota_exceeded),
        .usage_out(usage_out),
        .quota_out(quota_out),
        .flow_boost_on(flow_boost_on),     // <-- NEW
        .sequencer_active(sequencer_active), // <-- NEW
        .current_zone(current_zone)          // <-- NEW
    );

    // --- Clock Generation ---
    // 10ns period clock (100MHz)
    always #5 clk = ~clk;

    // --- Helper Tasks ---
    task pulse_flow;
        begin
            @(posedge clk);
            flow_pulse_raw = 1;
            repeat(10) @(posedge clk); // Hold for 10 cycles (longer than 2^3=8)
            flow_pulse_raw = 0;
            repeat(10) @(posedge clk); // Wait for pulse to clear debouncer
        end
    endtask

    // Helper task to pulse the 1-second clock
    task pulse_1hz;
        begin
            @(posedge clk); // Sync to main clock
            clk_1hz = 1;
            @(posedge clk);
            clk_1hz = 0;
        end
    endtask

    // Helper task to set quota for a specific zone
    task set_quota;
        input [1:0] zone;
        input [5:0] amount;
        begin
            user_select_manual = zone; // Select zone
            quota_set = amount;      // Set quota amount
            quota_wr = 1;            // Pulse write
            @(posedge clk);
            quota_wr = 0;
            @(posedge clk);
            $display("T=%0t: [Admin] Quota for Zone %0d set to %0d", $time, zone, quota_out);
        end
    endtask

    // --- Test Sequence ---
    initial begin
        // --- VCD Waveform Dump ---
        $dumpfile("smart_irrigation_auto.vcd");
        $dumpvars(0, tb_smart_irrigation_auto);

        $display("-----------------------------------------------------------------");
        $display("T=%0t: === Automated Irrigation Testbench ===", $time);
        $display("-----------------------------------------------------------------");
        
        // --- Monitor Task ---
        $monitor("T=%0t | Zone=%0d | S_Act=%b | V_On=%b | F_Boost=%b | Q_Ex=%4b | Usage=%0d | Quota=%0d | Rain=%b",
                 $time, current_zone, sequencer_active, valve_on, flow_boost_on, quota_exceeded, usage_out, quota_out, rain);

        // --- Part 1: Reset and Set Quotas ---
        rst_n = 0;
        #20;
        rst_n = 1;
        @(posedge clk);
        $display("\nT=%0t: System out of reset. Sequencer is IDLE.", $time);
        
        // While sequencer is IDLE, we can use user_select_manual to set quotas
        // Priority Order: Zone 2 -> 0 -> 3 -> 1
        set_quota(2, 10); // Prio 1: Zone 2 gets 10 pulses
        set_quota(0, 5);  // Prio 2: Zone 0 gets 5 pulses
        set_quota(3, 8);  // Prio 3: Zone 3 gets 8 pulses
        set_quota(1, 6);  // Prio 4: Zone 1 gets 6 pulses

        // --- Part 2: Test Automatic Sequence (No Peak Time) ---
        $display("\nT=%0t: === Test 2: Automatic Sequence (No Peak Time) ===", $time);
        moisture_dry = 1; // It's dry
        
        // Start the cycle
        auto_cycle_start = 1;
        @(posedge clk);
        auto_cycle_start = 0;
        @(posedge clk);
        
        $display("T=%0t: Auto cycle started. Waiting for Prio 1 (Zone 2)...", $time);
        
        // --- Prio 1: Zone 2 (Quota 10) ---
        repeat(10) pulse_flow();
        @(posedge clk); // Let FSM update
        $display("T=%0t: Zone 2 finished. Waiting for Prio 2 (Zone 0)...", $time);
        
        // --- Prio 2: Zone 0 (Quota 5) ---
        repeat(5) pulse_flow();
        @(posedge clk);
        $display("T=%0t: Zone 0 finished. Waiting for Prio 3 (Zone 3)...", $time);

        // --- Prio 3: Zone 3 (Quota 8) ---
        repeat(8) pulse_flow();
        @(posedge clk);
        $display("T=%0t: Zone 3 finished. Waiting for Prio 4 (Zone 1)...", $time);

        // --- Prio 4: Zone 1 (Quota 6) ---
        repeat(6) pulse_flow();
        @(posedge clk);
        $display("T=%0t: Zone 1 finished. Auto sequence complete.", $time);
        
        #50;
        if (sequencer_active) $error("Sequencer is still active after cycle!");
        if (valve_on) $error("Valve is still on after cycle!");

        // --- Part 3: Test Peak Time & Flow Boost (+2) ---
        $display("\nT=%0t: === Test 3: Peak Time & Flow Boost (+2) ===", $time);
        
        // Reset usage for all zones manually
        user_select_manual = 0; reset_user = 1; @(posedge clk); reset_user = 0;
        user_select_manual = 1; reset_user = 1; @(posedge clk); reset_user = 0;
        user_select_manual = 2; reset_user = 1; @(posedge clk); reset_user = 0;
        user_select_manual = 3; reset_user = 1; @(posedge clk); reset_user = 0;
        $display("T=%0t: All zone usage reset.", $time);

        // Advance 24hr clock to 10:00 (peak time)
        $display("T=%0t: Advancing clock to 10:00...", $time);
        repeat(10) pulse_1hz();
        
        // Start the cycle again, now in peak time
        auto_cycle_start = 1; @(posedge clk); auto_cycle_start = 0; @(posedge clk);
        $display("T=%0t: Auto cycle started. Prio 1 (Zone 2) should have +2 boost.", $time);
        
        // Prio 1: Zone 2 (Quota 10)
        // It should only take 5 pulses to meet quota (5 * 2 = 10)
        repeat(5) pulse_flow();
        @(posedge clk);
        
        if (usage_out != 10) $error("Flow boost failed! Usage is %0d, expected 10", usage_out);
        if (valve_on) $error("Valve did not shut off after 5 boosted pulses!");
        $display("T=%0t: Zone 2 finished with 5 boosted pulses. Correct.", $time);
        
        // Let the rest of the cycle finish (we don't care about it)
        #2000;
        rst_n = 0; #50; rst_n = 1; // Reset to stop cycle
        
        // --- Part 4: Test Rain & Manual Override ---
        $display("\nT=%0t: === Test 4: Rain & Manual Override ===", $time);
        moisture_dry = 1;
        user_select_manual = 0; // Select Zone 0
        manual_override = 1;
        @(posedge clk);
        $display("T=%0t: Manual Override ON. valve_on=%b (Should be 1)", $time, valve_on);
        
        rain = 1;
        @(posedge clk);
        $display("T=%0t: Rain ON. valve_on=%b (Should be 0)", $time, valve_on);
        
        rain = 0;
        @(posedge clk);
        $display("T=%0t: Rain OFF. valve_on=%b (Should be 1)", $time, valve_on);
        
        manual_override = 0;
        @(posedge clk);
        $display("T=%0t: Manual Override OFF. valve_on=%b (Should be 0)", $time, valve_on);

        $display("\n-----------------------------------------------------------------");
        $display("T=%0t: === Test Complete ===", $time);
        $display("-----------------------------------------------------------------");
        #50;
        $finish;
    end

endmodule