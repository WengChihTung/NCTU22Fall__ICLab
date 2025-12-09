module TT(
    //Input Port
    clk,
    rst_n,
	in_valid,
    source,
    destination,

    //Output Port
    out_valid,
    cost
    );

input               clk, rst_n, in_valid;
input       [3:0]   source;
input       [3:0]   destination;

output reg          out_valid;
output reg  [3:0]   cost;

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter IDLE = 3'd0;
parameter INPUT_SD = 3'd1;
parameter INPUT_TRACK = 3'd2;
parameter CALCULATION = 3'd5;
parameter OUTPUT = 3'd6;
parameter NO_OUTPUT = 3'd7;
integer i, j, k;

//==============================================//
//            FSM State Declaration             //
//==============================================//
reg[2:0] c_state, n_state;

//==============================================//
//                 reg declaration              //
//==============================================//
reg[3:0] station_source, station_destination, cost_count;
reg track_matrix[0:15][0:15], yes_track[0:15];

//==============================================//
//             Current State Block              //
//==============================================//

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= IDLE; /* initial state */
    else 
        c_state <= n_state;
end

//==============================================//
//              Next State Block                //
//==============================================//

always@(*) begin
    case(c_state)
        IDLE: begin 
            if(in_valid == 1'b1) n_state = INPUT_SD;
            else n_state = c_state;
        end
        INPUT_SD: begin
            if(in_valid == 1'b1) n_state = INPUT_TRACK;
            else n_state = NO_OUTPUT;
        end
        INPUT_TRACK: begin 
            if(in_valid == 1'b0 && yes_track[station_destination] == 1'b1) n_state = OUTPUT;
            else if(in_valid == 1'b0) n_state = CALCULATION;
            else n_state = c_state;
        end
        CALCULATION: begin
            if(yes_track[station_destination] == 1'b1) n_state = OUTPUT;
            else if((cost_count == 4'd15) || !(
                yes_track[0] |
                yes_track[1] |
                yes_track[2] |
                yes_track[3] |
                yes_track[4] |
                yes_track[5] |
                yes_track[6] |
                yes_track[7] |
                yes_track[8] |
                yes_track[9] |
                yes_track[10] |
                yes_track[11] |
                yes_track[12] |
                yes_track[13] |
                yes_track[14] |
                yes_track[15]
            )) n_state = NO_OUTPUT;
            else n_state = c_state;
        end
        OUTPUT: n_state = IDLE;
        NO_OUTPUT: n_state = IDLE;
        default: n_state = c_state;
    endcase
end

//==============================================//
//                  Input Block                 //
//==============================================//

// station_source
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) station_source <= 4'b0;
    else begin 
        case(n_state)
            INPUT_SD: station_source <= source;
        endcase
    end
end

// station_destination
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) station_destination <= 4'b0;
    else begin 
        case(n_state)
            INPUT_SD: station_destination <= destination;
        endcase
    end
end

// track_matrix
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) begin 
        for(i = 0; i < 16; i = i + 1) begin 
            for(j = 0; j < 16; j = j + 1) begin 
                track_matrix[i][j] <= 1'b0;
            end
        end
    end
    else begin 
        case(n_state)
            INPUT_SD: begin 
                for(i = 0; i < 16; i = i + 1) begin 
                    for(j = 0; j < 16; j = j + 1) begin 
                        track_matrix[i][j] <= 1'b0;
                    end
                end
            end
            INPUT_TRACK: begin
                track_matrix[source][destination] <= 1'b1;
                track_matrix[destination][source] <= 1'b1;
            end
            CALCULATION: begin
                for (i = 0; i < 16; i = i + 1) begin
                    for(j = 0; j < 16; j = j + 1) begin 
                        if(yes_track[i] == 1'b1) track_matrix[i][j] <= 1'b0;
                    end
                end
            end
        endcase
    end
end

//==============================================//
//              Calculation Block               //
//==============================================//

// yes_track
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) begin 
        for(k = 0; k < 16; k = k + 1) yes_track[k] <= 1'b0;
    end
    else begin 
        case(n_state)
            INPUT_SD: for(k = 0; k < 16; k = k + 1) yes_track[k] <= 1'b0;
            INPUT_TRACK: begin 
                if(source == station_source) yes_track[destination] <= 1'b1;
                else if(destination == station_source) yes_track[source] <= 1'b1;
            end
            CALCULATION: begin
                for(k = 0; k < 16; k = k + 1) begin
                    yes_track[k] <= 
                    (track_matrix[k][0] & yes_track[0]) | 
                    (track_matrix[k][1] & yes_track[1]) |
                    (track_matrix[k][2] & yes_track[2]) |
                    (track_matrix[k][3] & yes_track[3]) |
                    (track_matrix[k][4] & yes_track[4]) |
                    (track_matrix[k][5] & yes_track[5]) |
                    (track_matrix[k][6] & yes_track[6]) |
                    (track_matrix[k][7] & yes_track[7]) |
                    (track_matrix[k][8] & yes_track[8]) |
                    (track_matrix[k][9] & yes_track[9]) |
                    (track_matrix[k][10] & yes_track[10]) |
                    (track_matrix[k][11] & yes_track[11]) |
                    (track_matrix[k][12] & yes_track[12]) |
                    (track_matrix[k][13] & yes_track[13]) |
                    (track_matrix[k][14] & yes_track[14]) |
                    (track_matrix[k][15] & yes_track[15]);
                end
            end
        endcase
    end 
end

// cost_count
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) cost_count <= 4'd0;
    else begin 
        case(n_state)
            IDLE: cost_count <= 4'd1;
            CALCULATION: cost_count <= cost_count + 4'd1;
        endcase
    end
end

//==============================================//
//                Output Block                  //
//==============================================//

// out_valid
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 0; /* remember to reset */
    else begin
        case(n_state)
            OUTPUT: out_valid <= 1'b1;
            NO_OUTPUT: out_valid <= 1'b1;
            default: out_valid <= 1'b0;
        endcase
    end
end

// cost
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cost <= 0; /* remember to reset */
    else begin
        case(n_state)
            OUTPUT: cost <= cost_count;
            NO_OUTPUT: cost <= 4'd0;
            default: cost <= 4'd0;
        endcase
    end
end 

endmodule 