    // JUNIOR CGA outputs. 1: the RGB jacks mix intensity into each channel (levels 0, 111, 255).
    // 2: the composite jack's resistor ladder (16 grey levels), shown on a green monitor.
    function [17:0] junior_color;
        input [1:0] mon;
        input [3:0] color;
        reg [5:0] r, g, b, l;
        begin
            r = color[2] ? (color[3] ? 6'd63 : 6'd27) : (color[3] ? 6'd27 : 6'd0);
            g = color[1] ? (color[3] ? 6'd63 : 6'd27) : (color[3] ? 6'd27 : 6'd0);
            b = color[0] ? (color[3] ? 6'd63 : 6'd27) : (color[3] ? 6'd27 : 6'd0);
            case (color)
                4'h0: l = 6'd0;   4'h1: l = 6'd2;   4'h2: l = 6'd38;  4'h3: l = 6'd40;
                4'h4: l = 6'd18;  4'h5: l = 6'd20;  4'h6: l = 6'd56;  4'h7: l = 6'd57;
                4'h8: l = 6'd6;   4'h9: l = 6'd7;   4'hA: l = 6'd43;  4'hB: l = 6'd45;
                4'hC: l = 6'd23;  4'hD: l = 6'd25;  4'hE: l = 6'd61;  default: l = 6'd63;
            endcase
            junior_color = (mon == 2'd1) ? {b, g, r} :
                           (mon == 2'd2) ? {3'd0, l[5:3], l, 2'd0, l[5:2]} : rgbi_color(color);
        end
    endfunction
