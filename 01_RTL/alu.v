module alu (
    input [31:0] data1,
    input [31:0] data2,
    input [15:0] im,
    input [31:0] pc,
    input [5:0] opcode,
    output[31:0] o_data,
    output[1:0] overflow
    );
    reg [31:0] o_data_w;
    reg [1:0]  over_w;
    wire[31:0] data2_2s, ex_im, o_fp_add, o_fp_sub, o_fp_mul;
    wire[63:0] mult64;
    assign overflow = over_w;
    assign o_data = o_data_w;
    assign ex_im = {{16{im[15]}}, im};
    assign data2_2s = ~data2 + 1'b1;
    assign mult64 = $signed(data1) * $signed(data2);
    FP_mul fpmul(.data_1(data1), .data_2(data2), .o_data(o_fp_mul));
    FP_add fpadd(.data_1(data1), .data_2(data2), .o_data(o_fp_add));
    FP_add fpsub(.data_1(data1), .data_2({~data2[31], data2[30:0]}), .o_data(o_fp_sub));
    always @(*) begin
        case (opcode)
            `OP_ADD : begin
                o_data_w = $signed(data1) + $signed(data2);
                over_w = ((data1[31] & data2[31] & ~o_data_w[31])|(~data1[31] & ~data2[31] & o_data_w[31])) ?
                         `MIPS_OVERFLOW : `R_TYPE_SUCCESS;
            end 
            `OP_SUB : begin
                o_data_w = $signed(data1) + $signed(data2_2s);
                over_w = ((data1[31] & data2_2s[31] & ~o_data_w[31])|(~data1[31] & ~data2_2s[31] & o_data_w[31])) ?
                         `MIPS_OVERFLOW : `R_TYPE_SUCCESS;
            end
            `OP_MUL : begin
                o_data_w = mult64[31:0];
                over_w = (& mult64[63:31]) ? `R_TYPE_SUCCESS : 
                         (| mult64[63:31]) ? `MIPS_OVERFLOW : `R_TYPE_SUCCESS;
            end
            `OP_ADDI : begin
                o_data_w = $signed(data1) + $signed(ex_im);
                over_w = ((data1[31] & ex_im[31] & ~o_data_w[31])|(~data1[31] & ~ex_im[31] & o_data_w[31])) ?
                         `MIPS_OVERFLOW : `I_TYPE_SUCCESS;
            end
            `OP_LW : begin
                o_data_w = $signed(data1) + $signed(ex_im);
                over_w = (| o_data_w[31:8]) ? `MIPS_OVERFLOW : `I_TYPE_SUCCESS;
            end
            `OP_SW : begin
                o_data_w = $signed(data1) + $signed(ex_im);
                over_w = (| o_data_w[31:8]) ? `MIPS_OVERFLOW : `I_TYPE_SUCCESS;
            end
            `OP_AND : begin
                o_data_w = data1 & data2;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_OR : begin
                o_data_w = data1 | data2;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_NOR : begin
                o_data_w = ~(data1 | data2);
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_BEQ : begin
                o_data_w = (data1 == data2) ? pc + ex_im : pc + 32'h4;
                over_w = (| o_data_w[31:12]) ? `MIPS_OVERFLOW : `I_TYPE_SUCCESS;
            end
            `OP_BNE : begin
                o_data_w = (data1 == data2) ? pc + 32'h4 : pc + ex_im;
                over_w = (| o_data_w[31:12]) ? `MIPS_OVERFLOW : `I_TYPE_SUCCESS;                
            end
            `OP_SLT : begin
                o_data_w = ($signed(data1) < $signed(data2)) ? 32'h1 : 32'h0;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_FP_ADD : begin
                o_data_w = o_fp_add;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_FP_SUB : begin
                o_data_w = o_fp_sub;
                over_w = `R_TYPE_SUCCESS;              
            end
            `OP_FP_MUL : begin
                o_data_w = o_fp_mul;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_SLL : begin
                o_data_w = data1 << data2;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_SRL : begin
                o_data_w = data1 >> data2;
                over_w = `R_TYPE_SUCCESS;
            end
            `OP_EOF : begin
                o_data_w = 32'h0;
                over_w = `MIPS_END;                
            end
            default : begin
                o_data_w = 32'h0;
                over_w = `MIPS_OVERFLOW;
            end 
        endcase
    end
endmodule

