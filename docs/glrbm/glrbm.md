# GLRBM core specification

## glrbm_init
`void glrbm_init(void);`

#### Description
Invokes the BGA driver to map the framebuffer and get the pointer to it

#### Valid Usage
`glrbm_init` **must** be the very first GLRBM command called by a program intending to use it


---

## glrbm_set_res
`void glrbm_set_res(uint64_t width, uint64_t height);`

#### Description
Sets the BGA screen resolution

#### Arguments
- `width`: desired screen width in pixels
- `height`: desired screen height in pixels

#### Valid Usage
`width` and `height` must be > 0

---


### glrbm_SetPenColor
`void glrbm_SetPenColor(uint32_t color);`

#### Description
Sets the active pen color which is used for strokes, lines and outlines


#### Arguments
- `color`: pen color in the ARGB format

---

### glrbm_SetBrushColor
`void glrbm_SetBrushColor(uint32_t color);`

#### Description
Sets the active brush color which is used for filled geometry

#### Arguments
- `color`: brush color in the ARGB format

---

### glrbm_MoveTo
`void glrbm_MoveTo(uint64_t x, uint64_t y);`

#### Description
Updates the coordinate cursor without drawing anything

#### Arguments
- `x`: new X coordinate
- `y`: new Y coordinate

#### Valid Usage
`x` and `y` must be within the bounds of the current screen resolution

---

### glrbm_put_pixel
`void glrbm_put_pixel(uint64_t x, uint64_t y, uint32_t color);`

#### Description
Draws a pixel at X,Y with `color`

#### Arguments
- `x`: X coordinate
- `y`: Y coordinate
- `color`: pixel color in the ARGB format

#### Valid Usage
`x` and `y` must be less than the current width and height

---


### glrbm_draw_rect
`void glrbm_draw_rect(uint64_t x, uint64_t y, uint64_t width, uint64_t height, uint32_t color);`

#### Description
Draws a solid rectangle

#### Arguments
- `x`: X coordinate (top left)
- `y`: Y coordinate (top left)
- `width`: width of the rectangle
- `height`: height of the rectangle
- `color` : color of the rectangle in ARGB format

---

### glrbm_LineTo
`void glrbm_LineTo(uint64_t x, uint64_t y);`

#### Description
Draws a line from the cursor position set by `glrbm_MoveTo` and sets the coordinate cursor to the x,y

#### Arguments
- `x`: X coordinate
- `y`: Y coordinate

#### Valid Usage
the cursor coordinates must have been established before calling `glrbm_LineTo`

---



### glrbm_FillRect
`void glrbm_FillRect(uint64_t x1, uint64_t y1, uint64_t x2, uint64_t y2);`

#### Description
Draws a filled rectangle using the active brush color

#### Parameters
- `x1`,`y1`: Top left coordinate
- `x2`,`y2`: Bottom right coordinate

#### Valid Usage
- `x2` must be greater than `x1`
- `y2` must be greater than `y1`


---

### glrbm_FrameRect
`void glrbm_FrameRect(uint64_t x1, uint64_t y1, uint64_t x2, uint64_t y2);`

#### Description
Draws an outline of a rectangle using the active pen color

#### Parameters
- `x1`,`y1`: Top left coordinate
- `x2`,`y2`: Bottom right coordinate

#### Valid Usage
- `x2` must be greater than `x1`
- `y2` must be greater than `y1`

---

### glrbm_Rectangle
`void glrbm_Rectangle(uint64_t x1, uint64_t y1, uint64_t x2, uint64_t y2);`

#### Description
Draws a filled rectangle using the active brush color and draws an outline around it using the active pen color

#### Parameters
- `x1`,`y1`: Top left coordinate
- `x2`,`y2`: Bottom right coordinate

#### Valid Usage
- `x2` must be greater than `x1`
- `y2` must be greater than `y1`


---

### glrbm_FrameTriangle
`void glrbm_FrameTriangle(uint64_t x1, uint64_t y1, uint64_t x2, uint64_t y2, uint64_t x3, uint64_t y3);`

#### Description
Draws an outline of a triangle using the active pen color

#### Parameters
- `x1`, `y1`: 1st vertex
- `x2`,`y2`: 2nd vertex
- `x3`,`y3`: 3rd vertex

#### Valid Usage
The vertices must form a triangle

---


### glrbm_FillTriangle
`void glrbm_FillTriangle(uint64_t x1, uint64_t y1, uint64_t x2, uint64_t y2, uint64_t x3, uint64_t y3);`

#### Description
Draws a triangle using the active brush color

#### Parameters
- `x1`, `y1`: 1st vertex
- `x2`,`y2`: 2nd vertex
- `x3`,`y3`: 3rd vertex

#### Valid Usage
The vertices must form a triangle

---




### glrbm_InterpolatedTriangle
`void glrbm_InterpolatedTriangle(uint64_t x1, uint64_t y1, uint32_t c1, uint64_t x2, uint64_t y2, uint32_t c2, uint64_t x3, uint64_t y3, uint32_t c3);`

#### Description
Draws an interpolated triangle (Alpha ignored)

#### Parameters
- `x1`,`y1`,`c1`: 1st vertex & the color of it
- `x2`,`y2`,`c2`: 2nd vertex & the color of it
- `x3`,`y3`,`c3`: 3rd vertex & the color of it

#### Valid Usage
The vertices must form a triangle


---

### glrbm_BitBlt
`uint64_t glrbm_BitBlt(int64_t destX, int64_t destY, int64_t width, int64_t height, const void* src, int64_t srcX, int64_t srcY, uint64_t pitch, uint32_t rop);`

#### Description
Copies ARGB pixels from a source buffer in memory to the framebuffer at the specified coordinates, returns 1 on successful blit, 0 on failure

#### Arguments
- `destX`: X destination coordinate
- `destY`: Y destination corrdinate
- `width`: Width to copy in pixels
- `height`: Height to copy in pixels
- `src`: Ptr to the pixel buffer in ARGB format
- `srcX`: Starting X coordinate in the src
- `srcY`: Starting Y coordinate in the src
- `pitch`: Width of the src buffer in pixels
- `rop`: Raster Operation

#### Valid Usage
- `width` and `height` must be > 0
- `pitch` must be in pixels

#### Raster Operations
- `0x00CC0020` (SRCCOPY): Overwrites dest with src pixels (default)
- `0x00EE0086` (SRCPAINT): Bitwise OR (dst = dst | src)
- `0x008800C6` (SRCAND): Bitwise AND (dst = dst & src)
- `0x00660046` (SRCINVERT): Bitwise XOR (dst = dst ^ src)


