import * as moonscratch from '../_build/js/debug/build/moonscratch.js'
import type { ScratchProject } from 'sb3-types'

type MaybePromise<T> = T | Promise<T>

export type JsonPrimitive = string | number | boolean | null
export type JsonValue = JsonPrimitive | { [key: string]: JsonValue } | JsonValue[]
export type ProjectJson = JsonValue | ScratchProject

export interface VMOptions {
  turbo: boolean
  compatibility30tps: boolean
  maxClones: number
  deterministic: boolean
  seed: number
  penWidth: number
  penHeight: number
}

export interface VMOptionsInput extends Partial<VMOptions> {
  compatibility_30tps?: boolean
  max_clones?: number
  pen_width?: number
  pen_height?: number
}

interface RawVMOptions {
  turbo?: boolean
  compatibility_30tps?: boolean
  max_clones?: number
  deterministic?: boolean
  seed?: number
  pen_width?: number
  pen_height?: number
}

interface RawStepReport {
  now_ms: number
  active_threads: number
  stepped_threads: number
  emitted_effects: number
}

export interface StepReport {
  nowMs: number
  activeThreads: number
  steppedThreads: number
  emittedEffects: number
}

export interface VMSnapshotTarget {
  id: string
  name: string
  isStage: boolean
  x: number
  y: number
  direction: number
  size: number
  volume: number
  musicInstrument: number
  textToSpeechVoice: string
  visible: boolean
  currentCostume: number
  variables: Record<string, JsonValue>
  lists: Record<string, JsonValue[]>
}

export interface VMSnapshot {
  runId: number
  nowMs: number
  running: boolean
  answer: string
  musicTempo: number
  textToSpeechLanguage: string
  activeThreads: number
  targets: VMSnapshotTarget[]
}

export interface PlaySoundEffect {
  type: 'play_sound'
  target: string
  sound: string
}

export interface MusicPlayNoteEffect {
  type: 'music_play_note'
  target: string
  note: number
  beats: number
  instrument: number
  tempo: number
}

export interface MusicPlayDrumEffect {
  type: 'music_play_drum'
  target: string
  drum: number
  beats: number
  tempo: number
}

export interface TextToSpeechEffect {
  type: 'text_to_speech'
  target: string
  words: string
  voice: string
  language: string
  waitKey: string
}

export interface TranslateRequestEffect {
  type: 'translate_request'
  words: string
  language: string
}

export interface StopAllSoundsEffect {
  type: 'stop_all_sounds'
}

export interface SayEffect {
  type: 'say'
  target: string
  message: string
}

export interface ThinkEffect {
  type: 'think'
  target: string
  message: string
}

export interface AskEffect {
  type: 'ask'
  question: string
}

export interface BroadcastEffect {
  type: 'broadcast'
  message: string
}

export interface LogEffect {
  type: 'log'
  level: string
  message: string
}

export interface UnknownEffect {
  type: string
  [key: string]: JsonValue
}

type KnownEffect =
  | PlaySoundEffect
  | MusicPlayNoteEffect
  | MusicPlayDrumEffect
  | TextToSpeechEffect
  | TranslateRequestEffect
  | StopAllSoundsEffect
  | SayEffect
  | ThinkEffect
  | AskEffect
  | BroadcastEffect
  | LogEffect

export type VMEffect = KnownEffect | UnknownEffect

export type TranslateCache = Record<string, Record<string, string>>

export interface EffectHandlers {
  translate?: (effect: TranslateRequestEffect) => MaybePromise<string | null | undefined>
  textToSpeech?: (effect: TextToSpeechEffect) => MaybePromise<void>
  musicNote?: (effect: MusicPlayNoteEffect) => MaybePromise<void>
  musicDrum?: (effect: MusicPlayDrumEffect) => MaybePromise<void>
  effect?: (effect: VMEffect) => MaybePromise<void>
}

export interface CreateHeadlessVMOptions {
  projectJson: string | ProjectJson
  assets?: string | Record<string, JsonValue>
  options?: string | VMOptionsInput
  viewerLanguage?: string
  translateCache?: TranslateCache
}

interface MoonOk<T> {
  $tag: 1
  _0: T
}

interface MoonErr<E> {
  $tag: 0
  _0: E
}

type MoonResult<T, E> = MoonOk<T> | MoonErr<E>

const DEFAULT_LANGUAGE = 'en'
const DEFAULT_STEP_MS = 16

const normalizeLanguage = (language: unknown): string =>
  String(language ?? '')
    .trim()
    .toLowerCase() || DEFAULT_LANGUAGE

const cloneTranslateCache = (cache: TranslateCache | undefined): TranslateCache => {
  const out: TranslateCache = {}
  for (const [language, bucket] of Object.entries(cache ?? {})) {
    if (!bucket || typeof bucket !== 'object' || Array.isArray(bucket)) {
      continue
    }
    const normalizedLanguage = normalizeLanguage(language)
    out[normalizedLanguage] = {}
    for (const [words, translated] of Object.entries(bucket)) {
      out[normalizedLanguage][String(words)] = String(translated)
    }
  }
  return out
}

