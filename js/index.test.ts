import { describe, expect, test, vi } from 'vite-plus/test'

import { createHeadlessVM, createVM, type HeadlessVM, type JsonValue } from './index.ts'
import * as sb3 from 'sb3-types'

const PROJECT_META: sb3.Meta = {
  semver: '3.0.0',
  vm: '0.2.0',
  agent: 'moonscratch-tests',
}

const EXAMPLE_PROJECT: sb3.ScratchProject = {
  meta: PROJECT_META,
  targets: [
    {
      isStage: true,
      name: 'Stage',
      currentCostume: 0,
      variables: { var_score: ['score', 0] },
      lists: {},
      blocks: {},
      broadcasts: {},
      costumes: [],
      sounds: [],
    },
    {
      isStage: false,
      name: 'Sprite1',
      currentCostume: 0,
      variables: {},
      lists: {},
      broadcasts: {},
      costumes: [],
      sounds: [],
      blocks: {
        hat: {
          opcode: 'event_whenflagclicked',
          next: 'set',
          parent: null,
          inputs: {},
          fields: {},
          topLevel: true,
        },
        set: {
          opcode: 'data_setvariableto',
          next: null,
          parent: 'hat',
          inputs: { VALUE: [1, [4, 42]] },
          fields: { VARIABLE: ['score', 'var_score'] },
          topLevel: false,
        },
      },
    },
  ],
}

const TEXT_TO_SPEECH_TRANSLATE_PROJECT: sb3.ScratchProject = {
  meta: PROJECT_META,
  targets: [
    {
      isStage: true,
      name: 'Stage',
      currentCostume: 0,
      variables: {
        var_viewer: ['viewer', ''],
        var_trans: ['translated', ''],
        var_done: ['done', 0],
      },
      lists: {},
      blocks: {},
      broadcasts: {},
      costumes: [],
      sounds: [],
    },
    {
      isStage: false,
      name: 'Sprite1',
      currentCostume: 0,
      variables: {},
      lists: {},
      broadcasts: {},
      costumes: [],
      sounds: [],
      blocks: {
        hat_flag: {
          opcode: 'event_whenflagclicked',
          next: 'set_viewer',
          parent: null,
          inputs: {},
          fields: {},
          topLevel: true,
        },
        set_viewer: {
          opcode: 'data_setvariableto',
          next: 'set_translate',
          parent: 'hat_flag',
          inputs: { VALUE: [2, 'viewer_reporter'] },
          fields: { VARIABLE: ['viewer', 'var_viewer'] },
          topLevel: false,
        },
        viewer_reporter: {
          opcode: 'translate_getViewerLanguage',
          next: null,
          parent: 'set_viewer',
          inputs: {},
          fields: {},
          topLevel: false,
        },
        set_translate: {
          opcode: 'data_setvariableto',
          next: 'set_voice',
          parent: 'set_viewer',
          inputs: { VALUE: [2, 'translate_reporter'] },
          fields: { VARIABLE: ['translated', 'var_trans'] },
          topLevel: false,
        },
        translate_reporter: {
          opcode: 'translate_getTranslate',
          next: null,
          parent: 'set_translate',
          inputs: {
            WORDS: [1, [10, 'hello']],
            LANGUAGE: [1, [10, 'ja']],
          },
          fields: {},
          topLevel: false,
        },
        set_voice: {
          opcode: 'text2speech_setVoice',
          next: 'set_language',
          parent: 'set_translate',
          inputs: { VOICE: [1, [10, 'TENOR']] },
          fields: {},
          topLevel: false,
        },
        set_language: {
          opcode: 'text2speech_setLanguage',
          next: 'speak',
          parent: 'set_voice',
          inputs: { LANGUAGE: [1, [10, 'ja']] },
          fields: {},
          topLevel: false,
        },
        speak: {
          opcode: 'text2speech_speakAndWait',
          next: 'set_done',
          parent: 'set_language',
          inputs: { WORDS: [1, [10, 'hello']] },
          fields: {},
          topLevel: false,
        },
        set_done: {
          opcode: 'data_setvariableto',
          next: null,
          parent: 'speak',
          inputs: { VALUE: [1, [4, 1]] },
          fields: { VARIABLE: ['done', 'var_done'] },
          topLevel: false,
        },
      },
    },
  ],
}

