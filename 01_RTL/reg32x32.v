module reg32x32 (
    input clk, 
    input rst_n,
    input we,
    input [4:0] i_addr,
    input [31:0] i_wdata,
    output[31:0] o_rdata
    );
    integer i;
    reg [31:0] reg32_w[31:0], reg32_r[31:0];
    assign o_rdata = reg32_r[i_addr];
    always @(*) begin
        for (i = 0;i < 32;i = i + 1) reg32_w[i] = (we == 1 & i == i_addr) ? i_wdata : reg32_r[i];
    end
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) for (i = 0;i < 32;i = i + 1) reg32_r[i] <= 32'b0;
        else for (i = 0;i < 32;i = i + 1) reg32_r[i] <= reg32_w[i];
    end
endmodule