`timescale 1ns / 1ps
//================================================================
// SMART IRRIGATION SYSTEM — BEHAVIORAL MODEL
// Compatible with tb_smart_irrigation (no changes needed)
//================================================================

//===============================================================
// SUBMODULE 1: Debounce Pulse (Behavioral)
//===============================================================
module debounce_pulse (
    input  wire raw_in,
    input  wire clk,
    input  wire rst_n,
    output reg  clean_out
);
    reg [2:0] sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync <= 3'b000;
        else
            sync <= {sync[1:0], raw_in};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clean_out <= 1'b0;
        else if (sync[2] & ~sync[1]) // detect rising edge
            clean_out <= 1'b1;
        else
            clean_out <= 1'b0;
    end
endmodule

//===============================================================
// SUBMODULE 2: Sun Timer (Behavioral)
//===============================================================
module sun_timer (
    input  wire [5:0] hour_cnt,
    output reg  peak_time
);
    always @(*) begin
        if (hour_cnt >= 6'd10 && hour_cnt <= 6'd16)
            peak_time = 1'b1;
        else
            peak_time = 1'b0;
    end
endmodule

//===============================================================
// SUBMODULE 3: Zone FSM (Behavioral)
//===============================================================
module zone_fsm (
    input  wire auto_cycle_start,
    input  wire [1:0] user_select_manual,
    output reg  [1:0] final_user_select,
    output reg  sequencer_active
);
    always @(*) begin
        if (auto_cycle_start) begin
            sequencer_active   = 1'b1;
            final_user_select  = 2'b10;
        end else begin
            sequencer_active   = 1'b0;
            final_user_select  = user_select_manual;
        end
    end
endmodule

//===============================================================
// SUBMODULE 4: Irrigation Core (Behavioral)
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

    output reg  [NUM_USERS-1:0] quota_exceeded,
    output reg  [WIDTH-1:0] usage_out,
    output reg  [WIDTH-1:0] quota_out,
    output reg  valve_on,
    output reg  flow_boost_on
);
    integer i;

    always @(*) begin
        // Check which users have exceeded their quota
        for (i = 0; i < NUM_USERS; i = i + 1)
            quota_exceeded[i] = (usage[i] >= quota[i]) ? 1'b1 : 1'b0;

        // Output the selected user's usage and quota
        case (user_select)
            2'b00: begin usage_out = usage[0]; quota_out = quota[0]; end
            2'b01: begin usage_out = usage[1]; quota_out = quota[1]; end
            2'b10: begin usage_out = usage[2]; quota_out = quota[2]; end
            2'b11: begin usage_out = usage[3]; quota_out = quota[3]; end
            default: begin usage_out = 0; quota_out = 0; end
        endcase

        // Valve control logic
        if (!rain && (manual_override || (moisture_dry && !quota_exceeded[user_select])))
            valve_on = 1'b1;
        else
            valve_on = 1'b0;

        // Flow boost at peak hours
        flow_boost_on = valve_on & peak_time;
    end
endmodule

//===============================================================
// TOP MODULE — SMART IRRIGATION SYSTEM (Behavioral)
//===============================================================
module smart_irrigation #(
    parameter WIDTH = 6,
    parameter NUM_USERS = 4,
    parameter DEBOUNCE_WIDTH = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire clk_1hz,
    input  wire flow_pulse_raw,
    input  wire moisture_dry,
    input  wire rain,
    input  wire auto_cycle_start,
    input  wire [1:0] user_select_manual,
    input  wire reset_user,
    input  wire quota_wr,
    input  wire [WIDTH-1:0] quota_set,
    input  wire manual_override,

    output wire valve_on,
    output wire [NUM_USERS-1:0] quota_exceeded,
    output wire [WIDTH-1:0] usage_out,
    output wire [WIDTH-1:0] quota_out,
    output wire flow_boost_on,
    output wire sequencer_active,
    output wire [1:0] current_zone
);
    //===========================================================
    // Internal signals
    //===========================================================
    wire flow_pulse_clean;
    wire peak_time;
    wire [1:0] user_select_final;
    reg  [NUM_USERS-1:0][WIDTH-1:0] usage_reg, quota_reg;
    integer i;

    //===========================================================
    // Debounce pulse generation
    //===========================================================
    debounce_pulse u_debounce (
        .raw_in(flow_pulse_raw),
        .clk(clk),
        .rst_n(rst_n),
        .clean_out(flow_pulse_clean)
    );

    //===========================================================
    // Sun Timer
    //===========================================================
    reg [5:0] hour_cnt = 6'd12;
    sun_timer u_sun (.hour_cnt(hour_cnt), .peak_time(peak_time));

    //===========================================================
    // Zone FSM
    //===========================================================
    zone_fsm u_zone (
        .auto_cycle_start(auto_cycle_start),
        .user_select_manual(user_select_manual),
        .final_user_select(user_select_final),
        .sequencer_active(sequencer_active)
    );

    //===========================================================
    // User data update logic
    //===========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_USERS; i = i + 1) begin
                usage_reg[i] <= 0;
                quota_reg[i] <= 0;
            end
        end else begin
            if (quota_wr)
                quota_reg[user_select_final] <= quota_set;
            if (reset_user)
                usage_reg[user_select_final] <= 0;
            else if (flow_pulse_clean)
                usage_reg[user_select_final] <= usage_reg[user_select_final] + 1;
        end
    end

    //===========================================================
    // Core Irrigation Logic
    //===========================================================
    irrigation_core #(
        .WIDTH(WIDTH),
        .NUM_USERS(NUM_USERS)
    ) u_core (
        .usage(usage_reg),
        .quota(quota_reg),
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

    assign current_zone = user_select_final;
endmodule
