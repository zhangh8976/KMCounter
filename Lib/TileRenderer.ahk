; Solid matte keycaps and neutral controls; shared by native and preview rendering.
StartTileRenderer() {
  global TileGdipToken, TileDrawCalls, TileRenderErrors
  TileDrawCalls := 0, TileRenderErrors := 0
  DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
  VarSetCapacity(startup, A_PtrSize = 8 ? 24 : 16, 0)
  NumPut(1, startup, 0, "UInt")
  status := DllCall("gdiplus\GdiplusStartup", "Ptr*", TileGdipToken, "Ptr", &startup, "Ptr", 0)
  if (status)
    throw Exception("GDI+ initialization failed", -1, status)

}

DrawDashboardTile(wParam, pointer) {
  global TileBrushes, HoverTile, TileDrawCalls
  controlType := NumGet(pointer+0, 0, "UInt")
  if (controlType != 5 && controlType != 4)
    return
  handle := NumGet(pointer+0, A_PtrSize=8 ? 24 : 20, "Ptr")
  if (!TileBrushes.HasKey(handle))
    return
  hdc := NumGet(pointer+0, A_PtrSize=8 ? 32 : 24, "Ptr")
  offset := A_PtrSize=8 ? 40 : 28
  width := NumGet(pointer+0, offset+8, "Int") - NumGet(pointer+0, offset, "Int")
  height := NumGet(pointer+0, offset+12, "Int") - NumGet(pointer+0, offset+4, "Int")
  VarSetCapacity(label, 1024, 0)
  DllCall("GetWindowText", "Ptr", handle, "Str", label, "Int", 512)
  font := DllCall("SendMessage", "Ptr", handle, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
  tile := TileBrushes[handle]
  DrawKeycap(hdc, width, height, label, font, tile.bg, tile.fg, (handle=HoverTile || (controlType=4 && (NumGet(pointer+0, 16, "UInt") & 0x10))), tile.neutral, tile.role)
  TileDrawCalls += 1
  return true
}

DrawKeycap(hdc, width, height, label, font, background, foreground, hover := false, neutral := false, role := "key") {
  global TileRenderErrors, ThemeIndex
  if (SubStr(role, 1, 6) = "theme-") {
    DrawThemePreview(hdc, width, height, font, SubStr(role, 7)+0, hover)
    return
  }
  if (SubStr(role, 1, 8) = "palette-") {
    DrawPalettePreview(hdc, width, height, font, SubStr(role, 9)+0, hover)
    return
  }
  theme := GetDashboardTheme()
  saved := DllCall("SaveDC", "Ptr", hdc)
  VarSetCapacity(rect, 16, 0), NumPut(width, rect, 8, "Int"), NumPut(height, rect, 12, "Int")
  backdrop := InStr(role, "segment") ? (ThemeIndex=1 ? "494949" : "E9E9E9") : theme.surface
  surface := DllCall("CreateSolidBrush", "UInt", RGBtoBGR(backdrop), "Ptr")
  DllCall("FillRect", "Ptr", hdc, "Ptr", &rect, "Ptr", surface)
  DllCall("DeleteObject", "Ptr", surface)
  status := DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", graphics)
  if (status) {
    TileRenderErrors += 1
    DllCall("RestoreDC", "Ptr", hdc, "Int", saved)
    return
  }
  DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
  DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 2)
  if (role = "settings")
    DrawSettingsGlyph(graphics, width, height, foreground, hover)
  else if (role = "legend" || SubStr(role, 1, 10) = "stat-icon-") {
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", "0xFF" background, "Ptr*", fill)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", fill, "Float", 0, "Float", 0, "Float", width, "Float", height)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", fill)
    if (role != "legend")
      DrawStatGlyph(graphics, SubStr(role, 11)+0, foreground)
  } else if (role != "label") {
    x := 2, y := 2, w := width-4, h := height-4, radius := Min(4, h/2)
    if (role = "panel")
      x := 0.5, y := 0.5, w := width-1, h := height-1, radius := 7
    else if (role = "track")
      x := 0.5, y := 0.5, w := width-1, h := height-1, radius := 8
    else if (InStr(role, "segment"))
      x := 1, y := 0.5, w := width-2, h := height-1, radius := 5
    if (role = "segment-selected") {
      path := KeycapPath(x, y+0.8, w, h, radius)
      DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0x16000000, "Ptr*", shadow)
      DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", shadow, "Ptr", path)
      DllCall("gdiplus\GdipDeleteBrush", "Ptr", shadow)
      DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    }
    path := KeycapPath(x, y, w, h, radius)
    if (hover && role != "track" && role != "panel")
      background := MixTileColor(background, ThemeIndex=1 ? "FFFFFF" : "000000", 0.04)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", "0xFF" background, "Ptr*", fill)
    DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", fill, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", fill)
    if (hover && role = "key") {
      DllCall("gdiplus\GdipCreatePen1", "UInt", "0x35" foreground, "Float", 0.7, "Int", 2, "Ptr*", pen)
      DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", path)
      DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
    }
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
  }
  DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
  if (role != "settings" && role != "legend" && SubStr(role, 1, 10) != "stat-icon-") {
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", font)
    NumPut(1, rect, 0, "Int"), NumPut(width-1, rect, 8, "Int"), NumPut(height-2, rect, 12, "Int")
    DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", RGBtoBGR(foreground))
    DllCall("DrawText", "Ptr", hdc, "Str", label, "Int", -1, "Ptr", &rect, "UInt", 0x825)
  }
  DllCall("RestoreDC", "Ptr", hdc, "Int", saved)
}

