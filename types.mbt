///|
pub suberror VmError {
  InvalidProject(String)
}

///|
pub(all) struct ProjectBundle {
  project_json : String
  assets : Map[String, Json]
} derive(Show, Eq, ToJson)

///|
pub(all) struct VmOptions {
  mut turbo : Bool
  mut compatibility_30tps : Bool
  mut max_clones : Int
  mut deterministic : Bool
  mut seed : Int
} derive(Show, Eq, ToJson)

///|
pub fn default_vm_options() -> VmOptions {
  {
    turbo: false,
    compatibility_30tps: false,
    max_clones: 300,
    deterministic: false,
    seed: 0x1234_5678,
  }
}

///|
pub enum HostEffect {
  PlaySound(String, String)
  StopAllSounds
  Say(String, String)
  Think(String, String)
  Ask(String)
  Broadcast(String)
  Log(String, String)
} derive(Show, Eq, ToJson)

///|
pub enum ControlFrameKind {
  Repeat
  Forever
} derive(Show, Eq, ToJson)

///|
pub(all) struct ControlFrame {
  kind : ControlFrameKind
  mut remaining : Int
  substack : String?
  after : String?
} derive(Show, Eq, ToJson)

///|
pub(all) struct ScratchBlock {
  id : String
  opcode : String
  next : String?
  parent : String?
  inputs : Map[String, Json]
  fields : Map[String, Json]
  top_level : Bool
} derive(Show, Eq, ToJson)

///|
pub(all) struct TargetState {
  id : String
  name : String
  is_stage : Bool
  is_original : Bool
  mut deleted : Bool
  mut x : Double
  mut y : Double
  mut direction : Double
  mut size : Double
  mut visible : Bool
  mut current_costume : Int
  variables : Map[String, Json]
  variable_names : Map[String, String]
  lists : Map[String, Array[Json]]
  list_names : Map[String, String]
  blocks : Map[String, ScratchBlock]
  top_level_hats : Array[String]
}

///|
pub(all) struct Thread {
  id : Int
  target_index : Int
  mut pc : String?
  mut wait_until_ms : Int?
  mut wait_for_input : String?
  mut done : Bool
  mut stack : Array[ControlFrame]
  mut loop_counters : Map[String, Int]
  parent_waiter : Int?
}

///|
pub(all) struct Vm {
  targets : Array[TargetState]
  stage_index : Int
  assets : Map[String, Json]
  options : VmOptions
  mut threads : Array[Thread]
  mut next_thread_id : Int
  mut run_id : Int
  mut now_ms : Int
  mut running : Bool
  mut answer : String
  mut effects : Array[HostEffect]
  mut io_state : Map[String, Json]
  mut waiting_children : Map[Int, Int]
  mut rng_state : Int
  mut control_counter : Int
  mut next_clone_id : Int
}

///|
pub(all) struct StepReport {
  now_ms : Int
  active_threads : Int
  stepped_threads : Int
  emitted_effects : Int
} derive(Show, Eq, ToJson)
