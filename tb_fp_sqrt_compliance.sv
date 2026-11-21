`timescale 1ns/1ps
module tb_fp_sqrt_compliance;
  reg clk=0, reset=1, in_valid=0;
  reg [31:0] a=0;
  wire out_valid;
  wire [31:0] result;
  integer fd, rc, tests=0, errors=0;
  reg [31:0] operand, expected;
  fp_sqrt dut(.clk(clk),.reset(reset),.in_valid(in_valid),.a(a),.out_valid(out_valid),.result(result));
  always #5 clk=~clk;
  initial begin
    fd=$fopen("vectors.txt","r");
    if(fd==0) begin $display("ERROR: cannot open vectors.txt"); $finish; end
    repeat(3) @(posedge clk);
    @(negedge clk); reset=0;
    while (!$feof(fd)) begin
      rc=$fscanf(fd,"%h %h\n",operand,expected);
      if(rc==2) begin
        @(negedge clk); a=operand; in_valid=1;
        @(posedge clk); #1;
        tests=tests+1;
        if(out_valid!==1'b1 || result!==expected) begin
          if(errors<30) $display("FAIL test=%0d input=%08h got=%08h valid=%b expected=%08h",tests,operand,result,out_valid,expected);
          errors=errors+1;
        end
        @(negedge clk); in_valid=0; a=32'hDEADBEEF;
        @(posedge clk); #1;
        if(out_valid!==1'b0) begin
          if(errors<30) $display("FAIL out_valid not pulsed low after test %0d",tests);
          errors=errors+1;
        end
      end
    end
    $fclose(fd);
    if(errors==0) $display("COMPLIANCE PASS: %0d vectors",tests);
    else $display("COMPLIANCE FAIL: %0d errors across %0d vectors",errors,tests);
    $finish;
  end
endmodule
