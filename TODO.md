# TODO

Scratch VM (`scratch-editor/packages/scratch-vm`) と比較した未実装 opcode 管理。

## Done in this pass (`control_*`)

- [x] `control_all_at_once`
- [x] `control_clear_counter`
- [x] `control_create_clone_of`
- [x] `control_for_each`
- [x] `control_get_counter`
- [x] `control_incr_counter`
- [x] `control_repeat_until`
- [x] `control_start_as_clone`
- [x] `control_wait_until`
- [x] `control_while`

## Remaining core opcodes

### `data_*`

- [ ] `data_hidelist`
- [ ] `data_hidevariable`
- [ ] `data_itemnumoflist`
- [ ] `data_showlist`
- [ ] `data_showvariable`

### `event_*`

- [ ] `event_whenbackdropswitchesto`
- [ ] `event_whengreaterthan`
- [ ] `event_whenkeypressed`
- [ ] `event_whenstageclicked`
- [ ] `event_whenthisspriteclicked`
- [ ] `event_whentouchingobject`

### `looks_*`

- [ ] `looks_backdropnumbername`
- [ ] `looks_changeeffectby`
- [ ] `looks_changestretchby`
- [ ] `looks_cleargraphiceffects`
- [ ] `looks_costumenumbername`
- [ ] `looks_goforwardbackwardlayers`
- [ ] `looks_gotofrontback`
- [ ] `looks_hideallsprites`
- [ ] `looks_nextbackdrop`
- [ ] `looks_seteffectto`
- [ ] `looks_setstretchto`
- [ ] `looks_size`
- [ ] `looks_switchbackdropto`
- [ ] `looks_switchbackdroptoandwait`

### `motion_*`

- [ ] `motion_align_scene`
- [ ] `motion_direction`
- [ ] `motion_glidesecstoxy`
- [ ] `motion_glideto`
- [ ] `motion_goto`
- [ ] `motion_ifonedgebounce`
- [ ] `motion_pointindirection`
- [ ] `motion_pointtowards`
- [ ] `motion_scroll_right`
- [ ] `motion_scroll_up`
- [ ] `motion_setrotationstyle`
- [ ] `motion_xposition`
- [ ] `motion_xscroll`
- [ ] `motion_yposition`
- [ ] `motion_yscroll`

### `procedures_*`

- [ ] `procedures_call`
- [ ] `procedures_definition`

### `sensing_*`

- [ ] `sensing_coloristouchingcolor`
- [ ] `sensing_current`
- [ ] `sensing_dayssince2000`
- [ ] `sensing_distanceto`
- [ ] `sensing_keypressed`
- [ ] `sensing_loud`
- [ ] `sensing_loudness`
- [ ] `sensing_mousedown`
- [ ] `sensing_mousex`
- [ ] `sensing_mousey`
- [ ] `sensing_of`
- [ ] `sensing_online`
- [ ] `sensing_resettimer`
- [ ] `sensing_touchingcolor`
- [ ] `sensing_touchingobject`
- [ ] `sensing_userid`
- [ ] `sensing_username`

### `sound_*`

- [ ] `sound_beats_menu`
- [ ] `sound_changeeffectby`
- [ ] `sound_changevolumeby`
- [ ] `sound_cleareffects`
- [ ] `sound_effects_menu`
- [ ] `sound_seteffectto`
- [ ] `sound_setvolumeto`
- [ ] `sound_sounds_menu`
- [ ] `sound_volume`

## Extensions (not started)

`pen_*`, `music_*`, `videoSensing_*`, `text2speech_*`, `translate_*`, `wedo2_*`, `ev3_*`, `boost_*`, `gdxfor_*`, `makeymakey_*`, `microbit_*`, `faceSensing_*`
