///|
fn repeat_frame(
  remaining : Int,
  substack : String?,
  after : String?,
) -> ControlFrame {
  { kind: ControlFrameKind::Repeat, remaining, substack, after }
}

///|
fn forever_frame(substack : String?) -> ControlFrame {
  { kind: ControlFrameKind::Forever, remaining: 0, substack, after: None }
}

///|
fn unwind_control(thread : Thread) -> Thread {
  let thread = thread
  while thread.pc is None {
    match thread.stack.pop() {
      Some(frame) =>
        match frame.kind {
          ControlFrameKind::Repeat =>
            if frame.remaining > 1 {
              let next_frame = frame
              next_frame.remaining = frame.remaining - 1
              thread.stack.push(next_frame)
              thread.pc = frame.substack
            } else {
              thread.pc = frame.after
            }
          ControlFrameKind::Forever => thread.pc = frame.substack
        }
      None => {
        thread.done = true
        return thread
      }
    }
  }
  thread
}

///|
fn kill_other_scripts_for_target(
  vm : Vm,
  target_index : Int,
  current_thread_id : Int,
) -> Unit {
  for i, thread in vm.threads {
    if thread.target_index == target_index && thread.id != current_thread_id {
      vm.threads[i].done = true
    }
  }
}

///|
fn block_broadcast_name(
  vm : Vm,
  target_index : Int,
  block : ScratchBlock,
) -> String {
  let from_input = value_from_input(
    vm, target_index, block, "BROADCAST_INPUT", 0,
  )
  let from_input_text = json_to_string_value(from_input)
  if from_input_text != "" {
    return from_input_text
  }
  match field_value(block, "BROADCAST_OPTION") {
    Some((name, _)) => name
    None => ""
  }
}

///|
fn hat_broadcast_name(block : ScratchBlock) -> String {
  match field_value(block, "BROADCAST_OPTION") {
    Some((name, _)) => name
    None => ""
  }
}

///|
fn block_clone_option(
  vm : Vm,
  target_index : Int,
  block : ScratchBlock,
) -> String {
  let from_input = json_to_string_value(
    value_from_input(vm, target_index, block, "CLONE_OPTION", 0),
  )
  if from_input != "" {
    return from_input
  }
  match field_value(block, "CLONE_OPTION") {
    Some((name, _)) => name
    None => ""
  }
}

///|
fn find_clone_source_target(vm : Vm, current_target_index : Int, name : String) -> Int? {
  if name == "_myself_" {
    if current_target_index >= 0 &&
      current_target_index < vm.targets.length() &&
      !vm.targets[current_target_index].deleted {
      return Some(current_target_index)
    }
    return None
  }

  for i, target in vm.targets {
    if !target.deleted &&
      !target.is_stage &&
      target.is_original &&
      target.name == name {
      return Some(i)
    }
  }
  for i, target in vm.targets {
    if !target.deleted && !target.is_stage && target.name == name {
      return Some(i)
    }
  }
  None
}

///|
fn spawn_clone_start_hats(vm : Vm, target_index : Int) -> Int {
  if target_index < 0 || target_index >= vm.targets.length() {
    return 0
  }
  let target = vm.targets[target_index]
  if target.deleted {
    return 0
  }

  let mut count = 0
  for hat_id in target.top_level_hats {
    match target.blocks.get(hat_id) {
      Some(hat) =>
        if hat.opcode == "control_start_as_clone" {
          match hat.next {
            Some(start) => {
              spawn_thread(vm, target_index, start, None)
              count += 1
            }
            None => ()
          }
        }
      None => ()
    }
  }
  count
}

///|
fn spawn_hats_for_message(
  vm : Vm,
  message : String,
  parent_waiter : Int?,
) -> Int {
  let mut count = 0
  for target_index, target in vm.targets {
    if target.deleted {
      continue
    }
    for hat_id in target.top_level_hats {
      match target.blocks.get(hat_id) {
        Some(hat) =>
          if hat.opcode == "event_whenbroadcastreceived" &&
            hat_broadcast_name(hat) == message {
            match hat.next {
              Some(start) => {
                spawn_thread(vm, target_index, start, parent_waiter)
                count += 1
              }
              None => ()
            }
          }
        None => ()
      }
    }
  }
  count
}

