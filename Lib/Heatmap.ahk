; Native dashboard: all keyboard geometry is transformed once, never persisted as layout.
BuildDashboard() {
  global
  StartTileRenderer()
  OnMessage(0x2B, "DrawDashboardTile")
  ControlList := LoadControlList(layout), TileBrushes := {}, KeyHandles := {}, RangeHandles := []
  theme := GetDashboardTheme()
  Gui, 1:New, -DPIScale +HwndhWin -MaximizeBox
  Gui, 1:Margin, 12, 12
  Gui, 1:Color, % theme.surface, % theme.surface
  Gui, 1:Font, % "s" 9 / (A_ScreenDPI/96), Segoe UI
  maxRight := 0, maxBottom := 0
  ; Resolve upstream relative keyboard geometry at its original scale.
  keyboardRight := 0
  for i, ctl in ControlList {
    if (!RegExMatch(ctl.Hwnd, "^sc\d+$"))
      continue
    options := ""
    for j, prop in ["x", "y", "w", "h"]
      if (ctl[prop] != "")
        options .= " " prop ctl[prop]
    text := ctl.Text
    if (text = "PageUp")
      text := "PgUp"
    if (text = "PageDn")
      text := "PgDn"
    if (text = "NumLock")
      text := "Num"
    if (text = "BackSpace")
      text := "⌫"
    if (text = "Insert")
      text := "Ins"
    if (text = "Delete")
      text := "Del"
    Gui, 1:Add, Text, % options " +0x10D hwndkeyHandle vkey" ctl.Hwnd, %text%
    KeyHandles[ctl.Hwnd] := keyHandle
    GuiControlGet, pos, 1:Pos, %keyHandle%
    ctl.rect := {x:posX, y:posY, w:posW, h:posH}
    maxRight := Max(maxRight, posX + posW), maxBottom := Max(maxBottom, posY + posH)
  }
  ; Keep the compact width; add 40px of height for taller, less compressed keycaps.
  DashboardWidth := Max(820, Round((maxRight - 12) * UIScale) + 24)
  DashboardHeight := Round((maxBottom - 12) * UIScale) + 100
  keyboardBottom := DashboardHeight - 40
  keyScaleY := (keyboardBottom - 68) / (maxBottom - 12)
  keyScaleX := (DashboardWidth - 40) / (maxRight - 12)
  for i, ctl in ControlList {
    if (!IsObject(ctl.rect))
      continue
    rect := ctl.rect, handle := KeyHandles[ctl.Hwnd]
    GuiControl, 1:Move, %handle%, % "x" Round((rect.x-12)*keyScaleX+20) " y" Round((rect.y-12)*keyScaleY+68) " w" Round(rect.w*keyScaleX) " h" Round(rect.h*keyScaleY)
    GuiControlGet, keyRect, 1:Pos, %handle%
    keyboardRight := Max(keyboardRight, keyRectX+keyRectW-2)
    PaintTile(handle, "1C2B41", "A9BED2")
  }
  ; One quiet settings action, with the period selector centered between the gear and legend.
  Gui, 1:Font, % "s" 9 / (A_ScreenDPI/96) " norm", Microsoft YaHei UI
  Gui, 1:Add, Button, x20 y20 w34 h34 +0xB gOpenSettings vSettingsButton hwndSettingsButtonHandle, 设置
  InstallOwnerDrawButton(SettingsButtonHandle)
  selectorX := Floor((54 + (DashboardWidth-260) - 330)/2)
  Gui, 1:Add, Text, % "x" selectorX " y20 w330 h34 +0xD hwndRangeTrackHandle",
  for i, label in ["今日", "本周", "本月", "今年", "历史总计"] {
    Gui, 1:Add, Text, % "x" selectorX+5+(i-1)*64 " y24 w64 h26 +0x10D gRangeClick vRange" i " hwndhandle", %label%
    RangeHandles.Push(handle)
  }
  Gui, 1:Font, % "s" 8 / (A_ScreenDPI/96), Microsoft YaHei UI
  ; Compact always-visible stats occupy the unused area above the navigation/numpad.
  ; Align the panel bottom with the visible Esc/function keycap bottom (2px inset).
  GuiControlGet, functionKey, 1:Pos, % KeyHandles["sc1"]
  StatsPanelY := functionKeyY+functionKeyH-2-32
  StatsPanelX := keyboardRight-256
  Gui, 1:Add, Text, % "x" StatsPanelX " y" StatsPanelY-32 " w256 h13 c9CB6CA Right vQuickStats",
  Gui, 1:Add, Text, % "x" StatsPanelX " y" StatsPanelY " w256 h32 +0xD hwndStatsPanelHandle",
  StatsPanelTexts := [], StatsIconHandles := []
  for i, name in ["StatsLine", "ClickStat", "RightClickStat", "DistanceStat"] {
    statX := StatsPanelX+8+(i-1)*60
    Gui, 1:Add, Text, % "x" statX " y" StatsPanelY+8 " w14 h16 +0x10D vStatIcon" i " hwndstatIconHandle",
    StatsIconHandles.Push(statIconHandle)
    Gui, 1:Font, % "s" 7.5 / (A_ScreenDPI/96) " norm", Segoe UI
    Gui, 1:Add, Text, % "x" statX+18 " y" StatsPanelY+6 " w42 h20 +0x200 v" name " hwndstatTextHandle",
    StatsPanelTexts.Push({handle:statTextHandle, primary:true})
  }
  Gui, 1:Font, % "s" 8 / (A_ScreenDPI/96), Microsoft YaHei UI
  Gui, 1:Add, Text, % "x20 y" keyboardBottom+8 " w" DashboardWidth-40 " h14 c7E9CB4 vCoverageLine",
  LegendHandles := []
  Loop, 80 {
    legendX := Round((A_Index-1)*256/80), legendWidth := Round(A_Index*256/80)-legendX
    Gui, 1:Add, Text, % "x" StatsPanelX+legendX " y" StatsPanelY-12 " w" legendWidth " h4 hwndhandle",
    LegendHandles.Push(handle)
  }
  OnMessage(0x138, "TileColorMessage")
  OnMessage(0x200, "DashboardMouseMove")
  ; Dark DWM frame + rounded corners on Windows 11; older Windows retain the solid dark surface.
  DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWin, "UInt", 20, "Int*", 1, "UInt", 4)
  DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWin, "UInt", 33, "Int*", 2, "UInt", 4)
  Gui, 1:Show, % "Hide w" DashboardWidth " h" DashboardHeight
  ApplyDashboardTheme()
}

