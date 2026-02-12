import { describe, expect, test, vi } from 'vite-plus/test'

import { fromCanvas, fromImageData, fromRgbaBytes, fromRgbaMatrix } from './create.ts'

describe('moonscratch/js/assets/create.ts', () => {
  test('builds an asset from image data', () => {
    const asset = fromImageData({
      width: 1,
      height: 1,
      data: new Uint8Array([0, 255, 0, 255]),
    })

    expect(asset).toEqual({
      width: 1,
      height: 1,
      rgbaBase64: 'AP8A/w==',
    })
  })

  test('builds an asset from flat rgba bytes', () => {
    const asset = fromRgbaBytes(2, 1, new Uint8Array([0, 255, 0, 255, 255, 0, 0, 255]))

    expect(asset).toEqual({
      width: 2,
      height: 1,
      rgbaBase64: 'AP8A//8AAP8=',
    })
  })

  test('builds an asset from H x W x 4 matrix', () => {
    const asset = fromRgbaMatrix([
      [
        [0, 255, 0, 255],
        [255, 0, 0, 255],
      ],
      [
        [0, 0, 255, 255],
        [255, 255, 255, 255],
      ],
    ])

    expect(asset).toEqual({
      width: 2,
      height: 2,
      rgbaBase64: 'AP8A//8AAP8AAP///////w==',
    })
  })

  test('builds an asset from canvas API', () => {
    const getImageData = vi.fn(() => ({
      width: 1,
      height: 1,
      data: new Uint8Array([255, 0, 0, 255]),
    }))

    const getContext = vi.fn(() => ({ getImageData }))

    const asset = fromCanvas({
      width: 1,
      height: 1,
      getContext,
    })

    expect(getContext).toHaveBeenCalledWith('2d')
    expect(getImageData).toHaveBeenCalledWith(0, 0, 1, 1)
    expect(asset.rgbaBase64).toBe('/wAA/w==')
  })

  test('throws when matrix row widths are inconsistent', () => {
    expect(() =>
      fromRgbaMatrix([
        [
          [0, 0, 0, 255],
          [255, 255, 255, 255],
        ],
        [[0, 0, 0, 255]],
      ]),
    ).toThrow('pixels[1] must contain exactly 2 columns')
  })
})
