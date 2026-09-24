# OBLIVION — Documento de design

Remake em Godot 4.7 do mini game de enigmas "Oblivion" (versão de navegador, 2023,
Sistemas de Informação). Jogo de **terror, suspense e enigmas**. Mantém os enigmas originais e
as respostas; a história foi reescrita para ter uma tragédia concreta por trás de cada lugar,
uma ameaça que caça o jogador e um final com escolha.

## Pilares

- **Dois personagens, um jogador.** O jogador controla os dois (troca com `Tab`). Cada
  personagem só lê o que ele próprio encontrou: o diário e o bloco de notas são por personagem.
  A pergunta fica com um e a chave com o outro. Para passar informação de um para o outro, o
  jogador usa papel e caneta de verdade, como no original.
- **Terror que tem regra.** O Esquecido caça quem fica sozinho, patrulha e persegue; errar um
  enigma apaga as luzes; esconder-se e correr salvam. Nada de gore: sangue só na mão.
- **O hospital vaza para o sonho.** Bipes, chiado de rádio e vozes clínicas (legenda fria no
  alto da tela) contam, aos poucos, o que aconteceu fora do pesadelo.
- **Cada lugar é um pedaço daquela noite.** O jogador entende a história montando os lugares,
  as vozes do hospital e as 8 lembranças escondidas — nunca por sermão.
- **A culpa só aparece no fim.** Até o cap. 7 nada diz quem dirigia: as lembranças são
  fragmentos que A ainda consegue encarar, os objetos não são identificados em voz alta e as
  vozes do hospital só dão dados frios. O cap. 8 abre rachaduras (o exame de sangue, a
  esfinge); o cap. 9 junta tudo. Os personagens não explicam o que sentem: falas curtas,
  subtexto, perguntas sem resposta.
- **HD-2D.** Cenários 3D low-poly com textura pixel, sprites billboard, neblina volumétrica,
  câmera fixa a ~40°. Paleta noturna azulada; fase final branca que vira hospital.

## A história de verdade (o que o jogador descobre)

A (nome digitado, padrão "Ana") e B (padrão "Leo") são amigos desde crianças. Na noite do
aniversário de B, a festa foi na casa da família de B (a casa dos capítulos 5–7).

1. A tomou dois comprimidos do próprio remédio para dormir (a cabeça doía) e, depois, bebeu o
   que alguém ofereceu. A bula dizia "não dirija".
2. B pediu a chave do carro: "Vamos embora. Eu dirijo." A não entregou. Empurrou. "Eu sei dirigir."
3. Às 3:50, na estrada, B trocava a música e cantava alto, desafinado de propósito, para A não
   dormir. "Olha pra estrada."
4. **Às 4:15**, A fechou os olhos por um segundo. O carro saiu da ponte e caiu no riacho (o
   riacho do capítulo 1).
5. Debaixo d'água, o cinto de A não abria. B abriu por A e empurrou A pela janela quebrada,
   gritando **"SAIA!"**. A subiu. B não.
6. Os bombeiros tiraram os dois do rio. Os dois estão em coma no mesmo hospital: A no **leito
   `number_a`**, B no **leito `number_b`** (os números aleatórios que cada um "sente afinidade").
7. O pesadelo é a cabeça de A tentando **esquecer** (oblivion) que a culpa foi de A.

O **"SAIA!"** sussurrado pela casa não é ameaça: é B, naquela noite, salvando A. A lembrança 7
mostra que alguém gritou; só no final B diz que foi B.

### Como a verdade é dosada

| Cap. | O jogador sabe | Ainda não sabe |
|---|---|---|
| 1–3 | Os dois acordaram molhados; há luzes no fundo do riacho; houve uma festa | Que houve acidente; que estão em coma |
| 4–6 | Houve uma festa de aniversário de B; os dois estão num hospital | Quem dirigia; o que A tomou |
| 7 | Alguém gritou "SAIA!" debaixo d'água; o leito de B piorou | De quem era a voz |
| 8 | O sangue de A tinha remédio e álcool | Que A dirigia |
| 9 | Houve briga pela chave; A dirigia; B salvou A; o Esquecido é A | — |

### O Esquecido

