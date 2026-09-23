# OBLIVION — Documento de design

Remake em Godot 4.7 do mini game de enigmas "Oblivion" (versão de navegador, 2023,
Sistemas de Informação). Mantém a história, o tom e os enigmas originais; completa o que
faltava (enigmas 1–3, masmorra, fase branca e caça ao tesouro dentro do jogo).

## Pilares

- **Dois personagens, um jogador.** O jogador controla os dois (troca com `Tab`). Cada
  personagem só lê o que ele próprio encontrou: o diário é por personagem. A pergunta fica
  com um e a chave com o outro, como no original, em que a dupla precisava conversar.
  O bloco de notas também é
  separado por personagem: para passar informação de um para o outro, o jogador usa papel
  e caneta de verdade, como no original.
- **HD-2D.** Cenários 3D low-poly com textura pixel (filtro nearest), personagens e
  vegetação em sprite 2D com billboard, neblina volumétrica, glow, profundidade de campo
  tilt-shift e câmera fixa em ângulo de ~40°. Paleta noturna azulada (herdada da arte
  original) e fase final branca.
- **Terror psicológico, não gore.** Sussurros, "SAIA!", rosto com a mão de sangue (arte
  original reaproveitada), jumpscares raros e avisados pelo som.
- **Mensagem final:** "Ainda há esperança. Esteja no controle da sua vida."

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Mover | WASD / setas | analógico esquerdo |
| Correr | Shift | RB |
| Interagir | E / Enter / Espaço | A |
| Trocar personagem | Tab | Y |
| Diário | J | Select/Back |
| Pausa | Esc | Start |

## Estrutura

`Menu → Nomes → Regras → Introdução → Cap. 1 … Cap. 9 → Final → Créditos`

Save automático no início de cada capítulo (`user://save.json`); o menu oferece "Continuar".
Cada enigma tem **dicas progressivas** (botão "Dica" na interface do enigma e no diário).
Respostas são normalizadas: maiúsculas, sem acento, sem espaço e sem pontuação.

## Personagens

- **A** (nome digitado pelo jogador, padrão "Ana"): segue sempre pela **esquerda**.
- **B** (nome do parceiro, padrão "Leo"): segue sempre pela **direita**.
- Cada um recebe um número aleatório de 10 a 99 ("uma estranha afinidade com o número xx").
  O número volta no final: é o leito do hospital.

## Capítulos e respostas

### Introdução
"Sua cabeça dói..." / o nome digitado se desfaz na tela / "Você não se lembra do seu nome" /
"mas sente uma estranha afinidade com o número XX".

### Cap. 1 — A Clareira (novo, tutorial)
A e B acordam em margens opostas de um riacho. A ponte levadiça está erguida.
- Lado de B: pedra pintada com três círculos, verde pequeno, vermelho médio e azul grande,
  com a inscrição "Do menor ao maior".
- Lado de A: três alavancas (vermelha, verde, azul).
- **Resposta:** puxar verde → vermelha → azul. Ordem errada reseta as alavancas.

### Cap. 2 — O Cemitério (novo)
B fica dentro do cemitério murado; A fica na porta da capela.
- Seis lápides numeradas de I a VI, espalhadas fora de ordem, formam um acróstico:
  I "Luz nenhuma alcança este chão" · II "Esquecemos o caminho de volta" ·
  III "Mas a memória não morreu" · IV "Busque o nome que se perdeu" ·
  V "Rastros de quem já partiu" · VI "Ecoam pelo vale vazio".
- Porta da capela: cadeado de 6 rodas de letras.
- **Resposta:** `LEMBRE`.

### Cap. 3 — A Capela (novo)
- Grade levadiça que só fica aberta enquanto alguém pisa na placa: um segura e o outro passa,
  e do outro lado uma alavanca trava a grade aberta. Ensina a cooperação física.
- No confessionário há um relógio de bolso parado em **3:15**, com o bilhete "Meu relógio
  sempre atrasou uma hora. Foi a hora em que eu parti."
- No altar fica o console do relógio da torre (hora e minuto).
- **Resposta:** `4:15`. O altar se abre e o espelho mostra a mão de sangue e os números.

### Cap. 4 — Dois Caminhos (enigma 4 original)
"Há dois caminhos à frente de vocês. Qual lado cada um seguirá?" A vai pela esquerda e B pela
direita. Os dois lados se reencontram no portão de ferro, que tem **dois cadeados**.
- Esquerda (A): porta velha com "GET OUT OF HERE" talhado e um bilhete em **morse**
  `. ... --.- ..- . -.-. .-`; a caixa de ferramentas do píer guarda a **chave pigpen**.
- Direita (B): carroça e corpo com um bilhete em **pigpen** (NUNCA); a caixa de ferramentas
  guarda a **tabela morse**.
- Cadeado do lado A: `ESQUECA`. Cadeado do lado B: `NUNCA`. Juntos: "NUNCA ESQUEÇA".

### Cap. 5 — A Casa (enigma 5 original)
Fachada com "SAIA!" sussurrado. A sobe pela trepadeira (esquerda) e B pela escada (direita).
- A porta de A mostra uma amostra de cor **lilás** e um teclado hexadecimal. A acha o bilhete
  "Coordenadas para o CIANO: 0 vermelho, 255 verde, 255 azul".
- A porta de B mostra uma amostra **ciano**. B acha "Coordenadas para o LILÁS: 177, 156, 217".
- **Respostas:** porta de A `B19CD9`, porta de B `00FFFF` (com ou sem `#`).