RefreshDashboard() {
  global
  Critical
  Gui, 1:Default
  theme := GetDashboardTheme()
  DisplayCounts := AggregateRange(SelectedRange, today)
  maximum := 0
  for key, handle in KeyHandles
    maximum := Max(maximum, DisplayCounts.keyboard[key] + 0)
  for key, handle in KeyHandles {
    count := DisplayCounts.keyboard[key] + 0
    color := count > 0 ? HeatColor(LogHeat(count, maximum), PaletteIndex, ThemeIndex) : theme.zero
    PaintTile(handle, color, count > 0 ? ContrastText(color) : theme.muted)
  }
  PaintTile(RangeTrackHandle, ThemeIndex=1 ? "494949" : "E9E9E9", theme.text, true, "track")
  for i, handle in RangeHandles {
    active := i=SelectedRange
    background := ThemeIndex=1 ? (active ? "717171" : "494949") : (active ? "FFFFFF" : "E9E9E9")
    foreground := ThemeIndex=1 ? (active ? "FFFFFF" : "BDBDBD") : (active ? "242424" : "737373")
    PaintTile(handle, background, foreground, true, active ? "segment-selected" : "segment")
  }
  PaintTile(StatsPanelHandle, theme.panel, theme.text, true, "panel")
  for i, item in StatsPanelTexts
    PaintTile(item.handle, theme.panel, item.primary ? theme.text : theme.panelMuted, true, "stattext")
  for i, handle in StatsIconHandles
    PaintTile(handle, theme.panel, theme.text, true, "stat-icon-" i)
  PaintTile(SettingsButtonHandle, theme.surface, theme.muted, false, "settings")
  for i, handle in LegendHandles
    PaintTile(handle, HeatColor((i-1)/79, PaletteIndex, ThemeIndex), "FFFFFF")
  k := DisplayCounts.keyboard, m := DisplayCounts.mouse
  GuiControl, 1:, QuickStats, % Tr("低频                                     高频", "Low                                      High")
  MouseDetailText := Tr("左键 ", "Left ") FormatCount(m.lbcount) Tr(" · 右键 ", " · Right ") FormatCount(m.rbcount) Tr(" · 中键 ", " · Middle ") FormatCount(m.mbcount) Tr(" · 侧键 ", " · Side ") FormatCount(m.xbcount) Tr(" · 滚轮 ", " · Wheel ") FormatCount(m.wheel) Tr(" · 横滚 ", " · H wheel ") FormatCount(m.hwheel)
  StatsDetailText := Tr("键击次数 ", "Keystrokes ") FormatCount(k.keystrokes) "`n" MouseDetailText "`n" Tr("移动距离 ", "Distance ") Format("{:.1f} m", m.move)
  LayoutDashboardStats([k.keystrokes+0, m.lbcount+0, m.rbcount+0, m.move+0])

  if (SelectedRange = 5)
    coverage := Tr("历史总计 · 独立累计值，包含已归档日期", "All time · Includes archived dates")
  else {
    expected := EnvSub(today, DisplayCounts.start, "Days") + 1
    coverage := PrettyDate(DisplayCounts.start) " — " PrettyDate(today) Tr("  ·  可用明细 ", "  ·  Available days ") DisplayCounts.days "/" expected Tr(" 天", " days")
    if (DisplayCounts.days < expected)
      coverage .= Tr("（缺失日期未计入）", " (missing dates excluded)")
  }
  if (DemoMode)
    coverage := Tr("DEMO · 合成数据  |  ", "DEMO · Sample data  |  ") coverage
  if (ArchiveWarning != "")
    coverage := ArchiveWarning
  GuiControl, 1:, CoverageLine, %coverage%
}

