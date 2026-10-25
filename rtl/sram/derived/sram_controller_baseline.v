//-----------------------------------------------------------------
//                AXI4 -> Async SRAM (16-bit) Interface
//                              V0.1
//                        Ultra-Embedded.com
//                          Copyright 2019
//
//                 Email: admin@ultra-embedded.com
//
//                       License: LGPL
//-----------------------------------------------------------------
//
// This source file may be used and distributed without
// restriction provided that this copyright statement is not
// removed from the file and that any derivative work contains
// the original copyright notice and the associated disclaimer.
//
// This source file is free software; you can redistribute it
// and/or modify it under the terms of the GNU Lesser General
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any
// later version.
//
// This source is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
// PURPOSE.  See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General
// Public License along with this source; if not, write to the
// Free Software Foundation, Inc., 59 Temple Place, Suite 330,
// Boston, MA  02111-1307  USA
//-----------------------------------------------------------------

//-----------------------------------------------------------------
//                          Generated File
//-----------------------------------------------------------------

//-----------------------------------------------------------------
// OBRA DERIVADA (LGPL) - sram_controller_baseline (Fase 1)
//
// Derivada de rtl/third_party/ultra_embedded_asram16_axi4/asram16_axi4.v
// (Ultra-Embedded, v0.1, 2019), que permanece no repositorio sem alteracao.
// O aviso de copyright e a licenca acima foram preservados integralmente.
// Projeto interface_amba (TCC) - MAS_axi4_sram.md §5.5, decisao D14.
//
// Aproveita a FSM de acesso a SRAM da IP (esperas fixas, ~6 ciclos/beat de leitura e
// ~8 de escrita com as esperas em 1) e expoe o contrato ram_* (MAS §3.2), de modo que
// possa ser trocada pelo sram_controller (Fase 2) sem alterar o frontend AXI.
// Toda linha nova ou alterada traz o marcador "// B<n>". O codigo herdado nao foi
// reformatado. Alteracoes:
//   B0  modulo renomeado de asram16_axi4 para sram_controller_baseline
//   B1  o frontend AXI interno (instancia asram16_axi4_pmem) e retirado; o modulo passa a
//       expor o contrato ram_* nas portas
//   B2  requisicao de escrita reconhecida por ram_wr_req_i; escrita com strobe nulo
//       responde ack sem acessar a SRAM (na IP original viraria uma leitura)
//   B3  saida registrada sram_data_out_en_o (direcao de DQ, MAS §5.2, L-01)
// O endereco de entrada chega alinhado a 4 bytes (MAS §4.2, D17); os 20 bits de
// endereco da SRAM sao obtidos pelo wrapper a partir de sram_address_o.
// Auditoria: make audit_fork
//-----------------------------------------------------------------

module sram_controller_baseline // B0
( // B1
    // Inputs // B1
     input           clk_i // B1
    ,input           rst_i // B1
    ,input  [ 31:0]  ram_addr_i // B1
    ,input  [  3:0]  ram_wr_i // B1
    ,input           ram_wr_req_i // B1
    ,input           ram_rd_i // B1
    ,input  [ 31:0]  ram_write_data_i // B1
    ,input  [ 15:0]  sram_data_in_i
    // Outputs // B1
    ,output          ram_accept_o // B1
    ,output          ram_ack_o // B1
    ,output [ 31:0]  ram_read_data_o // B1
    ,output [ 31:0]  sram_address_o
    ,output [ 15:0]  sram_data_out_o
    ,output          sram_data_out_en_o // B3
    ,output          sram_oe_n_o
    ,output          sram_cs_n_o
    ,output [  1:0]  sram_be_n_o
    ,output          sram_we_n_o
);

//-----------------------------------------------------------------
// Timing params
//-----------------------------------------------------------------
parameter WRITE_WAIT_CYCLES   = 4'd7;
parameter READ_WAIT_CYCLES    = 4'd7;
parameter WRITE_HOLD_CYCLES   = 4'd7;