const getStageVariables = (vm: HeadlessVM): Record<string, JsonValue> => {
  const stage = vm.snapshot().targets.find((target) => target.isStage)
  if (!stage) {
    throw new Error('stage target was not found in snapshot')
  }
  return stage.variables
}

const stepMany = (vm: HeadlessVM, count: number): void => {
  for (let i = 0; i < count; i += 1) {
    vm.step(16)
  }
}

describe('moonscratch/js/index.ts', () => {
  test('exports createVM as alias of createHeadlessVM', () => {
    expect(createVM).toBe(createHeadlessVM)
  })

  test('runs the example project and normalizes step dt values', () => {
    const vm = createHeadlessVM({ projectJson: EXAMPLE_PROJECT })
    vm.greenFlag()

    const first = vm.step(16.9)
    const clamped = vm.step(-4)

    expect(first).toEqual({
      nowMs: 16,
      activeThreads: 0,
      steppedThreads: 1,
      emittedEffects: 0,
    })
    expect(clamped.nowMs).toBe(16)
    expect(() => vm.step(Number.POSITIVE_INFINITY)).toThrow('dtMs must be a finite number')
    expect(getStageVariables(vm).var_score).toBe(42)
  })

  test('rejects empty project JSON strings', () => {
    expect(() => createHeadlessVM({ projectJson: '  ' })).toThrow(
      'projectJson must be a non-empty JSON string or object',
    )
  })

  test('normalizes viewer language and translate cache in constructor options', () => {
    const vm = createHeadlessVM({
      projectJson: TEXT_TO_SPEECH_TRANSLATE_PROJECT,
      viewerLanguage: ' JA ',
      translateCache: { JA: { hello: 'こんにちは' } },
    })

    vm.greenFlag()
    stepMany(vm, 6)

    const effects = vm.takeEffects()
    expect(effects).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: 'text_to_speech',
          waitKey: 'text2speech_done_1',
          language: 'ja',
        }),
      ]),
    )
    expect(effects.some((effect) => effect.type === 'translate_request')).toBe(false)

    vm.ackTextToSpeech('text2speech_done_1')
    stepMany(vm, 10)

    const stageVars = getStageVariables(vm)
    expect(stageVars.var_viewer).toBe('ja')
    expect(stageVars.var_trans).toBe('こんにちは')
    expect(stageVars.var_done).toBe(1)
  })

  test('handleEffects dispatches handlers and caches translated text for next run', async () => {
    const vm = createHeadlessVM({
      projectJson: TEXT_TO_SPEECH_TRANSLATE_PROJECT,
      viewerLanguage: 'ja',
    })
    const translate = vi.fn(async () => 'こんにちは')
    const textToSpeech = vi.fn(async () => undefined)
    const effect = vi.fn(async () => undefined)

    vm.greenFlag()
    stepMany(vm, 6)

    const handled = await vm.handleEffects({ translate, textToSpeech, effect })
    expect(handled.map((item) => item.type)).toEqual(['translate_request', 'text_to_speech'])
    expect(translate).toHaveBeenCalledTimes(1)
    expect(textToSpeech).toHaveBeenCalledTimes(1)
    expect(effect).toHaveBeenCalledTimes(2)

    stepMany(vm, 10)
    expect(getStageVariables(vm).var_done).toBe(1)
    expect(getStageVariables(vm).var_trans).toBe('hello')

    vm.greenFlag()
    stepMany(vm, 6)

    const secondRunEffects = vm.takeEffects()
    expect(secondRunEffects.some((item) => item.type === 'translate_request')).toBe(false)
    const secondRunTts = secondRunEffects.find(
      (item): item is { type: 'text_to_speech'; waitKey: string } =>
        item.type === 'text_to_speech' &&
        typeof (item as { waitKey?: unknown }).waitKey === 'string',
    )
    expect(secondRunTts).toBeDefined()
    if (!secondRunTts) {
      throw new Error('text_to_speech effect was not found in second run')
    }
    vm.ackTextToSpeech(secondRunTts.waitKey)
    stepMany(vm, 10)

    expect(getStageVariables(vm).var_done).toBe(1)
    expect(getStageVariables(vm).var_trans).toBe('こんにちは')
  })
})
