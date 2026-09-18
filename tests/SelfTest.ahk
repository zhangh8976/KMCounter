RunSelfTests() {
  global
  TestPassed := 0, TestFailed := 0
  AssertEq(RangeStart(2, "20260914"), "20260914", "Monday week start")
  AssertEq(RangeStart(2, "20260920"), "20260914", "Sunday week start")
  AssertEq(RangeStart(2, "20260101"), "20251229", "Week crosses year")
  AssertEq(RangeStart(3, "20240229"), "20240201", "Leap month")
  AssertEq(RangeStart(4, "20260918"), "20260101", "Year start")
  AssertEq(LogHeat(0, 0), 0, "Empty heatmap")
  AssertEq(LogHeat(10, 10), 1, "Peak heat")
  prior := -1
  for i, n in [0,1,10,100,1000,10000] {
    heat := LogHeat(n, 10000)
    AssertTrue(heat > prior && heat <= 1, "Log monotonic " n)
    prior := heat
  }
  AssertTrue(LogHeat(10, 10000) > 0.25, "Rare keys visible")
  Loop, 4 {
    palette := A_Index
    Loop, 101 {
      hex := HeatColor((A_Index-1)/100, palette)
      AssertTrue(RegExMatch(hex, "^[0-9A-F]{6}$"), "Palette hex " palette "/" A_Index)
    }
  }
  AssertEq(HeatColor(0, 1), "42535F", "Palette cold endpoint")
  AssertEq(HeatColor(1, 1), "B7D4D9", "Palette hot endpoint")
  AssertEq(ContrastText("FFFFFF"), "29272B", "Bright key contrast")
  AssertEq(ContrastText("000000"), "FFFFFF", "Dark key contrast")
  AssertTrue(LinearChannel(128) > 0.21 && LinearChannel(128) < 0.22, "sRGB uses fractional division")
  Loop, 2 {
    themeId := A_Index
    Loop, 4 {
      paletteId := A_Index, previousLuminance := themeId=1 ? -1 : 2
      Loop, 101 {
        hex := HeatColor((A_Index-1)/100, paletteId, themeId)
        luminance := ColorLuminance(hex)
        AssertTrue(themeId=1 ? luminance >= previousLuminance : luminance <= previousLuminance, "Ordered luminance theme/palette " themeId "/" paletteId)
        if (themeId != 1) {
          AssertTrue(luminance >= 0.34, "Light themes retain pastel peak luminance")
          AssertTrue(ColorLuminance(MixTileColor(hex, "000000", 0.02)) >= 0.32, "Light keycap shadow remains soft")
        }
        previousLuminance := luminance
        textLuminance := ColorLuminance(ContrastText(hex))
        contrast := (Max(luminance,textLuminance)+0.05)/(Min(luminance,textLuminance)+0.05)
        AssertTrue(contrast >= 4.5, "Legible key labels theme/palette " themeId "/" paletteId)
      }
    }
  }
  AssertEq(FormatCount(1234567), "1,234,567", "Digit grouping")
  today := "20260918", mouse := {}, keyboard := {}, DataFiles := {}, DayCache := {}
  current := EmptyCounts(), current.keyboard.sc30 := 7, current.keyboard.keystrokes := 7
  current.mouse.move := 1.5
  mouse[today] := current.mouse, keyboard[today] := current.keyboard
  total := EmptyCounts(), total.keyboard.sc30 := 999, total.keyboard.keystrokes := 999
  mouse.total := total.mouse, keyboard.total := total.keyboard
  for day, value in {20260918:100,20260917:11,20260901:13,20260101:17,20251231:19} {
    counts := EmptyCounts(), counts.keyboard.sc30 := value, counts.keyboard.keystrokes := value
    counts.mouse.move := value / 10
    DayCache[day] := counts, DataFiles[day] := "test"
  }
  AssertEq(AggregateRange(1, today).keyboard.sc30, 7, "Today uses live count")
  AssertEq(AggregateRange(2, today).keyboard.sc30, 18, "Week includes today once")
  AssertEq(AggregateRange(3, today).keyboard.sc30, 31, "Month sum")
  AssertEq(AggregateRange(4, today).keyboard.sc30, 48, "Year sum excludes previous year")
  AssertEq(AggregateRange(5, today).keyboard.sc30, 999, "Total independent of daily retention")
  AssertEq(AggregateRange(2, today).mouse.move, 2.6, "Mouse range sum")
  AssertEq(AggregateRange(2, today).days, 2, "Missing days coverage")
  keyboard[today].sc30 += 1
  AssertEq(AggregateRange(2, today).keyboard.sc30, 19, "Live refresh bypasses history cache")
  AssertEq(keyboard.total.sc30, 999, "Switching ranges never resets total")

  root := A_ScriptDir "\tests\tmp\" A_TickCount
  FileCreateDir, %root%
  source := root "\KMCounter.ini", directory := root "\history"
  IniWrite(9, source, "20240101", "sc30")
  IniWrite(9, source, "20240101", "keystrokes")
  IniWrite(4, source, "20240101", "sc999")
  IniWrite(6.5, source, "20240101", "move")
  IniWrite(20, source, "20260918", "sc30")
  IniWrite(99, source, "total", "sc30")
  IniWrite(30, source, "history", "storage")
  AssertTrue(ArchiveHistory("20250918", source, directory), "Archive succeeds")
  AssertTrue(FileExist(source ".pre-archive.bak"), "Migration backup created")
  AssertEq(ReadCounts(directory "\2024.ini", "20240101").keyboard.sc30, 9, "Archive retains old counts")
  AssertEq(ReadCounts(directory "\2024.ini", "20240101").keyboard.sc999, 4, "Unknown scan codes preserved")
  AssertEq(ReadCounts(directory "\2024.ini", "20240101").mouse.move, 6.5, "Archive retains mouse distance")
  AssertEq(IniRead(source, "20240101", "sc30", -1), -1, "Old source removed after archive")
  AssertEq(ReadCounts(source, "20260918").keyboard.sc30, 20, "Recent date retained")
  AssertEq(ReadCounts(source, "total").keyboard.sc30, 99, "Archive leaves total unchanged")
  IniWrite(9, source, "20240101", "sc30")
  AssertTrue(ArchiveHistory("20250918", source, directory), "Interrupted archive retry succeeds")
  AssertEq(ReadCounts(directory "\2024.ini", "20240101").keyboard.sc30, 9, "Retry overwrites instead of adds")
  AssertTrue(ArchiveHistory("20250918", source, directory), "Repeated archive is no-op")
  AssertEq(ReadCounts(root "\missing.ini", today).keyboard.keystrokes, 0, "Missing file zero counts")
  DataFiles := {}, DayCache := {}
  IndexHistoryFile(directory "\2024.ini")
  AssertTrue(DataFiles.HasKey(20240101), "Archived date indexed")
  ; The hot file saves daily and lifetime counters as one verified replacement.
  previousDirectory := A_WorkingDir
  SetWorkingDir, %root%
  DataStorageDays := 366, PaletteIndex := 2, ThemeIndex := 2, AppLanguage := "en", DemoMode := false
  DarkPaletteIndex := 4, LightPaletteIndex := 2
  layout := {kw:52,kh:45,ks:2,khs:10,kvs:10}, devicecaps := {w:600,h:340}
  AssertTrue(SaveData(), "Atomic snapshot save")
  AssertEq(ReadCounts("KMCounter.ini", today).keyboard.sc30, 8, "Saved live counter")
  AssertEq(ReadCounts("KMCounter.ini", "total").keyboard.sc30, 999, "Saved lifetime counter")
  AssertEq(IniRead("KMCounter.ini", "appearance", "palette"), 2, "Palette persists")
  AssertEq(IniRead("KMCounter.ini", "appearance", "theme"), 2, "Theme persists")
  appearanceReadback := ReadAppearance()
  AssertEq(appearanceReadback.mode "/" appearanceReadback.palette, "2/2", "Mode and selected color survive reload")
  AssertEq(appearanceReadback.dark "/" appearanceReadback.light,"4/2","Dark and light remember independent colors")
  for migrationStep, fixture in [{oldMode:1,oldPalette:4,mode:1,palette:4},{oldMode:2,oldPalette:3,mode:2,palette:1},{oldMode:3,oldPalette:1,mode:2,palette:2}] {
    IniWrite, 1, legacy-appearance.ini, appearance, schema
    IniWrite, % fixture.oldMode, legacy-appearance.ini, appearance, theme
    IniWrite, % fixture.oldPalette, legacy-appearance.ini, appearance, palette
    migrated := ReadAppearance("legacy-appearance.ini")
    AssertEq(migrated.mode "/" migrated.palette,fixture.mode "/" fixture.palette,"Legacy appearance migrates without mismatched background")
  }
  AssertEq(ReadAppLanguage(), "en", "Language preference survives INI readback")
  FileCreateDir, blocked
  AssertTrue(!PrepareSnapshot("KMCounter.ini", "blocked\missing\snapshot.ini"), "Failed snapshot copy preserves source")
  AssertEq(ReadCounts("KMCounter.ini", "total").keyboard.sc30, 999, "Source intact after failure")
  SetWorkingDir, %previousDirectory%
  FileAppend, % "PASS " TestPassed " / FAIL " TestFailed "`n", *
  ExitApp, % TestFailed ? 1 : 0
}
AssertTrue(value, name) {
  global TestPassed, TestFailed
  if (value)
    TestPassed += 1
  else {
    TestFailed += 1
    FileAppend, % "FAIL: " name "`n", *
  }
}
AssertEq(actual, expected, name) {
  AssertTrue(actual = expected, name " expected=" expected " actual=" actual)
}

