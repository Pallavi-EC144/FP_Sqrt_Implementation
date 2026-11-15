`timescale 1ns/1ps

module tb_fp_sqrt;
    reg clk = 0;
    reg reset = 1;
    reg in_valid = 0;
    reg [31:0] a = 0;
    wire out_valid;
    wire [31:0] result;
    integer errors = 0;
    integer tests = 0;

    fp_sqrt dut (
        .clk(clk), .reset(reset), .in_valid(in_valid), .a(a),
        .out_valid(out_valid), .result(result)
    );

    always #5 clk = ~clk;

    task check;
        input [31:0] operand;
        input [31:0] expected;
        begin
            @(negedge clk);
            a = operand;
            in_valid = 1'b1;
            @(posedge clk);
            #1;
            tests = tests + 1;
            if (out_valid !== 1'b1 || result !== expected) begin
                $display("FAIL a=%08h got=%08h valid=%b expected=%08h",
                         operand, result, out_valid, expected);
                errors = errors + 1;
            end
            @(negedge clk);
            in_valid = 1'b0;
            a = 32'hdeadbeef;
            @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk); reset = 0;

        check(32'h00000000, 32'h00000000); // +0
        check(32'h80000000, 32'h80000000); // -0
        check(32'h3f800000, 32'h3f800000); // 1
        check(32'h40000000, 32'h3fb504f3); // 2
        check(32'h40800000, 32'h40000000); // 4
        check(32'h7f800000, 32'h7f800000); // +inf
        check(32'hff800000, 32'h7fc00000); // -inf
        check(32'hbf800000, 32'h7fc00000); // -1
        check(32'h7fc12345, 32'h7fc00000); // NaN
        check(32'h00000001, 32'h1a3504f3); // smallest subnormal
        check(32'h007fffff, 32'h1fffffff); // largest subnormal
        check(32'h00800000, 32'h20000000); // smallest normal

        if (errors == 0)
            $display("PASS: %0d directed tests", tests);
        else
            $display("FAIL: %0d errors in %0d tests", errors, tests);
        $finish;
    end
endmodule