### Cap. 6 — O Sótão (enigma 6 original, texto reescrito para fechar a conta)
Contagem: número da linha = número da letra, contando **só letras** (espaços e pontuação não
contam). O quadro de exemplo mostra "ITS COLD HERE / DONT LEAVE ME: 2 = 4 → T".
- Lado A: carta de 4 linhas —
  1 "A noite caiu depressa e a escuridão ficou tão densa que eu mal conseguia respirar"
  2 "Escrevo esta carta na esperança de que você volte para me buscar"
  3 "Estou perdido numa floresta escura e não reconheço nenhum caminho"
  4 "Algo terrível se esconde nas sombras e sussurra o meu nome todas as noites"
- Lado B: placa `1=40 2=34 3=49 4=32` → a porta de **B** pede `NOME`.
- Lado B: canção de ninar —
  1 "Dorme criança que a lua já vem" 2 "Fecha os olhos e não conte a ninguém"
  3 "O que se esconde debaixo da cama" 4 "Espera acordado e chama por quem ama"
- Lado A: placa `1=4 2=21 3=14 4=22` → a porta de **A** pede `MEDO`.

### Cap. 7 — O Saguão (enigma 7 original)
"Vocês se encontram novamente. Se separar pode ser perigoso." A porta do subterrâneo tem 4
cadeados (I–IV) e duas rodas que precisam girar **juntas**: um personagem segura uma e o
outro gira a outra.
- **Quarto (I):** na parede, `VLOHQFLR`. Na geladeira da cozinha, "CÉSAR DISSE: +3".
  O armário pede `SILENCIO`.
- **Cozinha (II):** alvo de dardos com 5 dardos. Os setores alternam vermelho e preto. Bilhete:
  "Mamãe só contava os dardos no vermelho, e somava tudo." Dardos no vermelho: 17, 6, 19
  (no preto: 20, 3). A despensa pede `42`.
- **Escritório (III):** piano. Na mesa, a carta do pai com a tabela C D E F G A B =
  DÓ RÉ MI FÁ SOL LÁ SI. Sob o travesseiro do quarto, "Eles me destruíram sem Dó / O Sol já
  não nasce como antes / Não quero mais voltar Lá / Eles apenas Fa-zem chacota de mim".
  O piano pede **C G A F**.
- **Banheiro (IV):** o espelho embaçado escreve palavras caractere por caractere, e ACORDE
  é a que mais se repete. Bilhetes: "Repetir é a chave para o sucesso", "Minhas palavras são
  construídas caractere por caractere" e "Aquele que mais se repete, ele está certo".
  O armário pede `ACORDE`.

### Cap. 8 — Ascendência (LV 8 original)
Masmorra com um monstro acorrentado (a esfinge): "O que é, o que é: quanto mais se tem,
menos se vê?" → `ESCURIDAO` (aceita também ESCURO, TREVAS, BREU). As correntes se partem, tudo
fica branco e o parceiro some. Na **fase branca**, calma, o jogador controla só A ("Não há
ninguém para chamar."); junta 3 memórias (luzes) e a voz pede "Acorde...".

### Cap. 9 — Ainda Há Esperança (LV 9 original, caça ao tesouro dentro do jogo)
Casa branca. As 4 pistas impressas originais viram locais da casa; cada local entrega uma
frase e a pista seguinte.
1. "Aonde eles se alimentam, desça à esquerda, siga até a escuridão, aonde guardamos nossos
   carros, aonde jogamos os entulhos" → garagem. AQUELE QUE TE DOPA: *seus remédios te cegam*.
2. "Local de conhecimento, antes por pergaminhos, agora por impressão; após este local, à
   esquerda, aquela que purifica o ar, a primeira delas" → primeira planta ao sair da
   biblioteca. AQUELE QUE TE INDUZ: *suas drogas te traem*.
3. "Símbolo de valor monetário, ícone nacional, arte; olhe para a onça-pintada e sinta orgulho
   de sua nação; na escuridão me escondo; aquela que purifica o ar, à esquerda, no fundo" →
   quadro da nota de R$ 50 e a planta no canto escuro. AQUELE QUE TE SEDUZ: *suas influências
   te destroem*.
4. "No início ou no fim, acima ou abaixo, à vista ou escondido... no local mais óbvio, volte ao
   local do seu pesadelo" → a cama onde A acordou. AQUELE QUE TE SEPARA: *seu orgulho te cega*.
- **Laboratório:** um terminal pede as 4 frases. Ao completar: "AINDA HÁ ESPERANÇA".
- **Final:** um monitor cardíaco, "Leito XX" e o texto final. "Obrigado por jogar! Esteja no
  controle da sua vida." Seguem os créditos.

## Estrutura técnica

```
project.godot
scripts/autoload/  game.gd (estado, save, opções) · audio.gd · ui.gd (camada de UI global)
scripts/core/      party, player, interactable, camera, level_base, builder (geometria)
scripts/ui/        menu, diário, pausa, opções, nota, diálogo, transição
scripts/puzzles/   interfaces de enigma (código, roda de letras, relógio, piano, dardos...)
scripts/levels/    ch01.gd … ch09.gd (cada capítulo monta a sua geometria em código)
scenes/            main.tscn, levels/chNN.tscn
assets/            sprites, textures, audio, fonts (OFL), legacy (arte original reaproveitada)
tools/             gen_art.py, gen_audio.py (arte e áudio gerados proceduralmente)
tests/             testes headless das respostas e do carregamento das cenas
```
