`timescale 1ns / 1ps
//================================================================
// TESTBENCH: Smart Irrigation System
//================================================================
// Simulates behavior of all abstraction levels:
// - FSM sequencing
// - Quota logic
// - Rain/Moisture control
// - Peak sunlight rate increase
//================================================================

module tb_smart_irrigation;

    // ------------------- Parameters -------------------
    parameter NUM_USERS = 4;
    parameter WIDTH = 6;
    parameter DEBOUNCE_WIDTH = 8;  // smaller for faster sim

    // ------------------- Testbench Signals -------------------
    reg clk;
    reg clk_1hz;
    reg rst_n;

    // Sensor inputs
    reg flow_pulse_raw;
    reg moisture_dry;
    reg rain;

    // Control inputs
    reg auto_cycle_start;
    reg [1:0] user_select_manual;
    reg reset_user;
    reg quota_wr;
    reg [WIDTH-1:0] quota_set;
    reg manual_override;

    // Outputs
    wire valve_on;
    wire [NUM_USERS-1:0] quota_exceeded;
    wire [WIDTH-1:0] usage_out;
    wire [WIDTH-1:0] quota_out;
    wire flow_boost_on;
    wire sequencer_active;
    wire [1:0] current_zone;

    // loop variable for testbench (Verilog-2001 compatible)
    integer i;

    // ------------------- DUT Instantiation -------------------
    smart_irrigation #(
        .NUM_USERS(NUM_USERS),
        .WIDTH(WIDTH),
        .DEBOUNCE_WIDTH(DEBOUNCE_WIDTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .clk_1hz(clk_1hz),
        .flow_pulse_raw(flow_pulse_raw),
        .moisture_dry(moisture_dry),
        .rain(rain),
        .auto_cycle_start(auto_cycle_start),
        .user_select_manual(user_select_manual),
        .reset_user(reset_user),
        .quota_wr(quota_wr),
        .quota_set(quota_set),
        .manual_override(manual_override),
        .valve_on(valve_on),
        .quota_exceeded(quota_exceeded),
        .usage_out(usage_out),
        .quota_out(quota_out),
        .flow_boost_on(flow_boost_on),
        .sequencer_active(sequencer_active),
        .current_zone(current_zone)
    );

    //================================================================
    // VCD / Waveform dump
    //================================================================
    initial begin
        $dumpfile("smart_irrigation_auto.vcd");
        $dumpvars(0, tb_smart_irrigation);
    end

    //================================================================
    // CLOCK GENERATION
    //================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;      // 100 MHz main clock (period 10ns)
    end

    initial begin
        clk_1hz = 0;
        forever #500 clk_1hz = ~clk_1hz; // Simulated 1Hz = 1000ns period
    end

    //================================================================
    // TEST SEQUENCE
    //================================================================
    initial begin
        // Initialize signals
        rst_n = 0;
        flow_pulse_raw = 0;
        moisture_dry = 0;
        rain = 0;
        auto_cycle_start = 0;
        user_select_manual = 0;
        reset_user = 0;
        quota_wr = 0;
        quota_set = {WIDTH{1'b0}};
        manual_override = 0;

        // Reset Phase
        $display("\n---- SYSTEM RESET ----");
        #50;
        rst_n = 1;
        #100;

        // Assign initial quotas
        $display("---- SETTING INITIAL QUOTAS ----");
        for (i = 0; i < NUM_USERS; i = i + 1) begin
            quota_set = 6'd20 + (i * 5); // Each zone different quota
            user_select_manual = i[1:0];
            quota_wr = 1;
            #20;
            quota_wr = 0;
            #20;
        end

        // Start automatic sequence
        $display("---- START AUTO CYCLE ----");
        auto_cycle_start = 1;
        #20 auto_cycle_start = 0;
        moisture_dry = 1;  // soil is dry

        // Simulate watering activity (some pulses)
        repeat (10) begin
            // Generate water flow pulses (debounced module uses counter so pulses must persist)
            flow_pulse_raw = 1;
            #10;
            flow_pulse_raw = 0;
            #40;
        end

        // Simulate rain event
        $display("---- RAIN DETECTED ----");
        rain = 1;
        #200;
        rain = 0;

        // Simulate manual override
        $display("---- MANUAL OVERRIDE ACTIVATED ----");
        manual_override = 1;
        moisture_dry = 1;
        #200;
        manual_override = 0;

        // Simulate next zone switch (give some pulses)
        $display("---- NEXT ZONE TRIGGER ----");
        flow_pulse_raw = 0;
        moisture_dry = 1;
        repeat (5) begin
            flow_pulse_raw = 1; #10;
            flow_pulse_raw = 0; #30;
        end

        // Reset one zone manually
        $display("---- RESET USER 1 ----");
        user_select_manual = 2'd1;
        reset_user = 1;
        #20 reset_user = 0;

        // Wait a bit to observe behaviour then finish
        $display("---- SIMULATION COMPLETE ----");
        #500;
        $finish;
    end

    //================================================================
    // MONITOR OUTPUTS
    //================================================================
    always @(posedge clk) begin
        $display("T=%0t | Zone=%0d | Valve=%b | Rain=%b | Dry=%b | QuotaUsed=%0d | QuotaLimit=%0d | QuotaExceeded=%b | FlowBoost=%b | SeqActive=%b",
            $time, current_zone, valve_on, rain, moisture_dry, usage_out, quota_out, quota_exceeded, flow_boost_on, sequencer_active);
    end

endmodule