; Monochrome pictograms at native pixel size, with distinct filled mouse buttons.
DrawStatGlyph(graphics, index, color) {
  DllCall("gdiplus\GdipCreatePen1", "UInt", "0xFF" color, "Float", 1.1, "Int", 2, "Ptr*", pen)
  DllCall("gdiplus\GdipCreateSolidFill", "UInt", "0xFF" color, "Ptr*", fill)
  if (index=1) {
    path := KeycapPath(0.7, 3, 12.6, 10, 1.5)
    DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", path)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    for i, x in [3, 6.5, 10]
      DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", fill, "Float", x, "Float", 5.5, "Float", 1.3, "Float", 1.3)
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 3, "Float", 10, "Float", 11, "Float", 10)
  } else if (index=2 || index=3) {
    path := KeycapPath(2.5, 0.8, 9, 14.3, 4.3)
    DllCall("gdiplus\GdipSetClipPath", "Ptr", graphics, "Ptr", path, "Int", 0)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", fill, "Float", index=2 ? 2.5 : 7, "Float", 0.8, "Float", 4.5, "Float", 6)
    DllCall("gdiplus\GdipResetClip", "Ptr", graphics)
    DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", path)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 2.5, "Float", 6.8, "Float", 11.5, "Float", 6.8)
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 7, "Float", 1, "Float", 7, "Float", 6.8)
  } else {
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 2, "Float", 12, "Float", 6, "Float", 6)
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 6, "Float", 6, "Float", 12, "Float", 4)
    for i, point in [[0.5,10.5], [10.5,2.5]]
      DllCall("gdiplus\GdipFillEllipse", "Ptr", graphics, "Ptr", fill, "Float", point[1], "Float", point[2], "Float", 3, "Float", 3)
  }
  DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
  DllCall("gdiplus\GdipDeleteBrush", "Ptr", fill)
}

KeycapPath(x, y, width, height, radius) {
  DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", path)
  diameter := radius*2
  for i, corner in [[x,y,180], [x+width-diameter,y,270], [x+width-diameter,y+height-diameter,0], [x,y+height-diameter,90]]
    DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", corner[1], "Float", corner[2], "Float", diameter, "Float", diameter, "Float", corner[3], "Float", 90)
  DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
  return path
}
MixTileColor(hex, other, amount) {
  a := "0x" hex, b := "0x" other
  return Format("{:02X}{:02X}{:02X}", Round((a>>16)*(1-amount)+(b>>16)*amount)
      , Round(((a>>8)&255)*(1-amount)+((b>>8)&255)*amount), Round((a&255)*(1-amount)+(b&255)*amount))
}
ColorLuminance(hex) {
  n := "0x" hex
  return 0.2126*LinearChannel((n>>16)&255) + 0.7152*LinearChannel((n>>8)&255) + 0.0722*LinearChannel(n&255)
}

