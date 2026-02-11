///|
fn is_hat_opcode(opcode : String) -> Bool {
  opcode == "event_whenflagclicked" ||
  opcode == "event_whenbroadcastreceived" ||
  opcode == "event_whenkeypressed" ||
  opcode == "event_whenthisspriteclicked" ||
  opcode == "event_whenstageclicked" ||
  opcode == "event_whenbackdropswitchesto" ||
  opcode == "event_whengreaterthan"
}

///|
fn json_to_string_option(json : Json) -> String? {
  match json {
    String(value) => Some(value)
    Null => None
    _ => None
  }
}

///|
fn parse_scratch_block(id : String, json : Json) -> ScratchBlock raise VmError {
  let obj = expect_object(json, "block \{id}")
  let opcode = object_get_string_or(obj, "opcode", "")
  if opcode == "" {
    invalid_project("block \{id} has no opcode")
  }
  let next = match object_get(obj, "next") {
    Some(value) => json_to_string_option(value)
    None => None
  }
  let parent = match object_get(obj, "parent") {
    Some(value) => json_to_string_option(value)
    None => None
  }
  let inputs = object_get_object_or_empty(obj, "inputs")
  let fields = object_get_object_or_empty(obj, "fields")
  let top_level = object_get_bool_or(obj, "topLevel", false)
  { id, opcode, next, parent, inputs, fields, top_level }
}

///|
fn parse_variables(
  raw : Map[String, Json],
) -> (Map[String, Json], Map[String, String]) {
  let values = {}
  let names = {}
  raw.each(fn(id, descriptor) {
    match descriptor {
      Array(parts) =>
        if parts.length() >= 2 {
          let name = json_to_string_value(parts[0])
          values[id] = parts[1]
          names[name] = id
        }
      _ => ()
    }
  })
  (values, names)
}

///|
fn parse_lists(
  raw : Map[String, Json],
) -> (Map[String, Array[Json]], Map[String, String]) {
  let values = {}
  let names = {}
  raw.each(fn(id, descriptor) {
    match descriptor {
      Array(parts) =>
        if parts.length() >= 2 {
          let name = json_to_string_value(parts[0])
          match parts[1] {
            Array(items) => {
              values[id] = items
              names[name] = id
            }
            _ => {
              values[id] = []
              names[name] = id
            }
          }
        }
      _ => ()
    }
  })
  (values, names)
}

///|
fn parse_blocks(
  raw : Map[String, Json],
) -> (Map[String, ScratchBlock], Array[String]) raise VmError {
  let blocks = {}
  let hats = []
  raw.each((id, block_json) => {
    let block = parse_scratch_block(id, block_json)
    if block.top_level && is_hat_opcode(block.opcode) {
      hats.push(id)
    }
    blocks[id] = block
  })
  (blocks, hats)
}

///|
fn parse_target(index : Int, json : Json) -> TargetState raise VmError {
  let obj = expect_object(json, "target")
  let name = object_get_string_or(obj, "name", "target_\{index}")
  let is_stage = object_get_bool_or(obj, "isStage", false)
  let target_id = if is_stage { "__stage__" } else { "target_\{index}_\{name}" }

  let x = object_get_number_or(obj, "x", 0.0)
  let y = object_get_number_or(obj, "y", 0.0)
  let direction = object_get_number_or(obj, "direction", 90.0)
  let size = object_get_number_or(obj, "size", 100.0)
  let visible = object_get_bool_or(obj, "visible", true)
  let current_costume = object_get_number_or(obj, "currentCostume", 0.0).to_int()

  let raw_variables = object_get_object_or_empty(obj, "variables")
  let raw_lists = object_get_object_or_empty(obj, "lists")
  let raw_blocks = object_get_object_or_empty(obj, "blocks")

  let (variables, variable_names) = parse_variables(raw_variables)
  let (lists, list_names) = parse_lists(raw_lists)
  let (blocks, hats) = parse_blocks(raw_blocks)

  {
    id: target_id,
    name,
    is_stage,
    x,
    y,
    direction,
    size,
    visible,
    current_costume,
    variables,
    variable_names,
    lists,
    list_names,
    blocks,
    top_level_hats: hats,
  }
}

///|
fn parse_bundle(
  project_json : String,
  assets_json : String?,
) -> ProjectBundle raise VmError {
  let assets = match assets_json {
    Some(raw) =>
      if raw.trim().is_empty() {
        {}
      } else {
        let json = parse_json_or_fail(raw)
        expect_object(json, "assets")
      }
    None => {}
  }
  { project_json, assets }
}

///|
fn parse_project_targets(
  project_json : String,
) -> (Array[TargetState], Int) raise VmError {
  let root = parse_json_or_fail(project_json)
  let root_obj = expect_object(root, "project")
  let targets_json = object_get_or(root_obj, "targets", json_array([]))
  let target_values = expect_array(targets_json, "project.targets")

  let targets = []
  let mut stage_index = 0
  for i, target_json in target_values {
    let target = parse_target(i, target_json)
    if target.is_stage {
      stage_index = i
    }
    targets.push(target)
  }

  if targets.is_empty() {
    invalid_project("project has no targets")
  }

  (targets, stage_index)
}
