module core #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
    ) (   
    input                    i_clk,
    input                    i_rst_n,
    output  [ADDR_WIDTH-1:0] o_i_addr,
    input   [INST_WIDTH-1:0] i_i_inst,
    output                   o_d_we,
    output  [ADDR_WIDTH-1:0] o_d_addr,
    output  [DATA_WIDTH-1:0] o_d_wdata,
    input   [DATA_WIDTH-1:0] i_d_rdata,
    output  [           1:0] o_status,
    output                   o_status_valid
    );
// assign output /////////////////////////////////////////////
    reg     [31:0] o_i_addr_w, o_i_addr_r, o_d_addr_r, o_d_wdata_r;
    reg     [1:0]  o_status_w, o_status_r;
    reg            o_d_we_w, o_d_we_r, o_status_valid_w, o_status_valid_r;
    assign o_i_addr = o_i_addr_r;
    assign o_d_addr = o_d_addr_r;
    assign o_d_we = o_d_we_r;
    assign o_d_wdata = o_d_wdata_r;
    assign o_status = o_status_r;
    assign o_status_valid = o_status_valid_r;
/////////////////////////////////////////////////////////////
    wire            reg_wen, I_type;
    wire    [1:0]   alu_over;
    wire    [5:0]   op;
    wire    [4:0]   s2, s3, R_s1, I_s1, reg1_addr, reg2_addr;
    wire    [15:0]  I_im;
    wire    [31:0]  reg_wdata, alu_out, o_reg1, o_reg2;
    reg     [31:0]  data_r, over_r;
    reg             reg_wen_w;
    reg     [3:0]   current_state, next_state;
    reg     [4:0]   reg1_addr_w, reg2_addr_w;
// instruction data /////////////////////////////////////////
    assign op = i_i_inst[31:26];
    assign {s2, s3, R_s1} = i_i_inst[25:11];
    assign {I_s1, I_im} = i_i_inst[20:0];
// submodule /////////////////////////////////////////////////
    assign reg_wen = reg_wen_w;
    assign reg_wdata = (op == `OP_LW) ? i_d_rdata : data_r;
    assign {reg1_addr, reg2_addr} = {reg1_addr_w, reg2_addr_w};
    reg32x32 reg_1(.clk(i_clk), .rst_n(i_rst_n), .we(reg_wen), .i_addr(reg1_addr), .i_wdata(reg_wdata), .o_rdata(o_reg1));//s2
    reg32x32 reg_2(.clk(i_clk), .rst_n(i_rst_n), .we(reg_wen), .i_addr(reg2_addr), .i_wdata(reg_wdata), .o_rdata(o_reg2));//s3 & s1
    alu a1(.data1(o_reg1), .data2(o_reg2), .im(I_im), .pc(o_i_addr_r), .opcode(op), .o_data(alu_out), .overflow(alu_over));
/////////////////////////////////////////////////////////////
    assign I_type = (op == `OP_ADDI | op == `OP_LW | op == `OP_SW | op == `OP_BEQ | op == `OP_BNE);
    always @(*) begin//state control
        case (current_state)
            `idle       : next_state = `fetch;
            `fetch      : next_state = `decode;
            `decode     : next_state = `compute;
            `compute    : next_state = (alu_over[1]) ? `process_end :
                                       (op == `OP_LW) ? `write_back : `next_pc;
            `write_back : next_state = `next_pc;
            `next_pc    : next_state = (over_r[1]) ? `process_end : `idle;
            default : next_state = current_state;
        endcase
    end
    always @(*) begin//for register & memory address, wen
        case (current_state)
            `idle : begin
                reg_wen_w = 1'b0;
                reg1_addr_w = 1'b0;
                reg2_addr_w = 1'b0;
                o_i_addr_w = o_i_addr_r;
                o_d_we_w = 1'b0;
                o_status_w = 2'b00;
                o_status_valid_w = 1'b0;
            end
            `fetch : begin
                reg_wen_w = 1'b0;
                reg1_addr_w = 1'b0;
                reg2_addr_w = 1'b0; 
                o_i_addr_w = o_i_addr_r;
                o_d_we_w = 1'b0;
                o_status_w = 2'b00;
                o_status_valid_w = 1'b0;        
            end
            `decode : begin
                reg_wen_w = 1'b0;
                reg1_addr_w = s2;
                reg2_addr_w = (I_type) ? I_s1 : s3;
                o_i_addr_w = o_i_addr_r;
                o_d_we_w = 1'b0;
                o_status_w = 2'b00;
                o_status_valid_w = 1'b0;
            end
            `compute : begin//result store in data_r
                reg_wen_w = 1'b0;
                reg1_addr_w = s2;
                reg2_addr_w = (I_type) ? I_s1 : s3;
                o_i_addr_w = o_i_addr_r;
                o_d_we_w = (op == `OP_SW) ? 1'b1 : 1'b0;
                o_status_w = (op == `OP_LW) ? 2'b00 : alu_over;
                o_status_valid_w = (op == `OP_LW) ? 1'b0 : 1'b1;       
            end
            `write_back : begin //only LW 
                reg_wen_w = 1'b0;
                reg1_addr_w = I_s1;
                reg2_addr_w = I_s1;
                o_i_addr_w = o_i_addr_r;
                o_d_we_w = 1'b0;
                o_status_w = over_r;
                o_status_valid_w = 1'b1; 
            end
            `next_pc : begin
                reg_wen_w = (op == `OP_SW | op == `OP_BEQ | op == `OP_BNE) ? 1'b0 : 1'b1;
                reg1_addr_w = (I_type) ? I_s1 : R_s1;
                reg2_addr_w = (I_type) ? I_s1 : R_s1;
                o_i_addr_w = (op == `OP_BEQ | op == `OP_BNE) ? data_r : o_i_addr_r + 32'h4;
                o_d_we_w = 1'b0;
                o_status_w = 2'b00;
                o_status_valid_w = 1'b0;
            end
            default : begin //replace idle & fetch
                reg_wen_w = 1'b0;
                reg1_addr_w = 1'b0;
                reg2_addr_w = 1'b0;
                o_i_addr_w = o_i_addr_r;
                o_d_we_w = 1'b0;
                o_status_w = 2'b00;
                o_status_valid_w = 1'b0;
            end
        endcase
    end
    always @(posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_i_addr_r <= 32'b0;
            o_d_addr_r <= 32'b0;
            o_d_we_r <= 1'b0;
            o_d_wdata_r <= 32'b0;
            o_status_r <= 2'b0;
            o_status_valid_r <= 1'b0;
            current_state <= `idle;
            data_r <= 1'b0;
            over_r <= 1'b0;
        end else begin
            o_i_addr_r <= o_i_addr_w;
            o_d_we_r <= o_d_we_w;
            o_d_addr_r <= (current_state == `compute) ? alu_out : o_d_addr_r;
            o_d_wdata_r <= o_reg2;
            o_status_r <= o_status_w;
            o_status_valid_r <= o_status_valid_w;
            current_state <= next_state;
            data_r <= (current_state == `compute) ? alu_out : data_r;
            over_r <= (current_state == `compute) ? alu_over : over_r;
        end
    end
endmodule