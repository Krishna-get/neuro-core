`timescale 1ns / 1ps

module tb_exp_negative_range;

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

    // Instantiate UUT
    exp_fixed_point_negative_optimized uut (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in),
        .x_in_valid(x_in_valid),
        .x_in_ready(x_in_ready),
        .exp_out(exp_out),
        .output_valid(output_valid),
        .output_ready(output_ready)
    );

    real real_output;
    real expected_val;

    // DEBUG: Monitor the Internal State of the Core
    always @(uut.current_state) begin
        case(uut.current_state)
            2'b00: $display("[Time %t] Core State -> IDLE", $time);
            2'b01: $display("[Time %t] Core State -> COMPUTE (Iter: %d)", $time, uut.i);
            2'b10: $display("[Time %t] Core State -> VALID", $time);
        endcase
    end

    initial begin
        $display("---------------------------------------------------------------");
        $display("Testing Negative Range [-1, 0] Performance (DEBUG MODE)");
        $display("---------------------------------------------------------------");
        
        // 1. Initialization
        rst_n = 0; 
        x_in = 0; 
        x_in_valid = 0; 
        output_ready = 1;
        
        // 2. Reset Sequence
        #20; 
        rst_n = 1; 
        $display("[Time %t] Reset Released", $time);
        #20;

        // 3. Run Tests
        // e^0 = 1
        run_test(0.0);   
        
        // e^-0.5
        run_test(-0.5);  
        
        // e^-1.0 (Boundary)
        run_test(-1.0);  

        $display("---------------------------------------------------------------");
        $display("ALL TESTS PASSED");
        $finish;
    end

    task run_test;
        input real val;
        reg signed [63:0] fixed_val;
        begin
            $display("[Time %t] Starting Test for Input: %f", $time, val);
            
            // Convert Real to S1.23.40
            fixed_val = val * 1099511627776.0;
            
            // Send Data
            wait(x_in_ready);
            @(posedge clk);
            x_in = fixed_val;
            x_in_valid = 1;
            @(posedge clk);
            x_in_valid = 0;
            $display("[Time %t] Input Sent. Waiting for Output...", $time);
            
            // Wait for result with TIMEOUT
            fork : wait_block
                begin
                    wait(output_valid);
                    $display("[Time %t] Output Valid Detected!", $time);
                    disable wait_block;
                end
                begin
                    #5000; // 5000ns Timeout
                    $display("[Time %t] ERROR: Timeout! Core stuck in state: %b", $time, uut.current_state);
                    $stop;
                end
            join
            
            // Display Result
            real_output = $itor(exp_out) / 1099511627776.0;
            expected_val = $exp(val);
            
            $display("Input: %f | Output: %f | Expected: %f | Error: %e", 
                     val, real_output, expected_val, real_output - expected_val);
            
            // Add a small delay between tests
            #50;
        end
    endtask

endmodule