local computer = require("computer")
local event = require("event")
local term = require("term")
local config = require("config.config")
local gui = require("modules.gui")
local flux = require("modules.flux")
local me = require("modules.me")
local reactors = require("modules.reactors")
local players = require("modules.players")
local chat = require("modules.chat")
local updater = require("modules.updater")

local ok, err = gui.init()
if not ok then print(err); return end
chat.start(players)
local lastMissing = 0

while true do
  local meData = me.update()
  if meData then gui.drawME(meData.cpu) end

  local fluxData = flux.update()
  if fluxData then gui.drawFlux(fluxData) end

  local reactorData = reactors.update(
    me.getFluid(),
    false,
    me.isFluidConfirmedLow()
  )
  if reactorData then
    gui.drawReactors(reactorData)
    if reactorData.missing > 0 and reactorData.missing ~= lastMissing then
      chat.notifyMissing(reactorData.missing, reactorData.count, reactorData.count + reactorData.missing)
    end
    lastMissing = reactorData.missing
  end

  local playerData, changes = players.update()
  if playerData then gui.drawPlayers(playerData); chat.notifyChanges(changes) end
  gui.drawButtons()

  local e = {event.pull(config.tickInterval)}
  if e[1] == "touch" then
    local action = gui.hitButton(e[3], e[4])
    if action == "restart" then
      computer.shutdown(true)
    elseif action == "exit" then
      term.clear(); print("Мониторинг остановлен"); return
    elseif action == "update" then
      term.clear(); print("Обновление всего проекта...")
      local success, message = updater.run(); print(message)
      if success then computer.shutdown(true)
      else print("Нажмите любую клавишу"); event.pull("key_down"); gui.init() end
    end
  end
end