module MSB (input [48:0] i_data, output [5:0] o_data);
    wire [31:0] x32;
    wire [15:0] x16;
    wire [7:0] x8;
    wire [3:0] x4;
    wire [1:0] x2;
    assign o_data[5] = | i_data[48:32];
    assign x32 = (o_data[5]) ? {17'b0, i_data[46:32]} : i_data[31:0];
    assign o_data[4] = | x32[31:16];
    assign x16 = (o_data[4]) ? x32[31:16] : x32[15:0];
    assign o_data[3] = | x16[15:8];
    assign x8 = (o_data[3]) ? x16[15:8] : x16[7:0];
    assign o_data[2] = | x8[7:4];
    assign x4 = (o_data[2]) ? x8[7:4] : x8[3:0];
    assign o_data[1] = | x4[3:2];
    assign x2 = (o_data[1]) ? x4[3:2] : x4[1:0];
    assign o_data[0] = x2[1];
endmodule

module FP_add (input [31:0] data_1, input [31:0] data_2, output [31:0] o_data);
    wire a_s, b_s, o_s;    //{a_s, a_e, a_f} & {b_s, b_e, b_f}
    wire [7:0] a_e, b_e, o_e;
    wire [22:0] a_f, b_f, o_f;
    wire [48:0] ex_af, ex_bf, ex_af_2s, ex_bf_2s, exbf_shift;//1+1+1+23+23
    wire [48:0] ex_add, ex_add_2s, add_shift;
    wire [5:0] expon_shift, normal_shift, f1;
    wire G, R, S, GRS;
    assign {a_s, a_e, a_f} = (data_1[30:23] > data_2[30:23]) ? data_1 : data_2;
    assign {b_s, b_e, b_f} = (data_1[30:23] > data_2[30:23]) ? data_2 : data_1;
    assign expon_shift = a_e - b_e;
    //{sign, carry, hidden, a_f, 23bit} 1+1+1+23+23 bits
    assign ex_af = {3'b001, a_f, 23'b0};
    assign ex_bf = {3'b001, b_f, 23'b0};
    assign exbf_shift = ex_bf >> expon_shift;
    assign ex_af_2s = (a_s) ? ~ex_af + 1'b1 : ex_af;
    assign ex_bf_2s = (b_s) ? ~exbf_shift + 1'b1 : exbf_shift;
    assign ex_add = ex_af_2s + ex_bf_2s;
    assign ex_add_2s = (ex_add[48]) ? ~ex_add + 1'b1 : ex_add;
    MSB m1 (.i_data(ex_add_2s), .o_data(f1));//get MSB
    assign normal_shift = (ex_add_2s[47]) ? 1'b0 : 6'd46 - f1;
    assign add_shift = ex_add_2s << normal_shift;
    assign G = (ex_add_2s[47]) ? add_shift[24] : add_shift[23];
    assign R = (ex_add_2s[47]) ? add_shift[23] : add_shift[22];
    assign S = (ex_add_2s[47]) ? |add_shift[22:0] : |add_shift[21:0];
    assign GRS = (R & S) | (G & R);
    assign o_s = ex_add[48];
    assign o_e = a_e + ex_add_2s[47] - normal_shift;
    assign o_f = (ex_add_2s[47]) ? add_shift[46:24] + GRS : add_shift[45:23] + GRS;
    assign o_data = {o_s, o_e, o_f};
endmodule

module FP_mul (input [31:0] data_1, input [31:0] data_2, output [31:0] o_data);
    wire G, R, S, GRS;
    wire a_s, b_s, o_s;
    wire [7:0] a_e, b_e, o_e;
    wire [22:0] a_f, b_f, ab_f_round;
    wire [47:0] ab_f;
    assign GRS = (R & S) | (G & R);
    assign {a_s, a_e, a_f} = data_1;
    assign {b_s, b_e, b_f} = data_2;
    assign ab_f = {1'b1, a_f} * {1'b1, b_f};//2Q46
    assign {G, R, S} = (ab_f[47]) ? {ab_f[24:23], |ab_f[22:0]} : {ab_f[23:22], |ab_f[21:0]};
    assign ab_f_round = (ab_f[47]) ? ab_f[46:24] + GRS : ab_f[45:23] + GRS;
    assign o_s = a_s ^ b_s;
    assign o_e = a_e + b_e + 8'd129 + ab_f[47];
    assign o_data = {o_s, o_e, ab_f_round};
endmodule