DrawSettingsGlyph(graphics, width, height, color, highlighted := false) {
  global ThemeIndex
  if (highlighted) {
    path := KeycapPath(1, 1, width-2, height-2, 7)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", ThemeIndex=1 ? 0x18FFFFFF : 0x09000000, "Ptr*", brush)
    DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush, "Ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    DllCall("gdiplus\GdipDeletePath", "Ptr", path)
  }
  cx := width/2, cy := height/2
  DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", path)
  ; Eight teeth; a single outline and center hole stay legible at 20px.
  Loop, 32 {
    step := A_Index-1, angle := (step*11.25-5.625)*0.0174532925199433
    radius := Mod(step,4)<2 ? 9 : 6.8
    x := cx + Cos(angle)*radius, y := cy + Sin(angle)*radius
    if (step=0)
      firstX := x, firstY := y
    else
      DllCall("gdiplus\GdipAddPathLine", "Ptr", path, "Float", oldX, "Float", oldY, "Float", x, "Float", y)
    oldX := x, oldY := y
  }
  DllCall("gdiplus\GdipAddPathLine", "Ptr", path, "Float", oldX, "Float", oldY, "Float", firstX, "Float", firstY)
  DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
  DllCall("gdiplus\GdipCreatePen1", "UInt", "0xFF" color, "Float", 1.45, "Int", 2, "Ptr*", pen)
  DllCall("gdiplus\GdipSetPenLineJoin", "Ptr", pen, "Int", 2)
  DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", path)
  DllCall("gdiplus\GdipDrawEllipse", "Ptr", graphics, "Ptr", pen, "Float", cx-3, "Float", cy-3, "Float", 6, "Float", 6)
  DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
  DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}

