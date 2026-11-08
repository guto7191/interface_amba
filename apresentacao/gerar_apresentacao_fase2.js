// Gera apresentacao_axi4_sram_fase2.pptx com o template de apresentacao_axi_sram.pptx.
//
//   NODE_PATH=<node_modules com pptxgenjs> node apresentacao/gerar_apresentacao_fase2.js
//
// Os layouts (TITULO, CONTEUDO, ESCURO) repetem a geometria do original e, depois de
// gravado, o tema do original (paleta "AXI SRAM", Cambria/Calibri) é copiado para o novo
// arquivo. Fontes dos números: docs/MAS_axi4_sram.md e build/report.md.
const path = require("path");
const fs = require("fs");
const pptxgen = require("pptxgenjs");
const JSZip = require(require.resolve("jszip", { paths: [require.resolve("pptxgenjs")] }));

const DIR = __dirname;
const TEMPLATE = path.join(DIR, "apresentacao_axi_sram.pptx");
const OUT = path.join(DIR, "apresentacao_axi4_sram_fase2.pptx");

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9"; // 10" x 5,625", igual ao original
pres.title = "Subordinado AXI4 com SRAM externa";
pres.author = "TCC";
pres.company = "TCC";
pres.theme = { headFontFace: "Cambria", bodyFontFace: "Calibri" };

const C = pres.SchemeColor;
const MONO = "Courier New";
const HEAD = "Cambria";
const SHAPE = pres.shapes;

// ---------------------------------------------------------------- layouts
const SLIDE_NUM = { x: 9.1, y: 5.25, w: 0.5, h: 0.25, fontSize: 10, color: C.accent5, align: "right" };

pres.defineSlideMaster({
	title: "TITULO",
	background: { color: C.text2 },
	objects: [
		{ placeholder: { options: { name: "title", type: "title", x: 0.7, y: 1.5, w: 8.6, h: 1.4, fontSize: 40, bold: true, color: C.background1, align: "left" }, text: "" } },
		{ placeholder: { options: { name: "body", type: "body", x: 0.7, y: 3.1, w: 8.6, h: 1.2, fontSize: 18, color: C.background2, align: "left" }, text: "" } },
	],
});
pres.defineSlideMaster({
	title: "CONTEUDO",
	background: { color: C.background1 },
	objects: [
		{ placeholder: { options: { name: "title", type: "title", x: 0.5, y: 0.3, w: 9.0, h: 0.75, fontSize: 30, bold: true, color: C.text2, align: "left" }, text: "" } },
	],
	slideNumber: SLIDE_NUM,
});
pres.defineSlideMaster({
	title: "ESCURO",
	background: { color: C.text2 },
	objects: [
		{ placeholder: { options: { name: "title", type: "title", x: 0.5, y: 0.3, w: 9.0, h: 0.75, fontSize: 30, bold: true, color: C.background1, align: "left" }, text: "" } },
	],
	slideNumber: { ...SLIDE_NUM },
});

// ---------------------------------------------------------------- auxiliares
let seq = 0;
const nome = (p) => `${p}_${++seq}`;

function titulo(slide, text) {
	slide.addText(text, { placeholder: "title", margin: 0, valign: "middle" });
}

function texto(slide, text, o) {
	slide.addText(text, { isTextBox: true, margin: 0, valign: "top", fontSize: 16, color: C.text1, objectName: nome("txt"), ...o });
}

function bullets(slide, itens, o) {
	const runs = itens.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < itens.length - 1 } }));
	texto(slide, runs, { paraSpaceAfter: 10, ...o });
}

function cartao(slide, x, y, w, h, fill, o = {}) {
	slide.addShape(SHAPE.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: o.r || 0.08, fill: { color: fill }, line: o.line, objectName: nome(o.name || "cartao") });
}

// Bloco de módulo: nome em mono negrito, descrição abaixo (como no slide 3 original).
function modulo(slide, x, y, w, h, nomeMod, desc, o = {}) {
	const runs = [{ text: nomeMod, options: { fontSize: o.size || 14, bold: true, breakLine: !!desc } }];
	if (desc) runs.push({ text: desc, options: { fontSize: 12 } });
	slide.addText(runs, {
		shape: SHAPE.ROUNDED_RECTANGLE, rectRadius: 0.08, x, y, w, h,
		fill: o.fill ? { color: o.fill } : undefined,
		line: o.line,
		fontFace: MONO, color: o.color || C.background1, align: "center", valign: "middle", margin: 0.01,
		objectName: nome("modulo"),
	});
}

