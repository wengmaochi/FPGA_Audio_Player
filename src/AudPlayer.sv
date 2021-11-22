module AudPlayer(
	input       i_rst_n,
	            i_bclk, // Bit-Steam clock
	            i_daclrck, // DAC LR clock 
	            i_en, // enable AudPlayer only when playing audio, work with AudDSP
	input [15:0]i_dac_data, // dac_data
	output      o_aud_dacdat,


	output 		[1:0]o_state
);

localparam S_IDLE = 0 ; 
localparam S_SEND = 1 ;

logic [1:0] state_w, state_r ;
logic [15:0] data_w, data_r ;
logic lrclk_w, lrclk_r ;
logic [3:0] cnt_w, cnt_r ;

assign o_aud_dacdat = data_r[15] ;
// enable should rise as daclrck rises or falls

assign o_state = state_r ;

always_comb begin
	lrclk_w = i_daclrck ;
	case (state_r)
		S_IDLE : begin // 0
			if( i_en & ( lrclk_w ^ lrclk_r ) ) begin
				state_w = S_SEND ;
				data_w = i_dac_data ;
				cnt_w = 4'd0 ;
				lrclk_w = lrclk_r ;
			end
			else begin
				state_w = state_r ;
				data_w = data_r ;
				cnt_w = 4'd0 ;
				lrclk_w = lrclk_r ;
			end
		end
		S_SEND : begin // 1
			if( cnt_r == 15 ) begin
				state_w = S_IDLE ;
			end
			else begin
				state_w = S_SEND ;
			end
			data_w = data_r << 1 ;
			cnt_w = cnt_r + 1'b1 ;
		end
		default : begin
			state_w = S_IDLE ;
			data_w = data_r ;
			cnt_w = 4'd0 ;
			lrclk_w = lrclk_r ;
		end
	endcase
end


always_ff @( posedge i_bclk, negedge i_rst_n ) begin
	if(!i_rst_n) begin
		state_r <= S_IDLE ;
		data_r <= 16'd0 ;
		cnt_r <= 4'd0 ;
		lrclk_r <= 1'd0 ;
	end
	else begin
		state_r <= state_w ;
		data_r <= data_w ;
		cnt_r <= cnt_w ;
		lrclk_r <= lrclk_w ;
	end
end



endmodule