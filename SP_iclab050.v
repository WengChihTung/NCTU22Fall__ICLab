// synopsys translate_off 
`ifdef RTL
`include "GATED_OR.v"
`else
`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on


module SP(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	in_data,
	in_mode,
	// Output signals
	out_valid,
	out_data
);

// INPUT AND OUTPUT DECLARATION  
input		clk;
input		rst_n;
input		in_valid;
input		cg_en;
input [8:0] in_data;
input [2:0] in_mode;

output reg 		  out_valid;
output reg signed[9:0] out_data;

//////////// PARAMETER /////////////

parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter CAL = 2'd3;
parameter OUTPUT = 2'd2;

//////////// reg ////////////////

reg[1:0] c_state, n_state;

wire clk_data;
wire clk_output;
wire clk_input;
reg sleep_data;
reg sleep_output;
reg sleep_input;

reg[3:0] input_counter;
reg[2:0] which_mode;
wire[8:0] gray_out;
wire signed[9:0] gray_code;
reg signed[9:0] max_in;
reg signed[9:0] min_in;
reg signed[9:0] the_data[8:0];
wire signed[9:0] fuckin_data;

reg cal_counter;
wire signed[9:0] difference;
wire signed[9:0] midpoint;
reg signed[9:0] half[8:0];
wire signed[9:0] SMA[8:0];

reg[1:0] out_counter;
wire signed[9:0] cmp1[17:0];
wire signed[9:0] median1[8:0];
wire signed[9:0] cmp2[17:0];
wire signed[9:0] median2[8:0];
wire signed[9:0] cmp3[5:0];
wire signed[9:0] final_data[2:0];
reg signed[9:0] mid_out;
reg signed[9:0] min_out;
reg signed[9:0] fake_out_data;

///////////////// FSM /////////////////

// c_state
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) c_state <= IDLE;
	else c_state <= n_state;
end

// n_state
always@(*) begin 
	case(c_state)
		IDLE: begin 
			if(in_valid) n_state = INPUT;
			else n_state = c_state;
		end
		INPUT: begin 
			if(!in_valid && which_mode != 0) n_state = CAL;
			else if(!in_valid) n_state = OUTPUT;
			else n_state = c_state;
		end
		CAL: begin 
			if(which_mode == 0) n_state = OUTPUT;
			else n_state = c_state;
		end
		OUTPUT: begin 
			if(out_counter == 3) n_state = IDLE;
			else n_state = c_state;
		end
	endcase
end

///////////////////// GATE ////////////////////////

GATED_OR GATED_data(.CLOCK(clk), .SLEEP_CTRL(sleep_data), .RST_N(rst_n), .CLOCK_GATED(clk_data));
GATED_OR GATED_output(.CLOCK(clk), .SLEEP_CTRL(sleep_output), .RST_N(rst_n), .CLOCK_GATED(clk_output));
GATED_OR GATED_input(.CLOCK(clk), .SLEEP_CTRL(sleep_input), .RST_N(rst_n), .CLOCK_GATED(clk_input));

// sleep_data
always@(*) begin
	if(cg_en) begin
		case(n_state)
			IDLE: sleep_data = 1;
			OUTPUT: sleep_data = 1;
			default: sleep_data = 0;
		endcase
	end
	else sleep_data = 0;
end

// sleep_output
always@(*) begin 
	if(cg_en) begin 
		case(n_state)
			OUTPUT: sleep_output = 1;
			default: sleep_output = 0;
		endcase
	end
	else sleep_output = 0;
end

// sleep_input
always@(*) begin 
	if(cg_en && (n_state != OUTPUT && n_state != CAL && (n_state != INPUT || input_counter < 8))) sleep_input = 1;
	else sleep_input = 0;
end

///////////////////// INPUT ////////////////////////

assign fuckin_data[8:0] = in_data;
assign fuckin_data[9] = fuckin_data[8];

// input_counter
always@(posedge clk_output or negedge rst_n) begin 
	if(!rst_n) input_counter <= 4'b0;
	else begin 
		case(n_state)
			IDLE: input_counter <= 4'b0;
			INPUT: input_counter <= input_counter + 4'b1;
			OUTPUT: input_counter <= 4'b0;
		endcase
	end
