///|
fn parse_options_json(options_json : String?) -> VmOptions raise VmError {
  let options = default_vm_options()
  match options_json {
    Some(raw) => {
      if raw.trim().is_empty() {
        return options
      }
      let parsed = parse_json_or_fail(raw)
      let obj = expect_object(parsed, "options")
      options.turbo = object_get_bool_or(obj, "turbo", options.turbo)
      options.compatibility_30tps = object_get_bool_or(
        obj,
        "compatibility_30tps",
        options.compatibility_30tps,
      )
      options.max_clones = object_get_number_or(
        obj,
        "max_clones",
        Double::from_int(options.max_clones),
      ).to_int()
      options.deterministic = object_get_bool_or(
        obj,
        "deterministic",
        options.deterministic,
      )
      options.seed = object_get_number_or(
        obj,
        "seed",
        Double::from_int(options.seed),
      ).to_int()
      options
    }
    None => options
  }
}

///|
fn effect_to_json(effect : HostEffect) -> Json {
  match effect {
    PlaySound(target, sound) =>
      json_object({
        "type": json_string("play_sound"),
        "target": json_string(target),
        "sound": json_string(sound),
      })
    StopAllSounds => json_object({ "type": json_string("stop_all_sounds") })
    Say(target, message) =>
      json_object({
        "type": json_string("say"),
        "target": json_string(target),
        "message": json_string(message),
      })
    Think(target, message) =>
      json_object({
        "type": json_string("think"),
        "target": json_string(target),
        "message": json_string(message),
      })
    Ask(question) =>
      json_object({
        "type": json_string("ask"),
        "question": json_string(question),
      })
    Broadcast(message) =>
      json_object({
        "type": json_string("broadcast"),
        "message": json_string(message),
      })
    Log(level, message) =>
      json_object({
        "type": json_string("log"),
        "level": json_string(level),
        "message": json_string(message),
      })
  }
}

///|
fn target_snapshot_json(target : TargetState) -> Json {
  let lists_json = {}
  target.lists.each((list_id, items) => lists_json[list_id] = json_array(items))

  json_object({
    "id": json_string(target.id),
    "name": json_string(target.name),
    "isStage": json_bool(target.is_stage),
    "x": json_number(target.x),
    "y": json_number(target.y),
    "direction": json_number(target.direction),
    "size": json_number(target.size),
    "visible": json_bool(target.visible),
    "currentCostume": json_number(Double::from_int(target.current_costume)),
    "variables": json_object(target.variables),
    "lists": json_object(lists_json),
  })
}

///|
fn snapshot_to_json(vm : Vm) -> Json {
  let targets = vm.targets.map(target_snapshot_json)
  json_object({
    "runId": json_number(Double::from_int(vm.run_id)),
    "nowMs": json_number(Double::from_int(vm.now_ms)),
    "running": json_bool(vm.running),
    "answer": json_string(vm.answer),
    "activeThreads": json_number(Double::from_int(vm.threads.length())),
    "targets": json_array(targets),
  })
}

///|
pub fn vm_new(bundle : ProjectBundle, options : VmOptions) -> Vm raise VmError {
  vm_new_internal(bundle, options)
}

///|
pub fn vm_new_from_json(
  project_json : String,
  assets_json? : String,
  options_json? : String,
) -> Vm raise VmError {
  let bundle = parse_bundle(project_json, assets_json)
  let options = parse_options_json(options_json)
  vm_new_internal(bundle, options)
}

///|
pub fn vm_start(vm : Vm) -> Unit {
  start_vm_runtime(vm)
}

///|
pub fn vm_green_flag(vm : Vm) -> Unit {
  green_flag_runtime(vm)
}

///|
pub fn vm_step(vm : Vm, dt_ms : Int) -> StepReport {
  step_runtime(vm, dt_ms)
}

///|
pub fn vm_post_io_json(vm : Vm, device : String, payload_json : String) -> Unit {
  post_io_json_runtime(vm, device, payload_json)
}

///|
pub fn vm_broadcast(vm : Vm, message : String) -> Unit {
  broadcast_runtime(vm, message)
}

///|
pub fn vm_stop_all(vm : Vm) -> Unit {
  clear_threads(vm)
  push_effect(vm, HostEffect::StopAllSounds)
}

///|
pub fn vm_take_effects_json(vm : Vm) -> String {
  let effects = take_effects(vm).map(effect_to_json)
  json_array(effects).stringify()
}

///|
pub fn vm_snapshot_json(vm : Vm) -> String {
  snapshot_to_json(vm).stringify(indent=2)
}