// Seta reta de (x1,y1) a (x2,y2).
function seta(slide, x1, y1, x2, y2, o = {}) {
	slide.addShape(SHAPE.LINE, {
		x: Math.min(x1, x2), y: Math.min(y1, y2), w: Math.abs(x2 - x1), h: Math.abs(y2 - y1),
		flipH: x2 < x1, flipV: y2 < y1,
		line: { color: o.color || C.accent5, width: o.width || 1.75, dashType: o.dash || "solid", endArrowType: o.noArrow ? undefined : "triangle" },
		objectName: nome("seta"),
	});
}

function rotulo(slide, text, x, y, w, o = {}) {
	texto(slide, text, { x, y, w, h: o.h || 0.25, fontSize: o.size || 11, color: o.color || C.accent5, align: o.align || "left", ...o.extra });
}

function numero(slide, n, x, y) {
	slide.addText(String(n), { shape: SHAPE.OVAL, x, y, w: 0.55, h: 0.55, fill: { color: C.accent1 }, fontSize: 16, color: C.background1, align: "center", valign: "middle", margin: 0, objectName: nome("numero") });
}

function itemNumerado(slide, n, x, y, w, cabeca, corpo) {
	numero(slide, n, x, y + 0.1);
	texto(slide, cabeca, { x: x + 0.75, y, w, h: 0.35, fontFace: HEAD, fontSize: 18, color: C.text2 });
	texto(slide, corpo, { x: x + 0.75, y: y + 0.4, w, h: 0.7, fontSize: 14 });
}

function destaque(slide, x, y, w, h, valor, legenda, o = {}) {
	cartao(slide, x, y, w, h, C.background2);
	const wv = o.wv || 1.7;
	texto(slide, valor, { x: x + 0.2, y, w: wv, h, fontFace: HEAD, fontSize: o.size || 24, color: C.accent1, valign: "middle" });
	texto(slide, legenda, { x: x + 0.25 + wv, y, w: w - wv - 0.4, h, fontSize: 14, valign: "middle" });
}

function tabela(slide, linhas, o) {
	const borda = { type: "solid", pt: 0.75, color: "7A8B99" };
	const rows = linhas.map((l, i) => l.map((cel, j) => ({
		text: cel,
		options: i === 0
			? { bold: true, color: C.background1, fill: { color: C.accent1 }, fontSize: o.size || 14 }
			: { color: C.text1, fontSize: o.size || 14, fontFace: o.monoCol === j ? MONO : undefined },
	})));
	slide.addTable(rows, { x: o.x, y: o.y, w: o.w, colW: o.colW, rowH: o.rowH, border: borda, valign: "middle", margin: [0.05, 0.1, 0.05, 0.1], objectName: nome("tabela") });
}

// ================================================================= slide 1
{
	const s = pres.addSlide({ masterName: "TITULO" });
	s.addText("Subordinado AXI4 com SRAM externa", { placeholder: "title", margin: 0, valign: "bottom" });
	s.addText([
		{ text: "Nova arquitetura: burst, IDs e controladora com pipeline", options: { breakLine: true } },
		{ text: "TCC · Reunião de orientação · outubro de 2026", options: { color: C.accent2 } },
	], { placeholder: "body", margin: 0, valign: "top" });
	s.addNotes(
		"Esta reunião apresenta a nova arquitetura do subordinado. A versão anterior era um subordinado AXI4-Lite " +
		"sobre uma RAM interna de 16 palavras. A nova é um subordinado AXI4 completo, com burst, IDs e transferências " +
		"estreitas, que acessa a SRAM externa de 2 MB da DE2-115. O roteiro: o que mudou, o diagrama de blocos, " +
		"como a IP de terceiros foi aproveitada, o tratamento de erros, o contrato ram_* que separa o frontend da " +
		"controladora, a FSM com pipeline, a temporização e os resultados da verificação. Fecho com limitações e " +
		"próximos passos. Tempo previsto: cerca de um minuto por slide."
	);
}

