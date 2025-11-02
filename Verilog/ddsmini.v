module smart_irrigation #(
    parameter NUM_USERS = 4,
    parameter WIDTH = 6, // 6-bit (0-63)
    parameter DEBOUNCE_WIDTH = 20
)(
    // --- System Inputs ---
    input  wire clk,                // Main fast clock
    input  wire rst_n,              // Active low reset
    input  wire clk_1hz,            // 1-second clock for 24-hour timer

    // --- Sensor Inputs ---
    input  wire flow_pulse_raw,    // Flow sensor pulse
    input  wire moisture_dry,      // 1 = dry
    input  wire rain,              // 1 = raining

    // --- Control Inputs ---
    input  wire auto_cycle_start,           // Start automatic sequence
    input  wire [1:0] user_select_manual,   // Manual zone select
    input  wire reset_user,                 // reset usage for CURRENT user
    input  wire quota_wr,                   // write quota for CURRENT user
    input  wire [WIDTH-1:0] quota_set,      // quota value to write
    input  wire manual_override,            // force valve on (except rain/exhausted)

    // --- System Outputs ---
    output reg  valve_on,
    output reg  [NUM_USERS-1:0] quota_exceeded,
    output reg  [WIDTH-1:0]     usage_out,
    output reg  [WIDTH-1:0]     quota_out,
    output wire flow_boost_on,
    output wire sequencer_active,
    output wire [1:0] current_zone
);

    //================================================================
    // 1. MEMORY AND DATA REGISTERS
    //================================================================
    reg [WIDTH-1:0] quota [0:NUM_USERS-1];
    reg [WIDTH-1:0] usage [0:NUM_USERS-1];
    integer i;

    //================================================================
    // 2. 24-HOUR CLOCK & PEAK TIME LOGIC
    //================================================================
    reg [4:0] hour_cnt; // 0-23 fits in 5 bits
    wire peak_time;

    // hour counter increments on posedge clk_1hz (clean pulse)
    always @(posedge clk_1hz or negedge rst_n) begin
        if (!rst_n) begin
            hour_cnt <= 0;
        end else begin
            if (hour_cnt == 23)
                hour_cnt <= 0;
            else
                hour_cnt <= hour_cnt + 1;
        end
    end

    assign peak_time = (hour_cnt >= 5'd10) && (hour_cnt <= 5'd16);

    //================================================================
    // 3. PRIORITY ZONE SEQUENCER (FSM)
    //================================================================
    localparam [2:0] S_IDLE   = 3'b000;
    localparam [2:0] S_ZONE_2 = 3'b001; // Priority 1: zone 2 (10)
    localparam [2:0] S_ZONE_0 = 3'b010; // Priority 2: zone 0 (00)
    localparam [2:0] S_ZONE_3 = 3'b011; // Priority 3: zone 3 (11)
    localparam [2:0] S_ZONE_1 = 3'b100; // Priority 4: zone 1 (01)

    reg [2:0] current_state;

    reg [1:0] internal_user_select_fsm;
    reg       internal_start_pulse;
    reg       internal_sequencer_active;

    // For edge detection of irrigating -> not-irrigating
    reg irrigating_last;

    // zone_finished pulse is true when irrigating was 1 last cycle and now 0
    wire zone_finished_pulse = irrigating_last && !irrigating;

    // Sequencer FSM (clocked by main clk)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            internal_start_pulse <= 1'b0;
        end else begin
            internal_start_pulse <= 1'b0; // default: 1-cycle pulse when asserted
            case (current_state)
                S_IDLE: begin
                    if (auto_cycle_start) begin
                        current_state <= S_ZONE_2;
                        internal_start_pulse <= 1'b1;
                    end
                end
                S_ZONE_2: begin
                    if (zone_finished_pulse) begin
                        current_state <= S_ZONE_0;
                        internal_start_pulse <= 1'b1;
                    end
                end
                S_ZONE_0: begin
                    if (zone_finished_pulse) begin
                        current_state <= S_ZONE_3;
                        internal_start_pulse <= 1'b1;
                    end
                end
                S_ZONE_3: begin
                    if (zone_finished_pulse) begin
                        current_state <= S_ZONE_1;
                        internal_start_pulse <= 1'b1;
                    end
                end
                S_ZONE_1: begin
                    if (zone_finished_pulse) begin
                        current_state <= S_IDLE;
                    end
                end
                default: current_state <= S_IDLE;
            endcase
        end
    end

    // Combinational outputs for FSM state
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

    // Final user select: FSM (if active) or manual select
    wire [1:0] final_user_select = internal_sequencer_active ? internal_user_select_fsm : user_select_manual;

    assign sequencer_active = internal_sequencer_active;
    assign current_zone = final_user_select;

    //================================================================
    // 4. DEBOUNCE PULSE
    //================================================================
    wire flow_pulse_debounced;
    debounce_pulse #(.WIDTH(DEBOUNCE_WIDTH)) u_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .raw_in(flow_pulse_raw),
        .clean_out(flow_pulse_debounced)
    );

    //================================================================
    // 5. CORE CONTROLLER LOGIC
    //================================================================
    reg irrigating;
    reg flow_pulse_last;

    // increment value: 2 during peak_time else 1
    wire [1:0] increment_val = peak_time ? 2'b10 : 2'b01;

    // max value of WIDTH bits
    wire [WIDTH-1:0] max_val = {WIDTH{1'b1}};

    // Reset and main sequential behavior
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irrigating <= 1'b0;
            flow_pulse_last <= 1'b0;
            irrigating_last <= 1'b0;
            // Clear memories on reset
            for (i = 0; i < NUM_USERS; i = i + 1) begin
                usage[i] <= {WIDTH{1'b0}};
                quota[i] <= {WIDTH{1'b0}};
            end
            // outputs
            usage_out <= {WIDTH{1'b0}};
            quota_out <= {WIDTH{1'b0}};
        end else begin
            // track previous pulse and irrigating state
            flow_pulse_last <= flow_pulse_debounced;
            irrigating_last <= irrigating;

            // handle writes/resets targeted at final_user_select
            if (reset_user) begin
                usage[final_user_select] <= {WIDTH{1'b0}};
            end

            if (quota_wr) begin
                quota[final_user_select] <= quota_set;
            end

            // Starting condition: a 1-cycle internal_start_pulse triggers irrigating start,
            // but we also check moisture_dry, rain, and quota_exceeded
            if (internal_start_pulse && !irrigating && moisture_dry && !rain && !quota_exceeded[final_user_select]) begin
                irrigating <= 1'b1;
            end
            // Stop conditions
            else if (irrigating && (!moisture_dry || rain || quota_exceeded[final_user_select])) begin
                irrigating <= 1'b0;
            end

            // Count rising edge of debounced flow pulse if valve_on is true
            if (valve_on && flow_pulse_debounced && !flow_pulse_last) begin
                // safe add with overflow clamp
                if (usage[final_user_select] <= max_val - {{(WIDTH-2){1'b0}}, increment_val}) begin
                    usage[final_user_select] <= usage[final_user_select] + {{(WIDTH-2){1'b0}}, increment_val};
                end else begin
                    usage[final_user_select] <= max_val;
                end
            end

            // Update outputs for currently selected user (registered output)
            usage_out <= usage[final_user_select];
            quota_out <= quota[final_user_select];
        end
    end

    // Quota exceeded combinational
    always @(*) begin
        for (i = 0; i < NUM_USERS; i = i + 1) begin
            quota_exceeded[i] = (usage[i] >= quota[i]);
        end
    end

    // Valve control combinational
    always @(*) begin
        if (rain) begin
            valve_on = 1'b0; // rain overrides everything
        end else if (manual_override && !quota_exceeded[final_user_select]) begin
            valve_on = 1'b1;
        end else if (irrigating && !quota_exceeded[final_user_select]) begin
            valve_on = 1'b1;
        end else begin
            valve_on = 1'b0;
        end
    end

    assign flow_boost_on = valve_on && peak_time;

endmodule


// Debounce module (unchanged; kept as reg output)
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

            if (raw_sync_1 == clean_out) begin
                counter <= {WIDTH{1'b0}};
            end else begin
                if (counter != {WIDTH{1'b1}}) begin
                    counter <= counter + 1'b1;
                end else begin
                    clean_out <= raw_sync_1;
                    counter <= {WIDTH{1'b0}};
                end
            end
        end
    end
endmodule
