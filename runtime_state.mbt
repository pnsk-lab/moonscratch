///|
fn vm_new_internal(
  bundle : ProjectBundle,
  options : VmOptions,
) -> Vm raise VmError {
  let (targets, stage_index) = parse_project_targets(bundle.project_json)
  {
    targets,
    stage_index,
    assets: bundle.assets,
    options,
    threads: [],
    next_thread_id: 1,
    run_id: 0,
    now_ms: 0,
    running: false,
    answer: "",
    effects: [],
    io_state: {},
    waiting_children: {},
    rng_state: options.seed,
  }
}

///|
fn push_effect(vm : Vm, effect : HostEffect) -> Unit {
  vm.effects.push(effect)
}

///|
fn take_effects(vm : Vm) -> Array[HostEffect] {
  let out = vm.effects.copy()
  vm.effects.clear()
  out
}

///|
fn next_random_unit(vm : Vm) -> Double {
  // 32-bit LCG for deterministic stepping.
  vm.rng_state = vm.rng_state * 1664525 + 1013904223
  let unsigned = vm.rng_state.abs()
  let x = unsigned % 1000000
  Double::from_int(x) / 1000000.0
}

///|
fn current_step_budget(vm : Vm) -> Int {
  if vm.options.turbo {
    1000
  } else {
    200
  }
}

///|
fn resolve_variable_ref(
  vm : Vm,
  target_index : Int,
  variable_id : String?,
  variable_name : String?,
) -> (Int, String)? {
  let target = vm.targets[target_index]
  let stage = vm.targets[vm.stage_index]

  match variable_id {
    Some(id) => {
      if target.variables.contains(id) {
        return Some((target_index, id))
      }
      if stage.variables.contains(id) {
        return Some((vm.stage_index, id))
      }
      None
    }
    None =>
      match variable_name {
        Some(name) =>
          match target.variable_names.get(name) {
            Some(id) => Some((target_index, id))
            None =>
              match stage.variable_names.get(name) {
                Some(id) => Some((vm.stage_index, id))
                None => None
              }
          }
        None => None
      }
  }
}

///|
fn read_variable(
  vm : Vm,
  target_index : Int,
  variable_id : String?,
  variable_name : String?,
) -> Json {
  match resolve_variable_ref(vm, target_index, variable_id, variable_name) {
    Some((owner_index, id)) =>
      vm.targets[owner_index].variables.get_or_default(id, Json::null())
    None => Json::null()
  }
}

///|
fn write_variable(
  vm : Vm,
  target_index : Int,
  variable_id : String?,
  variable_name : String?,
  value : Json,
) -> Unit {
  match resolve_variable_ref(vm, target_index, variable_id, variable_name) {
    Some((owner_index, id)) => vm.targets[owner_index].variables[id] = value
    None =>
      match variable_name {
        Some(name) => {
          let stage_index = vm.stage_index
          let new_id = "stage_var_\{name}"
          vm.targets[stage_index].variables[new_id] = value
          vm.targets[stage_index].variable_names[name] = new_id
        }
        None => ()
      }
  }
}

///|
fn resolve_list_ref(
  vm : Vm,
  target_index : Int,
  list_id : String?,
  list_name : String?,
) -> (Int, String)? {
  let target = vm.targets[target_index]
  let stage = vm.targets[vm.stage_index]

  match list_id {
    Some(id) => {
      if target.lists.contains(id) {
        return Some((target_index, id))
      }
      if stage.lists.contains(id) {
        return Some((vm.stage_index, id))
      }
      None
    }
    None =>
      match list_name {
        Some(name) =>
          match target.list_names.get(name) {
            Some(id) => Some((target_index, id))
            None =>
              match stage.list_names.get(name) {
                Some(id) => Some((vm.stage_index, id))
                None => None
              }
          }
        None => None
      }
  }
}

///|
fn read_list(
  vm : Vm,
  target_index : Int,
  list_id : String?,
  list_name : String?,
) -> Array[Json] {
  match resolve_list_ref(vm, target_index, list_id, list_name) {
    Some((owner_index, id)) =>
      vm.targets[owner_index].lists.get_or_default(id, [])
    None => []
  }
}

///|
fn with_list_mut(
  vm : Vm,
  target_index : Int,
  list_id : String?,
  list_name : String?,
) -> (Int, String)? {
  match resolve_list_ref(vm, target_index, list_id, list_name) {
    Some(pair) => Some(pair)
    None =>
      match list_name {
        Some(name) => {
          let stage_index = vm.stage_index
          let created = "stage_list_\{name}"
          vm.targets[stage_index].lists[created] = []
          vm.targets[stage_index].list_names[name] = created
          Some((stage_index, created))
        }
        None => None
      }
  }
}

///|
fn spawn_thread(
  vm : Vm,
  target_index : Int,
  start_block : String,
  parent_waiter : Int?,
) -> Unit {
  let thread_id = vm.next_thread_id
  vm.next_thread_id += 1
  let thread : Thread = {
    id: thread_id,
    target_index,
    pc: Some(start_block),
    wait_until_ms: None,
    wait_for_input: None,
    done: false,
    stack: [],
    parent_waiter,
  }
  vm.threads.push(thread)
}

///|
fn clear_threads(vm : Vm) -> Unit {
  vm.threads.clear()
  vm.waiting_children.clear()
  vm.running = false
}

///|
fn decrement_waiting_child(vm : Vm, waiter_id : Int) -> Unit {
  let current = vm.waiting_children.get_or_default(waiter_id, 0)
  if current <= 1 {
    vm.waiting_children.remove(waiter_id)
  } else {
    vm.waiting_children[waiter_id] = current - 1
  }
}

///|
fn cleanup_done_threads(vm : Vm) -> Unit {
  let survivors = []
  for thread in vm.threads {
    if thread.done {
      match thread.parent_waiter {
        Some(waiter) => decrement_waiting_child(vm, waiter)
        None => ()
      }
    } else {
      survivors.push(thread)
    }
  }
  vm.threads = survivors
  if vm.threads.is_empty() {
    vm.running = false
  }
}