Figura alta e magra, com o moletom de A encharcado, cabelo escorrido, e **a mão de sangue
cobrindo o rosto** (a arte original "rosto com a mão de sangue" é o susto dele). É a parte de A
que quer esquecer. Aparece em todo capítulo, cada vez mais perto e mais ousado. Quando alcança
alguém, sussurra "esqueça". No capítulo 9, abaixa a mão: o rosto é o de A.

Regras (ver `scripts/core/stalker.gd` e `LEVEL_GUIDE.md`):
- **Quem fica sozinho é caçado** (`lonely_watch`): quem segura uma placa/roda longe do parceiro
  ouve sussurros, depois ele surge atrás e anda até a vítima. Alcançou: susto e a vítima solta
  o que segurava.
- **Patrulha** (cap. 2, 4, 7): anda por uma rota, enxerga em cone, paredes bloqueiam a visão.
  Correr foge; esconderijos despistam. Alcançou: susto e os dois voltam ao último ponto seguro.
- **Errar custa** (`dread_light`): cada erro apaga uma luz perto do enigma; o 3º erro chama ele.

### A voz que imita B

Às vezes uma fala aparece com o nome de B, num tom errado (`"x: ..."`), pedindo para ficar,
para não acordar, para desistir. Depois, B de verdade diz que não falou nada.

### As 8 lembranças (uma escondida por capítulo, 1 a 8)

Só A pode tocar (são de A). São fragmentos fora de ordem, o que A ainda consegue encarar:
nenhuma diz quem dirigia. Com as 8, o final bom fica disponível. Texto exato (use `%s` =
`Game.name_b`):

| id | Cap. | Título | Objeto | Texto |
|---|---|---|---|---|
| m1 | 1 | A festa | copo | "A música estava alta demais. Alguém pôs um copo na minha mão.\n\n%s riu de alguma coisa que eu disse.\n\nQueria lembrar o que era." |
| m2 | 2 | As velas | vela de aniversário | "%s apagou as velas de olhos fechados.\n\nPerguntei o que tinha pedido.\n\n\"Se eu contar, não vale.\"" |
| m3 | 3 | A bolsa | frasco de remédio | "A cabeça doía. Procurei alguma coisa na bolsa.\n\nAchei. Tomei dois.\n\nNem olhei o que era." |
| m4 | 4 | A música | rádio, placa "PONTE 200 m" | "Três e cinquenta. %s cantava alto, desafinando de propósito.\n\nToda vez que eu ria, cantava mais alto.\n\nNão entendi por quê." |
| m5 | 5 | A mão aberta | chave | "%s parou na minha frente com a mão aberta, esperando.\n\nNão disse nada. Eu também não.\n\nPassei direto." |
| m6 | 6 | Um segundo | goteira | "Fechei os olhos só por um segundo.\n\nSó um.\n\nQuando abri, %s gritava o meu nome." |
| m7 | 7 | A água | banheira | "Frio. Escuro. O cinto não abria.\n\nDuas mãos abriram por mim.\n\n\"SAIA!\"\n\nEu subi. Eu respirei." |
| m8 | 8 | Depois | margem na cela | "Na margem, gritei até a voz acabar.\n\nAs duas luzes continuavam acesas lá no fundo.\n\nNinguém mais subiu." |

### Vozes do hospital (uma ou duas por capítulo, via `bleed`)

| Cap. | Linhas |
|---|---|
| 1 | "Pupilas reagindo." · "Mais um cobertor aqui, por favor." |
| 2 | "Escala de Glasgow: seis." |
| 3 | "Pressão estável. Pode diminuir a sedação." |
| 4 | "Colheram sangue dos dois?" · "Colheram. O resultado sai amanhã." |
| 5 | "O paciente do leito `number_a` fala dormindo. Sempre a mesma palavra." |
| 6 | "Pode conversar. Dizem que eles escutam." · "Fala o nome. Fala do que tem medo." |
| 7 | "Leito `number_b` teve uma parada às três. Conseguimos reverter." |
| 8 | "Chegou o sangue do leito `number_a`." · "Positivo. Benzodiazepínico e álcool." · "Leito `number_b` entrando em falência. Chamem a família." |
| 9 | Uma por pista (remédio, álcool, ninguém chamou táxi, briga pela chave + "Quem estava dirigindo?"). O cenário vira o hospital. |

