module HD(
	code_word1,
	code_word2,
	out_n
);
input[6:0] code_word1, code_word2;
output signed[5:0] out_n;

// declaration
wire[1:3] p1, p2;
wire[1:4] x1, x2;
wire[1:3] circle1, circle2;
reg[1:0] opt;
reg[3:0] c1, c2;
// reg[5:0] o1, o2;
wire signed[5:0] o1, o2, o3;
wire c_in;
wire c_out0, c_out1, c_out2, c_out3, c_out4, c_out5;

// p1 p2 x1 x2
assign p1[1:3] = code_word1[6:4];
assign x1[1:4] = code_word1[3:0];
assign p2[1:3] = code_word2[6:4];
assign x2[1:4] = code_word2[3:0];

// circle 1
assign circle1[1] = p1[1] ^ x1[1] ^ x1[2] ^ x1[3];
assign circle1[2] = p1[2] ^ x1[1] ^ x1[2] ^ x1[4];
assign circle1[3] = p1[3] ^ x1[1] ^ x1[3] ^ x1[4];

// circle 2
assign circle2[1] = p2[1] ^ x2[1] ^ x2[2] ^ x2[3];
assign circle2[2] = p2[2] ^ x2[1] ^ x2[2] ^ x2[4];
assign circle2[3] = p2[3] ^ x2[1] ^ x2[3] ^ x2[4];