end

// which_mode
always@(posedge clk_output or negedge rst_n) begin 
	if(!rst_n) which_mode <= 3'b0;
	else begin 
		case(n_state)
			INPUT: begin 
				if(c_state != INPUT) which_mode <= in_mode;
				else if(input_counter == 8) which_mode <= which_mode >> 1;
			end
			CAL: begin 
				if(which_mode == 3'b011) which_mode <= 3'b001;
				else which_mode <= 3'b0;
			end
			OUTPUT: which_mode <= 3'b0;
		endcase
	end
end

genvar i;
generate
	for(i = 1; i < 9; i = i + 1) begin 
		// the_data
		always@(posedge clk_data or negedge rst_n) begin 
			if(!rst_n) the_data[i] <= 10'b0;
			else begin 
				case(n_state)
					IDLE: the_data[i] <= ~the_data[i];
					INPUT: begin
						if(input_counter == i) begin 
							if(which_mode[0]) the_data[i] <= gray_code;
							else the_data[i] <= fuckin_data;
						end
					end
					CAL: begin 
						if(cal_counter == 0 && which_mode[0] == 1) the_data[i] <= half[i];
						else the_data[i] <= SMA[i];
					end
					OUTPUT: if(c_state == OUTPUT) the_data[i] <= ~the_data[i];
				endcase
			end
		end
	end
endgenerate
		
always@(posedge clk_output or negedge rst_n) begin 
	if(!rst_n) the_data[0] <= 10'b0;
	else begin 
		case(n_state)
			INPUT: begin
				if(c_state != INPUT) begin 
					if(in_mode[0]) the_data[0] <= gray_code;
					else the_data[0] <= fuckin_data;
				end
			end
			CAL: begin 
				if(cal_counter == 0 && which_mode[0] == 1) the_data[0] <= half[0];
				else the_data[0] <= SMA[0];
			end
			OUTPUT: if(c_state == OUTPUT) the_data[0] <= 10'b0;
		endcase
	end
end

assign gray_out[8] = in_data[8];
assign gray_out[7] = in_data[7];
assign gray_out[6] = gray_out[7] ^ in_data[6];
assign gray_out[5] = gray_out[6] ^ in_data[5];
assign gray_out[4] = gray_out[5] ^ in_data[4];
assign gray_out[3] = gray_out[4] ^ in_data[3];
assign gray_out[2] = gray_out[3] ^ in_data[2];
assign gray_out[1] = gray_out[2] ^ in_data[1];
assign gray_out[0] = gray_out[1] ^ in_data[0];

assign gray_code[8:0] = (gray_out[8])? ~gray_out + 9'h101 : gray_out;
assign gray_code[9] = gray_code[8];

// max_in
always@(posedge clk_output or negedge rst_n) begin 
	if(!rst_n) max_in <= 10'b0;
	else begin 
		case(n_state)
			INPUT: begin 
				if(c_state != INPUT) begin 
					if(in_mode[0] == 1) max_in <= gray_code;
					else max_in <= fuckin_data;
				end
				else begin 
					if(which_mode[0] == 1 && gray_code > max_in) max_in <= gray_code;
					else if(which_mode[0] == 0 && fuckin_data > max_in) max_in <= fuckin_data;
				end
			end 
			CAL: max_in <= max_in;
			OUTPUT: max_in <= 10'b0;
		endcase
	end
end

// min_in
always@(posedge clk_output or negedge rst_n) begin 
	if(!rst_n) min_in <= 10'b0;
	else begin 
		case(n_state)
			INPUT: begin 
				if(c_state != INPUT) begin 
					if(in_mode[0] == 1) min_in <= gray_code;
					else min_in <= fuckin_data;
				end
				else begin 
					if(which_mode[0] == 1 && gray_code < min_in) min_in <= gray_code;
					else if(which_mode[0] == 0 && fuckin_data < min_in) min_in <= fuckin_data;
				end
			end 
			CAL: min_in <= min_in;
			OUTPUT: min_in <= 10'b0;
		endcase
	end
end

///////////////////// CAL /////////////////////

// cal_counter
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) cal_counter <= 1'b0;
	else if(n_state == CAL) cal_counter <= cal_counter + 1'b1;
	else if(n_state == INPUT && input_counter == 8) cal_counter <= 1'b0;