Nunca use nome de personagem nas vozes do hospital: só números de leito.

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Mover | WASD / setas | analógico esquerdo |
| Correr | Shift | RB |
| Interagir / sair do esconderijo | E / Enter / Espaço | A |
| Trocar personagem | Tab | Y |
| Diário | J | Select/Back |
| Pausa | Esc | Start |

## Estrutura

`Menu → Nomes → Regras → Introdução → Cap. 1 … Cap. 9 → Escolha → Final (3) → Créditos`

Save automático no início de cada capítulo (`user://save.json`), incluindo as lembranças.
Cada enigma tem **dicas progressivas**. Respostas normalizadas: maiúsculas, sem acento, sem
espaço e sem pontuação.

## Personagens

- **A**: segue sempre pela **esquerda**. Moletom cinza (o mesmo do Esquecido).
- **B**: segue sempre pela **direita**. Jaqueta verde-escura.
- Números aleatórios de 10 a 99 = leitos do hospital. Nunca atribua gênero a A ou B no texto.

## Introdução

Preto. Água borbulhando, um baque abafado, um grito distante: "SAIA!". Um bipe.
"Sua cabeça dói..." / "Você não se lembra do seu nome." / os nomes se desfazem /
"mas sente uma estranha afinidade com o número XX".

## Capítulos, enigmas e terror

Os enigmas e as respostas **não mudam**. Cada capítulo ganha: lugar recontextualizado, pelo menos
um evento do Esquecido, uma voz do hospital, luzes de erro nos enigmas e a lembrança escondida.

### Cap. 1 — A Clareira (o lugar do acidente)
A e B acordam em margens opostas de um riacho; a ponte levadiça está erguida.
- Enigma: pedra de B com três círculos (verde pequeno, vermelho médio, azul grande), "Do menor
  ao maior". Alavancas de A. **Resposta:** verde → vermelha → azul. Ordem errada reseta.
- Terror: rio abaixo, perto da câmera, um **carro afundado** no riacho com os dois faróis piscando
  debaixo d'água (bolhas). Quem chega perto vê só "duas luzes" e não sabe o que é. Quando a
  ponte desce, a câmera mostra o Esquecido parado entre as árvores do outro lado; um clarão e
  ele some. "b: Tinha alguém ali. Entre as árvores."
- Voz: linhas do cap. 1 ao baixar a ponte. Lembrança m1 escondida do lado de A.

### Cap. 2 — O Cemitério
B dentro do cemitério murado; A na porta da capela (cadeado de 6 rodas de letras).
- Lápides I–VI (acróstico): I "Luz nenhuma alcança este chão" · II "Esquecemos o caminho de
  volta" · III "Mas a memória não morreu" · IV "Busque o nome que se perdeu" · V "Rastros de quem
  já partiu" · VI "Ecoam pelo vale vazio". **Resposta:** `LEMBRE`.
- Terror: uma **sétima cova**, de terra fresca, onde B acorda: cruz de madeira sem nome e uma
  vela de aniversário apagada fincada na terra. Depois que B lê duas lápides, o Esquecido **patrulha** entre as covas (lento,
  visão curta); dois esconderijos (mausoléu aberto, atrás do anjo). Luzes de erro no cadeado.
- Voz: cap. 2. Lembrança m2 do lado de A.

### Cap. 3 — A Capela
- Grade que só fica aberta enquanto alguém pisa na placa; do outro lado, uma alavanca trava a
  grade. **Quem fica na placa é caçado** (`lonely_watch`, ~30 s); alcançou: a vítima sai da placa.
- Confessionário: relógio de bolso parado em **3:15** e o bilhete "Meu relógio sempre atrasou uma
  hora. Foi a hora em que eu parti." B reconhece o relógio: era do avô de B. A voz falsa de B sai
  do confessionário pedindo para não acertar o relógio. A hora 4:15 só ganha sentido no final.
- Console do altar. **Resposta:** `4:15`. O espelho mostra a mão de sangue e os números; por um
  instante, há **três** figuras no reflexo. Voz: cap. 3. Lembrança m3.