// ================================================================= slide 2
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Da versão Lite ao AXI4 completo");
	bullets(s, [
		"Antes: AXI4-Lite sobre RAM interna de 16 palavras",
		"Agora: AXI4 com burst INCR, IDs e AxSIZE de 1, 2 e 4 bytes",
		"Memória: SRAM externa da DE2-115, barramento de 16 bits",
		"Núcleo da IP Ultra-Embedded (LGPL) em fork auditável",
		"Controladora trocável: Fase 1 (base) ou Fase 2 (pipeline)",
	], { x: 0.5, y: 1.4, w: 4.7, h: 3.6 });
	const stats = [
		["2 MB", "SRAM endereçável (R-07)"],
		["256", "beats por endereço (até 1 KB, R-02)"],
		["4", "transações em voo (R-13)"],
		["50 MHz", "clock único, sem PLL (D2)"],
	];
	stats.forEach(([v, l], i) => destaque(s, 5.6, 1.35 + i * 0.95, 3.9, 0.8, v, l, { size: 28, wv: 1.45 }));
	s.addNotes(
		"A mudança é de escopo. Antes, o subordinado falava AXI4-Lite, uma transferência por vez, sem ID, sobre uma " +
		"RAM de 16 palavras dentro do FPGA. Agora ele fala AXI4 completo, com burst: o mestre envia um único " +
		"endereço e, em seguida, uma sequência de transferências de dados, os beats. O campo AWLEN ou ARLEN, de 0 a " +
		"255, indica de 1 a 256 beats, e é o subordinado que calcula o endereço de cada beat seguinte. Com 4 bytes " +
		"por beat, um único burst move até 1 KB; no Lite, cada palavra exigia o próprio endereço e o próprio " +
		"handshake. Pela norma, o burst não pode cruzar uma fronteira de 4 KB. Além do burst, há IDs, com respostas " +
		"ordenadas por ID, e transferências estreitas de 1, 2 ou 4 bytes. A memória passou a ser a SRAM " +
		"IS61WV102416BLL da placa, com 2 MB e barramento de dados de 16 bits, o que faz cada beat de 32 bits exigir " +
		"dois acessos. Em vez de escrever o frontend AXI4 do zero, o projeto aproveita a IP asram16_axi4 da " +
		"Ultra-Embedded, sob LGPL, num fork. E a controladora da SRAM fica atrás de um contrato fixo, o que permite " +
		"trocar a versão base, Fase 1, pela versão com pipeline, Fase 2."
	);
}

// ================================================================= slide 3
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Arquitetura");
	// hierarquia
	cartao(s, 2.15, 1.2, 7.35, 3.25, C.background2, { r: 0.1, name: "top", line: { color: C.accent5, width: 1.25, dashType: "dash" } });
	rotulo(s, "de2_115_top.v  ›  axi_interface_subordinate_sram.v", 2.35, 1.27, 6.0, { size: 12 });
	// agente externo e frontend AXI4
	modulo(s, 0.5, 1.6, 1.35, 0.75, "Mestre AXI4", "externo", { fill: C.accent5, size: 12 });
	modulo(s, 2.35, 1.6, 2.0, 0.75, "decoder", "faixa · erros", { fill: C.accent1 });
	modulo(s, 5.3, 1.6, 2.3, 0.75, "transaction_mgr", "burst · ID · FIFOs", { fill: C.accent1, line: { color: C.accent2, width: 2.25, dashType: "dash" }, size: 13 });
	modulo(s, 3.85, 2.5, 1.95, 0.55, "read_align", "", { fill: C.accent1, size: 13 });
	seta(s, 1.85, 1.98, 2.35, 1.98);
	seta(s, 4.35, 1.85, 5.3, 1.85);
	rotulo(s, "AW · W · AR", 4.4, 1.55, 0.9, { size: 10 });
	seta(s, 5.6, 2.35, 5.3, 2.5);
	seta(s, 3.85, 2.78, 3.35, 2.35);
	rotulo(s, "R", 3.3, 2.6, 0.3);
	// contrato ram_*
	seta(s, 2.35, 3.2, 9.3, 3.2, { color: C.accent2, width: 2.25, dash: "dash", noArrow: true });
	rotulo(s, "contrato ram_*", 2.35, 2.92, 1.5, { color: C.text2, size: 11 });
	seta(s, 6.45, 2.35, 6.45, 3.4);
	// controladoras e pinos
	modulo(s, 2.35, 3.4, 2.4, 0.8, "baseline", "Fase 1 · não instanciada", { line: { color: C.accent5, width: 1.25, dashType: "dash" }, color: C.accent5 });
	modulo(s, 5.3, 3.4, 2.3, 0.8, "sram_controller", "Fase 2 · pipeline", { fill: C.text2, size: 13 });
	modulo(s, 8.0, 3.4, 1.3, 0.8, "io_buffer", "tri-state DQ", { fill: C.accent3, color: C.text2, size: 13 });
	seta(s, 7.6, 3.8, 8.0, 3.8);
	modulo(s, 8.0, 4.6, 1.3, 0.5, "SRAM 2 MB", "", { fill: C.accent5, size: 12 });
	seta(s, 8.65, 4.2, 8.65, 4.6, { width: 2.25 });
	rotulo(s, "DQ[15:0]", 7.05, 4.68, 0.9, { align: "right" });
	// legenda
	modulo(s, 0.5, 4.68, 0.3, 0.2, "", "", { fill: C.accent1 });
	rotulo(s, "projeto", 0.88, 4.65, 0.8);
	modulo(s, 1.75, 4.68, 0.3, 0.2, "", "", { fill: C.accent1, line: { color: C.accent2, width: 1.75, dashType: "dash" } });
	rotulo(s, "fork da IP (LGPL)", 2.13, 4.65, 1.5);
	modulo(s, 3.7, 4.68, 0.3, 0.2, "", "", { fill: C.text2 });
	rotulo(s, "controladora", 4.08, 4.65, 1.1);
	s.addNotes(
		"Diagrama com PHASE = 2, a configuração padrão do de2_115_top. O mestre AXI4 fica fora do escopo. O " +
		"axi_address_decoder recebe o AXI4, valida endereço e tamanho e, se estiver tudo certo, repassa a transação ao " +
		"axi_transaction_manager, que é o fork da IP: ele resolve burst, IDs, arbitragem e os FIFOs de 4 entradas. Na " +
		"volta da leitura, o axi_narrow_read_align posiciona o dado na byte lane certa antes de o R sair pelo " +
		"decoder. A linha tracejada é o contrato ram_*: tudo acima é frontend AXI, tudo abaixo é controladora. Abaixo " +
		"dela fica o sram_controller com pipeline; a versão base da Fase 1 aparece tracejada porque não está " +
		"instanciada. O sram_io_buffer faz o tri-state do barramento DQ de 16 bits que vai à SRAM."
	);
}

