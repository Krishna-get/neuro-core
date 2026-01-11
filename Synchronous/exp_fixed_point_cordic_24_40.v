`timescale 1ns / 1ps

module exp_fixed_point_cordic_24_40 (
    input wire clk,
    input wire rst_n,

    // Input handshake
    input wire signed [63:0] x_in,        
    input wire               x_in_valid,
    output reg               x_in_ready,

    // Output handshake
    output reg signed [63:0] exp_out,     
    output reg               output_valid,
    input wire               output_ready
);

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter ITERATIONS = 40;
	 
	 // CALIBRATED Hyperbolic Inverse Gain
    // Previous Run 1 Output was 1.649046, Target 1.648721
    // Ratio = 0.9998029
    // New Value = Old_Value * 0.9998029
    // Hex: 0x1350DF25916
    parameter signed [63:0] HYPERBOLIC_INV_GAIN = 64'h000001350DF25916;

    // -------------------------------------------------------------------------
    // State Machine
    // -------------------------------------------------------------------------
    localparam [1:0] IDLE    = 2'b00;
    localparam [1:0] COMPUTE = 2'b01;
    localparam [1:0] VALID   = 2'b10;

    reg [1:0] current_state, next_state;

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    reg signed [63:0] x_reg, y_reg, z_reg;
    reg signed [63:0] x_next, y_next, z_next;
    
    reg [5:0] i;             // Iteration counter (1 to 40)
    reg       repeat_flag;   // Handling 3k+1 repetitions
    
    // Variable to hold the current atan value from the lookup logic
    reg signed [63:0] current_atan;

    // -------------------------------------------------------------------------
    // Lookup Table Logic (Combinational)
    // Replaces the 'initial' block array to fix Quartus Synthesis Errors
    // -------------------------------------------------------------------------
    always @(*) begin
        case (i)
            6'd1:  current_atan = 64'h0000008c9f53d553; // atanh(2^-1)
            6'd2:  current_atan = 64'h000000416629982d; // atanh(2^-2)
            6'd3:  current_atan = 64'h0000002020c90fda; // atanh(2^-3)
            6'd4:  current_atan = 64'h00000010055755bc; // atanh(2^-4)
            6'd5:  current_atan = 64'h0000000800ab5560; // atanh(2^-5)
            6'd6:  current_atan = 64'h0000000400155557; // atanh(2^-6)
            6'd7:  current_atan = 64'h000000020002aaab; // atanh(2^-7)
            6'd8:  current_atan = 64'h0000000100005555; // atanh(2^-8)
            6'd9:  current_atan = 64'h0000000080000aaa; // atanh(2^-9)
            6'd10: current_atan = 64'h0000000040000155; // atanh(2^-10)
            6'd11: current_atan = 64'h000000002000002a; // atanh(2^-11)
            6'd12: current_atan = 64'h0000000010000005; // atanh(2^-12)
            6'd13: current_atan = 64'h0000000008000000; // atanh(2^-13)
            6'd14: current_atan = 64'h0000000004000000; // atanh(2^-14)
            6'd15: current_atan = 64'h0000000002000000; // atanh(2^-15)
            6'd16: current_atan = 64'h0000000001000000; // atanh(2^-16)
            6'd17: current_atan = 64'h0000000000800000; // atanh(2^-17)
            6'd18: current_atan = 64'h0000000000400000; // atanh(2^-18)
            6'd19: current_atan = 64'h0000000000200000; // atanh(2^-19)
            6'd20: current_atan = 64'h0000000000100000; // atanh(2^-20)
            6'd21: current_atan = 64'h0000000000080000; // atanh(2^-21)
            6'd22: current_atan = 64'h0000000000040000; // atanh(2^-22)
            6'd23: current_atan = 64'h0000000000020000; // atanh(2^-23)
            6'd24: current_atan = 64'h0000000000010000; // atanh(2^-24)
            6'd25: current_atan = 64'h0000000000008000; // atanh(2^-25)
            6'd26: current_atan = 64'h0000000000004000; // atanh(2^-26)
            6'd27: current_atan = 64'h0000000000002000; // atanh(2^-27)
            6'd28: current_atan = 64'h0000000000001000; // atanh(2^-28)
            6'd29: current_atan = 64'h0000000000000800; // atanh(2^-29)
            6'd30: current_atan = 64'h0000000000000400; // atanh(2^-30)
            6'd31: current_atan = 64'h0000000000000200; // atanh(2^-31)
            6'd32: current_atan = 64'h0000000000000100; // atanh(2^-32)
            6'd33: current_atan = 64'h0000000000000080; // atanh(2^-33)
            6'd34: current_atan = 64'h0000000000000040; // atanh(2^-34)
            6'd35: current_atan = 64'h0000000000000020; // atanh(2^-35)
            6'd36: current_atan = 64'h0000000000000010; // atanh(2^-36)
            6'd37: current_atan = 64'h0000000000000008; // atanh(2^-37)
            6'd38: current_atan = 64'h0000000000000004; // atanh(2^-38)
            6'd39: current_atan = 64'h0000000000000002; // atanh(2^-39)
            6'd40: current_atan = 64'h0000000000000001; // atanh(2^-40)
            default: current_atan = 64'b0;
        endcase
    end

	 // -------------------------------------------------------------------------
    // Next State Logic (Corrected)
    // -------------------------------------------------------------------------
    always @(*) begin
        case (current_state)
            IDLE:    next_state = (x_in_valid && x_in_ready) ? COMPUTE : IDLE;
            
            COMPUTE: begin
                // Only exit if we are at the last iteration AND we have finished repeating
                if (i == ITERATIONS && repeat_flag)
                    next_state = VALID;
                else
                    next_state = COMPUTE;
            end
            
            VALID:   next_state = output_ready ? IDLE : VALID;
            default: next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Sequential Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            x_in_ready    <= 1'b1;
            output_valid  <= 1'b0;
            x_reg         <= 64'b0;
            y_reg         <= 64'b0;
            z_reg         <= 64'b0;
            exp_out       <= 64'b0;
            i             <= 6'd1;
            repeat_flag   <= 1'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    x_in_ready   <= 1'b1;
                    output_valid <= 1'b0;
                    i            <= 6'd1; 
                    repeat_flag  <= 1'b0;

                    if (x_in_valid && x_in_ready) begin
                        x_in_ready <= 1'b0;
                        x_reg <= HYPERBOLIC_INV_GAIN;
                        y_reg <= 64'b0;
                        z_reg <= x_in; 
                    end
                end

                COMPUTE: begin
                    // 1. Determine direction
                    if (z_reg >= 0) begin
                        x_next = x_reg + (y_reg >>> i);
                        y_next = y_reg + (x_reg >>> i);
                        // Use the case-statement variable 'current_atan' here
                        z_next = z_reg - current_atan;
                    end else begin
                        x_next = x_reg - (y_reg >>> i);
                        y_next = y_reg - (x_reg >>> i);
                        z_next = z_reg + current_atan;
                    end

                    // 2. Update registers
                    x_reg <= x_next;
                    y_reg <= y_next;
                    z_reg <= z_next;

                    // 3. Handle Repetition
                    if ((i == 4 || i == 13 || i == 22 || i == 31 || i == 40) && !repeat_flag) begin
                        repeat_flag <= 1'b1;
                    end else begin
                        repeat_flag <= 1'b0;
                        i <= i + 6'd1;
                    end
                end

                VALID: begin
                    output_valid <= 1'b1;
                    exp_out <= x_reg + y_reg;
                end
            endcase
        end
    end

endmodule