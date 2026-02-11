import * as moonscratch from '../_build/js/debug/build/moonscratch.js'

const unwrapResult = (result, context) => {
  if (result.$tag === 1) {
    return result._0
  }
  throw new Error(`${context}: ${JSON.stringify(result._0)}`)
}

export const createHeadlessVM = ({ projectJson, assets = {}, options } = {}) => {
  if (typeof projectJson !== 'string' || projectJson.length === 0) {
    throw new Error('projectJson must be a non-empty string')
  }

  const assetsJson = JSON.stringify(assets)
  const optionsJson = options ? JSON.stringify(options) : undefined
  const vm = unwrapResult(
    moonscratch.vm_new_from_json(projectJson, assetsJson, optionsJson),
    'vm_new_from_json failed',
  )

  return {
    raw: vm,
    start() {
      moonscratch.vm_start(vm)
    },
    greenFlag() {
      moonscratch.vm_green_flag(vm)
    },
    step(dtMs = 16) {
      return moonscratch.vm_step(vm, dtMs)
    },
    postIO(device, payload) {
      moonscratch.vm_post_io_json(vm, device, JSON.stringify(payload))
    },
    broadcast(message) {
      moonscratch.vm_broadcast(vm, message)
    },
    stopAll() {
      moonscratch.vm_stop_all(vm)
    },
    takeEffects() {
      return JSON.parse(moonscratch.vm_take_effects_json(vm))
    },
    snapshot() {
      return JSON.parse(moonscratch.vm_snapshot_json(vm))
    },
    snapshotJson() {
      return moonscratch.vm_snapshot_json(vm)
    },
  }
}

export { moonscratch }
