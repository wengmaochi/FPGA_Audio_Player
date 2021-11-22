module AudDSP(
	input   i_rst_n,
	        i_clk,
	        i_start,
	        i_pause,
            i_stop,
            i_reverse,
	        i_fast,
	        i_slow_0, // constant interpolation
	        i_slow_1, // linear interpolation
	        i_daclrck,
	input   [3:0]  i_speed_scale,
	input   [15:0] i_sram_data,
	input 	[19:0] i_end_addr,
	output	o_player_en, // to player
	output  [15:0] o_dac_data, // to player
	output  [19:0] o_sram_addr, // to some other module
    output  o_rev_finish, // to tell that rev is finished

    output  [2:0] o_state,  //test 
    output  o_bit21 //test
);

// --------------------- parameter ---------------------
localparam S_IDLE = 3'd0 ;
localparam S_LOAD = 3'd1 ;
localparam S_LRCK_NEG = 3'd2 ;
localparam S_RUN = 3'd3 ;
localparam S_SLOW_0 = 3'd4 ;
localparam S_SLOW_1 = 3'd5 ;
localparam S_PAUSE = 3'd6 ;

// --------------------- register ---------------------
logic [2:0] state_w, state_r ;
logic [3:0] scale_w, scale_r ;
logic [4:0] cnt_slow_w, cnt_slow_r ; // used to determined when to load a new address
logic signed [15:0] pre_data_w, pre_data_r ; 
logic signed [15:0] data_w, data_r ;
logic signed [15:0] out_data_w, out_data_r ;
logic [20:0] addr_w, addr_r ;
logic player_en_w, player_en_r ; 
logic reverse_w, reverse_r ;


