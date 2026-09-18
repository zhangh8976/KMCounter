; INI compatibility + bounded active history. Archived daily sections are exact snapshots.
LoadData(date) {
  global
  AppLanguage := ReadAppLanguage()
  DataStorageDays := Max(1, IniRead("KMCounter.ini", "history", "storage", 366) + 0)
  firstday := EnvAdd(today, -DataStorageDays + 1, "Days", 1, 8)
  appearance := ReadAppearance()
  ThemeIndex := appearance.mode, PaletteIndex := appearance.palette
  DarkPaletteIndex := appearance.dark, LightPaletteIndex := appearance.light
  SelectedRange := 1
  UIScale := 0.70
  DayCache := {}, DataFiles := {}, ArchiveWarning := ""
  devicecaps.w := IniRead("KMCounter.ini", "devicecaps", "w", " ")
  devicecaps.h := IniRead("KMCounter.ini", "devicecaps", "h", " ")
  UpdateDeviceCaps(devicecaps.w, devicecaps.h)
  ratio := Min(1, A_ScreenWidth / 1920)
  for key, value in {kw:52, kh:45, ks:2, khs:10, kvs:10}
    layout[key] := IniRead("KMCounter.ini", "layout", key, Round(value * ratio))
  if (DemoMode) {
    BuildDemoData()
    return true
  }
  ArchiveHistory(firstday)
  Loop, Files, %A_ScriptDir%\history\*.ini
    IndexHistoryFile(A_LoopFileFullPath)
  IndexHistoryFile(A_ScriptDir "\KMCounter.ini")
  current := ReadCounts("KMCounter.ini", today)
  total := ReadCounts("KMCounter.ini", "total")
  mouse[today] := current.mouse, keyboard[today] := current.keyboard
  mouse.total := total.mouse, keyboard.total := total.keyboard
  return true
}

EmptyCounts() {
  result := {mouse:{}, keyboard:{keystrokes:0}}
  for i, key in ["lbcount", "rbcount", "mbcount", "xbcount", "wheel", "hwheel", "move"]
    result.mouse[key] := 0
  for i, ctl in LoadControlList()
    if (RegExMatch(ctl.Hwnd, "^sc\d+$"))
      result.keyboard[ctl.Hwnd] := 0
  return result
}

ReadCounts(file, section) {
  result := EmptyCounts()
  for i, line in StrSplit(IniRead(file, section, "", ""), "`n", "`r") {
    split := InStr(line, "=")
    if (!split)
      continue
    key := SubStr(line, 1, split - 1), value := Max(0, SubStr(line, split + 1) + 0)
    if (RegExMatch(key, "^sc\d+$") || key = "keystrokes")
      result.keyboard[key] := value
    else if (result.mouse.HasKey(key))
      result.mouse[key] := value
  }
  return result
}

IndexHistoryFile(file) {
  global DataFiles
  for i, section in StrSplit(IniRead(file), "`n", "`r")
    if (RegExMatch(section, "^\d{8}$"))
      DataFiles[section] := file
}

ArchiveHistory(cutoff, source := "KMCounter.ini", directory := "history") {
  global ArchiveWarning
  groups := {}
  for i, section in StrSplit(IniRead(source), "`n", "`r") {
    if (!RegExMatch(section, "^\d{8}$") || section >= cutoff)
      continue
    year := SubStr(section, 1, 4)
    if (!IsObject(groups[year]))
      groups[year] := []
    groups[year].Push(section)
  }
  if (!groups.Count())
    return true
  FileCreateDir, %directory%
  ; Keep the pre-migration input for recovery; never overwrite an existing backup.
  if (!FileExist(source ".pre-archive.bak")) {
    FileCopy, %source%, % source ".pre-archive.bak", 0
    if (ErrorLevel) {
      ArchiveWarning := Tr("归档备份失败，明细仍保留在主文件", "Archive backup failed; details remain in the main file")
      return false
    }
  }
  for year, sections in groups {
    target := directory "\" year ".ini", pending := target ".pending"
    if (FileExist(target)) {
      FileCopy, %target%, %pending%, 1
      if (ErrorLevel)
        return false
    } else {
      ; UTF-16 BOM makes Windows INI APIs preserve Unicode.
      file := FileOpen(pending, "w", "UTF-16")
      if (!IsObject(file))
        return false
      file.Write(""), file.Close()
    }
    for i, section in sections {
      body := IniRead(source, section)
      IniWrite, %body%, %pending%, %section%
      if (ErrorLevel || IniRead(pending, section) != body) {
        ArchiveWarning := Tr("归档校验失败，明细仍保留在主文件", "Archive verification failed; details remain in the main file")
        return false
      }
    }
    ; Flush and atomically replace the yearly file before removing any source section.
    absolute := A_WorkingDir "\" pending
    if (RegExMatch(pending, "i)^[A-Z]:\\"))
      absolute := pending
    DllCall("WritePrivateProfileString", "Ptr", 0, "Ptr", 0, "Ptr", 0, "Str", absolute)
    if (!DllCall("MoveFileEx", "Str", pending, "Str", target, "UInt", 9)) {
      ArchiveWarning := Tr("归档写入失败，明细仍保留在主文件", "Archive write failed; details remain in the main file")
      return false
    }
    for i, section in sections {
      ; A retry overwrites the same date snapshot, so crashes cannot double-count it.
      IniDelete, %source%, %section%
    }
  }
  return true
}

