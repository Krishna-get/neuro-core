`timescale 1ns / 1ps

module tb_exp_high_precision;

    // Signals
    reg clk;
    reg rst_n;
    
    reg signed [63:0] x_in;
    reg x_in_valid;
    wire x_in_ready;
    
    wire signed [63:0] exp_out;
    wire output_valid;
    reg output_ready;

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate the Wrapper (UUT)
    exp_high_precision_wrapper uut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .x_in_valid(x_in_valid),
        .x_in_ready(x_in_ready),
        .exp_out(exp_out),
        .output_valid(output_valid),
        .output_ready(output_ready)
    );

    // Monitor internal state (for debugging)
    // "uut.state" allows us to peek inside the module during sim
    always @(uut.state) begin
        case (uut.state)
            3'd0: $display("[Time %t] Wrapper State: IDLE", $time);
            3'd1: $display("[Time %t] Wrapper State: CALC_K", $time);
            3'd2: $display("[Time %t] Wrapper State: CALC_R", $time);
            3'd3: $display("[Time %t] Wrapper State: CALL_CORDIC", $time);
            3'd4: $display("[Time %t] Wrapper State: WAIT_CORE", $time);
            3'd5: $display("[Time %t] Wrapper State: SHIFT_RES", $time);
            3'd6: $display("[Time %t] Wrapper State: DONE", $time);
        endcase
    end

    // Helper Variables
    real real_output;
    real expected_val;

    // Test Sequence
    initial begin
        $display("Starting Simulation...");
        rst_n = 0;
        x_in = 0;
        x_in_valid = 0;
        output_ready = 1;

        #20;
        rst_n = 1;
        $display("Reset Released");
        #20;

        // ------------------------------------------------------------
        // Test Case 1: x = 0.5
        // ------------------------------------------------------------
        $display("Sending Input 0.5...");
        send_input(64'h0000_0080_0000_0000); 
        
        // Wait with Timeout to prevent hanging
        fork : wait_block
            begin
                wait(output_valid);
                $display("Output Received!");
                disable wait_block;
            end
            begin
                #5000; // Wait 5000ns (plenty of time)
                $display("ERROR: Timeout waiting for output!");
                $stop; // Pause simulation so you can check waveforms
            end
        join

        #2; 
        display_results(0.5);
        #50;

        // ------------------------------------------------------------
        // Test Case 2: x = 1.0
        // ------------------------------------------------------------
        $display("Sending Input 1.0...");
        send_input(64'h0000_0100_0000_0000);
        
        fork : wait_block_2
            begin
                wait(output_valid);
                disable wait_block_2;
            end
            begin
                #5000;
                $display("ERROR: Timeout waiting for output!");
                $stop;
            end
        join

        #2;
        display_results(1.0);
        #50;

        // ------------------------------------------------------------
        // Test Case 3: x = 2.0
        // ------------------------------------------------------------
        $display("Sending Input 2.0...");
        send_input(64'h0000_0200_0000_0000);
        
        fork : wait_block_3
            begin
                wait(output_valid);
                disable wait_block_3;
            end
            begin
                #5000;
                $display("ERROR: Timeout waiting for output!");
                $stop;
            end
        join

        #2;
        display_results(2.0);
        #50;

        // ------------------------------------------------------------
        // Test Case 4: x = -1.0 
        // ------------------------------------------------------------
        $display("Sending Input -1.0...");
        send_input(-64'sh0000_0100_0000_0000); 
        
        fork : wait_block_4
            begin
                wait(output_valid);
                disable wait_block_4;
            end
            begin
                #5000;
                $display("ERROR: Timeout waiting for output!");
                $stop;
            end
        join

        #2;
        display_results(-1.0);
        #50;

        $display("----------------------------------------");
        $display("All Tests Completed.");
        $finish;
    end

    task send_input;
        input signed [63:0] data;
        begin
            wait(x_in_ready);
            @(posedge clk);
            x_in = data;
            x_in_valid = 1;
            @(posedge clk);
            x_in_valid = 0;
        end
    endtask

    task display_results;
        input real input_val;
        begin
            real_output = $itor(exp_out) / 1099511627776.0;
            expected_val = $exp(input_val);
            
            $display("----------------------------------------");
            $display("Input x         : %f", input_val);
            $display("Output (Real)   : %f", real_output);
            $display("Expected (Real) : %f", expected_val);
            $display("Error           : %f", real_output - expected_val);
        end
    endtask

endmodule