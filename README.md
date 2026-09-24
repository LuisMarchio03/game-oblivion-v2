# OBLIVION

Jogo de terror, suspense e enigmas em HD-2D (Godot 4.7) sobre dois amigos presos num pesadelo. Remake do
mini game de navegador de 2023. Enredo, capítulos e respostas: [`docs/DESIGN.md`](docs/DESIGN.md).

## Jogar

```sh
godot --path .            # roda o jogo
godot -e --path .         # abre no editor
```

Requer Godot 4.7 (renderizador Forward+). Em máquina fraca, use Opções → Qualidade gráfica: Baixa.

| Ação | Teclado | Controle |
|---|---|---|
| Mover / correr | WASD ou setas / Shift | analógico / RB |
| Interagir | E, Enter ou Espaço | A |
| Trocar personagem | Tab | Y |
| Diário e bloco de notas | J | Select |
| Pausa | Esc | Start |

## Estrutura

- `scripts/autoload/` — `Game` (estado, save, opções), `Audio`, `Ui` (HUD, diálogo, painéis).
- `scripts/core/` — personagem, grupo, câmera, base de fase e o construtor de cenário `Build`.
- `scripts/puzzles/` — interfaces de enigma. `scripts/ui/` — menus, diário, notas, final.
- `scripts/levels/chNN.gd` — cada capítulo monta o próprio cenário em código.
  Guia para escrever/alterar capítulos: [`docs/LEVEL_GUIDE.md`](docs/LEVEL_GUIDE.md).
- `assets/` — sprites e texturas pixel, áudio, fontes (OFL/Apache), `legacy/` (arte original).

## Gerar arte e áudio

```sh
uv run --with pillow --with numpy python tools/gen_art.py
uv run --with numpy --with scipy python tools/gen_audio.py
```

## Testes

```sh
godot --headless --path . res://tests/check_scripts.tscn   # compila todos os scripts
godot --headless --path . res://tests/test_answers.tscn    # confere as respostas dos enigmas
godot --headless --path . res://tests/smoke.tscn           # carrega cada capítulo
godot --headless --path . res://tests/stalker_test.tscn    # perseguidor, esconderijo, "sozinho", luz de erro
tools/shot.sh /tmp/x.png --scene=res://scenes/levels/ch01.tscn   # captura fora da tela (Xvfb)
```

## Exportar

Requer os templates da Godot 4.7.1 em `~/.local/share/godot/export_templates/4.7.1.stable/`.

```sh
godot --headless --path . --export-release "Windows" build/windows/Oblivion.exe
godot --headless --path . --export-release "Linux" build/linux/Oblivion.x86_64
```

O jogo vai embutido no executável (um arquivo só). `build/` fica fora do git.

## Créditos

### Enrique Candido

Ideia original do jogo, parte da história e parte dos assets.

UI/UX Designer e desenvolvedor front-end, cofundador da LED Softwares e estudante de bacharelado
em Sistemas de Informação. Mineiros, Goiás.

[GitHub](https://github.com/Enrique-qa) · [LinkedIn](https://www.linkedin.com/in/enrique-candido-02b278183/)
