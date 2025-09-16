`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module fp_alu (
    input [31:0] a,
    input [31:0] b,
    input [2:0] selop,
    output reg [31:0] result,
    output parity,
    output overflow,output underflow
);
    wire [31:0] add_out, sub_out, mul_out, div_out;
    wire [31:0] not_out, nand_out, shr_out;
 // wire of_add, uf_add, of_sub, uf_sub, of_mul, uf_mul, of_div, uf_div;
    fp_add add_inst(.a(a), .b(b), .result(add_out),.overflow(overflow),.underflow(underflow));
    fp_sub sub_inst(.a(a), .b(b), .result(sub_out),.overflow(overflow),.underflow(underflow));
    fp_mul mul_inst(.a(a), .b(b), .result(mul_out),.overflow(overflow),.underflow(underflow));
    fp_div div_inst(.a(a), .b(b), .result(div_out),.overflow(overflow),.underflow(underflow));

    assign not_out = ~a;
    assign nand_out = ~(a & b);
    assign shr_out = a >> 1;

    assign parity = ^result;

    always @(*) begin
        case (selop)
            3'b000: result = add_out;
            3'b001: result = sub_out;
            3'b010: result = mul_out;
            3'b011: result = div_out;
            3'b100: result = not_out;
            3'b101: result = nand_out;
            3'b110: result = shr_out;
            default: result = 32'h00000000;
        endcase
    end
endmodule


module fp_add(input [31:0] a, input [31:0] b, output reg[31:0] result,output overflow,output underflow);
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] mant_a = (exp_a == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
    wire [23:0] mant_b = (exp_b == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};
    reg [7:0] exp_diff;
    reg [23:0] mantissa_a, mantissa_b;
    reg [24:0] sum;
    reg [7:0] final_exp;
    reg final_sign;

    always @(*) begin
        // Handle NaN
        if ((exp_a == 8'hFF && mant_a[22:0] != 0) || (exp_b == 8'hFF && mant_b[22:0] != 0)) begin
            result = 32'h7FC00000; // Canonical NaN
        end
        // Handle infinity + (-infinity)
        else if ((exp_a == 8'hFF && mant_a[22:0] == 0 && exp_b == 8'hFF && mant_b[22:0] == 0) && (sign_a != sign_b)) begin
            result = 32'h7FC00000; // NaN
        end
        // Normal operation
        else begin
            if (exp_a > exp_b) begin
                exp_diff = exp_a - exp_b;
                mantissa_a = mant_a;
                mantissa_b = mant_b >> exp_diff;
                final_exp = exp_a;
            end else begin
                exp_diff = exp_b - exp_a;
                mantissa_a = mant_a >> exp_diff;
                mantissa_b = mant_b;
                final_exp = exp_b;
            end

            if (sign_a == sign_b) begin
                sum = mantissa_a + mantissa_b;
                final_sign = sign_a;
            end else begin
                if (mantissa_a > mantissa_b) begin
                    sum = mantissa_a - mantissa_b;
                    final_sign = sign_a;
                end else begin
                    sum = mantissa_b - mantissa_a;
                    final_sign = sign_b;
                end
            end
end
            if (sum == 0) begin
                result = 32'h00000000; // zero
            end else begin
                while (sum[23] == 0 && final_exp > 0) begin
                    sum = sum << 1;
                    final_exp = final_exp - 1;
                end

                if (sum[24]) begin
                    sum = sum >> 1;
                    final_exp = final_exp + 1;
                end

               // Handle overflow
               // if (final_exp >= 8'hFF) begin
                    // overflow =1;
                  //  result = {final_sign, 8'hFF, 23'h0}; // Inf
               // end
                // Handle underflow
             //   else if (final_exp == 0) begin
                //underflow=1;
                  //  result = 32'h00000000; // Zero
               // end else begin
                    //result = {final_sign, final_exp, sum[22:0]};
                end
            end
                 assign overflow = (final_exp >= 8'hFF);
               assign underflow = (final_exp == 8'h00 && sum== 0);
               always@(*) begin
                result = (overflow) ? {final_sign, 8'hFF, 23'b0} : // map overflow -> Inf (simple)
                    (underflow) ? 32'b0 :
                    {final_sign, final_exp, sum[22:0]};
                    end
endmodule
module fp_sub(input [31:0] a, input [31:0] b, output [31:0] result,output overflow,output underflow);
           reg [7:0] final_exp;
    wire [31:0] b_neg = {~b[31], b[30:0]};
     //assign overflow  = (final_exp >= 8'hFF);
      //  assign underflow = (final_exp == 8'h00);
    fp_add add_sub (.a(a), .b(b_neg), .result(result),.overflow(overflow),.underflow(underflow));
endmodule
module fp_mul(input [31:0] a, input [31:0] b, output [31:0] result,output overflow,output underflow);
    wire sign = a[31] ^ b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]};
    wire [23:0] mant_b = {1'b1, b[22:0]};
    wire [47:0] product = mant_a * mant_b;
    wire [7:0] exp_out = exp_a + exp_b - 127;
    wire [22:0] mant_out;
    wire [7:0] norm_exp;
    assign {norm_exp, mant_out} = (product[47]) ?
        {exp_out + 1, product[46:24]} : {exp_out, product[45:23]};
        assign overflow  = (norm_exp >= 8'hFF);
        assign underflow = (norm_exp == 8'h00);
    assign result = {sign, norm_exp, mant_out};
endmodule
module fp_div(input [31:0] a, input [31:0] b, output [31:0] result,output overflow,output underflow);
    wire sign = a[31] ^ b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [23:0] mant_a = {1'b1, a[22:0]};
    wire [23:0] mant_b = {1'b1, b[22:0]};
    wire [47:0] quotient = (mant_a << 23) / mant_b;
    wire [7:0] exp_out = exp_a - exp_b + 127;
    reg[22:0] mant_out;
    reg [7:0] norm_exp;
  always@(*) begin
    if(b[31:0]==0) begin
    norm_exp=8'hFF;
    mant_out=0;
    end
    else if(quotient[23]) begin
      norm_exp=exp_out+1;
      mant_out=quotient[23:1];
      end
      else if(quotient[23]==0)begin
      norm_exp=exp_out;
      mant_out=quotient[22:0];
      end
   end
      
       //{exp_out + 1, quotient[23:1]} : {exp_out, quotient[22:0]};
         assign overflow  = (norm_exp >= 8'hFF);
        assign underflow = (norm_exp == 8'h00);
    assign result = {sign, norm_exp, mant_out};
endmodule