//-----------------------------------------------------------------
// Contrato ram_* (B1: no original, esta secao instanciava asram16_axi4_pmem)
//-----------------------------------------------------------------
wire [ 31:0]  ram_addr_w;
wire [  3:0]  ram_wr_w;
wire          ram_rd_w;
wire          ram_accept_w;
wire [ 31:0]  ram_write_data_w;
wire [ 31:0]  ram_read_data_w;
wire          ram_ack_w;

assign ram_addr_w       = ram_addr_i; // B1
assign ram_wr_w         = ram_wr_i; // B1
assign ram_rd_w         = ram_rd_i; // B1
assign ram_write_data_w = ram_write_data_i; // B1
assign ram_accept_o     = ram_accept_w; // B1
assign ram_ack_o        = ram_ack_w; // B1
assign ram_read_data_o  = ram_read_data_w; // B1

wire          ram_req_w   = ram_wr_req_i | ram_rd_w; // B2
wire          ram_wr_go_w = ram_wr_req_i & (|ram_wr_w); // B2 (escrita com algum strobe)

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [31:0] sram_address_q;
reg [15:0] sram_data_q;
reg        sram_oe_n_q;
reg [1:0]  sram_be_n_q;
reg        sram_we_n_q;

// State Machine status
reg [3:0]  state_q;
reg [3:0]  wait_q;
localparam MEM_IDLE          = 4'd0;
localparam MEM_WRITE_DATA1   = 4'd1;
localparam MEM_WRITE_SETUP2  = 4'd2;
localparam MEM_WRITE_DATA2   = 4'd3;
localparam MEM_READ_DATA1    = 4'd4;
localparam MEM_READ_DATA2    = 4'd5;
localparam MEM_WAIT_READ1    = 4'd6;
localparam MEM_WAIT_READ2    = 4'd7;
localparam MEM_WAIT_WRITE1   = 4'd8;
localparam MEM_WAIT_HOLD1    = 4'd9;
localparam MEM_WAIT_HOLD2    = 4'd10;
localparam MEM_WAIT_HOLD3    = 4'd11;

reg [31:0] data_q;
reg [1:0]  we_q;
reg        ack_q;
reg        data_out_en_q; // B3

//-----------------------------------------------------------------
// Xilinx synthesis hints
//-----------------------------------------------------------------
//synthesis attribute IOB of sram_address_q is "TRUE"
//synthesis attribute IOB of sram_data_q is "TRUE"
//synthesis attribute IOB of sram_oe_n_q is "TRUE"
//synthesis attribute IOB of sram_be_n_q is "TRUE"
//synthesis attribute IOB of sram_we_n_q is "TRUE"