TestDashboard() {
  global
  TestPassed := 0, TestFailed := 0
  SetDashboardLanguage("zh")
  initial := keyboard[today].keystrokes
  Gui, 1:Show, NA, KMCounter smoke test
  Loop, 2 {
    SetDashboardTheme(A_Index)
    menuState := DllCall("GetMenuState", "Ptr", MenuGetHandle("ThemeMenu"), "UInt", ThemeIndex-1, "UInt", 0x400)
    AssertTrue(menuState != 0xFFFFFFFF && (menuState & 8), "Tray theme is checked")
    Loop, 5 {
      SelectedRange := A_Index
      Loop, 4 {
        SetDashboardPalette(A_Index)
        paletteState := DllCall("GetMenuState", "Ptr", MenuGetHandle("PaletteMenu"), "UInt", PaletteIndex-1, "UInt", 0x400)
        AssertTrue(paletteState != 0xFFFFFFFF && (paletteState & 8), "Tray palette is checked")
        DllCall("RedrawWindow", "Ptr", hWin, "Ptr", 0, "Ptr", 0, "UInt", 0x185)
        for rangeId, rangeHandle in RangeHandles {
          rgb := "0x" TileBrushes[rangeHandle].bg
          AssertTrue((rgb>>16) = ((rgb>>8)&255) && ((rgb>>8)&255) = (rgb&255), "Time range stays grayscale")
        }
        AssertTrue(DisplayCounts.keyboard.keystrokes > 0, "Dashboard theme/range/palette " ThemeIndex "/" SelectedRange "/" PaletteIndex)
      }
    }
  }
  AssertEq(DllCall("GetWindowLong", "Ptr", SettingsButtonHandle, "Int", -16) & 15, 11, "Gear retains owner draw style")
  GuiControlGet, gearName, 1:, SettingsButton
  AssertEq(gearName, "设置", "Gear exposes an accessible settings label")
  AssertTrue(DllCall("GetWindowLong", "Ptr", SettingsButtonHandle, "Int", -16) & 0x10000, "Gear participates in keyboard tab navigation")
  Critical, Off
  DllCall("PostMessage", "Ptr", SettingsButtonHandle, "UInt", 0xF5, "Ptr", 0, "Ptr", 0)
  Sleep, 80
  AssertTrue(DllCall("IsWindowVisible", "Ptr", hSettings), "Clicking gear opens settings")
  GuiControl, 2:, dsd, 123
  for previewTestIndex, previewTestHandle in ThemePreviewHandles {
    Critical, Off
    DllCall("PostMessage", "Ptr", previewTestHandle, "UInt", 0xF5, "Ptr", 0, "Ptr", 0)
    Sleep, 80
    AssertEq(ThemeIndex, previewTestIndex, "Clicking theme preview applies its theme")
    GuiControlGet, editedDays, 2:, dsd
    AssertEq(editedDays, 123, "Theme preview preserves unsaved settings")
    menuState := DllCall("GetMenuState", "Ptr", MenuGetHandle("ThemeMenu"), "UInt", previewTestIndex-1, "UInt", 0x400)
    AssertTrue(menuState & 8, "Preview selection synchronizes tray theme")
  }
  for clickTestStep, clickTestIndex in [2,1,2,1,2,1] {
    clickTestHandle := ThemePreviewHandles[clickTestIndex]
    GuiControl, 2:Focus, dsd
    Critical, Off
    DllCall("SendMessage", "Ptr", clickTestHandle, "UInt", 0x201, "Ptr", 1, "Ptr", 40 | (40<<16))
    DllCall("SendMessage", "Ptr", clickTestHandle, "UInt", 0xF4, "Ptr", 1, "Ptr", 1)
    pressedState := DllCall("SendMessage", "Ptr", clickTestHandle, "UInt", 0xF2, "Ptr", 0, "Ptr", 0)
    AssertTrue(pressedState & 4, "First mouse down keeps preview pressed after focus change")
    DllCall("PostMessage", "Ptr", clickTestHandle, "UInt", 0x202, "Ptr", 0, "Ptr", 40 | (40<<16))
    Sleep, 100
    AssertEq(ThemeIndex, clickTestIndex, "Single mouse down/up applies theme on first click")
  }
  for paletteThemeTest, paletteThemeId in [1,2] {
    SetDashboardTheme(paletteThemeId)
    SetDashboardPalette(1)
    for paletteClickStep, paletteClickId in [4,2,3,1] {
      paletteClickHandle := PalettePreviewHandles[paletteClickId]
      paintBefore := PreviewPaintCounts.Clone()
      GuiControl, 2:Focus, dsd
      Critical, Off
      DllCall("SendMessage", "Ptr", paletteClickHandle, "UInt", 0x201, "Ptr", 1, "Ptr", 30 | (20<<16))
      DllCall("PostMessage", "Ptr", paletteClickHandle, "UInt", 0x202, "Ptr", 0, "Ptr", 30 | (20<<16))
      Sleep, 100
      AssertEq(PaletteIndex, paletteClickId, "Palette changes with one mouse click")
      for paintGroupIndex, paintGroup in [ThemePreviewHandles,PalettePreviewHandles]
        for paintIndex, paintHandle in paintGroup
          AssertTrue(PreviewPaintCounts[paintHandle] > paintBefore[paintHandle], "Every preview paints during live click callback " paletteThemeId "/" paletteClickId "/" paintGroupIndex "/" paintIndex " " paintBefore[paintHandle] "->" PreviewPaintCounts[paintHandle])
      paletteMenuState := DllCall("GetMenuState", "Ptr", MenuGetHandle("PaletteMenu"), "UInt", paletteClickId-1, "UInt", 0x400)
      AssertTrue(paletteMenuState & 8, "Palette preview synchronizes tray")
      AssertEq(TileBrushes[LegendHandles[80]].bg, HeatColor(1,paletteClickId,paletteThemeId), "Palette choice updates legend immediately")
      GuiControlGet, paletteEditedDays, 2:, dsd
      AssertEq(paletteEditedDays,123,"Palette choice keeps unsaved settings")
    }
  }
  SetDashboardTheme(1)
  SetDashboardPalette(4)
  SetDashboardTheme(2)
  SetDashboardPalette(3)
  SetDashboardTheme(1)
  AssertEq(PaletteIndex,4,"Dark mode restores its last color")
  SetDashboardTheme(2)
  AssertEq(PaletteIndex,3,"Light mode restores its last color")
  AssertEq(GetDashboardTheme().surface,GetDashboardTheme(2,3).surface,"Light background follows selected key palette")
  SetDashboardPalette(4)
  Critical, Off
  DllCall("PostMessage", "Ptr", ThemePreviewHandles[ThemeIndex], "UInt", 0xF5, "Ptr", 0, "Ptr", 0)
  Sleep, 100
  AssertEq(PaletteIndex,4,"Clicking selected theme does not reset palette")
  GuiControl, 2:Focus, PalettePreview2
  Critical, Off
  DllCall("SendMessage", "Ptr", PalettePreviewHandles[2], "UInt", 0x100, "Ptr", 32, "Ptr", 1)
  DllCall("PostMessage", "Ptr", PalettePreviewHandles[2], "UInt", 0x101, "Ptr", 32, "Ptr", 0xC0000001)
  Sleep, 100
  AssertEq(PaletteIndex,2,"Space activates focused palette preview")
  for i, handle in [SettingsButtonHandle, ThemePreviewHandles[1], ThemePreviewHandles[2], PalettePreviewHandles[1], PalettePreviewHandles[2], PalettePreviewHandles[3], PalettePreviewHandles[4]] {
    ; Reproduce the system's focus/default-button style transitions explicitly.
    DllCall("SendMessage", "Ptr", handle, "UInt", 0xF4, "Ptr", 1, "Ptr", 1)
    AssertEq(DllCall("GetWindowLong", "Ptr", handle, "Int", -16) & 15, handle=SettingsButtonHandle ? 11 : 1, "Button painting survives default-button promotion")
    DllCall("SendMessage", "Ptr", handle, "UInt", 0xF4, "Ptr", 0, "Ptr", 1)
    AssertEq(DllCall("GetWindowLong", "Ptr", handle, "Int", -16) & 15, handle=SettingsButtonHandle ? 11 : 0, "Button painting survives default-button demotion")
    VerifyOwnerDrawButton(handle)
  }
  Gui, 2:Hide
  Loop, 2 {
    SetDashboardTheme(A_Index)
    GuiControlGet, headingHandle, 2:Hwnd, SettingsHeading
    dc := DllCall("GetDC", "Ptr", headingHandle, "Ptr")
    DllCall("SendMessage", "Ptr", hSettings, "UInt", 0x138, "Ptr", dc, "Ptr", headingHandle)
    AssertEq(DllCall("GetTextColor", "Ptr", dc), RGBtoBGR(GetDashboardTheme().text), "Hidden settings labels follow theme text color")
    DllCall("ReleaseDC", "Ptr", headingHandle, "Ptr", dc)
  }
  GuiControlGet, removedTitle, 1:Hwnd, DashboardTitle
  AssertTrue(ErrorLevel, "Old dashboard title removed")
  GuiControlGet, removedPalette, 1:Hwnd, Palette1
  AssertTrue(ErrorLevel, "No palette switches on dashboard")
  GuiControlGet, selector, 1:Pos, %RangeTrackHandle%
  AssertTrue(Abs(selectorX+selectorW/2-(54+DashboardWidth-260)/2) <= 1, "Period selector centered between gear and legend")
  AssertTrue(TileDrawCalls > 0, "Native WM_DRAWITEM executed")
  AssertEq(TileRenderErrors, 0, "GDI+ drawing succeeded")
  AssertEq(keyboard[today].keystrokes, initial, "Rendering preserves counters")
  rectangles := []
  for key, handle in KeyHandles {
    GuiControlGet, rect, 1:Pos, %handle%
    AssertTrue(rectW > 0 && rectH > 0 && rectX >= 0 && rectX+rectW <= DashboardWidth && rectY+rectH <= DashboardHeight, "Key inside window " key)
    for i, other in rectangles
      AssertTrue(rectX >= other.x+other.w || rectX+rectW <= other.x || rectY >= other.y+other.h || rectY+rectH <= other.y, "Keys do not overlap " key "/" other.key)
    rectangles.Push({x:rectX,y:rectY,w:rectW,h:rectH,key:key})
  }
  AssertTrue(KeyHandles.Count() >= 100, "Complete keyboard")
  for i, name in ["StatsLine", "ClickStat", "RightClickStat", "DistanceStat", "StatCaption1", "StatCaption2", "StatCaption3", "StatCaption4"] {
    GuiControlGet, stat, 1:Pos, %name%
    AssertTrue(statW > 0 && statH > 0 && statX >= DashboardWidth-260 && statX+statW <= DashboardWidth-12, "Statistics stay inside legend width: " name)
    AssertTrue(statY >= 36 && statY+statH <= 88, "Statistics leave space before keyboard: " name)
  }
  savedMouse := mouse[today].Clone()
  savedRange := SelectedRange
  mouse[today].lbcount := 123, mouse[today].rbcount := 7
  mouse[today].mbcount := 999, mouse[today].xbcount := 555
  SelectedRange := 1
  RefreshDashboard()
  GuiControlGet, leftCount, 1:, ClickStat
  GuiControlGet, rightCount, 1:, RightClickStat
  AssertEq(leftCount, "123", "Left clicks exclude other mouse buttons")
  AssertEq(rightCount, "7", "Right clicks remain independent")
  mouse[today] := savedMouse, SelectedRange := savedRange
  RefreshDashboard()
  oldTheme := ThemeIndex, oldPalette := PaletteIndex, oldRange := SelectedRange
  GuiControl, 2:, dsd, 123
  SetDashboardLanguage("en")
  GuiControlGet, translated, 1:, Range5
  AssertEq(translated, "All time", "Range switches to English")
  GuiControlGet, translated, 1:, SettingsButton
  AssertEq(translated, "Settings", "Gear accessibility switches to English")
  GuiControlGet, translated, 1:, StatCaption2
  AssertEq(translated, "Left", "Left click label switches to English")
  GuiControlGet, translated, 1:, StatCaption3
  AssertEq(translated, "Right", "Right click label switches to English")
  GuiControlGet, translated, 2:, SaveButton
  AssertEq(translated, "Save", "Settings switches to English")
  GuiControlGet, editedDays, 2:, dsd
  AssertEq(editedDays, 123, "Language change preserves unsaved settings")
  AssertEq(ThemeIndex "/" PaletteIndex "/" SelectedRange, oldTheme "/" oldPalette "/" oldRange, "Language keeps display choices")
  AssertEq(keyboard[today].keystrokes, initial, "Language preserves counters")
  languageState := DllCall("GetMenuState", "Ptr", MenuGetHandle("LanguageMenu"), "UInt", 1, "UInt", 0x400)
  AssertTrue(languageState != 0xFFFFFFFF && (languageState & 8), "English menu radio is checked")
  SetDashboardLanguage("zh")
  GuiControlGet, translated, 2:, SaveButton
  AssertEq(translated, "保存", "Settings switches back to Chinese")
  FileAppend, % "GUI: " DashboardWidth " x " DashboardHeight "px, " KeyHandles.Count() " keys; PASS " TestPassed " / FAIL " TestFailed "`n", *
  FreeTileBrushes()
  ExitApp, % TestFailed ? 1 : 0
}

