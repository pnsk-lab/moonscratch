///|
fn json_is_null(value : Json) -> Bool {
  match value {
    Null => true
    _ => false
  }
}

///|
fn block_input_payload(block : ScratchBlock, input_name : String) -> Json? {
  match block.inputs.get(input_name) {
    Some(Array(parts)) =>
      if parts.length() >= 3 && json_is_null(parts[1]) {
        Some(parts[2])
      } else if parts.length() >= 2 {
        Some(parts[1])
      } else {
        None
      }
    Some(value) => Some(value)
    None => None
  }
}

///|
fn block_input_block_id(block : ScratchBlock, input_name : String) -> String? {
  match block_input_payload(block, input_name) {
    Some(String(id)) => Some(id)
    _ => None
  }
}

///|
fn decode_primitive(
  vm : Vm,
  target_index : Int,
  primitive : Array[Json],
) -> Json {
  if primitive.length() < 2 {
    return Json::null()
  }
  let code = json_to_number_value(primitive[0]).to_int()
  match code {
    4 | 5 | 6 | 7 | 8 => json_number(json_to_number_value(primitive[1]))
    9 => primitive[1]
    10 => json_string(json_to_string_value(primitive[1]))
    11 => json_string(json_to_string_value(primitive[1]))
    12 => {
      let variable_name = json_to_string_value(primitive[1])
      let variable_id = if primitive.length() >= 3 {
        Some(json_to_string_value(primitive[2]))
      } else {
        None
      }
      read_variable(vm, target_index, variable_id, Some(variable_name))
    }
    13 => {
      let list_name = json_to_string_value(primitive[1])
      let list_id = if primitive.length() >= 3 {
        Some(json_to_string_value(primitive[2]))
      } else {
        None
      }
      let items = read_list(vm, target_index, list_id, Some(list_name))
      json_string(items.map(json_to_string_value).join(" "))
    }
    _ => primitive[1]
  }
}

///|
fn field_value(block : ScratchBlock, field_name : String) -> (String, String?)? {
  match block.fields.get(field_name) {
    Some(Array(parts)) =>
      if parts.length() >= 2 {
        Some(
          (json_to_string_value(parts[0]), Some(json_to_string_value(parts[1]))),
        )
      } else if parts.length() == 1 {
        Some((json_to_string_value(parts[0]), None))
      } else {
        None
      }
    Some(String(value)) => Some((value, None))
    Some(value) => Some((json_to_string_value(value), None))
    None => None
  }
}

///|
fn value_from_input(
  vm : Vm,
  target_index : Int,
  block : ScratchBlock,
  input_name : String,
  depth : Int,
) -> Json {
  match block_input_payload(block, input_name) {
    Some(String(block_id)) =>
      eval_reporter_block_depth(vm, target_index, block_id, depth + 1)
    Some(Array(primitive)) => decode_primitive(vm, target_index, primitive)
    Some(value) => value
    None => Json::null()
  }
}

///|
fn mathop(name : String, value : Double) -> Double {
  match name.to_lower() {
    "abs" => value.abs()
    "floor" => value.floor()
    "ceiling" => value.ceil()
    "sqrt" => value.sqrt()
    "sin" => @math.sin(value * @math.PI / 180.0)
    "cos" => @math.cos(value * @math.PI / 180.0)
    "tan" => @math.tan(value * @math.PI / 180.0)
    "asin" => @math.asin(value) * 180.0 / @math.PI
    "acos" => @math.acos(value) * 180.0 / @math.PI
    "atan" => @math.atan(value) * 180.0 / @math.PI
    "ln" => @math.ln(value)
    "log" => @math.log10(value)
    "e ^" => @math.exp(value)
    "10 ^" => @math.pow(10.0, value)
    _ => value
  }
}

///|
fn as_number_or_none(value : Json) -> Double? {
  match value {
    Number(n, ..) => Some(n)
    String(s) => parse_double_or_none(s)
    True => Some(1.0)
    False => Some(0.0)
    _ => None
  }
}

///|
fn scratch_equals(left : Json, right : Json) -> Bool {
  match (as_number_or_none(left), as_number_or_none(right)) {
    (Some(a), Some(b)) => a == b
    _ =>
      json_to_string_value(left).to_lower() ==
      json_to_string_value(right).to_lower()
  }
}