; Measure the whole row so large totals can borrow space from shorter neighbors.
; Abbreviations affect presentation only; the tooltip retains exact totals.
LayoutDashboardStats(values) {
  global StatsPanelTexts, StatsIconHandles, StatsPanelX
  theme := GetDashboardTheme()
  labels := [], compact := {}, rounded := {}, exponent := {}
  for i, value in values
    labels.Push(i=4 ? Format("{:.1f} m", value) : FormatCount(value))
  Loop {
    widths := [], totalWidth := 0
    for i, item in StatsPanelTexts {
      Gui, 1:Font, % "s" 7.5 / (A_ScreenDPI/96) " norm c" theme.text, Segoe UI
      GuiControl, 1:Font, % item.handle
      width := MeasureStatText(item.handle, labels[i])+2
      widths.Push(width), totalWidth += width
    }
    ; 4 x (14px icon + 4px gap), plus at least 3 x 4px between groups.
    if (totalWidth <= 156)
      break
    best := 0, saving := 0
    for i, value in values {
      if (value < 1000 || compact.HasKey(i))
        continue
      candidate := CompactStatCount(value) (i=4 ? " m" : "")
      gain := widths[i] - (MeasureStatText(StatsPanelTexts[i].handle, candidate)+2)
      if (gain > saving)
        best := i, saving := gain, bestLabel := candidate
    }
    if (best) {
      labels[best] := bestLabel, compact[best] := true
      continue
    }
    ; Drop fractional thousands while retaining the same font in every range.
    for i, value in values {
      if (!compact.HasKey(i) || rounded.HasKey(i))
        continue
      candidate := Format("{:.0f}", value/1000) "k" (i=4 ? " m" : "")
      gain := widths[i] - (MeasureStatText(StatsPanelTexts[i].handle, candidate)+2)
      if (gain > saving)
        best := i, saving := gain, bestLabel := candidate
    }
    if (best) {
      labels[best] := bestLabel, rounded[best] := true
      continue
    }
    ; Exceptionally large imported totals: shorter exponent notation, still in k.
    for i, value in values {
      if (value < 1000 || exponent.HasKey(i))
        continue
      candidate := RegExReplace(Format("{:.0e}", value/1000), "e\+?0*", "e") "k" (i=4 ? " m" : "")
      gain := widths[i] - (MeasureStatText(StatsPanelTexts[i].handle, candidate)+2)
      if (gain > saving)
        best := i, saving := gain, bestLabel := candidate
    }
    if (best) {
      labels[best] := bestLabel, exponent[best] := true
      continue
    }
    break
  }
  gap := (240-72-totalWidth)/3, x := StatsPanelX+8
  for i, item in StatsPanelTexts {
    GuiControl, 1:MoveDraw, % StatsIconHandles[i], % "x" Round(x)
    GuiControl, 1:MoveDraw, % item.handle, % "x" Round(x+18) " w" widths[i]
    GuiControl, 1:, % item.handle, % labels[i]
    x += 18+widths[i]+gap
  }
}

