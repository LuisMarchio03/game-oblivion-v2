# Guia para escrever um capítulo

Leia antes: `docs/DESIGN.md` (enredo e respostas — seguir à risca), `scripts/levels/ch01.gd`
(capítulo de referência), `scripts/core/*.gd`, `scripts/puzzles/*.gd`, `scripts/ui/note_view.gd`.

## Estrutura

```gdscript
extends LevelBase

func _init() -> void:
	chapter_index = N - 1          # 0-based
	preset = "forest"              # forest, cemetery, chapel, house_ext, house, attic, dungeon, white
	ambience = "amb_forest"        # ver lista de áudio
	music = ""                     # opcional
	spawn_a = Vector3(...)         # A sempre à ESQUERDA (x < 0) quando separados
	spawn_b = Vector3(...)
	cam_bounds = Rect2(x, z, w, h) # limites do foco da câmera no plano XZ

func _build() -> void:            # só geometria e pontos de interação, tudo dentro de `geo`
	...

func _begin() -> void:            # corotina após o fade-in: falas, objective(), hints([...])
	...
```

## Espaço e câmera

- Y é para cima. A câmera fica ao sul (+Z) olhando para o norte (−Z), inclinada ~40°.
- Paredes do lado sul (perto da câmera) escondem a cena: use `Build.room(..., walls_south=false)`
  ou não crie parede sul. Não use teto visível (o `ceiling_mat` do `room` só projeta sombra).
- Chão com topo em y = 0, a menos que haja andares. Escadas: `Build.stairs`. Escalada:
  `await ch.climb([pontos], segundos)`.
- Feche o mapa com `Build.blocker` para ninguém sair da área.
- Escala: personagem ~1,7 m, porta 1,2 × 2,4 m, pé-direito 3–4 m.

## Ajudantes do LevelBase

- `interact(pos, prompt, func(ch): ..., who="any"|"a"|"b", radius, marker, marker_h)`
- `doc(pos, {id, title, body, style, image?, cipher?, swatch?, circles?}, prompt, who)` — lê e guarda
  no diário de quem leu. `id` único: `"chN_nome"`. Estilos: paper, hand, blue, stone, sign,
  screen, pigpen (`cipher`), pigpen_key, image. `body` aceita BBCode.
- `await puzzle(CodeLock.new(titulo, [respostas], descricao, [dicas]))` → true se resolvido.
  Também: `WheelLock`, `ClockLock`, `PianoPanel`, `TerminalPanel`, `DartboardView`, `MirrorView`
  (os dois últimos só mostram; use `await Ui.open_panel(...)`).
  `CodeLock` tem `keypad`, `swatch`, `prefix`, `max_len`, `placeholder` configuráveis antes de abrir.
- `zone(pos, size, func(ch): ..., once)`, `plate(pos)` (PressurePlate com sinal `changed(pressed)`),
  `exit_zone(pos, size, need_both)` termina o capítulo, `finish()`.
- `say(["a: fala", "b: fala", "narração", "?: voz"])`, `objective(texto)`, `hints([...])`.
- `party.a`, `party.b`, `party.active`, `party.activate(who)`, `party.solo(who)`,
  `party.set_switch_enabled(bool)`, `party.both_near(pos, raio)`.
- `cam.shake()`, `await cam.look_at_point(pos)`, depois `cam.target = party.active`;
  `cam.set_view(offset, fov)`.
- Build: `ground`, `box`, `wall`, `room`, `cylinder`, `sphere`, `stairs`, `blocker`, `water`,
  `billboard`, `flat_sprite`, `tree`, `scatter`, `omni`, `spot`, `candle`, `torch`, `decal`,
  `text3d`, `motes`, `door` (Door: `open()`, `rattle()`), `mover` (Mover: `open()`, `set_open()`),
  `lever` (Lever: `set_down()`), `mat(textura, tint, tile)`, `color_mat(cor, emissao)`.
- Ui: `Ui.toast`, `Ui.jumpscare()`, `Ui.flash()`, `Ui.whiteout()`, `Ui.clear_whiteout()`,
  `Ui.narrate([...])`, `Ui.fade_out/fade_in`.
- Game: `Game.name_a/name_b`, `Game.number_a/number_b`, `Game.set_flag/get_flag`, `Game.char_name(who)`.
- Audio: `Audio.sfx(nome, db)`, `Audio.sfx_at(nome, no3d)`, `Audio.music(nome)`, `Audio.ambience(nome)`.

## Terror (obrigatório em todo capítulo — ver "Terror por capítulo" no DESIGN)

- **O Esquecido** (`Stalker`, sprite `forgotten`, 4 quadros: 0 mão no rosto, 1-2 andando, 3 rosto de A):
  `var s := spawn_stalker()`; aparição roteirizada `s.appear(pos)`, `await s.vanish(t)`, `s.stand()`,
  `await s.walk_to(pos, vel)`, `s.reveal()`; patrulha `s.patrol([pontos])` (persegue quem enxergar,
  paredes bloqueiam a visão, correr foge, esconder-se despista), `s.chase(ch)`, `s.stalk(ch, vel)`.
  Ajustes: `walk_speed`, `chase_speed`, `sight`, `hunting`. Ao alcançar alguém: susto, os dois
  voltam a `set_checkpoint(pos_a, pos_b)` e `_caught(ch)` (sobrescreva para reposicionar a patrulha).
  O medo na tela (vinheta vermelha + batimento) sobe sozinho com a distância.