// --------------------- wire ---------------------
// fast : d = a - b - c
// normal, slow : e = a - c  
logic signed [31:0] a, b, c, d0, d, e ;
assign a = $signed(addr_r) ;
assign b = $signed(scale_r) ;
assign c = $signed(2'b01) ; 
assign d0 = $signed(a - b) ;
assign d = $signed(d0 - c) ;
assign e = $signed(a - c) ;



// --------------------- debug ---------------------

assign o_bit21 = addr_r[20] ;

// --------------------- output ---------------------
assign o_player_en = player_en_r ;
assign o_dac_data = out_data_r ;
assign o_rev_finish = d[31] && reverse_r ;

// less than 0
// more than 2^20 
assign o_sram_addr = ( ( addr_r[20] || o_rev_finish ) && ( state_r == S_LOAD )  ) ? 20'hfffff : addr_r[19:0] ;

assign o_state = state_r ; //test 

// --------------------- combinational ---------------------
always_comb begin 
    reverse_w = i_reverse ;
    case( state_r ) 
        S_IDLE: begin // 0
            if( i_start ) begin
                // if start is high -> go to s_load to load address
                state_w = S_LOAD ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
            else begin
                // remain at IDLE
                state_w = S_IDLE ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
        end
        S_LOAD: begin // 1
            // the only place that changes address
            // if( addr_r + scale_r >= i_end_addr ) begin
            //     // finish playing
            //     state_w = S_IDLE ;
            // end
            // else begin
            //     // resume playing
            //     state_w = S_LRCK_NEG ;
            // end
            state_w = S_LRCK_NEG ;
            scale_w = i_speed_scale ;
            pre_data_w = data_r ;
            data_w = data_r ;
            out_data_w = out_data_r ;
            if( i_fast ) begin
                // jump muttiple address 
                cnt_slow_w = 5'd0 ;
                
                addr_w = ( reverse_r ) ?  d[20:0] : ( addr_r + { 17'd0, scale_r} + 21'b1 ) ;
            end
            else if( i_slow_0 | i_slow_1 ) begin
                if( cnt_slow_r <= scale_r ) begin
                    // keep on the slow mode
                    cnt_slow_w = cnt_slow_r ;
                    addr_w = addr_r ;
                end
                else begin
                    // finish slow mode, go back to S_LOAD
                    cnt_slow_w = 5'd0 ;
                    addr_w = ( reverse_r ) ? e[20:0] : ( addr_r + 21'd1 ) ;
                end
            end
            else begin
                // normal speed
                // jump one address
                cnt_slow_w = 5'd0 ;
                addr_w = ( reverse_r ) ? e[20:0]  : ( addr_r + 21'd1 ) ;//
            end
            player_en_w = 1'd1 ;
        end
        S_LRCK_NEG: begin // 2
            if( i_stop ) begin
                // go to IDLE
                state_w = S_IDLE ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
            else if( i_pause ) begin
                // go to pause 
                state_w = S_PAUSE ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd0 ;
            end
            else begin
                if( i_slow_0 ) begin
                    if( i_daclrck ) begin
                        state_w = S_SLOW_0 ;
                    end
                    else begin
                        state_w = state_r ;
                    end
                    out_data_w = pre_data_r ;
                end
                else if( i_slow_1 ) begin
                    if( i_daclrck ) begin
                        state_w = S_SLOW_1 ; 
                    end
                    else begin
                        state_w = state_r ;
                    end
                    out_data_w = $signed( ($signed(data_r - pre_data_r) / $signed({12'd0, scale_r} + 16'd1)) * $signed({12'd0, cnt_slow_r}) ) + pre_data_r;
                end
                else if( i_daclrck ) begin
                    state_w = S_RUN ;
                end
                else begin
                    state_w = state_r  ;
                end
                out_data_w = data_r ;
                scale_w = i_speed_scale ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
            
        end
        S_RUN: begin // 3
            if( i_stop ) begin
                // go to IDLE
                state_w = S_IDLE ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
            else if( i_pause ) begin
                // go to pause 
                state_w = S_PAUSE ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd0 ;
            end
            else if( i_daclrck ) begin
                // stay at this address 
                state_w = S_RUN ;
                scale_w = i_speed_scale ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
            else begin
                // when i_daclrck falls, go to S_LOAD
                state_w = S_LOAD ;
                scale_w = i_speed_scale ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
        end
        S_SLOW_0: begin // 4
            if( i_stop ) begin
                // go to IDLE
                state_w = S_IDLE ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
            else if( i_pause ) begin
                // go to pause 
                state_w = S_PAUSE ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd0 ;
            end
           else if( i_daclrck ) begin
                // stay at this address 
                state_w = S_SLOW_0 ;
                scale_w = i_speed_scale ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
            else begin
                // when i_daclrck falls, go to S_LOAD
                state_w = S_LOAD ;
                scale_w = i_speed_scale ;
                cnt_slow_w = cnt_slow_r + 1'b1 ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
        end
        S_SLOW_1: begin // 5
            if( i_stop ) begin
                // go to IDLE
                state_w = S_IDLE ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
            else if( i_pause ) begin
                // go to pause 
                state_w = S_PAUSE ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd0 ;
            end
           else if( i_daclrck ) begin
                // stay at this address 
                state_w = S_SLOW_1 ;
                scale_w = i_speed_scale ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
            else begin
                // when i_daclrck falls, go to S_LOAD
                state_w = S_LOAD ;
                scale_w = i_speed_scale ;
                cnt_slow_w = cnt_slow_r + 1'b1 ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
        end
        S_PAUSE: begin // 6
            if( i_stop ) begin
                // stop
                state_w = S_IDLE ;
                scale_w = 4'd0 ;
                cnt_slow_w = 5'd0 ;
                pre_data_w = 16'd0 ;
                data_w = 16'd0 ;
                out_data_w = 16'd0 ;
                addr_w = 21'd0 ;
                player_en_w = 1'd0 ;
            end
            else if( i_pause ) begin
                // stay at pause
                state_w = S_PAUSE ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd0 ;
            end
            else if( i_daclrck ) begin
                // stay
                state_w = S_PAUSE ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd0 ;
            end
            else begin
                state_w = S_LOAD ;
                scale_w = scale_r ;
                cnt_slow_w = cnt_slow_r ;
                pre_data_w = pre_data_r ;
                data_w = i_sram_data ;
                out_data_w = out_data_r ;
                addr_w = addr_r ;
                player_en_w = 1'd1 ;
            end
        end
        default: begin
            state_w = S_IDLE ;
            scale_w = 4'd0 ;
            cnt_slow_w = 5'd0 ;
            pre_data_w = 16'd0 ;
            data_w = 16'd0 ;
            out_data_w = 16'd0 ;
            addr_w = 21'd0 ;
            player_en_w = 1'd0 ;
        end
    endcase
end

// --------------------- sequencial ---------------------
always_ff @( posedge i_clk, negedge i_rst_n )  begin
    if( !i_rst_n ) begin
        state_r <= S_IDLE ;
        scale_r <= 4'd0 ;
        cnt_slow_r <= 4'd0 ;
        pre_data_r <= 16'd0 ;
        data_r <= 16'd0 ;
        out_data_r <= 16'd0 ;
        addr_r <= 21'd0 ;
        player_en_r <= 1'd0 ;
        reverse_r <= 1'd0 ;
    end
    else begin
        state_r <= state_w ;
        scale_r <= scale_w ;
        cnt_slow_r <= cnt_slow_w ;
        pre_data_r <= pre_data_w ;
        data_r <= data_w ;
        out_data_r <= out_data_w ;
        addr_r <= addr_w ;
        player_en_r <= player_en_w ;
        reverse_r <= reverse_w ;
    end
end
endmodule

