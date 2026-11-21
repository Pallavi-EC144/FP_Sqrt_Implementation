// IEEE-754 binary32 square-root unit (hierarchical RTL)
// Top module and interface remain compatible with the assignment template.
// The datapath is combinational and the result is registered on the next edge.

module fp_sqrt (
    input  logic        clk,
    input  logic        reset,
    input  logic        in_valid,
    input  logic [31:0] a,
    output logic        out_valid,
    output logic [31:0] result
);
    logic        special_valid;
    logic [31:0] special_result;
    logic [47:0] radicand;
    logic signed [31:0] adjusted_exp;
    logic [24:0] root;
    logic [25:0] remainder;
    logic [31:0] finite_result;
    logic [31:0] next_result;

    fp32_operand_prepare u_prepare (
        .x(a),
        .special_valid(special_valid),
        .special_result(special_result),
        .radicand(radicand),
        .adjusted_exp(adjusted_exp)
    );

    fp32_restoring_isqrt u_isqrt (
        .radicand(radicand),
        .root(root),
        .remainder(remainder)
    );

    fp32_round_pack u_round_pack (
        .root(root),
        .remainder(remainder),
        .adjusted_exp(adjusted_exp),
        .result(finite_result)
    );

    always_comb begin
        next_result = special_valid ? special_result : finite_result;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            result    <= 32'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid)
                result <= next_result;
        end
    end
endmodule

// Classifies IEEE-754 special values and prepares a positive finite operand.
// For finite positive x, radicand and adjusted_exp encode the normalized value.
module fp32_operand_prepare (
    input  logic [31:0] x,
    output logic       special_valid,
    output logic [31:0] special_result,
    output logic [47:0] radicand,
    output logic signed [31:0] adjusted_exp
);
    logic [7:0]  exp_field;
    logic [22:0] frac_field;
    logic [24:0] significand;
    integer shift_count;
    integer i;

    always_comb begin
        exp_field      = x[30:23];
        frac_field     = x[22:0];
        significand    = 25'b0;
        shift_count    = 0;
        adjusted_exp   = 0;
        radicand       = 48'b0;
        special_valid = 1'b0;
        special_result = 32'b0;

        if ((exp_field == 8'hff) && (frac_field != 23'b0)) begin
            special_valid  = 1'b1;
            special_result = 32'h7fc0_0000;
        end else if ((exp_field == 8'h00) && (frac_field == 23'b0)) begin
            special_valid  = 1'b1;
            special_result = {x[31], 31'b0};
        end else if (exp_field == 8'hff) begin
            special_valid = 1'b1;
            if (x[31]) special_result = 32'h7fc0_0000;
            else       special_result = 32'h7f80_0000;
        end else if (x[31]) begin
            special_valid  = 1'b1;
            special_result = 32'h7fc0_0000;
        end else begin
            if (exp_field == 8'h00) begin
                significand  = {2'b00, frac_field};
                adjusted_exp = -126;
                for (i = 0; i < 23; i = i + 1) begin
                    if (significand[23] == 1'b0) begin
                        significand = significand << 1;
                        shift_count = shift_count + 1;
                    end
                end
                adjusted_exp = adjusted_exp - shift_count;
            end else begin
                significand  = {1'b0, 1'b1, frac_field};
                adjusted_exp = $signed({1'b0, exp_field}) - 127;
            end

            if ((adjusted_exp % 2) != 0) begin
                significand  = significand << 1;
                adjusted_exp = adjusted_exp - 1;
            end
            radicand = {23'b0, significand} << 23;
        end
    end
endmodule

// 24-step unrolled restoring base-4 integer square-root datapath.
// These are combinational iterations, not 24 clock cycles.
module fp32_restoring_isqrt (
    input  logic [47:0] radicand,
    output logic [24:0] root,
    output logic [25:0] remainder
);
    logic [25:0] trial;
    integer i;

    always_comb begin
        root      = 25'b0;
        remainder = 26'b0;
        trial     = 26'b0;
        for (i = 23; i >= 0; i = i - 1) begin
            remainder = (remainder << 2) |
                        ((radicand >> (i * 2)) & 48'h3);
            trial = (root << 2) | 26'd1;
            if (remainder >= trial) begin
                remainder = remainder - trial;
                root = (root << 1) | 25'd1;
            end else begin
                root = root << 1;
            end
        end
    end
endmodule

// Rounds the integer root and packs the binary32 exponent/fraction fields.
module fp32_round_pack (
    input  logic [24:0] root,
    input  logic [25:0] remainder,
    input  logic signed [31:0] adjusted_exp,
    output logic [31:0] result
);
    logic [24:0] rounded_root;
    logic [22:0] out_fraction;
    logic [7:0] out_exponent;
    logic signed [31:0] result_exp;

    always_comb begin
        rounded_root = root;
        if (remainder > root)
            rounded_root = root + 25'd1;

        result_exp = adjusted_exp / 2;
        if (rounded_root[24]) begin
            out_fraction = 23'b0;
            result_exp = result_exp + 1;
        end else begin
            out_fraction = rounded_root[22:0];
        end
        out_exponent = result_exp + 127;
        result = {1'b0, out_exponent, out_fraction};
    end
endmodule