; Dialog focus management sends BM_SETSTYLE and otherwise turns BS_OWNERDRAW
; into BS_DEFPUSHBUTTON. Keep the native button semantics while preserving paint.
InstallOwnerDrawButton(handle) {
  static callback := RegisterCallback("OwnerDrawButtonProc", "", 6)
  DllCall("comctl32\SetWindowSubclass", "Ptr", handle, "Ptr", callback, "UPtr", 1, "UPtr", 0)
  DllCall("SendMessage", "Ptr", handle, "UInt", 0xF4, "Ptr", 0xB, "Ptr", 1)
}
OwnerDrawButtonProc(handle, message, wParam, lParam, id, data) {
  ; Owner-drawn buttons otherwise treat the second press as BN_DOUBLECLICKED.
  ; Appearance choices are repeatable single-click actions, including fast clicks.
  if (message = 0x203)
    message := 0x201
  if (message = 0xF4)
    wParam := (wParam & ~15) | 0xB
  return DllCall("comctl32\DefSubclassProc", "Ptr", handle, "UInt", message, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

PreviewRoundedFill(graphics, x, y, w, h, radius, color) {
  path := KeycapPath(x,y,w,h,radius)
  DllCall("gdiplus\GdipCreateSolidFill", "UInt", "0xFF" color, "Ptr*", brush)
  DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush, "Ptr", path)
  DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
  DllCall("gdiplus\GdipDeletePath", "Ptr", path)
}
DrawThemePreview(hdc, width, height, font, index, focused := false) {
  global ThemeIndex, PaletteIndex, DarkPaletteIndex, LightPaletteIndex
  palette := index=ThemeIndex ? PaletteIndex : (index=1 ? DarkPaletteIndex : LightPaletteIndex)
  DrawAppearancePreview(hdc,width,height,font,index,Max(1,palette),index=ThemeIndex,ThemeDisplayName(index))
}
DrawPalettePreview(hdc, width, height, font, index, focused := false) {
  global ThemeIndex, PaletteIndex
  DrawAppearancePreview(hdc,width,height,font,ThemeIndex,index,index=PaletteIndex,PaletteDisplayName(index))
}
DrawAppearancePreview(hdc, width, height, font, index, palette, selected, label) {
  theme := GetDashboardTheme(index,palette), current := GetDashboardTheme()
  saved := DllCall("SaveDC", "Ptr", hdc)
  VarSetCapacity(rect,16,0), NumPut(width,rect,8,"Int"), NumPut(height,rect,12,"Int")
  brush := DllCall("CreateSolidBrush", "UInt", RGBtoBGR(current.surface), "Ptr")
  DllCall("FillRect", "Ptr", hdc, "Ptr", &rect, "Ptr", brush)
  DllCall("DeleteObject", "Ptr", brush)
  DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", graphics)
  DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
  DllCall("gdiplus\GdipScaleWorldTransform", "Ptr", graphics, "Float", width/156, "Float", height/130, "Int", 0)
  PreviewRoundedFill(graphics,2,2,152,126,10,theme.surface)
  border := KeycapPath(2,2,152,126,10)
  DllCall("gdiplus\GdipCreatePen1", "UInt", "0xFF" (selected ? current.active : MixTileColor(current.surface,current.text,0.18)), "Float", selected ? 2 : 1, "Int", 2, "Ptr*", pen)
  DllCall("gdiplus\GdipDrawPath", "Ptr", graphics, "Ptr", pen, "Ptr", border)
  DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
  DllCall("gdiplus\GdipDeletePath", "Ptr", border)
  PreviewRoundedFill(graphics,14,17,68,10,3,index=1 ? "494949" : "E9E9E9")
  PreviewRoundedFill(graphics,35,18,21,8,2,index=1 ? "717171" : "FFFFFF")
  Loop, 20
    PreviewRoundedFill(graphics,98+(A_Index-1)*2.2,20,2.3,3,0.3,HeatColor((A_Index-1)/19,palette,index))
  Loop, 5 {
    row := A_Index
    Loop, 12 {
      col := A_Index
      color := Mod(row*13+col*7,5)=0 ? theme.zero : HeatColor(Mod(row*17+col*11,29)/28,palette,index)
      PreviewRoundedFill(graphics,14+(col-1)*10.6,37+(row-1)*10.5,8.8,8,1.5,color)
    }
  }
  PreviewRoundedFill(graphics,45,79,40,8,1.5,HeatColor(0.8,palette,index))
  if (selected) {
    PreviewRoundedFill(graphics,130,106,12,12,6,theme.active)
    DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFFFFFFFF, "Float", 1.4, "Int", 2, "Ptr*", pen)
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 133, "Float", 112, "Float", 135, "Float", 114)
    DllCall("gdiplus\GdipDrawLine", "Ptr", graphics, "Ptr", pen, "Float", 135, "Float", 114, "Float", 139, "Float", 110)
    DllCall("gdiplus\GdipDeletePen", "Ptr", pen)
  }
  DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
  DllCall("SelectObject", "Ptr", hdc, "Ptr", font)
  DllCall("SetBkMode", "Ptr", hdc, "Int", 1)
  DllCall("SetTextColor", "Ptr", hdc, "UInt", RGBtoBGR(theme.text))
  NumPut(Round(width*14/156),rect,0,"Int"), NumPut(Round(height*101/130),rect,4,"Int")
  NumPut(Round(width*125/156),rect,8,"Int"), NumPut(Round(height*123/130),rect,12,"Int")
  DllCall("DrawText", "Ptr", hdc, "Str", label, "Int", -1, "Ptr", &rect, "UInt", 0x824)
  DllCall("RestoreDC", "Ptr", hdc, "Int", saved)
}

