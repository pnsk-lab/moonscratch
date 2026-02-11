import { createHeadlessVM } from './headless-vm.mjs'

const projectJson = JSON.stringify({
  targets: [
    {
      isStage: true,
      name: 'Stage',
      variables: { var_score: ['score', 0] },
      lists: {},
      blocks: {},
    },
    {
      isStage: false,
      name: 'Sprite1',
      variables: {},
      lists: {},
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
})

const vm = createHeadlessVM({ projectJson })
vm.greenFlag()
vm.step(16)
console.dir(vm.snapshot(), { depth: null })
