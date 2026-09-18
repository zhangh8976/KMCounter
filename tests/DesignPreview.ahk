; Generates synthetic design previews by invoking the production keycap renderer.
; Does not capture screen pixels or enumerate desktop windows.
RenderDesignPreviews() {
  global
  FileCreateDir, %A_ScriptDir%\screenshots\redesign
  SelectedRange := 2
  for i, preset in [{theme:1,palette:1,name:"dark-ice"}, {theme:1,palette:2,name:"dark-jade"}
                  ,{theme:1,palette:4,name:"dark-amber"}, {theme:2,palette:1,name:"light-pink"}, {theme:2,palette:2,name:"light-mint"}, {theme:2,palette:3,name:"light-blue"}, {theme:2,palette:4,name:"light-lilac"}, {theme:1,palette:1,name:"dark-english",language:"en"}] {
    ThemeIndex := preset.theme, PaletteIndex := preset.palette
    SetDashboardLanguage(preset.language="en" ? "en" : "zh")
    ApplyDashboardTheme()
    RefreshDashboard()
    ExportDashboardDrawing(A_ScriptDir "\screenshots\redesign\" preset.name ".png")
    if (i=1 || i>=4) {
      ExportOwnClientDrawing(hSettings, A_ScriptDir "\screenshots\redesign\settings-" preset.name ".png")
      ExportOwnClientDrawing(hWin, A_ScriptDir "\screenshots\redesign\native-" preset.name ".png")
    }
  }
  ThemeIndex := 1, PaletteIndex := 1, SelectedRange := 5
  keyboard.total.keystrokes := 2164
  mouse.total.lbcount := 652, mouse.total.rbcount := 31, mouse.total.move := 206.4
  RefreshDashboard()
  ExportOwnClientDrawing(hWin, A_ScriptDir "\screenshots\redesign\native-approved-compact.png")
  keyboard.total.keystrokes := 1234567
  mouse.total.lbcount := 987654, mouse.total.rbcount := 123456, mouse.total.move := 12345.6
  RefreshDashboard()
  ExportOwnClientDrawing(hWin, A_ScriptDir "\screenshots\redesign\native-history-compact.png")
  FileAppend, % "Design previews rendered; drawing errors=" TileRenderErrors "`n", *
  FreeTileBrushes()
  ExitApp, % TileRenderErrors ? 1 : 0
}
ExportDashboardDrawing(path) {
  global DashboardWidth, DashboardHeight, KeyHandles, RangeHandles, SettingsButtonHandle, LegendHandles, RangeTrackHandle, StatsPanelHandle, StatsIconHandles, TileBrushes
  hdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
  VarSetCapacity(info, 40, 0)
  NumPut(40, info, 0, "UInt"), NumPut(DashboardWidth, info, 4, "Int"), NumPut(-DashboardHeight, info, 8, "Int")
  NumPut(1, info, 12, "UShort"), NumPut(32, info, 14, "UShort")
  bitmap := DllCall("gdi32\CreateDIBSection", "Ptr", hdc, "Ptr", &info, "UInt", 0, "Ptr*", bits, "Ptr", 0, "UInt", 0, "Ptr")
  previous := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", bitmap, "Ptr")
  theme := GetDashboardTheme()
  VarSetCapacity(rect, 16, 0), NumPut(DashboardWidth, rect, 8, "Int"), NumPut(DashboardHeight, rect, 12, "Int")
  brush := DllCall("gdi32\CreateSolidBrush", "UInt", RGBtoBGR(theme.surface), "Ptr")
  DllCall("FillRect", "Ptr", hdc, "Ptr", &rect, "Ptr", brush)
  DllCall("gdi32\DeleteObject", "Ptr", brush)
  for i, group in [[StatsPanelHandle], StatsIconHandles, [RangeTrackHandle], KeyHandles, RangeHandles, [SettingsButtonHandle]] {
    for key, handle in group {
      GuiControlGet, pos, 1:Pos, %handle%
      GuiControlGet, label, 1:, %handle%
      font := DllCall("SendMessage", "Ptr", handle, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
      tile := TileBrushes[handle]
      DllCall("gdi32\SetViewportOrgEx", "Ptr", hdc, "Int", posX, "Int", posY, "Ptr", 0)
      DrawKeycap(hdc, posW, posH, label, font, tile.bg, tile.fg, false, tile.neutral, tile.role)
    }
  }
  DllCall("gdi32\SetViewportOrgEx", "Ptr", hdc, "Int", 0, "Int", 0, "Ptr", 0)
  for i, handle in LegendHandles {
    GuiControlGet, pos, 1:Pos, %handle%
    NumPut(posX, rect, 0, "Int"), NumPut(posY, rect, 4, "Int")
    NumPut(posX+posW, rect, 8, "Int"), NumPut(posY+posH, rect, 12, "Int")
    DllCall("FillRect", "Ptr", hdc, "Ptr", &rect, "Ptr", TileBrushes[handle].brush)
  }
  for i, name in ["QuickStats", "StatsLine", "ClickStat", "RightClickStat", "DistanceStat", "CoverageLine"] {
    GuiControlGet, pos, 1:Pos, %name%
    GuiControlGet, label, 1:, %name%
    GuiControlGet, handle, 1:Hwnd, %name%
    font := DllCall("SendMessage", "Ptr", handle, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", font)
    DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
    DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", RGBtoBGR(i>=2 && i<=5 ? theme.text : theme.muted))
    NumPut(posX, rect, 0, "Int"), NumPut(posY, rect, 4, "Int")
    NumPut(posX+posW, rect, 8, "Int"), NumPut(posY+posH, rect, 12, "Int")
    DllCall("DrawText", "Ptr", hdc, "Str", label, "Int", -1, "Ptr", &rect, "UInt", 0x820 | (i>=2 && i<=5 ? 4 : 0) | (DllCall("GetWindowLong", "Ptr", handle, "Int", -16) & 3))
  }
  DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", bitmap, "Ptr", 0, "Ptr*", image)
  VarSetCapacity(clsid, 16, 0)
  DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", &clsid)
  status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", image, "WStr", path, "Ptr", &clsid, "Ptr", 0)
  DllCall("gdiplus\GdipDisposeImage", "Ptr", image)
  DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", previous)
  DllCall("gdi32\DeleteObject", "Ptr", bitmap)
  DllCall("gdi32\DeleteDC", "Ptr", hdc)
  if (status)
    throw Exception("Preview PNG save failed", -1, status)
}

; Ask only this test process's own GUI to paint into an offscreen bitmap.
; This tests actual native control styles, without reading any desktop pixels.
ExportOwnClientDrawing(handle, path) {
  VarSetCapacity(rect,16,0)
  DllCall("GetClientRect", "Ptr", handle, "Ptr", &rect)
  width := NumGet(rect,8,"Int"), height := NumGet(rect,12,"Int")
  dc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
  VarSetCapacity(info,40,0)
  NumPut(40,info,0,"UInt"), NumPut(width,info,4,"Int"), NumPut(-height,info,8,"Int")
  NumPut(1,info,12,"UShort"), NumPut(32,info,14,"UShort")
  bitmap := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", &info, "UInt", 0, "Ptr*", bits, "Ptr", 0, "UInt", 0, "Ptr")
  old := DllCall("SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
  theme := GetDashboardTheme()
  brush := DllCall("CreateSolidBrush", "UInt", RGBtoBGR(theme.surface), "Ptr")
  DllCall("FillRect", "Ptr", dc, "Ptr", &rect, "Ptr", brush)
  DllCall("DeleteObject", "Ptr", brush)
  ; WM_PRINT positions child controls relative to the non-client origin.
  VarSetCapacity(windowRect,16,0), VarSetCapacity(origin,8,0)
  DllCall("GetWindowRect", "Ptr", handle, "Ptr", &windowRect)
  DllCall("ClientToScreen", "Ptr", handle, "Ptr", &origin)
  dx := NumGet(origin,0,"Int")-NumGet(windowRect,0,"Int")
  dy := NumGet(origin,4,"Int")-NumGet(windowRect,4,"Int")
  DllCall("SetViewportOrgEx", "Ptr", dc, "Int", -dx, "Int", -dy, "Ptr", 0)
  DllCall("SendMessage", "Ptr", handle, "UInt", 0x317, "Ptr", dc, "Ptr", 28)
  DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", bitmap, "Ptr", 0, "Ptr*", image)
  VarSetCapacity(clsid,16,0)
  DllCall("ole32\CLSIDFromString", "WStr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", &clsid)
  status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", image, "WStr", path, "Ptr", &clsid, "Ptr", 0)
  DllCall("gdiplus\GdipDisposeImage", "Ptr", image)
  DllCall("SelectObject", "Ptr", dc, "Ptr", old)
  DllCall("DeleteObject", "Ptr", bitmap)
  DllCall("DeleteDC", "Ptr", dc)
  if (status)
    throw Exception("Native preview PNG save failed", -1, status)
}