// opt 1 and c1
always@(*) begin 
	if(circle1 == 3'b011) begin 
		opt[1] = x1[4];
		c1 = {x1[1], x1[2], x1[3], ~x1[4]};
	end
	else if(circle1 == 3'b101) begin 
		opt[1] = x1[3];
		c1 = {x1[1], x1[2], ~x1[3], x1[4]};
	end
	else if(circle1 == 3'b110) begin 
		opt[1] = x1[2];
		c1 = {x1[1], ~x1[2], x1[3], x1[4]};
	end
	else if(circle1 == 3'b111) begin 
		opt[1] = x1[1];
		c1 = {~x1[1], x1[2], x1[3], x1[4]};
	end
	else begin 
		c1 = x1;
		if(circle1[3] == 1'b1) opt[1] = p1[3];
		else if(circle1[2] == 1'b1) opt[1] = p1[2];
		else opt[1] = p1[1];
	end
end

// opt 0 and c2
always@(*) begin 
	if(circle2 == 3'b011) begin 
		opt[0] = x2[4];
		c2 = {x2[1], x2[2], x2[3], ~x2[4]};
	end
	else if(circle2 == 3'b101) begin 
		opt[0] = x2[3];
		c2 = {x2[1], x2[2], ~x2[3], x2[4]};
	end
	else if(circle2 == 3'b110) begin 
		opt[0] = x2[2];
		c2 = {x2[1], ~x2[2], x2[3], x2[4]};
	end
	else if(circle2 == 3'b111) begin 
		opt[0] = x2[1];
		c2 = {~x2[1], x2[2], x2[3], x2[4]};
	end
	else begin 
		c2 = x2;
		if(circle2[3] == 1'b1) opt[0] = p2[3];
		else if(circle2[2] == 1'b1) opt[0] = p2[2];
		else opt[0] = p2[1];
	end
end

/*
// c1
always@(*) begin 
	case(circle1)
		3'b011: begin 
			opt[1] = x1[4];
			c1 = {x1[1], x1[2], x1[3], ~x1[4]};
		end
		3'b101: begin 
			opt[1] = x1[3];
			c1 = {x1[1], x1[2], ~x1[3], x1[4]};
		end
		3'b110: begin 
			opt[1] = x1[2];
			c1 = {x1[1], ~x1[2], x1[3], x1[4]};
		end
		3'b111: begin 
			opt[1] = x1[1];
			c1 = {~x1[1], x1[2], x1[3], x1[4]};
		end
		3'b001: begin 
			opt[1] = p1[3];
			c1 = x1;
		end
		3'b010: begin 
			opt[1] = p1[2];
			c1 = x1;
		end
		3'b100: begin 
			opt[1] = p1[1];
			c1 = x1;
		end
		default: begin
			opt[1] = 1'bx;
			c1 = 4'bx;
		end
	endcase
end

// c2
always@(*) begin 
	case(circle2)
		3'b011: begin 
			opt[0] = x2[4];
			c2 = {x2[1], x2[2], x2[3], ~x2[4]};
		end
		3'b101: begin 
			opt[0] = x2[3];
			c2 = {x2[1], x2[2], ~x2[3], x2[4]};
		end
		3'b110: begin 
			opt[0] = x2[2];
			c2 = {x2[1], ~x2[2], x2[3], x2[4]};
		end
		3'b111: begin 
			opt[0] = x2[1];
			c2 = {~x2[1], x2[2], x2[3], x2[4]};
		end
		3'b001: begin 
			opt[0] = p2[3];
			c2 = x2;
		end
		3'b010: begin 
			opt[0] = p2[2];
			c2 = x2;
		end
		3'b100: begin 
			opt[0] = p2[1];
			c2 = x2;
		end
		default: begin
			opt[0] = 1'bx;
			c2 = 4'bx;
		end
	endcase
end
*/
// o1
assign o1[3:0] = (opt[1])? c1 : {c1[2:0], 1'b0};
assign o1[5:4] = {2{c1[3]}};

// o2
assign o2[3:0] = (opt[1])? {c2[2:0], 1'b0} : c2;
assign o2[5:4] = {2{c2[3]}};

/*
always@(*) begin 
	if(opt[1]) begin 
		o1[3:0] = c1;
		o2[3:0] = {c2[2:0], 1'b0};
	end
	else begin 
		o1[3:0] = {c1[2:0], 1'b0};
		o2[3:0] = c2;
	end
	o1[5:4] = {2{c1[3]}};
	o2[5:4] = {2{c2[3]}};
end
*/
/*
// o3
assign o3 = (opt[1] ^ opt[0])? (~o2 + 1'b1) : o2;

//out_n
assign out_n = o1 + o3;
*/

assign c_in = (opt[1] ^ opt[0])? 1'b1 : 1'b0;

assign o3[5] = o2[5] ^ c_in;
assign o3[4] = o2[4] ^ c_in;
assign o3[3] = o2[3] ^ c_in;
assign o3[2] = o2[2] ^ c_in;
assign o3[1] = o2[1] ^ c_in;
assign o3[0] = o2[0] ^ c_in;

FA add0(.a(o1[0]), .b(o3[0]), .c_in(c_in), .sum(out_n[0]), .c_out(c_out0));
FA add1(.a(o1[1]), .b(o3[1]), .c_in(c_out0), .sum(out_n[1]), .c_out(c_out1));
FA add2(.a(o1[2]), .b(o3[2]), .c_in(c_out1), .sum(out_n[2]), .c_out(c_out2));
FA add3(.a(o1[3]), .b(o3[3]), .c_in(c_out2), .sum(out_n[3]), .c_out(c_out3));
FA add4(.a(o1[4]), .b(o3[4]), .c_in(c_out3), .sum(out_n[4]), .c_out(c_out4));
FA add5(.a(o1[5]), .b(o3[5]), .c_in(c_out4), .sum(out_n[5]), .c_out(c_out5));

endmodule

module HA(
		a, 
		b, 
		sum, 
		c_out
);
  input wire a, b;
  output wire sum, c_out;
  xor (sum, a, b);
  and (c_out, a, b);
endmodule


module FA(
		a, 
		b, 
		c_in, 
		sum, 
		c_out
);
  input   a, b, c_in;
  output  sum, c_out;
  wire   w1, w2, w3;
  HA M1(.a(a), .b(b), .sum(w1), .c_out(w2));
  HA M2(.a(w1), .b(c_in), .sum(sum), .c_out(w3));
  or (c_out, w2, w3);
endmodule
