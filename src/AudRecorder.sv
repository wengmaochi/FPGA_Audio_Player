module AudRecorder(
	input i_rst_n, 
	input	i_clk,
	input	i_lrc,
	input	i_start,
	input	i_pause,
	input	i_stop,
	input	i_data,
	output [19:0] o_address,
	output [15:0] o_data,

	output [1:0] o_debug_state
);


localparam S_IDLE  = 2'd0;
localparam S_READ  = 2'd1;
localparam S_PAUSE = 2'd2;
localparam S_STOP  = 2'd3;
logic [4:0] counter_w, counter_r;
logic [1:0] state_w, state_r;
logic [19:0] address_w, address_r;
logic [15:0] o_data_w, o_data_r;
logic data_w, data_r;
logic lrc_w, lrc_r;
assign o_address = address_r;
assign o_data = o_data_r;


assign o_debug_state = state_r; 


always_comb begin 
	data_w = i_data;
	lrc_w = i_lrc;
	case (state_r) 
		S_IDLE : begin
			counter_w = 0;
			state_w = state_r;
			address_w = 0;
			o_data_w = 0;
			if(i_start) begin
				state_w = S_READ;
			end

		end
		S_READ : begin
			address_w = address_r;
			state_w = state_r;
			o_data_w = o_data_r;
			if(i_pause) begin       //pause
				state_w = S_PAUSE;
				counter_w = counter_r;
			end
			else if(i_stop) begin    //stop
				state_w = S_STOP;
				counter_w = counter_r;
				address_w = address_r;
				o_data_w = o_data_r;
			end
			else if (lrc_r == 1'd1) begin 
				counter_w = 0;
				address_w = address_r;
				o_data_w = o_data_r;
			end
			else if(counter_r == 5'd0) begin
				o_data_w = 16'd0;
				counter_w = counter_r + 1;
				address_w = address_r;
			end
			else if(counter_r == 5'd1) begin
				o_data_w = {15'b0 , data_r};
				counter_w = counter_r + 1;
				address_w = address_r;
			end
			else if(counter_r == 5'd16) begin
				address_w = address_r;
				counter_w = counter_r + 1;
				o_data_w = o_data_r << 1;
				o_data_w[0] = data_r;
			end
			else if(counter_r == 5'd17) begin
				address_w = address_r + 20'd1;
				counter_w = counter_r + 1;
				o_data_w = o_data_r;
			end
			else if(counter_r < 5'd16)begin
				address_w = address_r;
				counter_w = counter_r + 1;
				o_data_w = o_data_r << 1;
				o_data_w[0] = data_r;
			end
			else begin
				o_data_w = o_data_r;
				counter_w = counter_r;
				address_w = address_r;
			end
			
			//state

		end

		S_PAUSE : begin
			counter_w = counter_r;
			state_w = state_r; 
			address_w = address_r;
			o_data_w = o_data_r;
			if(i_pause) begin // i_pause is also resume 
				state_w = S_READ;
			end
			else if(i_stop) begin
				state_w = S_STOP;
			end


		end
		S_STOP : begin
			counter_w = 0;
			state_w = state_r; 
			address_w = address_r;
			o_data_w = o_data_r ;
			if(i_start) begin
				counter_w = 0;
				state_w = S_READ;
				address_w = 0;
				o_data_w = 0;
			end
		end
		default : begin
			counter_w = 0;
			state_w = state_r; //
			address_w = 0;
			o_data_w = o_data_r;
		end
	endcase



end



always_ff @( posedge i_clk, negedge i_rst_n ) begin 
	if(!i_rst_n) begin
		counter_r <= 0;
		state_r <= S_IDLE;
		address_r <= 0;
		o_data_r <= 0;
		data_r <= 0;
		lrc_r <= 0;
	end
	else begin
		counter_r <= counter_w;
		state_r <= state_w;
		address_r <= address_w;
		o_data_r <= o_data_w;
		data_r <= data_w;
		lrc_r <= lrc_w;
	end
end

endmodule
