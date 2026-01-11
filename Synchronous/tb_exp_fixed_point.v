`timescale 1ns / 1ps

module tb_exp_fixed_point;

    // Signals
    reg clk;
    reg rst_n;
    
    reg signed [63:0] x_in;
    reg x_in_valid;
    wire x_in_ready;
    
    wire signed [63:0] exp_out;
    wire output_valid;
    reg output_ready;

    // Clock Generation (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate the Unit Under Test (UUT)
    exp_fixed_point_cordic_24_40 uut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .x_in_valid(x_in_valid),
        .x_in_ready(x_in_ready),
        .exp_out(exp_out),
        .output_valid(output_valid),
        .output_ready(output_ready)
    );

    // Helper Variable for Display
    real real_output;
    real real_input;
    real expected_val;

    // Test Sequence
    initial begin
        // Initialize Inputs
        rst_n = 0;
        x_in = 0;
        x_in_valid = 0;
        output_ready = 1; // Always ready to receive result

        // Apply Reset
        #20;
        rst_n = 1;
        #20;

        // ------------------------------------------------------------
        // Test Case 1: x = 0.5
        // 0.5 * 2^40 = 549755813888 = 0x80_0000_0000
        // Expected e^0.5 ≈ 1.648721...
        // ------------------------------------------------------------
        send_input(64'h0000_0080_0000_0000); 
        wait(output_valid);
        #1; // wait for stability
        display_results(0.5);
        
        #50; // Wait a few cycles

        // ------------------------------------------------------------
        // Test Case 2: x = 1.0
        // 1.0 * 2^40 = 1099511627776 = 0x100_0000_0000
        // Expected e^1.0 ≈ 2.718281...
        // ------------------------------------------------------------
        send_input(64'h0000_0100_0000_0000);
        wait(output_valid);
        #1;
        display_results(1.0);

        #50;

        // ------------------------------------------------------------
        // Test Case 3: x = -0.5
        // -0.5 * 2^40 = Two's Complement of 0x80_0000_0000
        // Expected e^-0.5 ≈ 0.606530...
        // ------------------------------------------------------------
        send_input(-64'sh0000_0080_0000_0000);
        wait(output_valid);
        #1;
        display_results(-0.5);

        #50;
        
        $display("----------------------------------------");
        $display("Simulation Completed.");
        $finish;
    end

    // Task to drive inputs with handshake
    task send_input;
        input signed [63:0] data;
        begin
            wait(x_in_ready);  // Wait for module to be ready
            @(posedge clk);
            x_in = data;
            x_in_valid = 1;
            @(posedge clk);
            x_in_valid = 0;    // Deassert valid after one cycle
        end
    endtask

    // Task to display results in readable format
    task display_results;
        input real input_val;
        begin
            // Convert Fixed Point (S1.23.40) to Real
            // Divide by 2^40 (1099511627776.0)
            real_output = $itor(exp_out) / 1099511627776.0;
            expected_val = $exp(input_val); // Use Verilog built-in exp for check
            
            $display("----------------------------------------");
            $display("Input x         : %f", input_val);
            $display("Output (Hex)    : %h", exp_out);
            $display("Output (Real)   : %f", real_output);
            $display("Expected (Real) : %f", expected_val);
            $display("Error           : %f", real_output - expected_val);
        end
    endtask

endmodule