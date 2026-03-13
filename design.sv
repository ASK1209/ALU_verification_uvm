// Code your design here
// ============================================================
// 8-bit ALU - RTL Design
// Opcodes : 0=ADD 1=SUB 2=AND 3=OR 4=XOR 5=NOT
//           6=NAND 7=NOR 8=SHL 9=SHR
// ============================================================
module alu (
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  a,
    input  logic [7:0]  b,
    input  logic [3:0]  opcode,
    output logic [7:0]  result,
    output logic        zero_flag,
    output logic        carry_flag,
    output logic        overflow_flag
);
 
    logic [7:0]  res_comb;
    logic        carry_comb;
    logic        overflow_comb;
    logic [8:0]  temp;
 
    always_comb begin
        res_comb      = 8'b0;
        carry_comb    = 1'b0;
        overflow_comb = 1'b0;
        temp          = 9'b0;
 
        case (opcode)
            4'b0000: begin // ADD
                temp          = {1'b0, a} + {1'b0, b};
                res_comb      = temp[7:0];
                carry_comb    = temp[8];
                overflow_comb = (~a[7] & ~b[7] &  temp[7]) |
                                ( a[7] &  b[7] & ~temp[7]);
            end
            4'b0001: begin // SUB
                temp          = {1'b0, a} - {1'b0, b};
                res_comb      = temp[7:0];
                carry_comb    = temp[8];
                overflow_comb = (~a[7] &  b[7] &  temp[7]) |
                                ( a[7] & ~b[7] & ~temp[7]);
            end
            4'b0010: res_comb = a & b;          // AND
            4'b0011: res_comb = a | b;          // OR
            4'b0100: res_comb = a ^ b;          // XOR
            4'b0101: res_comb = ~a;             // NOT
            4'b0110: res_comb = ~(a & b);       // NAND
            4'b0111: res_comb = ~(a | b);       // NOR
            4'b1000: begin // SHL
                res_comb   = {a[6:0], 1'b0};
                carry_comb = a[7];
            end
            4'b1001: begin // SHR
                res_comb   = {1'b0, a[7:1]};
                carry_comb = a[0];
            end
            default: res_comb = 8'b0;
        endcase
    end
 
    always_ff @(posedge clk) begin
        if (rst) begin
            result        <= 8'b0;
            zero_flag     <= 1'b0;
            carry_flag    <= 1'b0;
            overflow_flag <= 1'b0;
        end else begin
            result        <= res_comb;
            zero_flag     <= (res_comb == 8'b0);
            carry_flag    <= carry_comb;
            overflow_flag <= overflow_comb;
        end
    end
 
endmodule