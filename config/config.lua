return {
  screenWidth = 120,
  screenHeight = 40,
  tickInterval = 0.1,

  fluxInterval = 1,
  reactorInterval = 1,
  reactorScanInterval = 30,
  rodRefreshInterval = 60,
  rodHardSyncDifference = 120,
  meInterval = 5,
  playerInterval = 1,

  reactorTempWarn = 950,
  expectedReactors = 6,

  minFluidDrop = 1000000,
  fluidItemName = "ae2fc:fluid_drop",
  fluidLabel = "low_temperature_refrigerant",
  fluidLowConfirmations = 5,
  fluidMaxValidValue = 1000000000000,

  reactorCoolantStopRatio = 0.68,
  reactorCoolantRestoreRatio = 0.80,
  autoRestartReactors = true,

  rodWarningSeconds = 86400,
  rodCriticalSeconds = 21600,

  dataDir = "/home/data",
  githubBase = "https://raw.githubusercontent.com/CihlaMaximum/ReactorN/refs/heads/main/",
  debugUser = "Delly",
  tableTitle = "Мониторинг",
  chatTitle = "Оператор",

  -- История и прогноз хладагента
  coolantHistorySize = 300,
  coolantForecastMinConsumption = 1,

  -- Пороговые уведомления по прогнозу хладагента, секунды
  coolantNotify12h = 43200,
  coolantNotify3h = 10800,
  coolantNotify1h = 3600,
  coolantCriticalRepeat = 600,

  -- Пороговые уведомления по стержням, секунды
  rodNotify12h = 43200,
  rodNotify6h = 21600,
  rodNotify3h = 10800,
  rodNotify1h = 3600,
  rodCriticalRepeat = 600
}
