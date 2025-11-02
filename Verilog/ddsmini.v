//================================================================
//  SMART IRRIGATION SYSTEM
//  Modelled across all abstraction levels: Behavioral, Dataflow, and Structural
//================================================================

module smart_irrigation #(
    parameter NUM_USERS = 4,
    parameter WIDTH = 6, // 6-bit (0-63)
    parameter DEBOUNCE_WIDTH = 20
)(
    // ------------------- System Inputs -------------------
    input  wire clk,                // Main fast clock
    input  wire rst_n,              // Active low reset
    input  wire clk_1hz,            // 1-second clock for 24-hour timer

    // ------------------- Sensor Inputs -------------------
    input  wire flow_pulse_raw,     // Flow sensor pulse
    input  wire moisture_dry,       // 1 = dry
    input  wire rain,               // 1 = raining

    // ------------------- Control Inputs -------------------
    input  wire auto_cycle_start,           // Start automatic sequence
    input  wire [1:0] user_select_manual,   // Manual zone select
    input  wire reset_user,                 // Reset usage for CURRENT user
    input  wire quota_wr,                   // Write quota for CURRENT user
    input  wire [WIDTH-1:0] quota_set,      // Quota value to write
    input  wire manual_override,            // Force valve on (except rain/exhausted)

    // ------------------- System Outputs -------------------
    output reg  valve_on,
    output reg  [NUM_USERS-1:0] quota_exceeded,
    output reg  [WIDTH-1:0]     usage_out,
    output reg  [WIDTH-1:0]     quota_out,
    output wire flow_boost_on,
    output wire sequencer_active,
    output wire [1:0] current_zone
);

    //================================================================
    // LEVEL 1: STRUCTURAL MODEL
    //================================================================
    // Defines interconnection of modules, memories, and signals.

    reg [WIDTH-1:0] quota [0:NUM_USERS-1];  // Register array for water quota
    reg [WIDTH-1:0] usage [0:NUM_USERS-1];  // Register array for used water amount
    integer i;

    //================================================================
    // LEVEL 2: DATAFLOW MODEL — Sun Time Calculation
    //================================================================
    // Computes how data moves through signals using continuous assignments.

    reg [4:0] hour_cnt;        // 0–23 fits in 5 bits
    wire peak_time;            // Logical flag for peak sunlight hours (10AM–4PM)

    always @(posedge clk_1hz or negedge rst_n) begin
        if (!rst_n)
            hour_cnt <= 0;
        else if (hour_cnt == 23)
            hour_cnt <= 0;
        else
            hour_cnt <= hour_cnt + 1;
    end

    assign peak_time = (hour_cnt >= 5'd10) && (hour_cnt <= 5'd16);

    //================================================================
    // LEVEL 3: BEHAVIORAL MODEL — Zone Sequencer FSM
    //================================================================
    // Describes *what the system does* using algorithmic state transitions.

    localparam [2:0]
        S_IDLE   = 3'b000,
        S_ZONE_2 = 3'b001, // Priority 1
        S_ZONE_0 = 3'b010, // Priority 2
        S_ZONE_3 = 3'b011, // Priority 3
        S_ZONE_1 = 3'b100; // Priority 4

    reg [2:0] current_state;
    reg [1:0] internal_user_select_fsm;
    reg       internal_start_pulse;
    reg       internal_sequencer_active;

    reg irrigating_last;
    wire zone_finished_pulse = irrigating_last && !irrigating;

    // FSM Controls the automatic switching between zones
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            internal_start_pulse <= 1'b0;
        end else begin
            internal_start_pulse <= 1'b0;
            case (current_state)
                S_IDLE:
                    if (auto_cycle_start) begin
                        current_state <= S_ZONE_2;
                        internal_start_pulse <= 1'b1;
                    end
                S_ZONE_2:
                    if (zone_finished_pulse) begin
                        current_state <= S_ZONE_0;
                        internal_start_pulse <= 1'b1;
                    end
                S_ZONE_0:
                    if (zone_finished_pulse) begin
                        current_state <= S_ZONE_3;
                        internal_start_pulse <= 1'b1;
                    end
                S_ZONE_3:
                    if (zone_finished_pulse) begin
                        current_state <= S_ZONE_1;
                        internal_start_pulse <= 1'b1;
                    end
                S_ZONE_1:
                    if (zone_finished_pulse)
                        current_state <= S_IDLE;
                default:
                    current_state <= S_IDLE;
            endcase
        end
    end

    // FSM Output Mapping
    always @(*) begin
        case (current_state)
            S_IDLE:   begin internal_user_select_fsm = 2'b00; internal_sequencer_active = 1'b0; end
            S_ZONE_2: begin internal_user_select_fsm = 2'b10; internal_sequencer_active = 1'b1; end
            S_ZONE_0: begin internal_user_select_fsm = 2'b00; internal_sequencer_active = 1'b1; end
            S_ZONE_3: begin internal_user_select_fsm = 2'b11; internal_sequencer_active = 1'b1; end
            S_ZONE_1: begin internal_user_select_fsm = 2'b01; internal_sequencer_active = 1'b1; end
            default:  begin internal_user_select_fsm = 2'b00; internal_sequencer_active = 1'b0; end
        endcase
    end

    // Choose zone: automatic or manual
    wire [1:0] final_user_select = internal_sequencer_active ? internal_user_select_fsm : user_select_manual;

    assign sequencer_active = internal_sequencer_active;
    assign current_zone = final_user_select;

    //================================================================
    // LEVEL 4: STRUCTURAL MODEL — Module Instantiation
    //================================================================
    // The debounce module removes input noise using synchronizers and counters.

    wire flow_pulse_debounced;
    debounce_pulse #(.WIDTH(DEBOUNCE_WIDTH)) u_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .raw_in(flow_pulse_raw),
        .clean_out(flow_pulse_debounced)
    );

    //================================================================
    // LEVEL 5: BEHAVIORAL + DATAFLOW — Main Control Logic
    //================================================================
    // This section mixes behavioral sequencing with dataflow relationships.

    reg irrigating;
    reg flow_pulse_last;
    wire [1:0] increment_val = peak_time ? 2'b10 : 2'b01; // Sunlight effect
    wire [WIDTH-1:0] max_val = {WIDTH{1'b1}};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irrigating <= 1'b0;
            flow_pulse_last <= 1'b0;
            irrigating_last <= 1'b0;
            for (i = 0; i < NUM_USERS; i = i + 1) begin
                usage[i] <= {WIDTH{1'b0}};
                quota[i] <= {WIDTH{1'b0}};
            end
            usage_out <= {WIDTH{1'b0}};
            quota_out <= {WIDTH{1'b0}};
        end else begin
            flow_pulse_last <= flow_pulse_debounced;
            irrigating_last <= irrigating;

            if (reset_user)
                usage[final_user_select] <= {WIDTH{1'b0}};

            if (quota_wr)
                quota[final_user_select] <= quota_set;

            // Start and Stop Conditions (Behavioral)
            if (internal_start_pulse && !irrigating && moisture_dry && !rain && !quota_exceeded[final_user_select])
                irrigating <= 1'b1;
            else if (irrigating && (!moisture_dry || rain || quota_exceeded[final_user_select]))
                irrigating <= 1'b0;

            // Flow Pulse Counting (Dataflow)
            if (valve_on && flow_pulse_debounced && !flow_pulse_last) begin
                if (usage[final_user_select] <= max_val - {{(WIDTH-2){1'b0}}, increment_val})
                    usage[final_user_select] <= usage[final_user_select] + {{(WIDTH-2){1'b0}}, increment_val};
                else
                    usage[final_user_select] <= max_val;
            end

            usage_out <= usage[final_user_select];
            quota_out <= quota[final_user_select];
        end
    end

    // Quota Exceeded Logic (Dataflow)
    always @(*) begin
        for (i = 0; i < NUM_USERS; i = i + 1)
            quota_exceeded[i] = (usage[i] >= quota[i]);
    end

    // Valve Control (Dataflow + Behavioral conditions)
    always @(*) begin
        if (rain)
            valve_on = 1'b0;
        else if (manual_override && !quota_exceeded[final_user_select])
            valve_on = 1'b1;
        else if (irrigating && !quota_exceeded[final_user_select])
            valve_on = 1'b1;
        else
            valve_on = 1'b0;
    end

    assign flow_boost_on = valve_on && peak_time; // Dataflow output

endmodule


//================================================================
// SUBMODULE: Debounce Pulse (Gate-Level Model Example)
//================================================================
// This module demonstrates a lower-level, gate-equivalent design.
// It filters mechanical switch noise using flip-flops and counters.

module debounce_pulse #(
    parameter WIDTH = 20
)(
    input wire clk,
    input wire rst_n,
    input wire raw_in,
    output reg clean_out
);
    reg [WIDTH-1:0] counter;
    reg raw_sync_0;
    reg raw_sync_1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_sync_0 <= 1'b0;
            raw_sync_1 <= 1'b0;
            counter    <= {WIDTH{1'b0}};
            clean_out  <= 1'b0;
        end else begin
            raw_sync_0 <= raw_in;
            raw_sync_1 <= raw_sync_0;

            if (raw_sync_1 == clean_out)
                counter <= {WIDTH{1'b0}};
            else if (counter != {WIDTH{1'b1}})
                counter <= counter + 1'b1;
            else begin
                clean_out <= raw_sync_1;
                counter <= {WIDTH{1'b0}};
            end
        end
    end
endmodule