CompactStatCount(value) {
  return RegExReplace(Format("{:.1f}", value/1000), "\.0$", "") "k"
}

MeasureStatText(handle, label) {
  dc := DllCall("GetDC", "Ptr", handle, "Ptr")
  font := DllCall("SendMessage", "Ptr", handle, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
  oldFont := DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", font, "Ptr")
  VarSetCapacity(size, 8, 0)
  DllCall("gdi32\GetTextExtentPoint32", "Ptr", dc, "Str", label, "Int", StrLen(label), "Ptr", &size)
  DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", oldFont)
  DllCall("ReleaseDC", "Ptr", handle, "Ptr", dc)
  return NumGet(size, 0, "Int")
}
LogHeat(count, maximum) {
  return maximum <= 0 || count <= 0 ? 0 : Min(1, Ln(1 + count) / Ln(1 + maximum))
}
HeatColor(t, palette := 1, theme := 1) {
  static palettes := [[0x42535F,0x5A7D91,0x7FA8B8,0xB7D4D9]
                    , [0x44574F,0x618470,0x86AB96,0xC0D9C9]
                    , [0x5B4751,0x8A626B,0xB98B84,0xE5C2AD]
                    , [0x5B5143,0x897654,0xB8A079,0xE0CCA4]]
  static lightPalettes := [[0xF8E9F0,0xEDCEDA,0xDFADC5,0xD093B0]
                        , [0xE7F3EC,0xC9E4D4,0xA4CFB6,0x7BB397]
                        , [0xE8F1F7,0xCDE0EC,0xAACBDC,0x80ADC4]
                        , [0xF0EBF8,0xDDD3EE,0xC6B5E1,0xAE96CF]]
  colors := theme = 1 ? palettes[palette] : lightPalettes[palette]
  scaled := Max(0, Min(1, t))*3
  index := Min(3, Floor(scaled)+1), fraction := scaled-(index-1)
  a := colors[index], b := colors[index+1]
  r := Round((a>>16) + ((b>>16)-(a>>16))*fraction)
  g := Round(((a>>8)&255) + (((b>>8)&255)-((a>>8)&255))*fraction)
  blue := Round((a&255) + ((b&255)-(a&255))*fraction)
  return Format("{:02X}{:02X}{:02X}", r, g, blue)
}
ContrastText(hex) {
  luminance := ColorLuminance(hex)
  darkRatio := (luminance+0.05)/(ColorLuminance("29272B")+0.05)
  lightRatio := 1.05/(luminance+0.05)
  return darkRatio >= 4.5 ? "29272B" : (lightRatio >= 4.5 ? "FFFFFF" : "020408")
}
LinearChannel(n) {
  n := n / 255.0
  return n <= 0.04045 ? n / 12.92 : ((n+0.055)/1.055)**2.4
}
PaintTile(handle, background, foreground, neutral := false, role := "key") {
  global TileBrushes, ThemeIndex
  old := TileBrushes[handle]
  if (old.bg = background && old.fg = foreground && old.theme = ThemeIndex && old.role = role)
    return
  if (old.brush)
    DllCall("DeleteObject", "Ptr", old.brush)
  TileBrushes[handle] := {bg:background, fg:foreground, theme:ThemeIndex, neutral:neutral, role:role, brush:DllCall("CreateSolidBrush", "UInt", RGBtoBGR(background), "Ptr")}
  DllCall("InvalidateRect", "Ptr", handle, "Ptr", 0, "Int", 1)
}
RGBtoBGR(hex) {
  n := "0x" hex
  return ((n&255)<<16) | (n&0xFF00) | ((n>>16)&255)
}
TileColorMessage(hdc, handle) {
  global TileBrushes
  if (!TileBrushes.HasKey(handle))
    return
  tile := TileBrushes[handle]
  DllCall("SetTextColor", "Ptr", hdc, "UInt", RGBtoBGR(tile.fg))
  DllCall("SetBkColor", "Ptr", hdc, "UInt", RGBtoBGR(tile.bg))
  return tile.brush
}
FreeTileBrushes() {
  global TileBrushes, TileGdipToken, PreviewBitmaps
  for handle, item in PreviewBitmaps
    DllCall("DeleteObject", "Ptr", item.bitmap)
  PreviewBitmaps := {}
  for handle, tile in TileBrushes
    DllCall("DeleteObject", "Ptr", tile.brush)
  if (TileGdipToken)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", TileGdipToken)
  TileGdipToken := 0
}
DashboardMouseMove(wParam, lParam, message, handle) {
  global DisplayCounts, TileBrushes, HoverTile, StatsDetailText, maximum
  nextHover := TileBrushes.HasKey(handle) ? handle : 0
  if (nextHover != HoverTile) {
    if (HoverTile)
      DllCall("InvalidateRect", "Ptr", HoverTile, "Ptr", 0, "Int", 0)
    HoverTile := nextHover
    if (HoverTile)
      DllCall("InvalidateRect", "Ptr", HoverTile, "Ptr", 0, "Int", 0)
  }
  static previous := ""
  if (A_Gui = 1 && A_GuiControl = "SettingsButton") {
    previous := ""
    ToolTip, % Tr("设置", "Settings")
    return
  }
  if (A_Gui = 1 && (A_GuiControl = "StatsLine" || A_GuiControl = "ClickStat" || A_GuiControl = "RightClickStat" || A_GuiControl = "DistanceStat" || RegExMatch(A_GuiControl, "^StatIcon[1-4]$"))) {
    previous := ""
    ToolTip, %StatsDetailText%
    return
  }
  if (A_Gui = 1 && A_GuiControl = "QuickStats") {
    previous := ""
    ToolTip, % Tr("对数刻度 · 当前范围峰值 ", "Log scale · Peak in this period: ") FormatCount(maximum) Tr(" 次", " presses")
    return
  }
  if (A_Gui = 1 && RegExMatch(A_GuiControl, "^key(sc\d+)$", match)) {
    text := (DisplayCounts.keyboard[match1]+0) Tr(" 次", " presses")
    if (previous != A_GuiControl text)
      ToolTip, %text%
    previous := A_GuiControl text
  } else {
    ToolTip
    previous := ""
  }
}
FormatCount(n) {
  return RegExReplace(Round(n)+0, "\d(?=(\d{3})+($))", "$0,")
}
PrettyDate(day) {
  return SubStr(day,1,4) "-" SubStr(day,5,2) "-" SubStr(day,7,2)
}

BuildSettings() {
  global
  Gui, 2:New, +HwndhSettings -MaximizeBox
  theme := GetDashboardTheme()
  Gui, 2:Color, % theme.surface, % theme.idle
  Gui, 2:Font, % "s12 c" theme.text, Microsoft YaHei UI
  Gui, 2:Add, Text, x20 y18 w492 h26 vSettingsHeading, 设置
  Gui, 2:Font, % "s10 c" theme.text, Microsoft YaHei UI
  Gui, 2:Add, Text, x20 y56 w492 h22 vThemeHeading, 外观模式
  Gui, 2:Font, % "s9 c" theme.muted, Microsoft YaHei UI
  Gui, 2:Add, Text, x20 y80 w492 h20 vThemeHint, 点击预览立即应用，也可在托盘中切换
  ThemePreviewHandles := []
  Loop, 2 {
    Gui, 2:Add, Button, % "x" 20+(A_Index-1)*252 " y106 w240 h130 vThemePreview" A_Index " hwndhandle", % ThemeDisplayName(A_Index)
    InstallPreviewButton(handle)
    ThemePreviewHandles.Push(handle)
  }
  Gui, 2:Font, % "s10 c" theme.text, Microsoft YaHei UI
  Gui, 2:Add, Text, x20 y252 w492 h22 vPaletteHeading, 配色
  Gui, 2:Font, % "s9 c" theme.text, Microsoft YaHei UI
  PalettePreviewHandles := []
  Loop, 4 {
    Gui, 2:Add, Button, % "x" 20+(A_Index-1)*126 " y280 w114 h100 vPalettePreview" A_Index " hwndhandle", % PaletteDisplayName(A_Index)
    InstallPreviewButton(handle)
    PalettePreviewHandles.Push(handle)
  }
  OnMessage(0x111, "SettingsAppearanceCommand")
  OnMessage(0x8001, "ApplyAppearanceChoice")
  Gui, 2:Add, Text, x20 y402 w410 h20 vRetentionLabel, 主文件保留天数（更早明细按年归档）
  Gui, 2:Add, Edit, x448 y399 w64 h23 Number vdsd, %DataStorageDays%
  Gui, 2:Add, Text, x20 y440 w410 h20 vMonitorLabel, 屏幕物理尺寸 / mm
  Gui, 2:Add, Text, x20 y472 w34 h20 vWidthLabel, 宽
  Gui, 2:Add, Edit, x56 y469 w65 h23 Number vdw, % devicecaps.w
  Gui, 2:Add, Text, x152 y472 w34 h20 vHeightLabel, 高
  Gui, 2:Add, Edit, x188 y469 w65 h23 Number vdh, % devicecaps.h
  Gui, 2:Add, Text, x20 y510 w492 h20 vLayoutLabel, 原始键盘布局 / px
  labels := ["键宽", "键高", "键间距", "水平距", "垂直距"]
  vars := ["lkw", "lkh", "lks", "lkhs", "lkvs"]
  keys := ["kw", "kh", "ks", "khs", "kvs"]
  Loop, 5 {
    Gui, 2:Add, Text, % "x" 20+(A_Index-1)*102 " y541 w84 h20 vLayoutCaption" A_Index, % labels[A_Index]
    Gui, 2:Add, Edit, % "x" 20+(A_Index-1)*102 " y565 w84 h23 Number v" vars[A_Index], % layout[keys[A_Index]]
  }
  Gui, 2:Add, Button, x348 y610 w76 h28 gCancelSetting vCancelButton, 取消
  Gui, 2:Add, Button, x436 y610 w76 h28 gSaveSetting vSaveButton, 保存
  Gui, 2:Show, Hide w532 h658, 设置
  ApplyDashboardTheme()
}

ThemeDisplayName(index) {
  return [Tr("深色", "Dark"), Tr("浅色", "Light")][index]
}
RefreshThemePreviews() {
  global ThemePreviewHandles, PalettePreviewHandles, ThemeIndex, PaletteIndex, hSettings
  current := GetDashboardTheme()
  for i, handle in ThemePreviewHandles {
    PaintTile(handle, current.surface, current.text, i=ThemeIndex, "theme-" i)
    CachePreviewButton(handle)
  }
  for i, handle in PalettePreviewHandles {
    PaintTile(handle, current.surface, current.text, i=PaletteIndex, "palette-" i)
    GuiControl, 2:, %handle%, % PaletteDisplayName(i)
    CachePreviewButton(handle)
  }
  if (hSettings)
    DllCall("RedrawWindow", "Ptr", hSettings, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

PaletteDisplayName(index) {
  global ThemeIndex
  return ThemeIndex=1 ? [Tr("冰川青", "Glacier"), Tr("翡翠", "Jade"), Tr("熔岩", "Lava"), Tr("琥珀", "Amber")][index]
    : [Tr("樱粉", "Blossom"), Tr("薄荷绿", "Mint"), Tr("雾蓝", "Mist blue"), Tr("淡紫", "Lilac")][index]
}
; Route native button notifications by HWND, independently of AHK's GUI-event
; classification. Apply outside the button's focus/paint callback stack.
SettingsAppearanceCommand(wParam, handle) {
  global ThemePreviewHandles, PalettePreviewHandles, hSettings
  notification := (wParam >> 16) & 0xFFFF
  if (notification != 0 && notification != 5)
    return
  for i, button in ThemePreviewHandles
    if (handle = button) {
      DllCall("PostMessage", "Ptr", hSettings, "UInt", 0x8001, "Ptr", i, "Ptr", 0)
      return 0
    }
  for i, button in PalettePreviewHandles
    if (handle = button) {
      DllCall("PostMessage", "Ptr", hSettings, "UInt", 0x8001, "Ptr", 100+i, "Ptr", 0)
      return 0
    }
}
ApplyAppearanceChoice(choice) {
  if (choice >= 1 && choice <= 2)
    SetDashboardTheme(choice)
  else if (choice >= 101 && choice <= 104)
    SetDashboardPalette(choice-100)
}

GetDashboardTheme(index := 0, palette := 0) {
  global ThemeIndex, PaletteIndex, DarkPaletteIndex, LightPaletteIndex
  if (!index)
    index := ThemeIndex
  if (!palette)
    palette := index=ThemeIndex ? PaletteIndex : (index=1 ? DarkPaletteIndex : LightPaletteIndex)
  palette := Max(1,Min(4,palette+0))
  if (index=2) {
    if (palette=1)
      return {surface:"FBF8FA", panel:"F0EBEF", panelMuted:"6C656D", text:"353238", muted:"767078", zero:"EEE3E9", idle:"F1E5EC", active:"B95783", activeText:"FFFFFF", border:"B69CA9"}
    if (palette=2)
      return {surface:"F7FAF8", panel:"EAF0EC", panelMuted:"626E67", text:"303833", muted:"6E7872", zero:"E1EDE5", idle:"E6F0E9", active:"377B58", activeText:"FFFFFF", border:"8EA99B"}
    if (palette=3)
      return {surface:"F6F9FC", panel:"E8EFF5", panelMuted:"626C79", text:"303844", muted:"6B7685", zero:"E1EAF2", idle:"E6EDF5", active:"527C9C", activeText:"FFFFFF", border:"95A9BA"}
    return {surface:"F9F7FC", panel:"EEEAF4", panelMuted:"6C6579", text:"37323F", muted:"776F84", zero:"E9E2F0", idle:"EEE7F5", active:"80609F", activeText:"FFFFFF", border:"AA9BBB"}
  }
  return {surface:"34373D", panel:"41454C", panelMuted:"B8BEC8", text:"E8EBF0", muted:"AFB5C0", zero:"42464E", idle:"41454C", active:"65707E", activeText:"F1F3F6", border:"FFFFFF"}
}

ApplyDashboardTheme() {
  global hWin, hSettings, ThemeIndex
  theme := GetDashboardTheme()
  Gui, 1:Color, % theme.surface, % theme.surface
  Gui, 2:Color, % theme.surface, % theme.idle
  for i, name in ["StatsLine", "ClickStat", "RightClickStat", "DistanceStat"]
    GuiControl, % "1:+c" theme.text, %name%
  GuiControl, % "1:+c" theme.muted, CoverageLine
  GuiControl, % "1:+c" theme.muted, QuickStats
  for i, window in [hWin, hSettings] {
    if (!window)
      continue
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window, "UInt", 20, "Int*", ThemeIndex=1, "UInt", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window, "UInt", 35, "UInt*", RGBtoBGR(theme.surface), "UInt", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window, "UInt", 36, "UInt*", RGBtoBGR(theme.text), "UInt", 4)
  }
  if (hSettings) {
    ; Address our controls directly: WinGet skips this window while hidden,
    ; leaving stale light text when a light theme is selected from the tray.
    for i, name in ["SettingsHeading", "ThemeHeading", "PaletteHeading", "RetentionLabel", "MonitorLabel", "WidthLabel", "HeightLabel", "LayoutLabel", "dsd", "dw", "dh", "lkw", "lkh", "lks", "lkhs", "lkvs", "CancelButton", "SaveButton"]
      GuiControl, % "2:+c" theme.text, %name%
    Loop, 5
      GuiControl, % "2:+c" theme.text, % "LayoutCaption" A_Index
  }
  RefreshThemePreviews()
  GuiControl, % "2:+c" theme.muted, ThemeHint
  DllCall("RedrawWindow", "Ptr", hWin, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
}

UpdateThemeMenu() {
  global ThemeMenuLabels, ThemeIndex
  for i, label in ThemeMenuLabels {
    if (i=ThemeIndex)
      Menu, ThemeMenu, Check, %label%
    else
      Menu, ThemeMenu, Uncheck, %label%
  }
}
SetDashboardTheme(index) {
  global ThemeIndex, PaletteIndex, DarkPaletteIndex, LightPaletteIndex, DemoMode
  if (index < 1 || index > 2 || index = ThemeIndex)
    return
  if (ThemeIndex=1)
    DarkPaletteIndex := PaletteIndex
  else
    LightPaletteIndex := PaletteIndex
  ThemeIndex := index
  PaletteIndex := Max(1,Min(4,(index=1 ? DarkPaletteIndex : LightPaletteIndex)+0))
  UpdateThemeMenu()
  UpdatePaletteMenu(true)
  ApplyDashboardTheme()
  RefreshDashboard()
  if (!DemoMode)
    SaveData()
}

UpdatePaletteMenu(rebuild := false) {
  global PaletteMenuLabels, ThemeIndex, PaletteIndex
  if (rebuild) {
    if (PaletteMenuLabels.Length())
      Menu, PaletteMenu, DeleteAll
    PaletteMenuLabels := [PaletteDisplayName(1), PaletteDisplayName(2), PaletteDisplayName(3), PaletteDisplayName(4)]
    for i, label in PaletteMenuLabels
      Menu, PaletteMenu, Add, %label%, SelectPaletteFromTray, +Radio
    Menu, SettingsMenu, Add, % Tr("热力色谱", "Heatmap palette"), :PaletteMenu
  }
  for i, label in PaletteMenuLabels {
    if (i=PaletteIndex)
      Menu, PaletteMenu, Check, %label%
    else
      Menu, PaletteMenu, Uncheck, %label%
  }
}
SetDashboardPalette(index) {
  global PaletteIndex, ThemeIndex, DarkPaletteIndex, LightPaletteIndex, DemoMode
  if (index < 1 || index > 4 || index = PaletteIndex)
    return
  PaletteIndex := index
  if (ThemeIndex=1)
    DarkPaletteIndex := index
  else
    LightPaletteIndex := index
  UpdatePaletteMenu()
  ApplyDashboardTheme()
  RefreshDashboard()
  if (!DemoMode)
    SaveData()
}