; Preview buttons retain native push-button input, but paint a complete cached
; image directly. No WM_DRAWITEM/OnMessage re-entry is needed during theme changes.
InstallPreviewButton(handle) {
  global PreviewBitmaps, PreviewPaintCounts
  static callback := RegisterCallback("PreviewButtonProc", "", 6)
  if (!IsObject(PreviewBitmaps))
    PreviewBitmaps := {}, PreviewPaintCounts := {}
  DllCall("comctl32\SetWindowSubclass", "Ptr", handle, "Ptr", callback, "UPtr", 2, "UPtr", 0)
}
CachePreviewButton(handle) {
  global PreviewBitmaps, TileBrushes
  VarSetCapacity(rect,16,0)
  DllCall("GetClientRect", "Ptr", handle, "Ptr", &rect)
  width := NumGet(rect,8,"Int"), height := NumGet(rect,12,"Int")
  dc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
  VarSetCapacity(info,40,0)
  NumPut(40,info,0,"UInt"), NumPut(width,info,4,"Int"), NumPut(-height,info,8,"Int")
  NumPut(1,info,12,"UShort"), NumPut(32,info,14,"UShort")
  bitmap := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", &info, "UInt", 0, "Ptr*", bits, "Ptr", 0, "UInt", 0, "Ptr")
  old := DllCall("SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
  font := DllCall("SendMessage", "Ptr", handle, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
  tile := TileBrushes[handle]
  DrawKeycap(dc,width,height,"",font,tile.bg,tile.fg,false,tile.neutral,tile.role)
  DllCall("SelectObject", "Ptr", dc, "Ptr", old)
  DllCall("DeleteDC", "Ptr", dc)
  previous := PreviewBitmaps[handle]
  PreviewBitmaps[handle] := {bitmap:bitmap,w:width,h:height}
  if (previous.bitmap)
    DllCall("DeleteObject", "Ptr", previous.bitmap)
  DllCall("InvalidateRect", "Ptr", handle, "Ptr", 0, "Int", 0)
}
PreviewButtonProc(handle, message, wParam, lParam, id, data) {
  global PreviewBitmaps, PreviewPaintCounts
  if ((message=0xF || message=0x318) && PreviewBitmaps.HasKey(handle)) {
    if (message=0xF) {
      VarSetCapacity(paint,A_PtrSize=8 ? 72 : 64,0)
      dc := DllCall("BeginPaint", "Ptr", handle, "Ptr", &paint, "Ptr")
    } else
      dc := wParam
    item := PreviewBitmaps[handle]
    memory := DllCall("CreateCompatibleDC", "Ptr", dc, "Ptr")
    old := DllCall("SelectObject", "Ptr", memory, "Ptr", item.bitmap, "Ptr")
    DllCall("BitBlt", "Ptr", dc, "Int", 0, "Int", 0, "Int", item.w, "Int", item.h, "Ptr", memory, "Int", 0, "Int", 0, "UInt", 0xCC0020)
    if (DllCall("GetFocus", "Ptr")=handle) {
      VarSetCapacity(focus,16,0), NumPut(6,focus,0,"Int"), NumPut(6,focus,4,"Int")
      NumPut(item.w-6,focus,8,"Int"), NumPut(item.h-6,focus,12,"Int")
      DllCall("DrawFocusRect", "Ptr", dc, "Ptr", &focus)
    }
    DllCall("SelectObject", "Ptr", memory, "Ptr", old)
    DllCall("DeleteDC", "Ptr", memory)
    if (message=0xF)
      DllCall("EndPaint", "Ptr", handle, "Ptr", &paint)
    PreviewPaintCounts[handle] := PreviewPaintCounts.HasKey(handle) ? PreviewPaintCounts[handle]+1 : 1
    return 0
  }
  if (message=0x14 && PreviewBitmaps.HasKey(handle))
    return 1
  result := DllCall("comctl32\DefSubclassProc", "Ptr", handle, "UInt", message, "Ptr", wParam, "Ptr", lParam, "Ptr")
  if (message=7 || message=8)
    DllCall("InvalidateRect", "Ptr", handle, "Ptr", 0, "Int", 0)
  return result
}