//-----------------------------------------------------------------
// Next State
//-----------------------------------------------------------------
reg [3:0] state_next_r;
always @ *
begin
   state_next_r = state_q;
   
   case (state_q)
   
   //--------------------------------------------------------------
   // MEM_IDLE
   //--------------------------------------------------------------       
   MEM_IDLE : 
   begin
       // Write operation
       if (ram_wr_go_w) // B2 
       begin
           // Write wait states? (WRITE_WAIT_CYCLES)
           if (WRITE_WAIT_CYCLES != 4'b0000)
                state_next_r = MEM_WAIT_WRITE1;
           // No wait states for WRITEs
           else
                state_next_r = MEM_WRITE_DATA1;
       end
       // Read operation
       else if (ram_rd_w & ram_req_w)
       begin
           // Read wait states? (READ_WAIT_CYCLES)
           if (READ_WAIT_CYCLES != 4'b0000)
                state_next_r = MEM_WAIT_READ1;
           // No wait states for READs
           else
                state_next_r = MEM_READ_DATA1;
       end
   end
   //--------------------------------------------------------------
   // MEM_WRITE_DATA1
   //--------------------------------------------------------------          
   MEM_WRITE_DATA1 : 
   begin
       // Write hold states? (WRITE_HOLD_CYCLES)
       if (WRITE_HOLD_CYCLES != 4'b0000)
            state_next_r = MEM_WAIT_HOLD1;
       // No wait states for WRITEs
       else
            state_next_r = MEM_WRITE_SETUP2;
   end
   //--------------------------------------------------------------
   // MEM_WRITE_SETUP2
   //--------------------------------------------------------------
   MEM_WRITE_SETUP2 : 
   begin
       // Write wait states? (WRITE_WAIT_CYCLES)
       if (WRITE_WAIT_CYCLES != 4'b0000)
            state_next_r = MEM_WAIT_HOLD2;
       // No wait states for WRITEs
       else
            state_next_r = MEM_WRITE_DATA2;
   end
   //--------------------------------------------------------------
   // MEM_WRITE_DATA2
   //--------------------------------------------------------------
   MEM_WRITE_DATA2 : 
   begin
       // Write wait states? (WRITE_WAIT_CYCLES)
       if (WRITE_HOLD_CYCLES != 4'b0000)
            state_next_r = MEM_WAIT_HOLD3;
       // No wait states for end of write
       else    
          state_next_r   = MEM_IDLE;
   end
   //--------------------------------------------------------------
   // MEM_READ_DATA1
   //--------------------------------------------------------------
   MEM_READ_DATA1 : 
   begin          
       // Read wait states? (READ_WAIT_CYCLES)
       if (READ_WAIT_CYCLES != 4'b0000)
            state_next_r = MEM_WAIT_READ2;
       // No wait states for READs
       else
            state_next_r = MEM_READ_DATA2;
   end
   //--------------------------------------------------------------
   // MEM_READ_DATA2
   //--------------------------------------------------------------
   MEM_READ_DATA2 : 
   begin
       // Next read command pending?
       if (ram_req_w & ram_rd_w)
       begin
            // Read wait states? (READ_WAIT_CYCLES)
            if (READ_WAIT_CYCLES != 4'b0000)
                state_next_r = MEM_WAIT_READ1;
            // No wait states for READs
            else
                state_next_r = MEM_READ_DATA1;
       end
       // No read pending, return to idle
       else
       begin
            // Done!
            state_next_r    = MEM_IDLE;
       end
   end
   //--------------------------------------------------------------
   // MEM_WAIT_READ1
   //--------------------------------------------------------------
   MEM_WAIT_READ1 : 
   begin
        // Wait expired?
        if (wait_q == 4'b0001)
            state_next_r = MEM_READ_DATA1;
   end
   //--------------------------------------------------------------
   // MEM_WAIT_READ2
   //--------------------------------------------------------------
   MEM_WAIT_READ2 : 
   begin
        // Wait expired?
        if (wait_q == 4'b0001)
            state_next_r = MEM_READ_DATA2;
   end
   //--------------------------------------------------------------
   // MEM_WAIT_WRITE1
   //--------------------------------------------------------------
   MEM_WAIT_WRITE1 : 
   begin
        // Wait expired?
        if (wait_q == 4'b0001)
            state_next_r = MEM_WRITE_DATA1;
   end   
   //--------------------------------------------------------------
   // MEM_WAIT_HOLD1
   //--------------------------------------------------------------
   MEM_WAIT_HOLD1 : 
   begin
        // Wait expired?
        if (wait_q == 4'b0001)
            state_next_r = MEM_WRITE_SETUP2;
   end
   //--------------------------------------------------------------
   // MEM_WAIT_HOLD2
   //--------------------------------------------------------------
   MEM_WAIT_HOLD2 : 
   begin
        // Wait expired?
        if (wait_q == 4'b0001)
            state_next_r = MEM_WRITE_DATA2;
   end
   //--------------------------------------------------------------
   // MEM_WAIT_HOLD3
   //--------------------------------------------------------------
   MEM_WAIT_HOLD3 : 
   begin
        // Wait expired?
        if (wait_q == 4'b0001)
            state_next_r = MEM_IDLE;
   end   
   default : 
        ;
   endcase
end

//-----------------------------------------------------------------
// State Machine
//-----------------------------------------------------------------
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin 
   wait_q         <= 4'b0000;
   state_q        <= MEM_IDLE;
end
else 
begin

   state_q <= state_next_r;
   
   case (state_q)
   
   //--------------------------------------------------------------
   // MEM_IDLE
   //--------------------------------------------------------------       
   MEM_IDLE : 
   begin
       // Write operation
       if (ram_wr_go_w) // B2 
       begin
           // Write wait states? (WRITE_WAIT_CYCLES)
           wait_q    <= WRITE_WAIT_CYCLES;
       end
       // Read operation
       else if (ram_rd_w) // B2
       begin
           // Read wait states? (READ_WAIT_CYCLES)
           wait_q    <= READ_WAIT_CYCLES;
       end
   end
   //--------------------------------------------------------------
   // MEM_WRITE_DATA1
   //--------------------------------------------------------------          
   MEM_WRITE_DATA1 : 
   begin
       // Write hold states? (WRITE_HOLD_CYCLES)
        wait_q    <= WRITE_HOLD_CYCLES;
   end
   //--------------------------------------------------------------
   // MEM_WRITE_DATA2
   //--------------------------------------------------------------          
   MEM_WRITE_DATA2 : 
   begin
       // Write hold states? (WRITE_HOLD_CYCLES)
       wait_q    <= WRITE_HOLD_CYCLES;
   end       
   //--------------------------------------------------------------
   // MEM_WRITE_SETUP2
   //--------------------------------------------------------------
   MEM_WRITE_SETUP2 : 
   begin
       // Write wait states? (WRITE_WAIT_CYCLES)
       wait_q    <= WRITE_WAIT_CYCLES;
   end
   //--------------------------------------------------------------
   // MEM_READ_DATA1
   //--------------------------------------------------------------
   MEM_READ_DATA1 : 
   begin          
       // Read wait states? (READ_WAIT_CYCLES)
       wait_q    <= READ_WAIT_CYCLES;
   end
   //--------------------------------------------------------------
   // MEM_READ_DATA2
   //--------------------------------------------------------------
   MEM_READ_DATA2 : 
   begin
        // Read wait states? (READ_WAIT_CYCLES)
        wait_q    <= READ_WAIT_CYCLES;
   end
   //--------------------------------------------------------------
   // MEM_WAIT
   //--------------------------------------------------------------         
   MEM_WAIT_READ1,
   MEM_WAIT_READ2, 
   MEM_WAIT_WRITE1,
   MEM_WAIT_HOLD1, 
   MEM_WAIT_HOLD2,
   MEM_WAIT_HOLD3:
   begin
        // Decrement wait state counter
        wait_q    <= wait_q - 4'd1;
   end
   default : 
        ;
   endcase
end

//-----------------------------------------------------------------
// Memory Access
//-----------------------------------------------------------------       
always @ (posedge clk_i or posedge rst_i)
if (rst_i)
begin 
   sram_oe_n_q     <= 1'b1;
   sram_we_n_q     <= 1'b1;
   sram_address_q  <= 32'b0;
   sram_data_q     <= 16'h0000;
   sram_be_n_q     <= 2'b11;
   ack_q           <= 1'b0;
   data_q          <= 32'h00000000;
   we_q            <= 2'b00;
   data_out_en_q   <= 1'b0; // B3
end
else 
begin 

   ack_q      <= 1'b0;
   
   case (state_q)
   
   //--------------------------------------------------------------
   // MEM_IDLE
   //--------------------------------------------------------------       
   MEM_IDLE : 
   begin
       // Write operation
       if (ram_wr_go_w) // B2 
       begin           
           // Store operation details
           data_q           <= ram_write_data_w;
           we_q             <= ram_wr_w[3:2];

           // Start first cycle
           sram_address_q   <= {1'b0, ram_addr_w[31:1]};
           sram_data_q      <= ram_write_data_w[15:0];
           sram_be_n_q      <= ~ram_wr_w[1:0];
           sram_we_n_q      <= 1'b0;
           data_out_en_q    <= 1'b1; // B3
       end
       // Read operation
       else if (ram_rd_w) // B2
       begin
           // Store operation details
           data_q           <= 32'h00000000;
           we_q             <= 2'b00;

           // Start first cycle
           sram_address_q   <= {1'b0, ram_addr_w[31:1]};
           sram_data_q      <= 16'h0000;
           sram_be_n_q      <= 2'b00;
           sram_we_n_q      <= 1'b1;
           sram_oe_n_q      <= 1'b0;
           data_out_en_q    <= 1'b0; // B3
       end
       // Escrita com strobe nulo: so responde, sem acessar a SRAM
       else if (ram_wr_req_i) // B2
       begin // B2
           ack_q            <= 1'b1; // B2
       end // B2
   end
   //--------------------------------------------------------------
   // MEM_WRITE_DATA1
   //--------------------------------------------------------------          
   MEM_WRITE_DATA1 : 
   begin
       // Perform write
       sram_we_n_q    <= 1'b1;
   end
   //--------------------------------------------------------------
   // MEM_WRITE_SETUP2
   //--------------------------------------------------------------
   MEM_WRITE_SETUP2 : 
   begin
       // Setup write for upper word
       sram_address_q     <= sram_address_q + 32'd1;
       sram_be_n_q        <= ~we_q;
       sram_data_q        <= data_q[31:16];
       sram_we_n_q        <= 1'b0;
   end
   //--------------------------------------------------------------
   // MEM_WRITE_DATA2
   //--------------------------------------------------------------
   MEM_WRITE_DATA2,
   MEM_WAIT_HOLD3 : 
   begin 
       // Perform write
       sram_we_n_q    <= 1'b1;

       if (state_next_r == MEM_IDLE)
          ack_q        <= 1'b1;
       if (state_next_r == MEM_IDLE) // B3
          data_out_en_q <= 1'b0; // B3
   end
   //--------------------------------------------------------------
   // MEM_READ_DATA1
   //--------------------------------------------------------------
   MEM_READ_DATA1 : 
   begin
       // Keep OE low during multi-cycle read
       sram_oe_n_q    <= 1'b0;
       
       // Load lower word
       data_q         <= {16'h0000, sram_data_in_i[15:0]};
       
       // Output next address
       sram_address_q <= sram_address_q + 32'd1;
   end
   //--------------------------------------------------------------
   // MEM_READ_DATA2
   //--------------------------------------------------------------
   MEM_READ_DATA2 : 
   begin
       // Load upper word
       data_q         <= {sram_data_in_i[15:0], data_q[15:0]};

       // Data ready!
       ack_q          <= 1'b1;

       // Next read request pending?
       if (ram_req_w & ram_rd_w)
       begin
           // Start from next address
           sram_address_q   <= {1'b0, ram_addr_w[31:1]};
       end
       else
       begin
            // Deselect RAM and return to idle
            sram_oe_n_q     <= 1'b1;
       end
   end
   
   default : 
        ;
   endcase
end
   
assign ram_read_data_w = data_q;
assign ram_accept_w    = ~((state_q != MEM_IDLE) ? ~ack_q : 1'b0);
assign ram_ack_w       = ack_q;

//-----------------------------------------------------------------
// SRAM pins
//-----------------------------------------------------------------
assign sram_address_o  = sram_address_q;
assign sram_data_out_o = sram_data_q;
assign sram_oe_n_o     = sram_oe_n_q;
assign sram_cs_n_o     = 1'b0;
assign sram_be_n_o     = sram_be_n_q;
assign sram_we_n_o     = sram_we_n_q;
assign sram_data_out_en_o = data_out_en_q; // B3


endmodule