### Cap. 4 — Dois Caminhos
A pela esquerda, B pela direita; os lados se reencontram no portão de ferro com **dois cadeados**.
- Esquerda (A): porta com "GET OUT OF HERE" talhado, bilhete em **morse**
  `. ... --.- ..- . -.-. .-`; a caixa do píer guarda a **chave pigpen**.
- Direita (B): carroça e **corpo de bruços** (a jaqueta é verde-escura, mas ninguém comenta; B
  se recusa a virar), bilhete em **pigpen** (NUNCA); a caixa guarda a **tabela morse**. Depois de
  ler, o corpo mudou de posição.
- Cadeado de A: `ESQUECA`. Cadeado de B: `NUNCA`. Juntos: "NUNCA ESQUEÇA".
- Terror: o Esquecido **patrulha** a trilha de A (esconderijos: barco virado, barril). Voz falsa
  de B quando A lê o morse. Voz: cap. 4. Lembrança m4.

### Cap. 5 — A Casa (a casa da festa)
Fachada com restos de festa (copos, garrafas, faixa "PARABÉNS, `name_b`"). "SAIA!" sussurrado.
A sobe pela trepadeira (esquerda), B pela escada (direita).
- Porta de A: amostra **lilás**; A acha "Coordenadas para o CIANO: 0 vermelho, 255 verde, 255 azul".
- Porta de B: amostra **ciano**; B acha "Coordenadas para o LILÁS: 177, 156, 217".
- **Respostas:** porta de A `B19CD9`, porta de B `00FFFF` (com ou sem `#`).
- Terror: o Esquecido olha de uma janela do andar de cima e some quando alguém chega perto; o
  susto do rosto com a mão (já existente); luzes de erro nas portas. Voz: cap. 5. Lembrança m5.

### Cap. 6 — O Sótão
Contagem: número da linha = número da letra, contando **só letras**. Quadro de exemplo
"ITS COLD HERE / DONT LEAVE ME: 2 = 4 → T".
- Carta (lado A), 4 linhas — **texto fixo, não alterar**:
  1 "A noite caiu depressa e a escuridão ficou tão densa que eu mal conseguia respirar"
  2 "Escrevo esta carta na esperança de que você volte para me buscar"
  3 "Estou perdido numa floresta escura e não reconheço nenhum caminho"
  4 "Algo terrível se esconde nas sombras e sussurra o meu nome todas as noites"
- Placa de B `1=40 2=34 3=49 4=32` → porta de **B** pede `NOME`.
- Canção (lado B): 1 "Dorme criança que a lua já vem" 2 "Fecha os olhos e não conte a ninguém"
  3 "O que se esconde debaixo da cama" 4 "Espera acordado e chama por quem ama".
- Placa de A `1=4 2=21 3=14 4=22` → porta de **A** pede `MEDO`.
- Terror: passos e arranhões do outro lado da parede de tábuas; desenhos infantis de duas crianças
  de mãos dadas (no lado de B, um foi coberto de azul e só sobrou uma mão); a voz falsa de B pela parede; num apagão, o Esquecido aparece parado
  num canto e some quando a luz volta. Voz: cap. 6. Lembrança m6.

### Cap. 7 — O Saguão (a casa da família de B)
"Vocês se encontram novamente. Se separar pode ser perigoso." Porta do subterrâneo com 4
cadeados (I–IV) e duas rodas que precisam girar **juntas**.
- **Quarto (I):** o quarto de infância de B. Parede `VLOHQFLR`; geladeira "CÉSAR DISSE: +3".
  Armário `SILENCIO`.
- **Cozinha (II):** alvo de dardos; "Mamãe só contava os dardos no vermelho, e somava tudo."
  Vermelho 17, 6, 19 (preto 20, 3). Despensa `42`.
- **Escritório (III):** piano; carta do pai com C D E F G A B = DÓ RÉ MI FÁ SOL LÁ SI; sob o
  travesseiro "Eles me destruíram sem Dó / O Sol já não nasce como antes / Não quero mais voltar
  Lá / Eles apenas Fa-zem chacota de mim". Piano **C G A F**.