///|
fn spawn_green_flag_hats(vm : Vm) -> Int {
  let mut count = 0
  for target_index, target in vm.targets {
    if target.deleted {
      continue
    }
    for hat_id in target.top_level_hats {
      match target.blocks.get(hat_id) {
        Some(hat) =>
          if hat.opcode == "event_whenflagclicked" {
            match hat.next {
              Some(start) => {
                spawn_thread(vm, target_index, start, None)
                count += 1
              }
              None => ()
            }
          }
        None => ()
      }
    }
  }
  count
}

///|
fn resolve_thread_input_wait(vm : Vm, thread : Thread) -> Thread {
  match thread.wait_for_input {
    Some(key) => {
      match vm.io_state.get(key) {
        Some(value) => {
          if key == "answer" {
            vm.answer = json_to_string_value(value)
          }
          vm.io_state.remove(key)
          thread.wait_for_input = None
        }
        None => ()
      }
      thread
    }
    None => thread
  }
}

///|
fn is_thread_blocked(vm : Vm, thread : Thread) -> Bool {
  let waiting_time = match thread.wait_until_ms {
    Some(until_ms) if vm.now_ms < until_ms => true
    Some(_) => false
    None => false
  }
  let waiting_input = match thread.wait_for_input {
    Some(_) => true
    None => false
  }
  let waiting_children = vm.waiting_children.get_or_default(thread.id, 0) > 0
  waiting_time || waiting_input || waiting_children
}

///|
fn execute_list_delete(
  vm : Vm,
  target_index : Int,
  block : ScratchBlock,
) -> Unit {
  match field_value(block, "LIST") {
    Some((list_name, list_id)) =>
      match with_list_mut(vm, target_index, list_id, Some(list_name)) {
        Some((owner, id)) => {
          let list = vm.targets[owner].lists.get_or_default(id, [])
          let index_value = value_from_input(
            vm, target_index, block, "INDEX", 0,
          )
          let key = json_to_string_value(index_value).trim().to_lower()
          if key == "all" {
            list.clear()
          } else {
            match
              normalize_index(index_value, list.length(), next_random_unit(vm)) {
              Some(index) =>
                if index >= 0 && index < list.length() {
                  ignore(list.remove(index))
                }
              None => ()
            }
          }
          vm.targets[owner].lists[id] = list
        }
        None => ()
      }
    None => ()
  }
}

///|
fn execute_list_insert(
  vm : Vm,
  target_index : Int,
  block : ScratchBlock,
) -> Unit {
  match field_value(block, "LIST") {
    Some((list_name, list_id)) =>
      match with_list_mut(vm, target_index, list_id, Some(list_name)) {
        Some((owner, id)) => {
          let list = vm.targets[owner].lists.get_or_default(id, [])
          let item = value_from_input(vm, target_index, block, "ITEM", 0)
          let index_value = value_from_input(
            vm, target_index, block, "INDEX", 0,
          )
          let raw = json_to_string_value(index_value).trim().to_lower()
          let idx = if raw == "last" {
            list.length()
          } else if raw == "random" || raw == "any" {
            let sampled = (next_random_unit(vm) *
              Double::from_int(list.length() + 1))
              .floor()
              .to_int()
            sampled.clamp(min=0, max=list.length())
          } else {
            let n = json_to_number_value(index_value).to_int() - 1
            n.clamp(min=0, max=list.length())
          }
          list.insert(idx, item)
          vm.targets[owner].lists[id] = list
        }
        None => ()
      }
    None => ()
  }
}

