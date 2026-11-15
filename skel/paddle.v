

// paddle -- button-controlled, using the scanned collision bus
//
// Like the balls, the paddle checks its neighbours with a perimeter scan
// on the shared collision bus (hcount_col/vcount_col).
//
// The move pulse fires hundreds of times per frame, which would make the
// paddle far too fast to control, so it only moves on every MOVE_DIV-th
// move pulse.

module paddle #(parameter xloc_start  = 320,
                parameter yloc_start  = 400,
                parameter xsize_div_2 = 5,
                parameter ysize_div_2 = 2,
                parameter MOVE_DIV    = 2)   // move once per MOVE_DIV move pulses
   (
    input            clk,        // 100 MHz system clock
    input            pixpulse,   // every 4 clocks for 25MHz pixel rate
    input            rst,
    // Paint ports (driven by vga_timing raster scan)
    input [9:0]      hcount,
    input [9:0]      vcount,
    // Collision ports (driven by the active sprite's scanner via top-level mux)
    input [9:0]      hcount_col,
    input [9:0]      vcount_col,
    input            empty_col,  // is the collision scan pixel empty?
    // Scan arbitration
    input            scan_grant,       // one-cycle pulse: my turn to scan
    output reg       scan_done,        // one-cycle pulse: scan complete
    output reg [9:0] hcount_col_out,   // my scan x
    output reg [9:0] vcount_col_out,   // my scan y
    output reg       scan_active,
    // Movement
    input            move,        // one-cycle pulse: update position
    input            frame_start, // one-pixpulse pulse at start of vblank
    input [3:0]      move_dir,    // one hot vector {up,right,down,left}
    // Outputs
    output           draw_paddle,     // paint this pixel as paddle
    output           draw_paddle_col, // is the paddle at the collision scan coords?
    output reg [9:0] xloc,
    output reg [9:0] yloc
    );

   localparam XB = xsize_div_2 + 1;   // perimeter distance, x
   localparam YB = ysize_div_2 + 1;   // perimeter distance, y
   localparam VLEN = 2*YB + 1;        // pixels on left/right sides
   localparam HLEN = 2*XB + 1;        // pixels on top/bottom sides

   reg        blk_lft, blk_rgt, blk_up, blk_dn;
   reg [1:0]  scan_side;    // 0=right, 1=left, 2=bottom, 3=top
   reg [9:0]  scan_offset;
   reg [7:0]  div_cnt;

   //------------------------------------------------------------
   // Paint from a position latched once per frame (no tearing)
   //------------------------------------------------------------
   reg [9:0] disp_x, disp_y;
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         disp_x <= xloc_start;
         disp_y <= yloc_start;
      end else if (pixpulse && frame_start) begin
         disp_x <= xloc;
         disp_y <= yloc;
      end
   end

   assign draw_paddle = (hcount <= disp_x + xsize_div_2) & (hcount >= disp_x - xsize_div_2) &
                        (vcount <= disp_y + ysize_div_2) & (vcount >= disp_y - ysize_div_2);

   assign draw_paddle_col = (hcount_col <= xloc + xsize_div_2) & (hcount_col >= xloc - xsize_div_2) &
                            (vcount_col <= yloc + ysize_div_2) & (vcount_col >= yloc - ysize_div_2);

   //------------------------------------------------------------
   // Collision scan coordinates
   //------------------------------------------------------------
   always @(*) begin
      case (scan_side)
         2'b00: begin
            hcount_col_out = xloc + XB;
            vcount_col_out = yloc - YB + scan_offset;
         end
         2'b01: begin
            hcount_col_out = xloc - XB;
            vcount_col_out = yloc - YB + scan_offset;
         end
         2'b10: begin
            hcount_col_out = xloc - XB + scan_offset;
            vcount_col_out = yloc + YB;
         end
         default: begin
            hcount_col_out = xloc - XB + scan_offset;
            vcount_col_out = yloc - YB;
         end
      endcase
   end

   wire last_offset = (scan_side[1] ? (scan_offset == HLEN - 1) : (scan_offset == VLEN - 1));

   //------------------------------------------------------------
   // Scan control: any non-empty pixel on a side blocks that side
   //------------------------------------------------------------
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         blk_lft <= 1'b0;  blk_rgt <= 1'b0;
         blk_up  <= 1'b0;  blk_dn  <= 1'b0;
         scan_side   <= 2'b0;
         scan_offset <= 10'd0;
         scan_active <= 1'b0;
         scan_done   <= 1'b0;
      end else if (pixpulse) begin
         scan_done <= 1'b0;

         if (scan_grant && !scan_active) begin
            blk_lft <= 1'b0;  blk_rgt <= 1'b0;
            blk_up  <= 1'b0;  blk_dn  <= 1'b0;
            scan_active <= 1'b1;
            scan_side   <= 2'b0;
            scan_offset <= 10'd0;
         end else if (scan_active) begin
            if (!empty_col) begin
               case (scan_side)
                  2'b00: blk_rgt <= 1'b1;
                  2'b01: blk_lft <= 1'b1;
                  2'b10: blk_dn  <= 1'b1;
                  2'b11: blk_up  <= 1'b1;
               endcase
            end

            if (last_offset) begin
               scan_offset <= 10'd0;
               if (scan_side == 2'b11) begin
                  scan_active <= 1'b0;
                  scan_done   <= 1'b1;
               end else begin
                  scan_side <= scan_side + 1'b1;
               end
            end else begin
               scan_offset <= scan_offset + 1'b1;
            end
         end
      end
   end

   //------------------------------------------------------------
   // Movement
   //------------------------------------------------------------
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         xloc    <= xloc_start;
         yloc    <= yloc_start;
         div_cnt <= 8'd0;
      end else if (pixpulse && move) begin
         if (div_cnt >= MOVE_DIV - 1) begin
            div_cnt <= 8'd0;
            case (move_dir)
               4'b0001: if (~blk_lft) xloc <= xloc - 1;  // left
               4'b0010: if (~blk_dn)  yloc <= yloc + 1;  // down
               4'b0100: if (~blk_rgt) xloc <= xloc + 1;  // right
               4'b1000: if (~blk_up)  yloc <= yloc - 1;  // up
               default: ;
            endcase
         end else begin
            div_cnt <= div_cnt + 1'b1;
         end
      end
   end

endmodule // paddle