// ================================================================= slide 4
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Fusão com a IP Ultra-Embedded");
	itemNumerado(s, 1, 0.5, 1.35, 3.6, "IP como núcleo (D1)", "Burst, ID, arbitragem e FIFOs vêm de asram16_axi4_pmem.v");
	itemNumerado(s, 2, 0.5, 2.6, 3.6, "Fork auditável (D10)", "axi_transaction_manager, alterações A0–A7; original intocado");
	itemNumerado(s, 3, 0.5, 3.85, 3.6, "Fase 1 = FSM da IP (D14)", "sram_controller_baseline, alterações B0–B3, já no contrato ram_*");
	tabela(s, [
		["Restrição da IP", "Contorno"],
		["DQ sem sinal de direção", "sram_io_buffer"],
		["Endereço de 32 bits", "truncado a 20; DECERR"],
		["Respostas sempre OKAY", "decoder gera DECERR e SLVERR"],
		["Esperas de 7 ciclos", "reduzidas a 1 (Fase 1)"],
		["Sem AxSIZE", "fork + read_align"],
	], { x: 5.0, y: 1.4, w: 4.5, colW: [2.0, 2.5], rowH: 0.5, size: 13 });
	rotulo(s, "MAS §1.5, restrições L-01, L-02, L-03, L-05 e L-07", 5.0, 4.6, 4.5);
	s.addNotes(
		"A decisão D1 foi fundir: a IP asram16_axi4 da Ultra-Embedded já resolve a parte trabalhosa do AXI4, que é " +
		"burst, ID, arbitragem e FIFOs, e o projeto escreve as camadas em volta dela. Pela D10, a IP foi copiada para " +
		"o fork axi_transaction_manager, com as alterações marcadas de A0 a A7, e o arquivo original continua no " +
		"repositório sem mudança, o que a LGPL exige e deixa o diff auditável. Pela D14, a FSM da IP virou a " +
		"controladora da Fase 1, já com o contrato ram_*. A tabela mostra as restrições herdadas da IP e onde cada uma " +
		"foi contornada: direção do barramento, largura de endereço, ausência de respostas de erro, esperas longas e a " +
		"falta de suporte a AxSIZE, que violava a norma."
	);
}

