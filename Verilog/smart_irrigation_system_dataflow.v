//================================================================
// SMART IRRIGATION SYSTEM — PURE DATAFLOW VERSION
// Compatible with tb_smart_irrigation
//================================================================
// No always blocks, no procedural FSM — purely combinational dataflow.
//================================================================

`timescale 1ns / 1ps

//===============================================================
// SUBMODULE 1: Debounce Pulse (Dataflow Approximation)
//===============================================================
module debounce_pulse (
    input  wire raw_in,
    input  wire clk,       // dummy (for compatibility)
    input  wire rst_n,     // dummy (for compatibility)
    output wire clean_out
);
    // In dataflow form: no delay filtering, pass-through
    assign clean_out = raw_in;
endmodule

//===============================================================
// SUBMODULE 2: Sun Timer (Dataflow Approximation)
//===============================================================
module sun_timer (
    input  wire [5:0] hour_cnt,  // simulated hour 0–23
    output wire peak_time
);
    assign peak_time = (hour_cnt >= 6'd10) && (hour_cnt <= 6'd16);
endmodule

//===============================================================
// SUBMODULE 3: Zone FSM (Dataflow Model)
//===============================================================
module zone_fsm (
    input  wire auto_cycle_start,
    input  wire [1:0] user_select_manual,
    output wire [1:0] final_user_select,
    output wire sequencer_active
);
    assign sequencer_active = auto_cycle_start;
    assign final_user_select = (auto_cycle_start) ? 2'b10 : user_select_manual;
endmodule

//===============================================================
// SUBMODULE 4: Irrigation Core (Dataflow Model)
//===============================================================
module irrigation_core #(
    parameter WIDTH = 6,
    parameter NUM_USERS = 4
)(
    input  wire [NUM_USERS-1:0][WIDTH-1:0] usage,
    input  wire [NUM_USERS-1:0][WIDTH-1:0] quota,
    input  wire [1:0] user_select,
    input  wire moisture_dry,
    input  wire rain,
    input  wire manual_override,
    input  wire peak_time,

    output wire [NUM_USERS-1:0] quota_exceeded,
    output wire [WIDTH-1:0] usage_out,
    output wire [WIDTH-1:0] quota_out,
    output wire valve_on,
    output wire flow_boost_on
);
    // Quota exceeded for each user
    assign quota_exceeded[0] = (usage[0] >= quota[0]);
    assign quota_exceeded[1] = (usage[1] >= quota[1]);
    assign quota_exceeded[2] = (usage[2] >= quota[2]);
    assign quota_exceeded[3] = (usage[3] >= quota[3]);

    // Select outputs for display
    assign usage_out = usage[user_select];
    assign quota_out = quota[user_select];

    // Irrigation permission
    wire irrigating_allowed = moisture_dry && !rain && !quota_exceeded[user_select];

    // Valve control
    assign valve_on = (!rain) && (
                        (manual_override && !quota_exceeded[user_select]) ||
                        irrigating_allowed
                     );

    // Flow boost when sunlight is strong
    assign flow_boost_on = valve_on && peak_time;
endmodule

//===============================================================
// TOP MODULE: SMART IRRIGATION (DATAFLOW VERSION)
//===============================================================
module smart_irrigation #(
    parameter WIDTH = 6,
    parameter NUM_USERS = 4,
    parameter DEBOUNCE_WIDTH = 8
)(
    input  wire clk,               // kept for compatibility
    input  wire rst_n,             // kept for compatibility
    input  wire clk_1hz,           // kept for compatibility
    input  wire flow_pulse_raw,
    input  wire moisture_dry,
    input  wire rain,
    input  wire auto_cycle_start,
    input  wire [1:0] user_select_manual,
    input  wire reset_user,        // dummy for compatibility
    input  wire quota_wr,          // dummy for compatibility
    input  wire [WIDTH-1:0] quota_set, // dummy
    input  wire manual_override,

    output wire valve_on,
    output wire [NUM_USERS-1:0] quota_exceeded,
    output wire [WIDTH-1:0] usage_out,
    output wire [WIDTH-1:0] quota_out,
    output wire flow_boost_on,
    output wire sequencer_active,
    output wire [1:0] current_zone
);
    // ------------------- Static Demo Data -------------------
    // For dataflow version, we use fixed usage/quota tables.
    // You can edit these constants as needed.
    wire [NUM_USERS-1:0][WIDTH-1:0] usage = {
        6'd25, 6'd12, 6'd5, 6'd18
    };
    wire [NUM_USERS-1:0][WIDTH-1:0] quota = {
        6'd40, 6'd30, 6'd20, 6'd35
    };

    // ------------------- Submodules -------------------
    wire flow_pulse_clean;
    debounce_pulse u_debounce (
        .raw_in(flow_pulse_raw),
        .clk(clk),
        .rst_n(rst_n),
        .clean_out(flow_pulse_clean)
    );

    wire peak_time;
    sun_timer u_sun (
        .hour_cnt(6'd12), // assume noon for now
        .peak_time(peak_time)
    );

    wire [1:0] user_select_final;
    zone_fsm u_fsm (
        .auto_cycle_start(auto_cycle_start),
        .user_select_manual(user_select_manual),
        .final_user_select(user_select_final),
        .sequencer_active(sequencer_active)
    );

    irrigation_core #(
        .WIDTH(WIDTH),
        .NUM_USERS(NUM_USERS)
    ) u_core (
        .usage(usage),
        .quota(quota),
        .user_select(user_select_final),
        .moisture_dry(moisture_dry),
        .rain(rain),
        .manual_override(manual_override),
        .peak_time(peak_time),
        .quota_exceeded(quota_exceeded),
        .usage_out(usage_out),
        .quota_out(quota_out),
        .valve_on(valve_on),
        .flow_boost_on(flow_boost_on)
    );

    // ------------------- Top Output Assignments -------------------
    assign current_zone = user_select_final;

endmodule
