module RCL(
    clk,
    rst_n,
    in_valid,
    coef_Q,
    coef_L,
    out_valid,
    out
);

////// in out /////

input clk;
input rst_n;
input in_valid;
input[4:0] coef_Q;
input[4:0] coef_L;

output reg out_valid;
output reg[1:0] out;

///// parameter /////

parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter OUTPUT = 2'd2;


////// declaration ////////

reg[1:0] c_state, n_state;
reg[1:0] input_counter;

reg signed[4:0] a, b, c, m, n;
reg[4:0] k;

reg signed[9:0] a_square, b_square;
reg signed[10:0] a_square_plus_b_square;
reg signed[9:0] a_m, b_n;
reg signed[10:0] a_m_plus_b_n;

wire signed[15:0] r;
wire signed[23:0] d;

reg[1:0] compare;


//////// FSM /////////

// c_state
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) c_state <= IDLE;
    else c_state <= n_state;
end

// n_state
always@(*) begin 
    case(c_state)
        IDLE: begin 
            if(in_valid == 1'b1) n_state = INPUT;
            else n_state = c_state;
        end
        INPUT: begin
            if(in_valid == 1'b0) n_state = OUTPUT;
            else n_state = c_state;
        end
        OUTPUT: n_state = IDLE;
        default: n_state = c_state;
    endcase

end

//////// INPUT ///////////

// input_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) input_counter <= 2'd0;
    else begin 
        case(n_state)
            INPUT: input_counter <= input_counter + 1'b1;
            default: input_counter <= 2'd0;
        endcase
    end
end

// a
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) a <= 5'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'b0) a <= coef_L;
        endcase
    end
end

// b
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) b <= 5'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'b1) b <= coef_L;
        endcase
    end
end

// c
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) c <= 5'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter[1]) c <= coef_L;
        endcase
    end
end

// m
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) m <= 5'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'b0) m <= coef_Q;
        endcase
    end
end

// n
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) n <= 5'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'b1) n <= coef_Q;
        endcase
    end
end

// k
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) k <= 5'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter[1]) k <= coef_Q;
        endcase
    end
end

//////// CALCULATION //////////

// a_square
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) a_square <= 10'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'b1) a_square <= a * a;
        endcase
    end
end

// a_m
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) a_m <= 10'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'b1) a_m <= a * m;
        endcase
    end
end

// a_square_plus_b_square
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) a_square_plus_b_square <= 11'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'd2) a_square_plus_b_square <= a_square + (b * b);
        endcase
    end
end

// a_m_plus_b_n
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) a_m_plus_b_n <= 11'b0;
    else begin 
        case(n_state)
            INPUT: if(input_counter == 2'd2) a_m_plus_b_n <= a_m + (b * n);
        endcase
    end
end

assign r = a_square_plus_b_square * k;
assign d = (a_m_plus_b_n + c) * (a_m_plus_b_n + c);

// compare
always@(*) begin 
    if(r < d) compare = 2'd0;
    else if(r == d) compare = 2'd1;
    else compare = 2'd2;
end

//////// OUTPUT ////////////

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
            OUTPUT: out <= compare;
            default: out <= 2'b0;
        endcase
    end
end

endmodule