const toJsonString = (
  input: string | ProjectJson,
  inputName: string,
  requireNonEmpty: boolean,
): string => {
  if (typeof input === 'string') {
    if (requireNonEmpty && input.trim().length === 0) {
      throw new Error(`${inputName} must be a non-empty JSON string or object`)
    }
    return input
  }

  try {
    return JSON.stringify(input)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(`${inputName} could not be serialized as JSON: ${message}`)
  }
}

const toOptionalJsonString = (
  input: string | JsonValue | undefined,
  inputName: string,
): string | undefined => {
  if (input === undefined) {
    return undefined
  }
  return toJsonString(input, inputName, false)
}

const toOptionsJson = (options: string | VMOptionsInput | undefined): string | undefined => {
  if (options === undefined) {
    return undefined
  }
  if (typeof options === 'string') {
    return options
  }

  const raw: RawVMOptions = {}
  if (options.turbo !== undefined) {
    raw.turbo = options.turbo
  }

  const compatibility30tps = options.compatibility30tps ?? options.compatibility_30tps
  if (compatibility30tps !== undefined) {
    raw.compatibility_30tps = compatibility30tps
  }

  const maxClones = options.maxClones ?? options.max_clones
  if (maxClones !== undefined) {
    raw.max_clones = maxClones
  }

  if (options.deterministic !== undefined) {
    raw.deterministic = options.deterministic
  }

  if (options.seed !== undefined) {
    raw.seed = options.seed
  }

  const penWidth = options.penWidth ?? options.pen_width
  if (penWidth !== undefined) {
    raw.pen_width = penWidth
  }

  const penHeight = options.penHeight ?? options.pen_height
  if (penHeight !== undefined) {
    raw.pen_height = penHeight
  }

  return JSON.stringify(raw)
}

const formatVmError = (error: unknown): string => {
  if (error && typeof error === 'object') {
    const candidate = (error as { _0?: unknown })._0
    if (typeof candidate === 'string' && candidate.trim().length > 0) {
      return candidate
    }
  }
  try {
    return JSON.stringify(error)
  } catch {
    return String(error)
  }
}

const unwrapResult = <T>(result: MoonResult<T, unknown>, context: string): T => {
  if (result.$tag === 1) {
    return result._0
  }
  throw new Error(`${context}: ${formatVmError(result._0)}`)
}

const parseJson = <T>(text: string, context: string): T => {
  try {
    return JSON.parse(text) as T
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(`${context}: failed to parse JSON (${message})`)
  }
}

const normalizeStepMs = (dtMs: number): number => {
  if (!Number.isFinite(dtMs)) {
    throw new Error('dtMs must be a finite number')
  }
  return Math.max(0, Math.trunc(dtMs))
}

const isObjectRecord = (value: unknown): value is Record<string, JsonValue | unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

const hasStringField = (value: unknown, key: string): value is { [k: string]: string } =>
  isObjectRecord(value) && typeof value[key] === 'string'

const hasNumberField = (value: unknown, key: string): value is { [k: string]: number } =>
  isObjectRecord(value) && typeof value[key] === 'number'

const isTranslateRequestEffect = (effect: VMEffect): effect is TranslateRequestEffect =>
  effect.type === 'translate_request' &&
  hasStringField(effect, 'words') &&
  hasStringField(effect, 'language')

const isTextToSpeechEffect = (effect: VMEffect): effect is TextToSpeechEffect =>
  effect.type === 'text_to_speech' &&
  hasStringField(effect, 'target') &&
  hasStringField(effect, 'words') &&
  hasStringField(effect, 'voice') &&
  hasStringField(effect, 'language') &&
  hasStringField(effect, 'waitKey')

const isMusicPlayNoteEffect = (effect: VMEffect): effect is MusicPlayNoteEffect =>
  effect.type === 'music_play_note' &&
  hasStringField(effect, 'target') &&
  hasNumberField(effect, 'note') &&
  hasNumberField(effect, 'beats') &&
  hasNumberField(effect, 'instrument') &&
  hasNumberField(effect, 'tempo')

const isMusicPlayDrumEffect = (effect: VMEffect): effect is MusicPlayDrumEffect =>
  effect.type === 'music_play_drum' &&
  hasStringField(effect, 'target') &&
  hasNumberField(effect, 'drum') &&
  hasNumberField(effect, 'beats') &&
  hasNumberField(effect, 'tempo')

const toStepReport = (report: RawStepReport): StepReport => ({
  nowMs: report.now_ms,
  activeThreads: report.active_threads,
  steppedThreads: report.stepped_threads,
  emittedEffects: report.emitted_effects,
})

export class HeadlessVM {
  private readonly vmHandle: unknown
  private translateCache: TranslateCache = {}

  constructor(vmHandle: unknown) {
    this.vmHandle = vmHandle
  }

  get raw(): unknown {
    return this.vmHandle
  }

