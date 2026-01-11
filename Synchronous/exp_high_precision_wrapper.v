`timescale 1ns / 1ps

module exp_high_precision_wrapper (
    input wire clk,
    input wire rst_n,

    // Input handshake
    input wire signed [63:0] x_in,        // S1.23.40
    input wire               x_in_valid,
    output reg               x_in_ready,

    // Output handshake
    output reg signed [63:0] exp_out,     // S1.23.40
    output reg               output_valid,
    input wire               output_ready
);

    // -------------------------------------------------------------------------
    // Constants (S1.23.40 format)
    // -------------------------------------------------------------------------
    // ln(2) = 0.69314718056...
    // 0.69314718056 * 2^40 = 762129219345
    localparam signed [63:0] LN2 = 64'h000000B17217F7D1;

    // 1/ln(2) = 1.44269504089...
    // 1.44269504089 * 2^40 = 1586264584888
    localparam signed [63:0] INV_LN2 = 64'h00000171547652B8;

    // -------------------------------------------------------------------------
    // State Machine
    // -------------------------------------------------------------------------
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CALC_K      = 3'd1; 
    localparam [2:0] CALC_R      = 3'd2; 
    localparam [2:0] CALL_CORDIC = 3'd3; 
    localparam [2:0] WAIT_CORE   = 3'd4; 
    localparam [2:0] SHIFT_RES   = 3'd5; 
    localparam [2:0] DONE        = 3'd6; 

    reg [2:0] state;

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    reg signed [63:0] k_val;         // Integer k
    reg signed [63:0] r_val;         // Remainder r
    
    // Core Interface
    reg signed [63:0] core_in;
    reg               core_in_valid;
    wire              core_in_ready;
    wire signed [63:0] core_out;
    wire              core_out_valid;
    reg               core_out_ready;

    // Math Temp (128-bit)
    reg signed [127:0] mult_temp; 

    // -------------------------------------------------------------------------
    // Instantiate Calibrated CORDIC Core
    // -------------------------------------------------------------------------
    exp_fixed_point_cordic_24_40 cordic_core (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(core_in),
        .x_in_valid(core_in_valid),
        .x_in_ready(core_in_ready),
        .exp_out(core_out),
        .output_valid(core_out_valid),
        .output_ready(core_out_ready)
    );

    // -------------------------------------------------------------------------
    // Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_in_ready <= 1'b1;
            output_valid <= 1'b0;
            exp_out <= 64'd0;
            k_val <= 64'd0;
            r_val <= 64'd0;
            core_in_valid <= 1'b0;
            core_out_ready <= 1'b0;
            core_in <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    x_in_ready <= 1'b1;
                    output_valid <= 1'b0;
                    if (x_in_valid && x_in_ready) begin
                        x_in_ready <= 1'b0;
                        r_val <= x_in; 
                        state <= CALC_K;
                    end
                end

                CALC_K: begin
                    // Step 1: k = round(x * 1/ln2)
                    mult_temp = r_val * INV_LN2;
                    
                    // FIX: Explicitly cast the constant to signed ($signed)
                    // This prevents Verilog from treating the addition as unsigned
                    k_val <= (mult_temp + $signed(128'd1 << 79)) >>> 80;
                    
                    state <= CALC_R;
                end

                CALC_R: begin
                    // Step 2: r = x - (k * ln2)
                    mult_temp = k_val * LN2;
                    r_val <= r_val - mult_temp[63:0];
                    state <= CALL_CORDIC;
                end

                CALL_CORDIC: begin
                    core_in <= r_val;
                    core_in_valid <= 1'b1;
                    if (core_in_ready) begin
                        state <= WAIT_CORE;
                    end
                end

                WAIT_CORE: begin
                    core_in_valid <= 1'b0;
                    core_out_ready <= 1'b1;
                    
                    if (core_out_valid) begin
                        r_val <= core_out; 
                        state <= SHIFT_RES;
                    end
                end

                SHIFT_RES: begin
                    core_out_ready <= 1'b0;
                    
                    // Step 4: Final Result = e^r * 2^k
                    if (k_val >= 0) begin
                        exp_out <= r_val <<< k_val;
                    end else begin
                        // Negate k for shift amount
                        // Using -k_val is safe now because k_val is correctly signed
                        exp_out <= r_val >>> (-k_val);
                    end
                    
                    state <= DONE;
                end

                DONE: begin
                    output_valid <= 1'b1;
                    
                    // FIX: Do NOT clear output_valid immediately.
                    // Let it stay high for 1 cycle until state changes.
                    if (output_ready) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule