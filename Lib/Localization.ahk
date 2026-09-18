Tr(chinese, english) {
  global AppLanguage
  return AppLanguage = "en" ? english : chinese
}

ReadAppLanguage(file := "KMCounter.ini") {
  fallback := (SubStr(A_Language, -1) = "04") ? "zh" : "en"
  saved := IniRead(file, "appearance", "language", fallback)
  return saved = "en" || saved = "zh" ? saved : fallback
}

SetDashboardLanguage(language) {
  global
  if (language != "zh" && language != "en")
    return
  AppLanguage := language
  gosub, MultiLanguage
  gosub, CreateMenu
  ApplyLanguageLabels()
  RefreshDashboard()
  if (!DemoMode)
    SaveData()
}

ApplyLanguageLabels() {
  global hWin, hSettings, DemoMode
  for i, label in [Tr("今日", "Today"), Tr("本周", "Week"), Tr("本月", "Month"), Tr("今年", "Year"), Tr("历史总计", "All time")]
    GuiControl, 1:, % "Range" i, %label%
  GuiControl, 1:, SettingsButton, % Tr("设置", "Settings")
  labels := {SettingsHeading:Tr("设置", "Settings"), RetentionLabel:Tr("主文件保留天数（更早明细按年归档）", "Active days (older data archived yearly)")
    , PaletteHeading:Tr("配色", "Color palette"), ThemeHeading:Tr("外观模式", "Appearance mode"), ThemeHint:Tr("点击预览立即应用，也可在托盘中切换", "Click a preview to apply. Also available in the tray.")
    , MonitorLabel:Tr("屏幕物理尺寸 / mm", "Display dimensions / mm"), WidthLabel:Tr("宽", "W"), HeightLabel:Tr("高", "H")
    , LayoutLabel:Tr("原始键盘布局 / px", "Keyboard layout / px"), CancelButton:Tr("取消", "Cancel"), SaveButton:Tr("保存", "Save")}
  for name, label in labels
    GuiControl, 2:, %name%, %label%
  for i, label in [Tr("键宽", "Key width"), Tr("键高", "Key height"), Tr("键间距", "Key gap"), Tr("水平距", "H gap"), Tr("垂直距", "V gap")]
    GuiControl, 2:, % "LayoutCaption" i, %label%
  Loop, 2
    GuiControl, 2:, % "ThemePreview" A_Index, % ThemeDisplayName(A_Index)
  RefreshThemePreviews()
  WinSetTitle, ahk_id %hWin%, , % "KMCounter" (DemoMode ? Tr(" · 演示数据", " · Demo") : "")
  WinSetTitle, ahk_id %hSettings%, , % Tr("设置", "Settings")
  ToolTip
}
