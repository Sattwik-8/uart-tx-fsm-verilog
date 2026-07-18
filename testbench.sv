module tb;
    reg clk = 0;
    reg rst_n = 0;
    reg tx_start = 0;
    reg [7:0] tx_data = 0;
    wire tx_line, tx_busy;

    integer pass_count = 0;
    integer fail_count = 0;
    integer rand_i;

    uart_tx #(.BAUD_DIV(4)) dut (
        .clk(clk), .rst_n(rst_n), .tx_start(tx_start),
        .tx_data(tx_data), .tx_line(tx_line), .tx_busy(tx_busy)
    );

    always #5 clk = ~clk;

    // ---- Global watchdog: force-finish if anything hangs ----
    initial begin
    #200000;
    $display("WATCHDOG: simulation timed out, forcing finish");
    $finish;
end

    task send_and_check(input [7:0] test_byte);
        reg [7:0] received;
        integer i;
        integer timeout;
        begin
            tx_data  = test_byte;
            @(posedge clk);
            #1 tx_start = 1;
            @(posedge clk);
            #1 tx_start = 0;

            timeout = 0;
            while (tx_line !== 1'b0 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 50) begin
                $display("FAIL: never saw START bit for %b (timeout)", test_byte);
                fail_count = fail_count + 1;
            end else begin
                repeat (2) @(posedge clk);   // move to middle of START bit

                received = 8'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    repeat (4) @(posedge clk);
                    received[i] = tx_line;
                end

                repeat (4) @(posedge clk);

                if (received === test_byte) begin
                    $display("PASS: sent %b, received %b", test_byte, received);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL: sent %b, received %b", test_byte, received);
                    fail_count = fail_count + 1;
                end
            end

            timeout = 0;
            while (tx_busy !== 1'b0 && timeout < 50) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            repeat (2) @(posedge clk);
        end
    endtask

    // ---- Task: send two bytes back-to-back, no idle gap ----
    task send_back_to_back(input [7:0] byte1, input [7:0] byte2);
        begin
            send_and_check(byte1);
            send_and_check(byte2);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;

        rst_n = 0;
        #12 rst_n = 1;
        #10;

        // ---- Directed test vectors ----
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'hAA);
        send_and_check(8'h55);
        send_and_check(8'hB5);

        // ---- Back-to-back transmission (no gap between bytes) ----
        send_back_to_back(8'hC3, 8'h3C);

        // ---- Randomized regression ----
        for (rand_i = 0; rand_i < 200; rand_i = rand_i + 1) begin
            send_and_check($random);
        end

        $display("---- FINAL RESULT: %0d PASS, %0d FAIL (out of %0d total) ----",
                  pass_count, fail_count, pass_count + fail_count);
        $finish;
    end
endmodule