end

assign difference = (max_in - min_in) / 2;
assign midpoint = (max_in + min_in) / 2;

genvar j;
generate
	for(j = 0; j < 9; j = j + 1) begin 
		// half
		always@(*) begin 
			if(the_data[j] > midpoint) half[j] = the_data[j] - difference;
			else if(the_data[j] < midpoint) half[j] = the_data[j] + difference;
			else half[j] = the_data[j];
		end
	end
endgenerate

assign SMA[0] = (the_data[8] + the_data[0] + the_data[1]) / 3;
assign SMA[1] = (the_data[0] + the_data[1] + the_data[2]) / 3;
assign SMA[2] = (the_data[1] + the_data[2] + the_data[3]) / 3;
assign SMA[3] = (the_data[2] + the_data[3] + the_data[4]) / 3;
assign SMA[4] = (the_data[3] + the_data[4] + the_data[5]) / 3;
assign SMA[5] = (the_data[4] + the_data[5] + the_data[6]) / 3;
assign SMA[6] = (the_data[5] + the_data[6] + the_data[7]) / 3;
assign SMA[7] = (the_data[6] + the_data[7] + the_data[8]) / 3;
assign SMA[8] = (the_data[7] + the_data[8] + the_data[0]) / 3;

///////////////////// OUTPUT /////////////////////////

assign cmp1[0] = (the_data[0] < the_data[1])? the_data[0] : the_data[1];
assign cmp1[1] = (the_data[0] < the_data[1])? the_data[1] : the_data[0];
assign cmp1[2] = (cmp1[0] < the_data[2])? cmp1[0] : the_data[2];
assign cmp1[3] = (cmp1[0] < the_data[2])? the_data[2] : cmp1[0];
assign cmp1[4] = (cmp1[1] < cmp1[3])? cmp1[1] : cmp1[3];
assign cmp1[5] = (cmp1[1] < cmp1[3])? cmp1[3] : cmp1[1];
assign median1[0] = cmp1[2];
assign median1[3] = cmp1[4];
assign median1[6] = cmp1[5];

assign cmp1[6] = (the_data[3] < the_data[4])? the_data[3] : the_data[4];
assign cmp1[7] = (the_data[3] < the_data[4])? the_data[4] : the_data[3];
assign cmp1[8] = (cmp1[6] < the_data[5])? cmp1[6] : the_data[5];
assign cmp1[9] = (cmp1[6] < the_data[5])? the_data[5] : cmp1[6];
assign cmp1[10] = (cmp1[7] < cmp1[9])? cmp1[7] : cmp1[9];
assign cmp1[11] = (cmp1[7] < cmp1[9])? cmp1[9] : cmp1[7];
assign median1[1] = cmp1[8];
assign median1[4] = cmp1[10];
assign median1[7] = cmp1[11];

assign cmp1[12] = (the_data[6] < the_data[7])? the_data[6] : the_data[7];
assign cmp1[13] = (the_data[6] < the_data[7])? the_data[7] : the_data[6];
assign cmp1[14] = (cmp1[12] < the_data[8])? cmp1[12] : the_data[8];
assign cmp1[15] = (cmp1[12] < the_data[8])? the_data[8] : cmp1[12];
assign cmp1[16] = (cmp1[13] < cmp1[15])? cmp1[13] : cmp1[15];
assign cmp1[17] = (cmp1[13] < cmp1[15])? cmp1[15] : cmp1[13];
assign median1[2] = cmp1[14];
assign median1[5] = cmp1[16];
assign median1[8] = cmp1[17];  