///|
fn execute_list_replace(
  vm : Vm,
  target_index : Int,
  block : ScratchBlock,
) -> Unit {
  match field_value(block, "LIST") {
    Some((list_name, list_id)) =>
      match with_list_mut(vm, target_index, list_id, Some(list_name)) {
        Some((owner, id)) => {
          let list = vm.targets[owner].lists.get_or_default(id, [])
          let item = value_from_input(vm, target_index, block, "ITEM", 0)
          let index_value = value_from_input(
            vm, target_index, block, "INDEX", 0,
          )
          match
            normalize_index(index_value, list.length(), next_random_unit(vm)) {
            Some(index) =>
              if index >= 0 && index < list.length() {
                list[index] = item
              }
            None => ()
          }
          vm.targets[owner].lists[id] = list
        }
        None => ()
      }
    None => ()
  }
}

///|
fn execute_thread_once(vm : Vm, thread : Thread) -> Thread {
  let mut thread = thread
  if thread.done {
    return thread
  }

  thread = resolve_thread_input_wait(vm, thread)
  if thread.wait_for_input is Some(_) {
    return thread
  }

  match thread.wait_until_ms {
    Some(until_ms) => {
      if vm.now_ms < until_ms {
        return thread
      }
      thread.wait_until_ms = None
    }
    None => ()
  }

  if vm.waiting_children.get_or_default(thread.id, 0) > 0 {
    return thread
  }

  let block_id = match thread.pc {
    Some(id) => id
    None => {
      thread.done = true
      return thread
    }
  }

  let target_index = thread.target_index
  if target_index < 0 || target_index >= vm.targets.length() {
    thread.done = true
    return thread
  }
  if vm.targets[target_index].deleted {
    thread.done = true
    return thread
  }
  let target = vm.targets[target_index]
  let block = match target.blocks.get(block_id) {
    Some(value) => value
    None => {
      thread.pc = None
      return unwind_control(thread)
    }
  }

  let mut next_pc = block.next

  match block.opcode {
    "motion_movesteps" => {
      let steps = json_to_number_value(
        value_from_input(vm, target_index, block, "STEPS", 0),
      )
      let radians = (90.0 - vm.targets[target_index].direction) *
        @math.PI /
        180.0
      vm.targets[target_index].x += @math.cos(radians) * steps
      vm.targets[target_index].y += @math.sin(radians) * steps
    }
    "motion_turnright" => {
      let degrees = json_to_number_value(
        value_from_input(vm, target_index, block, "DEGREES", 0),
      )
      vm.targets[target_index].direction += degrees
    }
    "motion_turnleft" => {
      let degrees = json_to_number_value(
        value_from_input(vm, target_index, block, "DEGREES", 0),
      )
      vm.targets[target_index].direction -= degrees
    }
    "motion_changexby" => {
      let value = json_to_number_value(
        value_from_input(vm, target_index, block, "DX", 0),
      )
      vm.targets[target_index].x += value
    }
    "motion_changeyby" => {
      let value = json_to_number_value(
        value_from_input(vm, target_index, block, "DY", 0),
      )
      vm.targets[target_index].y += value
    }
    "motion_setx" =>
      vm.targets[target_index].x = json_to_number_value(
        value_from_input(vm, target_index, block, "X", 0),
      )
    "motion_sety" =>
      vm.targets[target_index].y = json_to_number_value(
        value_from_input(vm, target_index, block, "Y", 0),
      )
    "motion_gotoxy" => {
      vm.targets[target_index].x = json_to_number_value(
        value_from_input(vm, target_index, block, "X", 0),
      )
      vm.targets[target_index].y = json_to_number_value(
        value_from_input(vm, target_index, block, "Y", 0),
      )
    }
    "looks_show" => vm.targets[target_index].visible = true
    "looks_hide" => vm.targets[target_index].visible = false
    "looks_switchcostumeto" => {
      let costume = json_to_number_value(
        value_from_input(vm, target_index, block, "COSTUME", 0),
      ).to_int()
      vm.targets[target_index].current_costume = if costume < 0 {
        0
      } else {
        costume
      }
    }
    "looks_nextcostume" => vm.targets[target_index].current_costume += 1
    "looks_changesizeby" => {
      let delta = json_to_number_value(
        value_from_input(vm, target_index, block, "CHANGE", 0),
      )
      vm.targets[target_index].size += delta
    }
    "looks_setsizeto" => {
      let size = json_to_number_value(
        value_from_input(vm, target_index, block, "SIZE", 0),
      )
      vm.targets[target_index].size = size
    }
    "looks_say" => {
      let message = json_to_string_value(
        value_from_input(vm, target_index, block, "MESSAGE", 0),
      )
      push_effect(vm, HostEffect::Say(vm.targets[target_index].name, message))
    }
    "looks_think" => {
      let message = json_to_string_value(
        value_from_input(vm, target_index, block, "MESSAGE", 0),
      )
      push_effect(vm, HostEffect::Think(vm.targets[target_index].name, message))
    }
    "looks_sayforsecs" => {
      let message = json_to_string_value(
        value_from_input(vm, target_index, block, "MESSAGE", 0),
      )
      let seconds = json_to_number_value(
        value_from_input(vm, target_index, block, "SECS", 0),
      )
      push_effect(vm, HostEffect::Say(vm.targets[target_index].name, message))
      let duration = if seconds < 0.0 { 0.0 } else { seconds }
      thread.wait_until_ms = Some(vm.now_ms + (duration * 1000.0).to_int())
    }
    "looks_thinkforsecs" => {
      let message = json_to_string_value(
        value_from_input(vm, target_index, block, "MESSAGE", 0),
      )
      let seconds = json_to_number_value(
        value_from_input(vm, target_index, block, "SECS", 0),
      )
      push_effect(vm, HostEffect::Think(vm.targets[target_index].name, message))
      let duration = if seconds < 0.0 { 0.0 } else { seconds }
      thread.wait_until_ms = Some(vm.now_ms + (duration * 1000.0).to_int())
    }
    "sound_play" | "sound_playuntildone" => {
      let sound = json_to_string_value(
        value_from_input(vm, target_index, block, "SOUND_MENU", 0),
      )
      push_effect(
        vm,
        HostEffect::PlaySound(vm.targets[target_index].name, sound),
      )
    }
    "sound_stopallsounds" => push_effect(vm, HostEffect::StopAllSounds)
    "data_setvariableto" =>
      match field_value(block, "VARIABLE") {
        Some((name, id)) => {
          let value = value_from_input(vm, target_index, block, "VALUE", 0)
          write_variable(vm, target_index, id, Some(name), value)
        }
        None => ()
      }
    "data_changevariableby" =>
      match field_value(block, "VARIABLE") {
        Some((name, id)) => {
          let delta = json_to_number_value(
            value_from_input(vm, target_index, block, "VALUE", 0),
          )
          let current = json_to_number_value(
            read_variable(vm, target_index, id, Some(name)),
          )
          write_variable(
            vm,
            target_index,
            id,
            Some(name),
            json_number(current + delta),
          )
        }
        None => ()
      }
    "data_addtolist" =>
      match field_value(block, "LIST") {
        Some((list_name, list_id)) =>
          match with_list_mut(vm, target_index, list_id, Some(list_name)) {
            Some((owner, id)) => {
              let list = vm.targets[owner].lists.get_or_default(id, [])
              list.push(value_from_input(vm, target_index, block, "ITEM", 0))
              vm.targets[owner].lists[id] = list
            }
            None => ()
          }
        None => ()
      }
    "data_deleteoflist" => execute_list_delete(vm, target_index, block)
    "data_deletealloflist" =>
      match field_value(block, "LIST") {
        Some((list_name, list_id)) =>
          match with_list_mut(vm, target_index, list_id, Some(list_name)) {
            Some((owner, id)) => vm.targets[owner].lists[id] = []
            None => ()
          }
        None => ()
      }
    "data_insertatlist" => execute_list_insert(vm, target_index, block)
    "data_replaceitemoflist" => execute_list_replace(vm, target_index, block)
    "control_wait" => {
      let duration_raw = json_to_number_value(
        value_from_input(vm, target_index, block, "DURATION", 0),
      )
      let duration = if duration_raw < 0.0 { 0.0 } else { duration_raw }
      thread.wait_until_ms = Some(vm.now_ms + (duration * 1000.0).to_int())
    }
    "control_wait_until" => {
      let condition = json_to_bool_value(
        value_from_input(vm, target_index, block, "CONDITION", 0),
      )
      if !condition {
        next_pc = Some(block.id)
      }
    }
    "control_repeat" => {
      let times = json_to_number_value(
          value_from_input(vm, target_index, block, "TIMES", 0),
        )
        .floor()
        .to_int()
      if times > 0 {
        let substack = block_input_block_id(block, "SUBSTACK")
        thread.stack.push(repeat_frame(times, substack, block.next))
        next_pc = substack
      }
    }
    "control_repeat_until" => {
      let condition = json_to_bool_value(
        value_from_input(vm, target_index, block, "CONDITION", 0),
      )
      if !condition {
        let substack = block_input_block_id(block, "SUBSTACK")
        thread.stack.push(repeat_frame(1, substack, Some(block.id)))
        next_pc = substack
      }
    }
    "control_while" => {
      let condition = json_to_bool_value(
        value_from_input(vm, target_index, block, "CONDITION", 0),
      )
      if condition {
        let substack = block_input_block_id(block, "SUBSTACK")
        thread.stack.push(repeat_frame(1, substack, Some(block.id)))
        next_pc = substack
      }
    }
    "control_for_each" =>
      match field_value(block, "VARIABLE") {
        Some((name, id)) => {
          let limit = json_to_number_value(
            value_from_input(vm, target_index, block, "VALUE", 0),
          )
          let key = "for_each:\{block.id}"
          let index = thread.loop_counters.get_or_default(key, 0)
          if Double::from_int(index) < limit {
            let next_index = index + 1
            thread.loop_counters[key] = next_index
            write_variable(
              vm,
              target_index,
              id,
              Some(name),
              json_number(Double::from_int(next_index)),
            )
            let substack = block_input_block_id(block, "SUBSTACK")
            thread.stack.push(repeat_frame(1, substack, Some(block.id)))
            next_pc = substack
          } else {
            thread.loop_counters.remove(key)
          }
        }
        None => ()
      }
    "control_forever" => {
      let substack = block_input_block_id(block, "SUBSTACK")
      thread.stack.push(forever_frame(substack))
      next_pc = substack
    }
    "control_if" => {
      let condition = json_to_bool_value(
        value_from_input(vm, target_index, block, "CONDITION", 0),
      )
      if condition {
        let substack = block_input_block_id(block, "SUBSTACK")
        thread.stack.push(repeat_frame(1, substack, block.next))
        next_pc = substack
      }
    }
    "control_if_else" => {
      let condition = json_to_bool_value(
        value_from_input(vm, target_index, block, "CONDITION", 0),
      )
      let branch = if condition {
        block_input_block_id(block, "SUBSTACK")
      } else {
        block_input_block_id(block, "SUBSTACK2")
      }
      thread.stack.push(repeat_frame(1, branch, block.next))
      next_pc = branch
    }
    "control_all_at_once" => {
      let substack = block_input_block_id(block, "SUBSTACK")
      thread.stack.push(repeat_frame(1, substack, block.next))
      next_pc = substack
    }
    "control_stop" => {
      let option = json_to_string_value(
        value_from_input(vm, target_index, block, "STOP_OPTION", 0),
      ).to_lower()
      if option == "all" {
        clear_threads(vm)
        push_effect(vm, HostEffect::StopAllSounds)
      } else if option == "other scripts in sprite" ||
        option == "other scripts in stage" {
        kill_other_scripts_for_target(vm, target_index, thread.id)
      }
      if option == "this script" ||
        option == "all" ||
        option == "other scripts in sprite" ||
        option == "other scripts in stage" {
        thread.done = true
      }
    }
    "control_create_clone_of" => {
      let option = block_clone_option(vm, target_index, block)
      if option != "" {
        match find_clone_source_target(vm, target_index, option) {
          Some(source_index) =>
            match spawn_clone_target(vm, source_index) {
              Some(clone_target_index) =>
                ignore(spawn_clone_start_hats(vm, clone_target_index))
              None => ()
            }
          None => ()
        }
      }
    }
    "control_delete_this_clone" => {
      if !vm.targets[target_index].is_original && !vm.targets[target_index].is_stage {
        dispose_clone_target(vm, target_index, thread.id)
        thread.done = true
      }
    }
    "control_clear_counter" => vm.control_counter = 0
    "control_incr_counter" => vm.control_counter += 1
    "event_broadcast" => {
      let message = block_broadcast_name(vm, target_index, block)
      if message != "" {
        ignore(spawn_hats_for_message(vm, message, None))
        push_effect(vm, HostEffect::Broadcast(message))
      }
    }
    "event_broadcastandwait" => {
      let message = block_broadcast_name(vm, target_index, block)
      if message != "" {
        let spawned = spawn_hats_for_message(vm, message, Some(thread.id))
        if spawned > 0 {
          vm.waiting_children[thread.id] = spawned
        }
        push_effect(vm, HostEffect::Broadcast(message))
      }
    }
    "sensing_askandwait" => {
      let question = json_to_string_value(
        value_from_input(vm, target_index, block, "QUESTION", 0),
      )
      push_effect(vm, HostEffect::Ask(question))
      thread.wait_for_input = Some("answer")
    }
    "sensing_setdragmode"
    | "control_start_as_clone"
    | "event_whenflagclicked"
    | "event_whenbroadcastreceived" => ()
    _ =>
      push_effect(
        vm,
        HostEffect::Log("warn", "unimplemented opcode: \{block.opcode}"),
      )
  }

  if thread.done {
    return thread
  }

  thread.pc = next_pc
  if thread.pc is None {
    unwind_control(thread)
  } else {
    thread
  }
}

