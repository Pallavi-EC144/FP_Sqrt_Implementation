// IEEE-754 binary32 square-root unit
// Round-to-nearest, ties-to-even. The result of sqrt for a positive
// finite binary32 input is always normal, so the final significand is
// rounded directly to 24 bits. Subnormal inputs are normalized first.

module fp_sqrt (
    input  logic        clk,
    input  logic        reset,
    input  logic        in_valid,
    input  logic [31:0] a,
    output logic        out_valid,
    output logic [31:0] result
);

    // Returns the correctly rounded binary32 square root.
    function automatic [31:0] sqrt_binary32(input [31:0] x);
        reg [7:0]  exp_field;
        reg [22:0] frac_field;
        reg [24:0] significand;
        reg [47:0] radicand;
        reg [25:0] remainder;
        reg [25:0] trial;
        reg [24:0] root;
        reg [24:0] rounded_root;
        reg [22:0] out_fraction;
        reg [7:0]  out_exponent;
        integer    unbiased_exp;
        integer    shift_count;
        integer    i;
        begin
            exp_field = x[30:23];
            frac_field = x[22:0];

            // NaNs are canonicalized, regardless of sign or payload.
            if ((exp_field == 8'hff) && (frac_field != 23'b0)) begin
                sqrt_binary32 = 32'h7fc0_0000;
            end
            // Preserve the sign of either zero.
            else if ((exp_field == 8'h00) && (frac_field == 23'b0)) begin
                sqrt_binary32 = {x[31], 31'b0};
            end
            // Positive infinity is unchanged; negative infinity is invalid.
            else if (exp_field == 8'hff) begin
                if (x[31])
                    sqrt_binary32 = 32'h7fc0_0000;
                else
                    sqrt_binary32 = 32'h7f80_0000;
            end
            // Every other negative number is invalid.
            else if (x[31]) begin
                sqrt_binary32 = 32'h7fc0_0000;
            end
            else begin
                // Convert the operand to a 24-bit normalized significand:
                // value = (significand / 2^23) * 2^unbiased_exp.
                if (exp_field == 8'h00) begin
                    significand = {2'b00, frac_field};
                    unbiased_exp = -126;
                    shift_count = 0;
                    for (i = 0; i < 23; i = i + 1) begin
                        if (significand[23] == 1'b0) begin
                            significand = significand << 1;
                            shift_count = shift_count + 1;
                        end
                    end
                    unbiased_exp = unbiased_exp - shift_count;
                end
                else begin
                    significand = {1'b0, 1'b1, frac_field};
                    unbiased_exp = exp_field - 127;
                end

                // Make the exponent even. Doubling the significand preserves
                // the represented value while allowing an integer square root.
                if (unbiased_exp % 2 != 0) begin
                    significand = significand << 1;
                    unbiased_exp = unbiased_exp - 1;
                end

                // sqrt(value) * 2^23 = sqrt(significand * 2^23).
                radicand = {23'b0, significand} << 23;

                // Restoring base-4 integer square root. After 24 iterations,
                // root=floor(sqrt(radicand)) and remainder=radicand-root^2.
                root = 25'b0;
                remainder = 26'b0;
                for (i = 23; i >= 0; i = i - 1) begin
                    remainder = (remainder << 2) |
                                ((radicand >> (i * 2)) & 48'h3);
                    trial = ({1'b0, root} << 2) | 26'd1;
                    if (remainder >= trial) begin
                        remainder = remainder - trial;
                        root = (root << 1) | 25'd1;
                    end
                    else begin
                        root = root << 1;
                    end
                end

                // Compare sqrt(N) with root+0.5 without floating point:
                // round up iff N-root^2 > root. An integer N can never be
                // exactly at the half-way point for this comparison.
                rounded_root = root;
                if (remainder > root)
                    rounded_root = root + 25'd1;

                // The unrounded root is in [2^23, 2^24). Rounding can
                // produce 2^24, requiring a one-bit renormalization.
                if (rounded_root[24]) begin
                    out_fraction = 23'b0;
                    unbiased_exp = (unbiased_exp / 2) + 1;
                end
                else begin
                    out_fraction = rounded_root[22:0];
                    unbiased_exp = unbiased_exp / 2;
                end

                out_exponent = unbiased_exp + 127;
                sqrt_binary32 = {1'b0, out_exponent, out_fraction};
            end
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            result    <= 32'b0;
        end
        else begin
            out_valid <= in_valid;
            if (in_valid)
                result <= sqrt_binary32(a);
        end
    end

endmodule

