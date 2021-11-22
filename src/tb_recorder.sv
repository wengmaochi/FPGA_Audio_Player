`timescale 1ns/100ps
module tb_player;
    localparam  CLK = 10;
    localparam  HCLK = CLK/2;
    logic clk,start_cal ,rst, stp, puse,lrcc; 
    initial clk = 0;
    always #HCLK clk = ~clk;
    // logic  [256-1:0]data;
    logic data;
    logic  data_arr[0:127];

    logic  [20-1:0] o_oaddress;
    logic  [16-1:0] o_odata;
    integer i;
    AudRecorder Recoder000(
        .i_rst_n(rst),
        .i_bclk(clk),
        .i_lrc(lrcc),
        .i_start(start_cal),
        .i_pause(puse),
        .i_stop(stp),
        .i_data(data),
        .o_address(o_oaddress),
        .o_data(o_odata)
    );

initial begin
    #0 lrcc = 1'b0;
    #(HCLK) lrcc = 1'b1;
    #(7*HCLK) lrcc = 1'b0;
    #(38*HCLK) lrcc = 1'b1;
    #(38*HCLK) lrcc = 1'b0;
    #(38*HCLK) lrcc = 1'b1;
end
initial begin
    #0 rst = 1'b0;
    #(HCLK) rst = 1'b1;
    #(2*HCLK) rst = 1'b0;
end

initial begin
    #0 start_cal = 1'b0;
    #(5*HCLK) start_cal = 1'b1;
    #(8*HCLK) start_cal = 1'b0;
end
initial begin
    #0 puse = 1'b0;
    stp = 1'b0;
end
initial begin
    $readmemb("./test_input_recoder.dat",data_arr);
end

initial begin
    $fsdbDumpfile("tb_recorder.fsdb");
    $fsdbDumpvars;
    // fp_input = $fopen("./test_input_recoder.dat","rb")

    #0 i = 0;
    #(9*HCLK);
    @(negedge clk) data = data_arr[i];

    for(i=1; i<16;i=i+1) begin
        @(negedge clk) data = data_arr[i];
        // $display(i,data_arr[i]);
        // $display("====");
    end 
    #(7*HCLK);
    i = 16;
    @(negedge clk) data = data_arr[i];
    for(i=17;i<32;i=i+1) begin
        @(negedge clk) data = data_arr[i];
    end
    #(7*HCLK);
    i = 32;
    @(negedge clk) data = data_arr[i];
    for(i=33;i<48;i=i+1) begin
        @(negedge clk) data = data_arr[i];
    end


    @(negedge clk) data = 1'd0;
    
    end


initial begin
    #(200*HCLK)
    $finish;
end
endmodule
