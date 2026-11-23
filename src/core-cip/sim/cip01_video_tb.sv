// SPDX-License-Identifier: GPL-3.0-or-later
module cip01_video_tb;
    reg clk=0, reset=1;
    always #5 clk=~clk;
    wire [13:0] addr;
    reg [7:0] data;
    wire [3:0] rgb;
    wire [8:0] x,y;
    wire [4:0] flash;
    wire hs,vs,hb,vb;
    reg [7:0] memory[0:16383];
    cip01_video dut (.clk(clk),.reset(reset),.ce_pixel(1'b1),.border(3'd6),
        .ram_addr(addr),.ram_data(data),.rgb(rgb),.hs(hs),.vs(vs),.hblank(hb),.vblank(vb),
        .x(x),.y(y),.flash_count(flash));
    always @(posedge clk) data<=memory[addr];
    integer i,row,col,n,expected,ink,paper,on_pixel,frames=0,checks=0;
    initial begin
        for(i=0;i<16384;i=i+1) memory[i]=8'ha5;
        for(row=0;row<24;row=row+1) for(col=0;col<32;col=col+1)
            memory[6144+row*32+col] = ((col&8)?128:0) | ((col&16)?64:0) | (((col+3)&7)<<3) | (col&7);
        repeat(4) @(negedge clk);
        reset=0;
        for(n=0;n<448*312*18;n=n+1) begin
            @(negedge clk);
            if(x==0 && y==0) frames=frames+1;
            if(frames>=2) begin
                if(x<256 && y<192) begin
                    col=x/8; ink=col&7; paper=(col+3)&7;
                    on_pixel=((8'ha5>>(7-(x%8)))&1) ^ (((col&8)!=0) && flash[4]);
                    expected=(on_pixel?ink:paper) | ((col&16)?8:0);
                    if(rgb !== expected[3:0]) $fatal(1,"Pixel mismatch at %d,%d: got %d expected %d",x,y,rgb,expected);
                    checks=checks+1;
                end else if(!hb && !vb && rgb!==4'd6) $fatal(1,"Border colour mismatch");
            end
        end
        if(frames!=18 || flash!=18 || checks<700000) $fatal(1,"Raster/FLASH frame cadence wrong");
        $display("PASS: raster, bitmap/attributes, all colours, BRIGHT, FLASH and border (%d pixels)",checks);
        $finish;
    end
endmodule
