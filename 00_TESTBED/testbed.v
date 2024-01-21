`timescale 1ns/100ps
`define CYCLE       10.0
`define HCYCLE      (`CYCLE/2)
`define MAX_CYCLE   120000

`ifdef p0
	`define Inst "../00_TESTBED/PATTERN/p0/inst.dat"
	`define Data "../00_TESTBED/PATTERN/p0/data.dat"
	`define Status "../00_TESTBED/PATTERN/p0/status.dat"
`elsif p1
`define Inst "../00_TESTBED/PATTERN/p1/inst.dat"
	`define Data "../00_TESTBED/PATTERN/p1/data.dat"
	`define Status "../00_TESTBED/PATTERN/p1/status.dat"
`endif
       module testbed;

         wire dmem_we, mips_status_valid;
         wire [ 31 : 0 ] imem_addr;
         wire [ 31 : 0 ] imem_inst;
         wire [ 31 : 0 ] dmem_addr;
         wire [ 31 : 0 ] dmem_wdata;
         wire [ 31 : 0 ] dmem_rdata;
         wire [  1 : 0 ] mips_status;
         reg clk, rst_n, jump;
         reg [1:0] golden_status[0:1023], output_status[0:1023];
         reg [31:0] golden_data[0:63], output_data[0:63];
         integer i, j, error_data, error_status;

         initial
         begin
           $readmemb (`Inst, u_inst_mem.mem_r);
           $readmemb (`Data, golden_data);
           $readmemb (`Status, golden_status);
         end
         core u_core (
                .i_clk(clk),
                .i_rst_n(rst_n),
                .o_i_addr(imem_addr),
                .i_i_inst(imem_inst),
                .o_d_we(dmem_we),
                .o_d_addr(dmem_addr),
                .o_d_wdata(dmem_wdata),
                .i_d_rdata(dmem_rdata),
                .o_status(mips_status),
                .o_status_valid(mips_status_valid)
              );
         inst_mem  u_inst_mem (
                     .i_clk(clk),
                     .i_rst_n(rst_n),
                     .i_addr(imem_addr),
                     .o_inst(imem_inst)
                   );
         data_mem  u_data_mem (
                     .i_clk(clk),
                     .i_rst_n(rst_n),
                     .i_we(dmem_we),
                     .i_addr(dmem_addr),
                     .i_wdata(dmem_wdata),
                     .o_rdata(dmem_rdata)
                   );
         initial
           clk=0;
         always #(`CYCLE/2) clk=~clk;

         initial
         begin
           $fsdbDumpfile("MIPS.fsdb");
           $fsdbDumpvars(0, "+mda");
         end

         initial
         begin
           i=0;
           rst_n = 1;
           error_data = 0;
           error_status = 0;
           jump=0;
           reset;

           while (i < 1024 && jump == 0)
           begin
             @(negedge clk)
              if(mips_status_valid ==1)
              begin
                output_status[i] = mips_status;
                if(mips_status == 2'd2 || mips_status == 2'd3 )
                  jump = 1;
                i=i+1;
              end
            end

            for (j=0; j<i ; j=j+1)
            begin
              if(golden_status[j] != output_status[j])
              begin
                error_status = error_status + 1;
                $display ("Status[%d]: ERROR! golden=%b, yours=%b",
                          j,golden_status[j],output_status[j]
                         );
              end
            end

            for (j=0; j<64 ; j=j+1)
            begin
              if (golden_data[j] != u_data_mem.mem_r[j])
              begin
                error_data = error_data +1;
                $display ("DATA[%d]: ERROR! golden=%b, yours=%b",
                          j,golden_data[j],u_data_mem.mem_r[j]
                         );
              end
            end
            if (error_data == 0 && error_status == 0)
            begin
              $display("----------------------------------------------");
              $display("-                 ALL PASS!                  -");
              $display("----------------------------------------------");
            end
            $finish;
         end

         initial
         begin
           # (`MAX_CYCLE * `CYCLE);
           $display("----------------------------------------------");
           $display("Latency of your design is over 120000 cycles!!");
           $display("----------------------------------------------");
           $finish;
         end

         task reset;
           begin
             # ( 0.5 * `CYCLE);
             rst_n = 0;
             # (3 * `CYCLE);
             @(negedge clk)
              rst_n = 1;
           end
         endtask

       endmodule



