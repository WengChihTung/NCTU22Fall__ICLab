module BP(
  clk,
  rst_n,
  in_valid,
  guy,
  in0,
  in1,
  in2,
  in3,
  in4,
  in5,
  in6,
  in7,
  
  out_valid,
  out
);

input             clk, rst_n;
input             in_valid;
input       [2:0] guy;
input       [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
output reg        out_valid;
output reg  [1:0] out;

reg[1:0] c_state, n_state;
reg[5:0] counter;
reg[2:0] array_position;
reg[109:0] out_array;
reg[15:0] fix_array;

parameter IDLE = 2'd0;
parameter GUY = 2'd1;
parameter INPUT = 2'd2;
parameter OUTPUT = 2'd3;
parameter LEFT = 1'd0;
parameter RIGHT = 1'd1;

wire[1:0] in[0:7];
reg yes_obstacle;
reg[2:0] obstacle_position;
reg obstacle_kind;
reg left_or_right;
reg[2:0] steps_diff;

assign in[0] = in0;
assign in[1] = in1;
assign in[2] = in2;
assign in[3] = in3;
assign in[4] = in4;
assign in[5] = in5;
assign in[6] = in6;
assign in[7] = in7;

////////////// FSM ///////////////////

always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) c_state <= IDLE;
	else c_state <= n_state;
end

always@(*) begin 
	case(c_state)
		IDLE: begin 
			if(in_valid == 1'b1) n_state = GUY;
			else n_state = c_state;
		end
		GUY: n_state = INPUT;
		INPUT: begin 
			if(in_valid == 1'b0) n_state = OUTPUT;
			else n_state = c_state;
		end
		OUTPUT: begin 
			if(counter == 6'd63) n_state = IDLE;
			else n_state = c_state;
		end
		//default: n_state = c_state;
	endcase
end

////////////// input ///////////////////

// yes_obstacle
always@(*) begin 
	case(n_state)
		INPUT: begin
			if(in[0] != 2'd0) yes_obstacle = 1'b1;
			else yes_obstacle = 1'b0;
		end
		default: yes_obstacle = 1'b0;
	endcase
end

// obstacle_position
always@(*) begin 
	case(n_state)
		INPUT: begin
			if(in[0] != 2'd3) obstacle_position = 3'd0;
			else if(in[1] != 2'd3) obstacle_position = 3'd1;
			else if(in[2] != 2'd3) obstacle_position = 3'd2;
			else if(in[3] != 2'd3) obstacle_position = 3'd3;
			else if(in[4] != 2'd3) obstacle_position = 3'd4;
			else if(in[5] != 2'd3) obstacle_position = 3'd5;
			else if(in[6] != 2'd3) obstacle_position = 3'd6;
			else obstacle_position = 3'd7;
		end
		default: obstacle_position = 3'd0;
	endcase
end

// obstacle_kind
always@(*) begin 
	case(n_state)
		INPUT: begin
			if(in[0] != 2'd3) obstacle_kind = in[0][0];
			else if(in[1] != 2'd3) obstacle_kind = in[1][0];
			else if(in[2] != 2'd3) obstacle_kind = in[2][0];
			else if(in[3] != 2'd3) obstacle_kind = in[3][0];
			else if(in[4] != 2'd3) obstacle_kind = in[4][0];
			else if(in[5] != 2'd3) obstacle_kind = in[5][0];
			else if(in[6] != 2'd3) obstacle_kind = in[6][0];
			else obstacle_kind = in[7][0];
		end
		default: obstacle_kind = 2'd0;
	endcase
end

// array_position
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin 
		array_position <= 3'd0;
	end
	else begin 
		case(n_state)
			GUY: begin
				array_position <= guy;
			end
			INPUT: begin 
				if(yes_obstacle) array_position <= obstacle_position;
			end
		endcase
	end
end

// left_or_right
always@(*) begin 
	case(n_state)
		INPUT: begin 
			if(array_position < obstacle_position) left_or_right = RIGHT;
			else left_or_right = LEFT;
		end
		default: left_or_right = 1'b0;
	endcase
end

// steps_diff
always@(*) begin 
	case(n_state)
		INPUT: begin 
			if(left_or_right) steps_diff = obstacle_position - array_position;
			else steps_diff = array_position - obstacle_position;
		end
		default: steps_diff = 3'd0;
	endcase
end

integer i, j;
// out_array
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) for(i = 0; i < 110; i = i + 1) out_array[i] <= 1'b0;
	else out_array[109:0] <= {out_array[107:0], fix_array[15:14]};
end

// fix_array
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) for(j = 0; j < 16; j = j + 1) fix_array[j] <= 1'b0;
	else begin 
		case(n_state)
			INPUT: begin 
				if(!yes_obstacle) fix_array[15:0] <= {fix_array[13:0], 2'b00};
				else begin
					if(!obstacle_kind) begin 
						case(steps_diff)
							3'd0: fix_array[15:0] <= {fix_array[13:0], 2'b00};
							3'd1: fix_array[15:0] <= {fix_array[13:0], {1{!left_or_right, left_or_right}}};
							3'd2: fix_array[15:0] <= {fix_array[13:2], {2{!left_or_right, left_or_right}}};
							3'd3: fix_array[15:0] <= {fix_array[13:4], {3{!left_or_right, left_or_right}}};
							3'd4: fix_array[15:0] <= {fix_array[13:6], {4{!left_or_right, left_or_right}}};
							3'd5: fix_array[15:0] <= {fix_array[13:8], {5{!left_or_right, left_or_right}}};
							3'd6: fix_array[15:0] <= {fix_array[13:10], {6{!left_or_right, left_or_right}}};
							3'd7: fix_array[15:0] <= {fix_array[13:12], {7{!left_or_right, left_or_right}}};
						endcase
					end
					else begin 
						case(steps_diff)
							3'd0: fix_array[15:0] <= {fix_array[13:0], {2{obstacle_kind}}};
							3'd1: fix_array[15:0] <= {fix_array[13:2], {1{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
							3'd2: fix_array[15:0] <= {fix_array[13:4], {2{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
							3'd3: fix_array[15:0] <= {fix_array[13:6], {3{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
							3'd4: fix_array[15:0] <= {fix_array[13:8], {4{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
							3'd5: fix_array[15:0] <= {fix_array[13:10], {5{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
							3'd6: fix_array[15:0] <= {fix_array[13:12], {6{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
							3'd7: fix_array[15:0] <= {{7{!left_or_right, left_or_right}}, {2{obstacle_kind}}};
						endcase
					end
				end
			end
			default: fix_array <= fix_array << 2;
		endcase
	end
end

////////////// output ////////////////////

// counter
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) counter <= 6'd0;
	else begin 
		case(n_state)
			OUTPUT: counter <= counter + 6'd1;
			default: counter <= 6'd0;
		endcase
	end
end

// out_valid
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) out_valid <= 1'b0;
	else begin 
		case(n_state)
			OUTPUT: out_valid <= 1'b1;
			default: out_valid <= 1'b0;
		endcase
	end
end

// out
always@(posedge clk or negedge rst_n) begin 
	if(!rst_n) out <= 2'b0;
	else begin 
		case(n_state)
			OUTPUT: out <= out_array[109:108];
			default: out <= 2'd0;
		endcase
	end
end
endmodule