// ================================================================= slide 5
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Erros e transferências estreitas");
	const cards = [
		[0.5, "Erros de endereço e tamanho", ["Fora de 2 MB: DECERR", "AxSIZE acima de 4 bytes: SLVERR", "O burst inteiro é drenado"], "axi_address_decoder.v"],
		[5.1, "Transferências estreitas", ["AxSIZE de 1, 2 ou 4 bytes", "Endereço avança 2^AxSIZE", "Dado lido na byte lane certa"], "axi_narrow_read_align.v"],
	];
	for (const [x, cab, linhas, arq] of cards) {
		cartao(s, x, 1.3, 4.4, 1.9, C.background2);
		texto(s, cab, { x: x + 0.25, y: 1.42, w: 3.9, h: 0.4, fontFace: HEAD, fontSize: 20, color: C.accent1 });
		texto(s, linhas.join("\n"), { x: x + 0.25, y: 1.88, w: 3.9, h: 0.9 });
		texto(s, arq, { x: x + 0.25, y: 2.8, w: 3.9, h: 0.3, fontFace: MONO, fontSize: 12, color: C.accent5 });
	}
	texto(s, "Leitura de 4 beats de 1 byte a partir de 0x01 (AxSIZE = 0)", { x: 0.5, y: 3.5, w: 9.0, h: 0.35 });
	[["beat 1", "lane 1 · 0x01"], ["beat 2", "lane 2 · 0x02"], ["beat 3", "lane 3 · 0x03"], ["beat 4", "lane 0 · 0x04"]].forEach(([b, l], i) =>
		modulo(s, 0.5 + i * 2.3, 3.95, 2.1, 0.95, b, l, { fill: i === 3 ? C.accent2 : C.accent1, color: i === 3 ? C.text2 : C.background1, size: 16 })
	);
	s.addNotes(
		"A IP original sempre respondia OKAY. Agora o axi_address_decoder intercepta a transação antes da IP: " +
		"endereço fora dos 2 MB recebe DECERR, sem aliasing, e AxSIZE maior que 4 bytes, ilegal num barramento de 32 " +
		"bits, recebe SLVERR. Em ambos os casos o burst é drenado: numa leitura saem arlen+1 beats com o erro e RLAST " +
		"no último; numa escrita os beats W são consumidos e sai uma única resposta B. À direita, as transferências " +
		"estreitas: o fork calcula o próximo endereço por 2 elevado a AxSIZE, a partir do endereço alinhado, e o " +
		"axi_narrow_read_align coloca o dado na byte lane correspondente. No exemplo, um burst de bytes a partir de " +
		"0x01 percorre as lanes 1, 2, 3 e volta à lane 0. As lanes não usadas recebem o dado replicado, decisão D12."
	);
}

// ================================================================= slide 6
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Contrato ram_*: a troca de fase");
	tabela(s, [
		["Sinal", "Dir.", "Função"],
		["ram_addr", "in", "endereço alinhado a 4 B"],
		["ram_rd", "in", "pede leitura"],
		["ram_wr_req", "in", "pede escrita (D16)"],
		["ram_wr", "in", "strobes; 0000 é válido"],
		["ram_size", "in", "tamanho do beat"],
		["ram_accept", "out", "requisição consumida"],
		["ram_ack", "out", "1 ciclo por resposta"],
	], { x: 0.5, y: 1.35, w: 4.7, colW: [1.6, 0.6, 2.5], rowH: 0.4, size: 12, monoCol: 0 });
	itemNumerado(s, 1, 5.5, 1.35, 3.25, "Exclusividade", "Leitura e escrita nunca pedem no mesmo ciclo");
	itemNumerado(s, 2, 5.5, 2.55, 3.25, "Ordem", "Respostas na ordem das requisições; é o que cumpre R-03");
	itemNumerado(s, 3, 5.5, 3.75, 3.25, "Pipeline", "Requisições em voo: 1 na Fase 1, 2 na Fase 2");
	s.addNotes(
		"O contrato ram_* é a fronteira que torna as duas fases intercambiáveis: qualquer controladora que o respeite " +
		"substitui a outra sem mexer no frontend AXI. A tabela mostra os sinais principais; ainda há ram_write_data e " +
		"ram_read_data. Duas alterações merecem nota: ram_wr_req, da decisão D16, porque na IP um beat W com strobe " +
		"zero não gerava requisição e o burst travava; e o alinhamento de ram_addr a 4 bytes no wrapper, D17. As " +
		"regras: leitura e escrita nunca pedem no mesmo ciclo, quem garante é o árbitro do frontend; as respostas " +
		"voltam na ordem em que as requisições foram aceitas, o que permite casar cada uma com o FIFO e cumpre a " +
		"ordenação por ID; e a controladora pode aceitar a próxima requisição antes de responder a anterior: uma em " +
		"voo na Fase 1, duas na Fase 2. Esse é o pipeline."
	);
}

