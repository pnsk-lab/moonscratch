///|
let broadcast_project =
  #|{
  #|  "targets": [
  #|    {
  #|      "isStage": true,
  #|      "name": "Stage",
  #|      "variables": {
  #|        "var_score": ["score", 0]
  #|      },
  #|      "lists": {},
  #|      "blocks": {}
  #|    },
  #|    {
  #|      "isStage": false,
  #|      "name": "Sprite1",
  #|      "variables": {},
  #|      "lists": {},
  #|      "blocks": {
  #|        "hat_flag": {
  #|          "opcode": "event_whenflagclicked",
  #|          "next": "set_score",
  #|          "parent": null,
  #|          "inputs": {},
  #|          "fields": {},
  #|          "topLevel": true
  #|        },
  #|        "set_score": {
  #|          "opcode": "data_setvariableto",
  #|          "next": "broadcast_go",
  #|          "parent": "hat_flag",
  #|          "inputs": {
  #|            "VALUE": [1, [4, 1]]
  #|          },
  #|          "fields": {
  #|            "VARIABLE": ["score", "var_score"]
  #|          },
  #|          "topLevel": false
  #|        },
  #|        "broadcast_go": {
  #|          "opcode": "event_broadcast",
  #|          "next": null,
  #|          "parent": "set_score",
  #|          "inputs": {
  #|            "BROADCAST_INPUT": [1, "broadcast_menu"]
  #|          },
  #|          "fields": {},
  #|          "topLevel": false
  #|        },
  #|        "broadcast_menu": {
  #|          "opcode": "event_broadcast_menu",
  #|          "next": null,
  #|          "parent": "broadcast_go",
  #|          "inputs": {},
  #|          "fields": {
  #|            "BROADCAST_OPTION": ["go", "broadcast_go_id"]
  #|          },
  #|          "topLevel": false,
  #|          "shadow": true
  #|        },
  #|        "hat_broadcast": {
  #|          "opcode": "event_whenbroadcastreceived",
  #|          "next": "change_score",
  #|          "parent": null,
  #|          "inputs": {},
  #|          "fields": {
  #|            "BROADCAST_OPTION": ["go", "broadcast_go_id"]
  #|          },
  #|          "topLevel": true
  #|        },
  #|        "change_score": {
  #|          "opcode": "data_changevariableby",
  #|          "next": null,
  #|          "parent": "hat_broadcast",
  #|          "inputs": {
  #|            "VALUE": [1, [4, 5]]
  #|          },
  #|          "fields": {
  #|            "VARIABLE": ["score", "var_score"]
  #|          },
  #|          "topLevel": false
  #|        }
  #|      }
  #|    }
  #|  ]
  #|}

///|
let ask_project =
  #|{
  #|  "targets": [
  #|    {
  #|      "isStage": true,
  #|      "name": "Stage",
  #|      "variables": {
  #|        "var_answer": ["answerVar", ""]
  #|      },
  #|      "lists": {},
  #|      "blocks": {}
  #|    },
  #|    {
  #|      "isStage": false,
  #|      "name": "Sprite1",
  #|      "variables": {},
  #|      "lists": {},
  #|      "blocks": {
  #|        "hat_flag": {
  #|          "opcode": "event_whenflagclicked",
  #|          "next": "ask_name",
  #|          "parent": null,
  #|          "inputs": {},
  #|          "fields": {},
  #|          "topLevel": true
  #|        },
  #|        "ask_name": {
  #|          "opcode": "sensing_askandwait",
  #|          "next": "set_answer",
  #|          "parent": "hat_flag",
  #|          "inputs": {
  #|            "QUESTION": [1, [10, "your name?"]]
  #|          },
  #|          "fields": {},
  #|          "topLevel": false
  #|        },
  #|        "set_answer": {
  #|          "opcode": "data_setvariableto",
  #|          "next": null,
  #|          "parent": "ask_name",
  #|          "inputs": {
  #|            "VALUE": [1, "answer_reporter"]
  #|          },
  #|          "fields": {
  #|            "VARIABLE": ["answerVar", "var_answer"]
  #|          },
  #|          "topLevel": false
  #|        },
  #|        "answer_reporter": {
  #|          "opcode": "sensing_answer",
  #|          "next": null,
  #|          "parent": "set_answer",
  #|          "inputs": {},
  #|          "fields": {},
  #|          "topLevel": false
  #|        }
  #|      }
  #|    }
  #|  ]
  #|}

///|
fn[T, E] unwrap_result(result : Result[T, E], message : String) -> T raise {
  match result {
    Ok(value) => value
    Err(_) => fail(message)
  }
}

///|
test "green flag + broadcast updates variable" {
  let vm = unwrap_result(
    try? @moonscratch.vm_new_from_json(broadcast_project),
    "vm init failed",
  )
  @moonscratch.vm_green_flag(vm)
  ignore(@moonscratch.vm_step(vm, 16))
  ignore(@moonscratch.vm_step(vm, 16))

  let snapshot = @moonscratch.vm_snapshot_json(vm)
  let root = unwrap_result(try? @json.parse(snapshot), "snapshot parse failed")
  let root_obj = match root {
    Object(obj) => obj
    _ => fail("snapshot must be object")
  }
  let targets = match root_obj["targets"] {
    Array(items) => items
    _ => fail("targets must be array")
  }
  let stage = match targets[0] {
    Object(obj) => obj
    _ => fail("stage must be object")
  }
  let vars = match stage["variables"] {
    Object(obj) => obj
    _ => fail("variables must be object")
  }
  assert_eq(vars["var_score"], Json::number(6.0))
}

///|
test "ask waits for answer and resumes via post_io" {
  let vm = unwrap_result(
    try? @moonscratch.vm_new_from_json(ask_project),
    "vm init failed",
  )
  @moonscratch.vm_green_flag(vm)

  ignore(@moonscratch.vm_step(vm, 16))
  let effects_before = unwrap_result(
    try? @json.parse(@moonscratch.vm_take_effects_json(vm)),
    "effects parse failed",
  )
  json_inspect(effects_before, content=[
    { "type": "ask", "question": "your name?" },
  ])

  @moonscratch.vm_post_io_json(vm, "answer", "\"moonscratch\"")
  ignore(@moonscratch.vm_step(vm, 16))

  let snapshot = unwrap_result(
    try? @json.parse(@moonscratch.vm_snapshot_json(vm)),
    "snapshot parse failed",
  )
  let root_obj = match snapshot {
    Object(obj) => obj
    _ => fail("snapshot must be object")
  }
  let targets = match root_obj["targets"] {
    Array(items) => items
    _ => fail("targets must be array")
  }
  let stage = match targets[0] {
    Object(obj) => obj
    _ => fail("stage must be object")
  }
  let vars = match stage["variables"] {
    Object(obj) => obj
    _ => fail("variables must be object")
  }
  assert_eq(vars["var_answer"], Json::string("moonscratch"))
}