assign cmp2[0] = (median1[0] < median1[1])? median1[0] : median1[1];
assign cmp2[1] = (median1[0] < median1[1])? median1[1] : median1[0];
assign cmp2[2] = (cmp2[0] < median1[2])? cmp2[0] : median1[2];
assign cmp2[3] = (cmp2[0] < median1[2])? median1[2] : cmp2[0];
assign cmp2[4] = (cmp2[1] < cmp2[3])? cmp2[1] : cmp2[3];
assign cmp2[5] = (cmp2[1] < cmp2[3])? cmp2[3] : cmp2[1];
assign median2[0] = cmp2[2];
assign median2[3] = cmp2[4];
assign median2[6] = cmp2[5];

assign cmp2[6] = (median1[3] < median1[4])? median1[3] : median1[4];
assign cmp2[7] = (median1[3] < median1[4])? median1[4] : median1[3];
assign cmp2[8] = (cmp2[6] < median1[5])? cmp2[6] : median1[5];
assign cmp2[9] = (cmp2[6] < median1[5])? median1[5] : cmp2[6];
assign cmp2[10] = (cmp2[7] < cmp2[9])? cmp2[7] : cmp2[9];
assign cmp2[11] = (cmp2[7] < cmp2[9])? cmp2[9] : cmp2[7];
assign median2[1] = cmp2[8];
assign median2[4] = cmp2[10];
assign median2[7] = cmp2[11];

assign cmp2[12] = (median1[6] < median1[7])? median1[6] : median1[7];
assign cmp2[13] = (median1[6] < median1[7])? median1[7] : median1[6];
assign cmp2[14] = (cmp2[12] < median1[8])? cmp2[12] : median1[8];
assign cmp2[15] = (cmp2[12] < median1[8])? median1[8] : cmp2[12];
assign cmp2[16] = (cmp2[13] < cmp2[15])? cmp2[13] : cmp2[15];
assign cmp2[17] = (cmp2[13] < cmp2[15])? cmp2[15] : cmp2[13];
assign median2[2] = cmp2[14];
assign median2[5] = cmp2[16];
assign median2[8] = cmp2[17];  

assign cmp3[0] = (median2[2] < median2[4])? median2[2] : median2[4];
assign cmp3[1] = (median2[2] < median2[4])? median2[4] : median2[2];
assign cmp3[3] = (cmp3[0] < median2[6])? median2[6] : cmp3[0];
assign cmp3[4] = (cmp3[1] < cmp3[3])? cmp3[1] : cmp3[3];
assign final_data[1] = cmp3[4];

// out_counter
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) out_counter <= 2'b0;
	else if(n_state == OUTPUT) out_counter <= out_counter + 2'b1;
	else if(n_state == INPUT && input_counter == 8) out_counter <= 2'b0;
	else if(n_state == CAL) out_counter <= 2'b0;
end

// out_valid
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) out_valid <= 1'b0;
	else if(n_state == OUTPUT) out_valid <= 1'b1;
	else out_valid <= 1'b0;
end

// mid_out
always@(posedge clk_input or negedge rst_n) begin 
	if(!rst_n) mid_out <= 10'b0;
	else if(n_state == OUTPUT && c_state != OUTPUT) mid_out <= final_data[1];
	else if(n_state != OUTPUT && n_state != CAL && (n_state != INPUT || input_counter < 8)) mid_out <= 10'b0;
end

// min_out
always@(posedge clk_input or negedge rst_n) begin 
	if(!rst_n) min_out <= 10'b0;
	else if(n_state == OUTPUT && c_state != OUTPUT) min_out <= median2[0];
	else if(n_state != OUTPUT && n_state != CAL && (n_state != INPUT || input_counter < 8)) min_out <= 10'b0;
end

// fake_out_data
always@(posedge clk_input or negedge rst_n) begin 
	if(!rst_n) fake_out_data <= 10'b0;
	else if(n_state == OUTPUT && out_counter == 0) fake_out_data <= median2[8];
	else if(n_state == OUTPUT && out_counter == 1) fake_out_data <= mid_out;
	else if(n_state == OUTPUT && out_counter == 2) fake_out_data <= min_out;
	else if(n_state != OUTPUT && n_state != CAL && (n_state != INPUT || input_counter < 8)) fake_out_data <= 10'b0;
end

// out_data
always@(*) begin 
	if(out_valid) out_data = fake_out_data;
	else out_data = 10'b0;
end

endmodule