- `hide_spot(pos, prompt, who)`: esconderijo (armário, debaixo da cama). Interagir de novo sai.
- `lonely_watch(func(): return <Character sozinho ou null>, limite_s, func(ch): <desfaz o que segurava>)`:
  quem fica sozinho parado (placa, roda) ouve sussurros e o Esquecido chega por trás. `stop_lonely_watch()`.
- `dread_light(luz, grupo)`: registre 2–4 luzes perto de cada enigma; `dread_focus(grupo)` antes de abrir o enigma faz o erro apagar primeiro as luzes dele. Cada erro apaga uma; o 3º erro dá susto
  e o Esquecido aparece atrás do jogador por 2 s (automático, via `Game.puzzle_failed`).
- `bleed(["linha", ...])` / `bleed_zone(pos, size, linhas)`: voz do hospital vazando (legenda fria,
  bipe e chiado; não bloqueia). Frases curtas, clínicas, sem nome de personagem (use o número do leito).
- `say()` aceita `"x: fala"`: a voz que imita B (aparece com o nome de B em tom errado). O B verdadeiro
  nega em uma ou duas linhas, cada vez mais curto; não repita o mesmo diálogo de negação.
- Não entregue a história: ninguém diz quem dirigia, de quem é um objeto ou o que sente. Siga a
  tabela "Como a verdade é dosada" do DESIGN.
- `memory(pos, "mN", titulo, corpo)`: lembrança escondida (brilho fraco, sem marcador). Só A toca.
  Esconda de verdade (atrás de objeto, canto escuro, fora do caminho), mas alcançável.
- `Ui.jumpscare()`, `Ui.set_dread(v)`, `Ui.flash(cor)`, `cam.shake()`. SFX novos: radio_static,
  flatline, stalker_step, whisper_many, light_out, dread_sting. Ambiente novo: amb_hospital.
- Pronomes: nunca use pronome ou adjetivo com gênero para A ou B (os nomes são digitados pelo
  jogador). Reescreva com o nome ou sem sujeito ("%s não subiu", "Estou com frio").

## Recursos

- Texturas (`Build.mat`): grass, dirt, forest_floor, stone_path, cobble, brick, stone_wall,
  wood_floor, wood_wall, planks_dark, wallpaper_stripes, wallpaper_damask, tile_checker, tile_bath,
  tile_kitchen, roof, bark, metal, rust_metal, carpet_red, bed_cloth, marble_white, plaster, water,
  gravestone, dungeon_stone, dirt_dark, ceiling_wood, curtain.
- Sprites: char_a/b, forgotten (4 quadros), monster (2 quadros), corpse, crow (2), tree_pine, tree_dead, tree_oak, bush,
  grass (3), fern, reeds, flower_white, vines, cobweb, flame (4), torch (4), firefly, dust, fog, glow,
  icon_key, icon_note, icon_journal, icon_hand, icon_eye. Arte original: `res://assets/legacy/`
  (face_hand.png, face_hand_wide.png, blood_hand.png, padlock.png, old_paper.jpg, house_front.png).
- SFX: ui_hover, ui_click, ui_back, type_blip, step_*, door_open, door_locked, gate_open, lock_open,
  lever, stone_grind, paper, success, error, whisper_saia, heartbeat, jumpscare, piano_c…piano_b,
  piano_wrong, music_box, clock_tick, clock_chime, chain_rattle, monster_growl, wind_gust, crow_caw,
  switch_char, key_pickup, drip, monitor_beep, bell, splash, dart_thud, wheel_click, glass_squeak,
  breath, flash.
- Música/ambiente: amb_forest, amb_house, amb_attic, amb_dungeon, amb_white, music_menu,
  music_tension, music_ending.

## Regras

- Texto em português do Brasil com acentos, tom de terror psicológico, frases curtas.
- Cada enigma: objetivo claro, 3 dicas progressivas (a última entrega a resposta), resposta
  exatamente como em DESIGN.md.
- Informação separada: a pergunta com um personagem, a chave com o outro, e as áreas fisicamente
  separadas quando o DESIGN pede.
- Ambientação rica: luzes quentes/frias, partículas, vegetação, objetos de cena.

## Verificação (obrigatória)

- `godot --headless --path . res://tests/check_scripts.tscn 2>&1 | grep -E "ERROR|FALHA|CHECK"`
  precisa terminar em `CHECK: 0 falha(s)`.
- Capturas **somente** com `tools/shot.sh <saida.png> --scene=res://scenes/levels/chNN.tscn
  --wait=3 [--who=b] [--pos=x,y,z] [--view=0,9,11] [--call=_debug_metodo]` e olhar a imagem com Read.
  O script roda fora da tela (Xvfb, renderizador de compatibilidade: sem neblina volumétrica).
- **Proibido abrir qualquer coisa na tela do usuário**: nunca rode `godot` com janela fora do
  `tools/shot.sh`, nunca use `hangar-preview`, navegador ou editor gráfico.
- Não instale pacotes. Não faça commit.