VerifyOwnerDrawButton(handle) {
  global TileBrushes, TileDrawCalls, PreviewPaintCounts
  VarSetCapacity(rect,16,0)
  DllCall("GetClientRect", "Ptr", handle, "Ptr", &rect)
  w := NumGet(rect,8,"Int"), h := NumGet(rect,12,"Int")
  dc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
  VarSetCapacity(info,40,0)
  NumPut(40,info,0,"UInt"), NumPut(w,info,4,"Int"), NumPut(-h,info,8,"Int")
  NumPut(1,info,12,"UShort"), NumPut(32,info,14,"UShort")
  bitmap := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", &info, "UInt", 0, "Ptr*", bits, "Ptr", 0, "UInt", 0, "Ptr")
  old := DllCall("SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
  before := PreviewPaintCounts.HasKey(handle) ? PreviewPaintCounts[handle] : TileDrawCalls
  DllCall("SendMessage", "Ptr", handle, "UInt", 0x318, "Ptr", dc, "Ptr", 4)
  after := PreviewPaintCounts.HasKey(handle) ? PreviewPaintCounts[handle] : TileDrawCalls
  AssertTrue(after > before, "Native button invokes production drawing " before "->" after)
  DllCall("GdiFlush")
  changed := 0, background := "0x" TileBrushes[handle].bg, colors := {}
  Loop, % w*h {
    pixel := NumGet(bits+0,(A_Index-1)*4,"UInt") & 0xFFFFFF
    colors[pixel] := true
    if (pixel != background)
      changed += 1
  }
  AssertTrue(colors.Count()>24,"Preview has artwork, not a blank solid button")
  AssertTrue(changed > 80, "Button artwork has visible non-background pixels")
  DllCall("SelectObject", "Ptr", dc, "Ptr", old)
  DllCall("DeleteObject", "Ptr", bitmap)
  DllCall("DeleteDC", "Ptr", dc)
}