// ================================================================= slide 7
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "sram_controller: FSM com pipeline");
	const st = (x, y, w, t, fill) => modulo(s, x, y, w, 0.6, t, "", { fill: fill || C.accent1, color: fill === C.accent2 ? C.text2 : C.background1, size: 14 });
	st(0.5, 2.55, 1.3, "IDLE");
	st(3.0, 1.55, 1.7, "RD_LOW");
	st(6.2, 1.55, 1.7, "RD_HIGH");
	const wx = [2.2, 4.05, 5.9, 7.75];
	["WR_LOW", "WR_LOW_HOLD", "WR_HIGH", "WR_HIGH_HOLD"].forEach((t, i) => st(wx[i], 3.55, 1.65, t));
	// entradas a partir de IDLE
	seta(s, 1.8, 2.7, 3.0, 1.95);
	rotulo(s, "leitura", 1.95, 2.0, 0.8);
	seta(s, 1.8, 3.0, 2.55, 3.55);
	rotulo(s, "escrita", 1.2, 3.35, 0.8, { align: "right" });
	// sequências
	seta(s, 4.7, 1.85, 6.2, 1.85);
	for (let i = 0; i < 3; i++) seta(s, wx[i] + 1.65, 3.85, wx[i + 1], 3.85);
	// pipeline de leitura: RD_HIGH -> RD_LOW por cima
	const AMB = { color: C.accent2, width: 2.25 };
	seta(s, 7.05, 1.55, 7.05, 1.33, { ...AMB, noArrow: true });
	seta(s, 7.05, 1.33, 3.85, 1.33, { ...AMB, noArrow: true });
	seta(s, 3.85, 1.33, 3.85, 1.55, AMB);
	rotulo(s, "nova leitura", 4.8, 1.08, 1.3, { color: C.text2, size: 11 });
	// pipeline de escrita: WR_HIGH_HOLD -> WR_LOW por baixo
	seta(s, 8.55, 4.15, 8.55, 4.4, { ...AMB, noArrow: true });
	seta(s, 8.55, 4.4, 3.0, 4.4, { ...AMB, noArrow: true });
	seta(s, 3.0, 4.4, 3.0, 4.15, AMB);
	rotulo(s, "nova escrita", 5.2, 4.42, 1.3, { color: C.text2, size: 11 });
	// retorno a IDLE
	seta(s, 7.05, 2.15, 7.05, 2.85, { noArrow: true });
	seta(s, 8.55, 3.55, 8.55, 2.85, { noArrow: true });
	seta(s, 8.55, 2.85, 1.8, 2.85);
	rotulo(s, "fim do acesso", 4.8, 2.58, 1.3);
	texto(s, "Âmbar: transições de pipeline. Leitura ↔ escrita sempre passa por IDLE.", { x: 0.5, y: 4.8, w: 8.5, h: 0.3, fontSize: 14 });
	s.addNotes(
		"A FSM tem sete estados. A SRAM tem 16 bits, então cada beat de 32 bits vira dois acessos: metade baixa e " +
		"metade alta. Na leitura, RD_LOW apresenta o endereço baixo e RD_HIGH captura a palavra baixa e apresenta o " +
		"endereço alto. Na escrita, cada metade gasta dois estados: o pulso de WE_N e o hold. O ganho está nas setas em " +
		"âmbar: se já há uma nova leitura pendente em RD_HIGH, a FSM volta direto a RD_LOW, sem passar por IDLE; o " +
		"mesmo vale na escrita, de WR_HIGH_HOLD para WR_LOW. É isso que dá dois ciclos por beat na leitura e quatro na " +
		"escrita em regime de burst. Escritas parciais pulam a metade sem strobe, e uma escrita com strobe zero " +
		"responde sem acessar a SRAM. A troca entre leitura e escrita sempre passa por IDLE, o que garante um ciclo de " +
		"turnaround no barramento bidirecional sem estado extra."
	);
}

