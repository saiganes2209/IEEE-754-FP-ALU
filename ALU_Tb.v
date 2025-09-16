module tb_fp_alu;
    reg [31:0] a, b;
    reg [2:0] selop;
    wire [31:0] result;
    wire parity,overflow,underflow;

    fp_alu uut (.a(a), .b(b), .selop(selop), .result(result), .parity(parity),.overflow(overflow), .underflow(underflow));

    initial begin
        $dumpfile("fp_alu.vcd");
        $dumpvars(0, tb_fp_alu);

        a = 32'h40400000; // 3.0
        b = 32'h40000000; // 2.0

        selop = 3'b000; #10;
        selop = 3'b001; #10;
        selop = 3'b010; #10;
        selop = 3'b011; #10;
        selop = 3'b100; #10;
        selop = 3'b101; #10;
        selop = 3'b110; #10;

        $finish;
    end
endmodule