///|
fn normalize_index(
  index_value : Json,
  length : Int,
  random_unit : Double,
) -> Int? {
  let raw = json_to_string_value(index_value).trim().to_lower()
  if raw == "last" {
    if length <= 0 {
      None
    } else {
      Some(length - 1)
    }
  } else if raw == "random" || raw == "any" {
    if length <= 0 {
      None
    } else {
      let sampled = (random_unit * Double::from_int(length)).floor().to_int()
      Some(sampled.clamp(min=0, max=length - 1))
    }
  } else {
    let n = json_to_number_value(index_value).to_int() - 1
    if n < 0 || n >= length {
      None
    } else {
      Some(n)
    }
  }
}

///|
fn eval_reporter_block_depth(
  vm : Vm,
  target_index : Int,
  block_id : String,
  depth : Int,
) -> Json {
  if depth > 40 {
    return Json::null()
  }

  let target = vm.targets[target_index]
  let block = match target.blocks.get(block_id) {
    Some(value) => value
    None => return Json::null()
  }

  match block.opcode {
    "math_number"
    | "math_integer"
    | "math_whole_number"
    | "math_positive_number"
    | "math_angle" =>
      match field_value(block, "NUM") {
        Some((value, _)) =>
          json_number(
            match parse_double_or_none(value) {
              Some(parsed) => parsed
              None => 0.0
            },
          )
        None => json_number(0.0)
      }
    "text" =>
      match field_value(block, "TEXT") {
        Some((value, _)) => json_string(value)
        None => json_string("")
      }
    "event_broadcast_menu" =>
      match field_value(block, "BROADCAST_OPTION") {
        Some((value, _)) => json_string(value)
        None => json_string("")
      }
    "control_create_clone_of_menu" =>
      match field_value(block, "CLONE_OPTION") {
        Some((value, _)) => json_string(value)
        None => json_string("")
      }
    "operator_add" => {
      let left = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM1", depth),
      )
      let right = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM2", depth),
      )
      json_number(left + right)
    }
    "operator_subtract" => {
      let left = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM1", depth),
      )
      let right = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM2", depth),
      )
      json_number(left - right)
    }
    "operator_multiply" => {
      let left = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM1", depth),
      )
      let right = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM2", depth),
      )
      json_number(left * right)
    }
    "operator_divide" => {
      let left = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM1", depth),
      )
      let right = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM2", depth),
      )
      if right == 0.0 {
        json_number(0.0)
      } else {
        json_number(left / right)
      }
    }
    "operator_random" => {
      let from = json_to_number_value(
        value_from_input(vm, target_index, block, "FROM", depth),
      )
      let to = json_to_number_value(
        value_from_input(vm, target_index, block, "TO", depth),
      )
      let low = if from <= to { from } else { to }
      let high = if from <= to { to } else { from }
      let sampled = low + (high - low) * next_random_unit(vm)
      json_number(sampled)
    }
    "operator_lt" => {
      let left = value_from_input(vm, target_index, block, "OPERAND1", depth)
      let right = value_from_input(vm, target_index, block, "OPERAND2", depth)
      json_bool(
        json_to_string_value(left).to_lower() <
        json_to_string_value(right).to_lower(),
      )
    }
    "operator_gt" => {
      let left = value_from_input(vm, target_index, block, "OPERAND1", depth)
      let right = value_from_input(vm, target_index, block, "OPERAND2", depth)
      json_bool(
        json_to_string_value(left).to_lower() >
        json_to_string_value(right).to_lower(),
      )
    }
    "operator_equals" => {
      let left = value_from_input(vm, target_index, block, "OPERAND1", depth)
      let right = value_from_input(vm, target_index, block, "OPERAND2", depth)
      json_bool(scratch_equals(left, right))
    }
    "operator_and" => {
      let left = json_to_bool_value(
        value_from_input(vm, target_index, block, "OPERAND1", depth),
      )
      let right = json_to_bool_value(
        value_from_input(vm, target_index, block, "OPERAND2", depth),
      )
      json_bool(left && right)
    }
    "operator_or" => {
      let left = json_to_bool_value(
        value_from_input(vm, target_index, block, "OPERAND1", depth),
      )
      let right = json_to_bool_value(
        value_from_input(vm, target_index, block, "OPERAND2", depth),
      )
      json_bool(left || right)
    }
    "operator_not" => {
      let value = json_to_bool_value(
        value_from_input(vm, target_index, block, "OPERAND", depth),
      )
      json_bool(!value)
    }
    "operator_join" => {
      let left = json_to_string_value(
        value_from_input(vm, target_index, block, "STRING1", depth),
      )
      let right = json_to_string_value(
        value_from_input(vm, target_index, block, "STRING2", depth),
      )
      json_string(left + right)
    }
    "operator_letter_of" => {
      let index = json_to_number_value(
          value_from_input(vm, target_index, block, "LETTER", depth),
        ).to_int() -
        1
      let text = json_to_string_value(
        value_from_input(vm, target_index, block, "STRING", depth),
      ).to_array()
      if index < 0 || index >= text.length() {
        json_string("")
      } else {
        json_string(String::from_array([text[index]]))
      }
    }
    "operator_length" => {
      let text = json_to_string_value(
        value_from_input(vm, target_index, block, "STRING", depth),
      )
      json_number(Double::from_int(text.char_length()))
    }
    "operator_contains" => {
      let text = json_to_string_value(
        value_from_input(vm, target_index, block, "STRING1", depth),
      ).to_lower()
      let needle = json_to_string_value(
        value_from_input(vm, target_index, block, "STRING2", depth),
      ).to_lower()
      json_bool(text.contains(needle))
    }
    "operator_mod" => {
      let left = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM1", depth),
      )
      let right = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM2", depth),
      )
      if right == 0.0 {
        json_number(0.0)
      } else {
        json_number(left.mod(right))
      }
    }
    "operator_round" => {
      let value = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM", depth),
      )
      json_number(value.round())
    }
    "operator_mathop" => {
      let op = match field_value(block, "OPERATOR") {
        Some((name, _)) => name
        None => ""
      }
      let value = json_to_number_value(
        value_from_input(vm, target_index, block, "NUM", depth),
      )
      json_number(mathop(op, value))
    }
    "sensing_answer" => json_string(vm.answer)
    "sensing_timer" => json_number(Double::from_int(vm.now_ms) / 1000.0)
    "control_get_counter" => json_number(Double::from_int(vm.control_counter))
    "data_variable" =>
      match field_value(block, "VARIABLE") {
        Some((name, id)) => read_variable(vm, target_index, id, Some(name))
        None => Json::null()
      }
    "data_listcontents" =>
      match field_value(block, "LIST") {
        Some((name, id)) => {
          let list = read_list(vm, target_index, id, Some(name))
          json_string(list.map(json_to_string_value).join(" "))
        }
        None => json_string("")
      }
    "data_itemoflist" =>
      match field_value(block, "LIST") {
        Some((name, id)) => {
          let list = read_list(vm, target_index, id, Some(name))
          let index_value = value_from_input(
            vm, target_index, block, "INDEX", depth,
          )
          match
            normalize_index(index_value, list.length(), next_random_unit(vm)) {
            Some(index) =>
              match list.get(index) {
                Some(value) => value
                None => Json::null()
              }
            None => Json::null()
          }
        }
        None => Json::null()
      }
    "data_lengthoflist" =>
      match field_value(block, "LIST") {
        Some((name, id)) => {
          let list = read_list(vm, target_index, id, Some(name))
          json_number(Double::from_int(list.length()))
        }
        None => json_number(0.0)
      }
    "data_listcontainsitem" =>
      match field_value(block, "LIST") {
        Some((name, id)) => {
          let list = read_list(vm, target_index, id, Some(name))
          let item = value_from_input(vm, target_index, block, "ITEM", depth)
          let needle = json_to_string_value(item).to_lower()
          json_bool(
            list.any(fn(entry) {
              json_to_string_value(entry).to_lower() == needle
            }),
          )
        }
        None => json_bool(false)
      }
    _ => Json::null()
  }
}