// ================================================================= slide 8
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Temporização: um ciclo por acesso");
	destaque(s, 0.5, 1.35, 4.3, 1.05, "20 ns", "período a 50 MHz, contra tAA = 10 ns da SRAM");
	destaque(s, 0.5, 2.55, 4.3, 1.05, "2 ciclos", "por meia palavra na escrita (pulso + hold, D15)");
	destaque(s, 0.5, 3.75, 4.3, 1.05, "1 clock", "sem PLL e sem CDC (D2, R-18)");
	// linha do tempo da leitura em burst
	cartao(s, 5.1, 1.35, 4.4, 3.45, C.text2);
	texto(s, "Leitura em burst: 2 ciclos por beat", { x: 5.3, y: 1.5, w: 4.0, h: 0.3, fontSize: 14, color: C.background1 });
	const cx = 6.2, cw = 0.52, cols = 6;
	const linhas = [
		["ciclo", ["1", "2", "3", "4", "5", "6"], null],
		["estado", ["LOW", "HIGH", "LOW", "HIGH", "LOW", "HIGH"], C.accent1],
		["endereço", ["n·lo", "n·hi", "n+1·lo", "n+1·hi", "n+2·lo", "n+2·hi"], C.accent3],
		["captura", ["", "n·lo", "n·hi", "n+1·lo", "n+1·hi", "n+2·lo"], C.accent2],
	];
	linhas.forEach(([nomeL, cels, cor], r) => {
		const y = 2.0 + r * 0.55;
		texto(s, nomeL, { x: 5.3, y, w: 0.85, h: 0.42, fontSize: 11, color: C.background2, valign: "middle" });
		for (let c = 0; c < cols; c++) {
			if (!cor) {
				texto(s, cels[c], { x: cx + c * cw, y, w: cw - 0.04, h: 0.42, fontFace: MONO, fontSize: 10, color: C.background2, align: "center", valign: "middle" });
			} else if (cels[c]) {
				modulo(s, cx + c * cw, y, cw - 0.04, 0.42, cels[c], "", { fill: cor, color: cor === C.accent1 ? C.background1 : C.text2, size: 8 });
			}
		}
	});
	// chave de um beat
	seta(s, cx, 4.3, cx + 2 * cw - 0.04, 4.3, { color: C.background2, width: 1.25, noArrow: true });
	texto(s, "1 beat de 32 bits", { x: cx, y: 4.38, w: 2.0, h: 0.3, fontSize: 11, color: C.background2 });
	s.addNotes(
		"Por que um ciclo basta. A SRAM é assíncrona: não tem clock nem comando, basta apresentar o endereço e esperar " +
		"o tAA, de 10 ns no grau de velocidade assumido. Com clock de 50 MHz, o período é de 20 ns, então o endereço " +
		"fica estável mais do que o dobro do necessário e cada acesso de leitura cabe num ciclo. A linha do tempo " +
		"mostra o pipeline: no mesmo ciclo em que a FSM captura uma metade, já apresenta o endereço da próxima, e o " +
		"beat de 32 bits sai a cada dois ciclos. Na escrita a escolha foi diferente, decisão D15: dois ciclos por meia " +
		"palavra, com WE_N baixo no primeiro e alto no segundo, mantendo endereço e dado. Isso evita gerar WE_N a " +
		"partir do clock e dá margem nos tempos de hold. Todo o projeto roda num único domínio de 50 MHz, sem PLL, e " +
		"por isso não há cruzamento de domínio de clock."
	);
}

