`include "riscv-defines.v"

module id (
	input wire rst,
	input wire[31:0] inst,

	input wire[63:0] reg1_data,
	input wire[63:0] reg2_data,

	output reg reg1_read_enable,
	output reg reg2_read_enable,
	output reg[4:0] reg1_addr,
	output reg[4:0] reg2_addr,

	/* request stall */
	output reg stall,

	/* forwarding logic */
	input wire reg_wr_enable_ex,
	input wire[4:0] reg_wr_addr_ex,
	input wire[63:0] reg_wr_data_ex,
	input wire reg_wr_enable_mem,
	input wire[4:0] reg_wr_addr_mem,
	input wire[63:0] reg_wr_data_mem,

	output reg[7:0] aluop_o,
	output reg[3:0] alusel_o,
	output reg[63:0] oprand1,
	output reg[63:0] oprand2,
	output reg[4:0] reg_write_addr_o,
	output reg reg_write_enable_o,
	output reg mem_valid,
	output reg mem_rw,
	output reg[63:0] mem_data,
	output reg[7:0] mem_data_byte_valid
);

	wire [6:0] opcode = inst[6:0];             /* common */
	wire [4:0] rd = inst[11:7];                /* R/I/U/J-type */
	wire [2:0] funct3 = inst[14:12];           /* R/I/S/B-type */
	wire [4:0] rs1 = inst[19:15];              /* R/I/S/B-type */
	wire [4:0] rs2 = inst[25:20];              /* R/S/B-type */
	wire [6:0] funct7 = inst[31:26];           /* R-type */
	
	
	reg [63:0] imm;

	always @ (*) begin
		if (rst == 1'b1) begin
			aluop_o <= 8'b0;
			alusel_o <= 4'b0;
			reg_write_addr_o <= 5'b0;
			reg_write_enable_o <= 1'b0;
			reg1_read_enable <= 1'b0;
			reg2_read_enable <= 1'b0;
			reg1_addr <= 5'b0;
			reg2_addr <= 5'b0;
			imm <= 64'b0;
			stall <= 1'b0;
			mem_valid <= 1'b0;
		    mem_rw <= 1'b0;
		    oprand1 <= 64'b0;
			oprand2 <= 64'b0;
		end else begin
			case (opcode)
                /* R-type */
				`RISCV_OPCODE_OP: begin
					reg1_read_enable <= 1'b1;
					reg2_read_enable <= 1'b1;
					reg_write_enable_o <= 1'b1;
					alusel_o <= {funct7[5], funct3[2:0]};
					if (reg_wr_enable_ex == 1'b1 && rs1 == reg_wr_addr_ex) begin
						oprand1 <= reg_wr_data_ex;
					end else if (reg_wr_enable_mem == 1'b1 && rs1 == reg_wr_addr_mem) begin
						oprand1 <= reg_wr_data_mem;
					end else begin
						reg1_addr <= rs1;
						oprand1 <= reg1_data;
					end

					if (reg_wr_enable_ex == 1'b1 && rs2 == reg_wr_addr_ex) begin
						oprand2 <= reg_wr_data_ex;
					end else if (reg_wr_enable_mem == 1'b1 && rs2 == reg_wr_addr_mem) begin
						oprand2 <= reg_wr_data_mem;
					end else begin
						reg2_addr <= rs2;
						oprand2 <= reg2_data;
					end

					reg_write_addr_o <= rd;
					
					mem_valid <= 1'b0;
				    mem_rw <= 1'b0;
				    mem_data_byte_valid <= 8'b0;

				end
				/* U-type */
				`RISCV_OPCODE_LUI: begin
					alusel_o <= 5'b0;
					reg1_read_enable <= 1'b0;
					reg2_read_enable <= 1'b0;
					oprand1 <= inst[31:12];
					oprand2 <= 64'b0;
					reg_write_addr_o <= rd;
					
					mem_valid <= 1'b0;
				    mem_rw <= 1'b0;
				    mem_data_byte_valid <= 8'b0;

				end
				/* I-type */
				`RISCV_OPCODE_OP_IMM: begin
				    reg1_read_enable <= 1'b1;
					reg2_read_enable <= 1'b0;
					reg_write_enable_o <= 1'b1;
					alusel_o <= {1'b0, funct3[2:0]};
					if (reg_wr_enable_ex == 1'b1 && rs1 == reg_wr_addr_ex) begin
						oprand1 <= reg_wr_data_ex;
					end else if (reg_wr_enable_mem == 1'b1 && rs1 == reg_wr_addr_mem) begin
						oprand1 <= reg_wr_data_mem;
					end else begin
						reg1_addr <= rs1;
						oprand1 <= reg1_data;
					end
                    /* sign extended immediate */
					oprand2 <= {{52{inst[31]}}, inst[31:20]};
					reg_write_addr_o <= rd;
					
					mem_valid <= 1'b0;
				    mem_rw <= 1'b0;
				    mem_data_byte_valid <= 8'b0;

				end
				`RISCV_OPCODE_STORE: begin
			        reg1_read_enable <= 1'b1;
					reg2_read_enable <= 1'b1;
					reg_write_enable_o <= 1'b0;
					alusel_o <= 3'b0;
					
					if (reg_wr_enable_ex == 1'b1 && rs1 == reg_wr_addr_ex) begin
						oprand1 <= reg_wr_data_ex;
					end else if (reg_wr_enable_mem == 1'b1 && rs1 == reg_wr_addr_mem) begin
						oprand1 <= reg_wr_data_mem;
					end else begin
						reg1_addr <= rs1;
						oprand1 <= reg1_data;
					end
					
					if (reg_wr_enable_ex == 1'b1 && rs2 == reg_wr_addr_ex) begin
						mem_data <= reg_wr_data_ex;
					end else if (reg_wr_enable_mem == 1'b1 && rs2 == reg_wr_addr_mem) begin
						mem_data <= reg_wr_data_mem;
					end else begin
						reg2_addr <= rs2;
						mem_data <= reg2_data;
					end

				    mem_valid <= 1'b1;
				    mem_rw <= 1'b1;
				    case (funct3)
				        3'b000: begin
				            mem_data_byte_valid = 8'b00000001;
				        end
				        3'b001:begin
				            mem_data_byte_valid = 8'b00000011;
				        end
				        3'b010:begin
				            mem_data_byte_valid = 8'b00001111;
				        end
				        3'b011:begin
				            mem_data_byte_valid = 8'b11111111;
				        end
				        default:begin
				            mem_data_byte_valid = 8'b00000001;
				        end
				    endcase

				    oprand2 <= {{52{inst[31]}}, inst[31:25], inst[11:7]};
				end
				
				`RISCV_OPCODE_LOAD: begin
			        reg1_read_enable <= 1'b1;
					reg2_read_enable <= 1'b0;
					reg_write_enable_o <= 1'b1;
					alusel_o <= 3'b0;
					
					if (reg_wr_enable_ex == 1'b1 && rs1 == reg_wr_addr_ex) begin
						oprand1 <= reg_wr_data_ex;
					end else if (reg_wr_enable_mem == 1'b1 && rs1 == reg_wr_addr_mem) begin
						oprand1 <= reg_wr_data_mem;
					end else begin
						reg1_addr <= rs1;
						oprand1 <= reg1_data;
					end
					
				    mem_valid <= 1'b1;
				    mem_rw <= 1'b0;
				    case (funct3)
				        3'b000: begin
				            mem_data_byte_valid = 8'b00000001;
				        end
				        3'b001:begin
				            mem_data_byte_valid = 8'b00000011;
				        end
				        3'b010:begin
				            mem_data_byte_valid = 8'b00001111;
				        end
				        3'b011:begin
				            mem_data_byte_valid = 8'b11111111;
				        end
				        default:begin
				            mem_data_byte_valid = 8'b00000001;
				        end
				    endcase
				    oprand2 <= {{52{inst[31]}}, inst[31:25], inst[11:7]};
				end
				default: begin
				    // invalid instruction exception
				end
			endcase
		end	
	end

endmodule
