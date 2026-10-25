// Coletor de cobertura funcional (VP §4.1), incluido dentro do modulo do TB.
// Cada transacao observada gera uma linha "len=.. type=.. strb=.. rdy=.. id=.. zone=.. size=..".
// scripts/merge_functional_coverage_bins.sh junta as linhas de todas as execucoes, confere as
// combinacoes obrigatorias e conta as celulas distintas do espaco de 6x2x6x3x3x4x3 = 7776.
//
// Os eixos "intermitencia de READY" e "ID" sao propriedades do modo de teste, nao da transacao:
// o teste os declara em cov_rdy (0 sempre pronto, 1 padrao 1010, 2 pseudoaleatorio) e
// cov_idmode (0 ID unico, 1 dois alternados, 2 dezesseis distintos) antes de emitir trafego.
// Escrita gera uma linha por BEAT de W (o padrao de wstrb e por beat); leitura, uma por burst.

integer cov_rdy    = 0;
integer cov_idmode = 0;
integer cov_fd     = 0;
reg [8*96-1:0] cov_fname;

initial begin
    $sformat(cov_fname, "build/cov/%0s.cov", `TB_NAME);
    cov_fd = $fopen(cov_fname, "a");
end

function [8*5-1:0] cov_zone(input [31:0] a);
    begin
        if (a >= 32'h0020_0000)      cov_zone = "out";
        else if (a < 32'h0000_1000)  cov_zone = "start";
        else if (a >= 32'h001F_F000) cov_zone = "end";
        else                         cov_zone = "mid";
    end
endfunction

function [8*6-1:0] cov_rdy_name(input integer m);
    begin
        case (m)
            1:       cov_rdy_name = "1010";
            2:       cov_rdy_name = "rand";
            default: cov_rdy_name = "always";
        endcase
    end
endfunction

function [8*8-1:0] cov_id_name(input integer m);
    begin
        case (m)
            1:       cov_id_name = "two";
            2:       cov_id_name = "sixteen";
            default: cov_id_name = "single";
        endcase
    end
endfunction

task cov_write_beat(input [31:0] addr, input [7:0] len, input [2:0] size, input [3:0] strb);
    begin
        if (cov_fd != 0)
            $fdisplay(cov_fd, "len=%0d type=W strb=%04b rdy=%0s id=%0s zone=%0s size=%0d",
                      len, strb, cov_rdy_name(cov_rdy), cov_id_name(cov_idmode), cov_zone(addr), size);
    end
endtask

task cov_read_burst(input [31:0] addr, input [7:0] len, input [2:0] size);
    begin
        if (cov_fd != 0)
            $fdisplay(cov_fd, "len=%0d type=R strb=---- rdy=%0s id=%0s zone=%0s size=%0d",
                      len, cov_rdy_name(cov_rdy), cov_id_name(cov_idmode), cov_zone(addr), size);
    end
endtask