///|
fn start_vm_runtime(vm : Vm) -> Unit {
  vm.running = true
}

///|
fn green_flag_runtime(vm : Vm) -> Unit {
  clear_threads(vm)
  reset_targets_for_green_flag(vm)
  vm.run_id += 1
  vm.running = true
  let spawned = spawn_green_flag_hats(vm)
  if spawned == 0 {
    vm.running = false
  }
}

///|
fn broadcast_runtime(vm : Vm, message : String) -> Unit {
  if message == "" {
    return
  }
  let spawned = spawn_hats_for_message(vm, message, None)
  if spawned > 0 {
    vm.running = true
  }
  push_effect(vm, HostEffect::Broadcast(message))
}

///|
fn post_io_json_runtime(
  vm : Vm,
  device : String,
  payload_json : String,
) -> Unit {
  if payload_json.trim().is_empty() {
    vm.io_state[device] = Json::null()
    return
  }
  let parsed = try? @json.parse(payload_json)
  match parsed {
    Ok(payload) => vm.io_state[device] = payload
    Err(err) =>
      push_effect(vm, HostEffect::Log("error", "invalid io payload: \{err}"))
  }
}

///|
fn step_runtime(vm : Vm, dt_ms : Int) -> StepReport {
  if dt_ms > 0 {
    vm.now_ms += dt_ms
  }

  let mut stepped = 0
  if vm.running {
    let budget = current_step_budget(vm)
    let mut index = 0
    while index < vm.threads.length() && stepped < budget {
      let thread = vm.threads[index]
      let updated = execute_thread_once(vm, thread)
      vm.threads[index] = updated
      if !is_thread_blocked(vm, updated) && !updated.done {
        stepped += 1
      } else if updated.done {
        stepped += 1
      }
      index += 1
    }
  }

  cleanup_done_threads(vm)

  {
    now_ms: vm.now_ms,
    active_threads: vm.threads.length(),
    stepped_threads: stepped,
    emitted_effects: vm.effects.length(),
  }
}