RangeStart(index, day) {
  if (index = 2) {
    FormatTime, weekday, %day%, WDay
    return EnvAdd(day, -Mod(weekday + 5, 7), "Days", 1, 8)
  }
  if (index = 3)
    return SubStr(day, 1, 6) "01"
  if (index = 4)
    return SubStr(day, 1, 4) "0101"
  return day
}

AggregateRange(index, day) {
  global mouse, keyboard, DataFiles, DayCache
  result := EmptyCounts(), result.days := 1, result.start := RangeStart(index, day)
  if (index = 5) {
    result.mouse := mouse.total.Clone(), result.keyboard := keyboard.total.Clone()
    return result
  }
  AddCounts(result, {mouse:mouse[day], keyboard:keyboard[day]})
  for savedDay, file in DataFiles {
    if (savedDay < result.start || savedDay >= day)
      continue
    if (!DayCache.HasKey(savedDay))
      DayCache[savedDay] := ReadCounts(file, savedDay)
    AddCounts(result, DayCache[savedDay])
    result.days += 1
  }
  return result
}

AddCounts(ByRef target, source) {
  for i, category in ["mouse", "keyboard"]
    for key, value in source[category]
      target[category][key] := (target[category][key] + 0) + value
}

BuildDemoData() {
  global today, keyboard, mouse, DataFiles, DayCache
  total := EmptyCounts()
  Loop, 45 {
    day := EnvAdd(today, 1 - A_Index, "Days", 1, 8), counts := EmptyCounts()
    for key, value in counts.keyboard {
      if (key = "keystrokes")
        continue
      sc := SubStr(key, 3) + 0
      count := Mod(sc * 19 + A_Index * 7, 15) = 0 ? 0 : Round(10 ** (Mod(sc * 31 + A_Index, 41) / 10))
      counts.keyboard[key] := count
      counts.keyboard.keystrokes += count
    }
    counts.mouse := {move:125.8 * A_Index, lbcount:352 * A_Index, rbcount:72, mbcount:5, xbcount:8, wheel:185, hwheel:0}
    if (day = today)
      keyboard[today] := counts.keyboard, mouse[today] := counts.mouse
    else
      DayCache[day] := counts, DataFiles[day] := "demo"
    AddCounts(total, counts)
  }
  keyboard.total := total.keyboard, mouse.total := total.mouse
}

NonNull_Ret(value, fallback, minimum := 0) {
  return value = "" ? fallback : Max(minimum, value)
}

SaveData() {
  global DemoMode, DataStorageDays, devicecaps, layout, mouse, keyboard, today, PaletteIndex, ThemeIndex, AppLanguage, ArchiveWarning, DarkPaletteIndex, LightPaletteIndex
  if (DemoMode)
    return true
  Critical
  pending := "KMCounter.ini.pending"
  if (!PrepareSnapshot("KMCounter.ini", pending)) {
    ArchiveWarning := Tr("保存失败：原统计文件已保留", "Save failed; the original statistics file is preserved")
    return false
  }
  sections := {history:{storage:DataStorageDays}, devicecaps:{w:devicecaps.w, h:devicecaps.h}
              , layout:layout, appearance:{schema:2, palette:PaletteIndex, theme:ThemeIndex, dark_palette:DarkPaletteIndex, light_palette:LightPaletteIndex, language:AppLanguage}}
  for i, day in [today, "total"] {
    sections[day] := keyboard[day].Clone()
    for key, value in mouse[day]
      sections[day][key] := value
  }
  for section, values in sections {
    body := ""
    for key, value in values
      body .= key "=" value "`n"
    body := RTrim(body, "`n")
    IniWrite, %body%, %pending%, %section%
    if (ErrorLevel || IniRead(pending, section) != body) {
      ArchiveWarning := Tr("保存校验失败：原统计文件已保留", "Save verification failed; the original statistics file is preserved")
      return false
    }
  }
  DllCall("WritePrivateProfileString", "Ptr", 0, "Ptr", 0, "Ptr", 0, "Str", A_WorkingDir "\" pending)
  if (!DllCall("MoveFileEx", "Str", pending, "Str", "KMCounter.ini", "UInt", 9)) {
    ArchiveWarning := Tr("保存失败：原统计文件已保留", "Save failed; the original statistics file is preserved")
    return false
  }
  return true
}
PrepareSnapshot(source, pending) {
  if (FileExist(source)) {
    FileCopy, %source%, %pending%, 1
    return !ErrorLevel
  }
  file := FileOpen(pending, "w", "UTF-16")
  if (!IsObject(file))
    return false
  file.Write(""), file.Close()
  return true
}

; Preserve the previous pink/mint appearances when upgrading to Dark/Light.
ReadAppearance(file := "KMCounter.ini") {
  mode := Max(1,Min(3,IniRead(file,"appearance","theme",1)+0))
  palette := Max(1,Min(4,IniRead(file,"appearance","palette",1)+0))
  if (IniRead(file,"appearance","schema",1)+0 < 2) {
    dark := mode=1 ? palette : 1
    light := mode=3 ? 2 : 1
    return {mode:mode=1 ? 1 : 2, palette:mode=1 ? dark : light, dark:dark, light:light}
  }
  mode := Min(2,mode)
  dark := Max(1,Min(4,IniRead(file,"appearance","dark_palette",mode=1 ? palette : 1)+0))
  light := Max(1,Min(4,IniRead(file,"appearance","light_palette",mode=2 ? palette : 1)+0))
  return {mode:mode, palette:mode=1 ? dark : light, dark:dark, light:light}
}