// ================================================================= slide 9
{
	const s = pres.addSlide({ masterName: "CONTEUDO" });
	titulo(s, "Resultados: Fase 1 × Fase 2");
	s.addChart(pres.charts.BAR, [
		{ name: "Fase 1", labels: ["Leitura", "Escrita"], values: [4.04, 8.03] },
		{ name: "Fase 2", labels: ["Leitura", "Escrita"], values: [2.04, 4.04] },
	], {
		x: 0.5, y: 1.3, w: 4.9, h: 2.9, barDir: "col", barGrouping: "clustered", barGapWidthPct: 60,
		chartColors: ["7A8B99", "1F7A74"],
		showTitle: true, title: "Ciclos por beat de 32 bits (menor é melhor)", titleFontSize: 13, titleColor: "0F2F33", titleFontFace: "+mn-lt",
		showValue: true, dataLabelPosition: "outEnd", dataLabelFontSize: 11, dataLabelColor: "1B1F23", dataLabelFormatCode: "0.00", dataLabelFontFace: "+mn-lt",
		showLegend: true, legendPos: "b", legendFontSize: 11, legendFontFace: "+mn-lt", legendColor: "1B1F23",
		catAxisLabelColor: "1B1F23", catAxisLabelFontSize: 12, catAxisLabelFontFace: "+mn-lt",
		valAxisHidden: true, valAxisMaxVal: 9, valAxisMinVal: 0,
		valGridLine: { style: "none" }, catGridLine: { style: "none" },
		objectName: "grafico_ciclos",
	});
	texto(s, "Medido em simulação (build/report.md, T-S-PERF)", { x: 0.5, y: 4.2, w: 4.9, h: 0.25, fontSize: 11, color: C.accent5 });
	destaque(s, 5.6, 1.35, 3.9, 1.3, "62 MB/s", "vazão mista na Fase 2 (Fase 1: 32)", { size: 26, wv: 1.75 });
	destaque(s, 5.6, 2.85, 3.9, 1.3, "530", "ciclos de latência de cauda (Fase 1: 1555)", { size: 26, wv: 1.75 });
	cartao(s, 0.5, 4.5, 9.0, 0.6, C.text2);
	texto(s, "113 casos, 191 execuções: todas PASS · 11 sementes sem erro · cobertura obrigatória 100%", {
		x: 0.7, y: 4.5, w: 8.6, h: 0.6, fontSize: 13, color: C.background2, valign: "middle",
	});
	s.addNotes(
		"Os números vêm do relatório de verificação, medidos em simulação. Trocando só a controladora, a leitura cai " +
		"de 4,04 para 2,04 ciclos por beat, que é o mínimo teórico para dois acessos de 16 bits, e a escrita cai de " +
		"8,03 para 4,04. A vazão mista praticamente dobra, de 32 para 62 MB/s. A latência de cauda, medida com uma " +
		"leitura emitida no meio de um burst de escrita de 256 beats, cai de 1555 para 530 ciclos. Na verificação, " +
		"113 casos distintos, rodados contra as duas fases, somam 191 execuções, todas aprovadas, incluindo onze " +
		"sementes de estresse aleatório com cinco mil transações cada. A cobertura funcional obrigatória está em 100% " +
		"e a amostrada em 64,9%, acima da meta de 60%. O que ainda não existe é resultado de síntese na placa."
	);
}

// ================================================================= slide 10
{
	const s = pres.addSlide({ masterName: "ESCURO" });
	titulo(s, "Conclusão e próximos passos");
	const cols = [
		[0.5, C.accent6, "Pronto", ["AXI4 com burst, ID e AxSIZE", "Leitura a 2 ciclos por beat", "Verificação completa em simulação"]],
		[3.6, C.accent2, "Limitações", ["FIFOs de 4 entradas", "Arbitragem por comando", "Escrita a 4 ciclos por beat", "FIXED e WRAP viram INCR"]],
		[6.7, C.accent3, "Próximos passos", ["Compilar no Quartus e fechar timing", "Validar na DE2-115", "Integrar um mestre real"]],
	];
	for (const [x, cor, cab, itens] of cols) {
		cartao(s, x, 1.4, 2.9, 3.4, C.accent1);
		s.addShape(SHAPE.OVAL, { x: x + 0.25, y: 1.6, w: 0.4, h: 0.4, fill: { color: cor }, objectName: nome("marca") });
		texto(s, cab, { x: x + 0.8, y: 1.6, w: 2.0, h: 0.4, fontFace: HEAD, fontSize: 18, color: C.background1, valign: "middle" });
		bullets(s, itens, { x: x + 0.25, y: 2.25, w: 2.45, h: 2.4, fontSize: 14, color: C.background1, paraSpaceAfter: 8 });
	}
	s.addNotes(
		"Fechando. Está pronto o subordinado AXI4 com burst, ID e transferências estreitas, a controladora com " +
		"pipeline atingindo o mínimo teórico na leitura e a verificação completa em simulação. As limitações " +
		"assumidas: os FIFOs de quatro entradas herdados da IP limitam as transações em voo; a arbitragem é por " +
		"comando, o que alonga a latência de cauda do sentido preterido; a escrita gasta quatro ciclos por beat por " +
		"margem de temporização; e bursts FIXED e WRAP são tratados como INCR. Os próximos passos: compilar no " +
		"Quartus e fechar o timing com o SDC, inclusive nos pinos da SRAM, validar na DE2-115 e integrar um mestre " +
		"real, um processador soft-core ou um DMA. Abro para perguntas."
	);
}

// ---------------------------------------------------------------- gravação + tema do original
(async () => {
	await pres.writeFile({ fileName: OUT });
	const tpl = await JSZip.loadAsync(fs.readFileSync(TEMPLATE));
	const out = await JSZip.loadAsync(fs.readFileSync(OUT));
	out.file("ppt/theme/theme1.xml", await tpl.file("ppt/theme/theme1.xml").async("string"));
	fs.writeFileSync(OUT, await out.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
	console.log("gerado:", OUT);
})();