- **Banheiro (IV):** espelho embaçado; ACORDE é a que mais se repete. Armário `ACORDE`.
- Terror: depois da primeira chave, o Esquecido **patrulha** o saguão e entra nos cômodos; um
  esconderijo em cada cômodo e no saguão. Voz falsa de B no espelho. Voz: cap. 7. Lembrança m7.

### Cap. 8 — Ascendência
Masmorra: dois corredores paralelos, duas placas que precisam de peso ao mesmo tempo. A esfinge
acorrentada encara A ("Você trouxe `name_b` até aqui. Não foi a primeira vez.").
"O que é, o que é: quanto mais se tem, menos se vê?" → `ESCURIDAO` (aceita ESCURO, TREVAS, BREU).
Errar: ameaças da esfinge e luzes de erro nas tochas. Acertou: tudo fica branco e B some
(voz do cap. 8 com a linha reta do monitor). **Fase branca:** só A; três lembranças de B (luzes);
a cada uma, o Esquecido aparece mais perto no branco; na terceira, logo atrás de A. Lembrança m8
na masmorra.

### Cap. 9 — Quatro e Quinze
Casa branca que, aos poucos, vira hospital (suportes de soro, cortinas, macas, lâmpadas frias
piscando; ambiente passa de `amb_white` para `amb_hospital`). O Esquecido aparece no fim dos
corredores e some. Caça ao tesouro com as 4 pistas originais:
1. Garagem (cozinha → escada à esquerda → escuridão → entulho). AQUELE QUE TE DOPA: *seus
   remédios te cegam*.
2. Primeira planta à esquerda ao sair da biblioteca. AQUELE QUE TE INDUZ: *suas drogas te traem*.
3. Quadro da nota de R$ 50 (onça-pintada) → planta no canto escuro, fundo à esquerda da galeria.
   AQUELE QUE TE SEDUZ: *suas influências te destroem*.
4. A cama onde A acordou. AQUELE QUE TE SEPARA: *seu orgulho te cega*.
- **Laboratório:** o terminal pede as 4 frases (respostas inalteradas). Ao completar, as luzes
  apagam. O Esquecido entra, anda até A e **abaixa a mão: o rosto é o de A**. "?: Você não
  precisa lembrar. Lá fora, `name_b` está morrendo por sua causa. Aqui, não." Então B aparece e
  junta as lembranças: pediu a chave, cantou para A não dormir, gritou para A sair do carro.
  "b: Agora eu grito de novo."
- **Escolha:** "Lembrar" ou "Esquecer".

## Finais

- **Esquecer** (`forget`): o branco fica bonito, B sorri, o sol não se põe; o monitor desacelera
  até a linha reta. "LEITO `number_a` — 04:15". "Existem outros finais."
- **Lembrar** (`remember`, menos de 8 lembranças): A acorda. O leito `number_b` ao lado está vazio;
  uma enfermeira dobra o cobertor. No criado-mudo, um relógio de bolso parado em 3:15. A limpa o
  vapor da janela: do lado de dentro do vidro, a marca de uma mão vermelha.
- **Ainda há esperança** (`hope`, lembrou com as 8): A acorda. B respira por um tubo no leito
  `number_b`; o monitor de B responde ao de A. Os dedos de B se fecham nos de A. A escreve no vapor
  da janela: NUNCA ESQUEÇA.
- Créditos: nome dos dois, tempo, lembranças n/8, final alcançado e, por último, a mensagem do
  autor: "Esteja no controle da sua vida."

## Estrutura técnica

```
scripts/autoload/  game.gd (estado, save, lembranças, final) · audio.gd · ui.gd (medo, vozes, escolha)
scripts/core/      party, character (esconder), stalker (O Esquecido), level_base (terror), build
scripts/ui/        menu, diário, pausa, opções, nota, escolha, final
scripts/puzzles/   interfaces de enigma (erro emite Game.puzzle_failed)
scripts/levels/    ch01.gd … ch09.gd
tools/             gen_art.py (inclui forgotten), gen_audio.py (inclui sons de terror e amb_hospital)
tests/             respostas, carga das cenas, compilação
```