  start(): void {
    moonscratch.vm_start(this.vmHandle)
  }

  greenFlag(): void {
    moonscratch.vm_green_flag(this.vmHandle)
  }

  step(dtMs = DEFAULT_STEP_MS): StepReport {
    const raw = moonscratch.vm_step(this.vmHandle, normalizeStepMs(dtMs)) as RawStepReport
    return toStepReport(raw)
  }

  postIO(device: string, payload: JsonValue): void {
    moonscratch.vm_post_io_json(this.vmHandle, device, JSON.stringify(payload))
  }

  postIORawJson(device: string, payloadJson: string): void {
    moonscratch.vm_post_io_json(this.vmHandle, device, payloadJson)
  }

  setAnswer(answer: string): void {
    this.postIO('answer', answer)
  }

  setMouseState(input: { x: number; y: number; isDown?: boolean }): void {
    this.postIO('mouse', {
      x: input.x,
      y: input.y,
      isDown: input.isDown ?? false,
    })
  }

  setKeysDown(keys: string[]): void {
    this.postIO('keys_down', keys)
  }

  setTouching(touching: Record<string, string[]>): void {
    this.postIO('touching', touching)
  }

  broadcast(message: string): void {
    moonscratch.vm_broadcast(this.vmHandle, message)
  }

  stopAll(): void {
    moonscratch.vm_stop_all(this.vmHandle)
  }

  takeEffects(): VMEffect[] {
    const effects = parseJson<unknown>(
      moonscratch.vm_take_effects_json(this.vmHandle),
      'vm_take_effects_json',
    )
    if (!Array.isArray(effects)) {
      throw new Error('vm_take_effects_json: expected JSON array')
    }
    return effects as VMEffect[]
  }

  snapshot(): VMSnapshot {
    const snapshot = parseJson<unknown>(
      moonscratch.vm_snapshot_json(this.vmHandle),
      'vm_snapshot_json',
    )
    if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) {
      throw new Error('vm_snapshot_json: expected JSON object')
    }
    return snapshot as VMSnapshot
  }

  snapshotJson(): string {
    return moonscratch.vm_snapshot_json(this.vmHandle)
  }

  setViewerLanguage(language: string): void {
    this.postIO('viewer_language', normalizeLanguage(language))
  }

  setTranslateResult(words: string, language: string, translated: string): string {
    const normalizedLanguage = normalizeLanguage(language)
    if (!this.translateCache[normalizedLanguage]) {
      this.translateCache[normalizedLanguage] = {}
    }
    this.translateCache[normalizedLanguage][String(words)] = String(translated)
    this.syncTranslateCache()
    return translated
  }

  setTranslateCache(cache: TranslateCache): void {
    this.translateCache = cloneTranslateCache(cache)
    this.syncTranslateCache()
  }

  clearTranslateCache(): void {
    this.translateCache = {}
    this.syncTranslateCache()
  }

  ackTextToSpeech(waitKey: string | null | undefined): void {
    if (typeof waitKey !== 'string' || waitKey.length === 0) {
      return
    }
    this.postIO(waitKey, true)
  }

  async handleEffects(handlers: EffectHandlers = {}): Promise<VMEffect[]> {
    const effects = this.takeEffects()
    for (const effect of effects) {
      if (isTranslateRequestEffect(effect) && handlers.translate) {
        const translated = await handlers.translate(effect)
        if (typeof translated === 'string') {
          this.setTranslateResult(effect.words, effect.language, translated)
        }
      } else if (isTextToSpeechEffect(effect)) {
        if (handlers.textToSpeech) {
          await handlers.textToSpeech(effect)
        }
        this.ackTextToSpeech(effect.waitKey)
      } else if (isMusicPlayNoteEffect(effect) && handlers.musicNote) {
        await handlers.musicNote(effect)
      } else if (isMusicPlayDrumEffect(effect) && handlers.musicDrum) {
        await handlers.musicDrum(effect)
      }

      if (handlers.effect) {
        await handlers.effect(effect)
      }
    }
    return effects
  }

  private syncTranslateCache(): void {
    this.postIO('translate_cache', this.translateCache)
  }
}

export const createHeadlessVM = ({
  projectJson,
  assets = {},
  options,
  viewerLanguage,
  translateCache,
}: CreateHeadlessVMOptions): HeadlessVM => {
  const vm = unwrapResult(
    moonscratch.vm_new_from_json(
      toJsonString(projectJson, 'projectJson', true),
      toOptionalJsonString(assets, 'assets'),
      toOptionsJson(options),
    ) as MoonResult<unknown, unknown>,
    'vm_new_from_json failed',
  )

  const runtime = new HeadlessVM(vm)
  if (viewerLanguage !== undefined) {
    runtime.setViewerLanguage(viewerLanguage)
  }
  if (translateCache !== undefined) {
    runtime.setTranslateCache(translateCache)
  }
  return runtime
}

export const createVM = createHeadlessVM
export { moonscratch }
