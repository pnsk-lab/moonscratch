import { buildAsset } from './build-asset.ts'
import type { CanvasLike, ImageDataLike, RgbaAsset, RgbaMatrix } from './types.ts'
import { toByte, toPositiveInt } from './validation.ts'

export const fromRgbaBytes = (width: number, height: number, rgba: ArrayLike<number>): RgbaAsset =>
  buildAsset(width, height, rgba)

export const fromImageData = (imageData: ImageDataLike): RgbaAsset =>
  buildAsset(imageData.width, imageData.height, imageData.data)

export const fromCanvas = (canvas: CanvasLike): RgbaAsset => {
  const width = toPositiveInt(canvas.width, 'canvas.width')
  const height = toPositiveInt(canvas.height, 'canvas.height')
  const context = canvas.getContext('2d')

  if (!context) {
    throw new Error('canvas.getContext("2d") returned null')
  }

  return fromImageData(context.getImageData(0, 0, width, height))
}

export const fromRgbaMatrix = (pixels: RgbaMatrix): RgbaAsset => {
  const height = pixels.length
  if (height <= 0) {
    throw new Error('pixels must have at least one row')
  }

  const firstRow = pixels[0]
  const width = firstRow?.length ?? 0
  if (width <= 0) {
    throw new Error('pixels must have at least one column')
  }

  const flat = new Uint8Array(width * height * 4)

  for (let y = 0; y < height; y += 1) {
    const row = pixels[y]
    if (!row || row.length !== width) {
      throw new Error(`pixels[${y}] must contain exactly ${width} columns`)
    }

    for (let x = 0; x < width; x += 1) {
      const pixel = row[x]
      if (!pixel || pixel.length < 4) {
        throw new Error(`pixels[${y}][${x}] must contain 4 channels (RGBA)`)
      }

      const base = (y * width + x) * 4
      flat[base] = toByte(pixel[0], `pixels[${y}][${x}][0]`)
      flat[base + 1] = toByte(pixel[1], `pixels[${y}][${x}][1]`)
      flat[base + 2] = toByte(pixel[2], `pixels[${y}][${x}][2]`)
      flat[base + 3] = toByte(pixel[3], `pixels[${y}][${x}][3]`)
    }
  }

  return buildAsset(width, height, flat)
}
