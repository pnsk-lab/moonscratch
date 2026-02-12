import * as moonscratch from '../_build/js/debug/build/moonscratch.js'

const unwrapResult = (result, context) => {
  if (result.$tag === 1) {
    return result._0
  }
  throw new Error(`${context}: ${JSON.stringify(result._0)}`)
}

const normalizeLanguage = (language) =>
  String(language ?? '')
    .trim()
    .toLowerCase() || 'en'

const cloneTranslateCache = (cache) => {
  const out = {}
  for (const [language, bucket] of Object.entries(cache ?? {})) {
    if (!bucket || typeof bucket !== 'object' || Array.isArray(bucket)) continue
    out[normalizeLanguage(language)] = {}
    for (const [words, translated] of Object.entries(bucket)) {
      out[normalizeLanguage(language)][String(words)] = String(translated)
    }
  }
  return out
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
  let translateCache = {}

  const postIO = (device, payload) => {
    moonscratch.vm_post_io_json(vm, device, JSON.stringify(payload))
  }

  const syncTranslateCache = () => {
    postIO('translate_cache', translateCache)
  }

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
      postIO(device, payload)
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
    setViewerLanguage(language) {
      postIO('viewer_language', normalizeLanguage(language))
    },
    setTranslateResult(words, language, translated) {
      const lang = normalizeLanguage(language)
      if (!translateCache[lang]) {
        translateCache[lang] = {}
      }
      translateCache[lang][String(words)] = String(translated)
      syncTranslateCache()
      return translated
    },
    setTranslateCache(cache) {
      translateCache = cloneTranslateCache(cache)
      syncTranslateCache()
    },
    clearTranslateCache() {
      translateCache = {}
      syncTranslateCache()
    },
    ackTextToSpeech(waitKey) {
      if (typeof waitKey !== 'string' || waitKey.length === 0) return
      postIO(waitKey, true)
    },
    async handleEffects(handlers = {}) {
      const effects = this.takeEffects()
      for (const effect of effects) {
        if (effect?.type === 'translate_request' && typeof handlers.translate === 'function') {
          const translated = await handlers.translate(effect)
          if (typeof translated === 'string') {
            this.setTranslateResult(effect.words, effect.language, translated)
          }
          continue
        }
        if (effect?.type === 'text_to_speech') {
          if (typeof handlers.textToSpeech === 'function') {
            await handlers.textToSpeech(effect)
          }
          this.ackTextToSpeech(effect.waitKey)
          continue
        }
        if (effect?.type === 'music_play_note' && typeof handlers.musicNote === 'function') {
          await handlers.musicNote(effect)
          continue
        }
        if (effect?.type === 'music_play_drum' && typeof handlers.musicDrum === 'function') {
          await handlers.musicDrum(effect)
        }
      }
      return effects
    },
  }
}

export { moonscratch }
