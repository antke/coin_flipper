local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local DebugOverlay = {}
DebugOverlay.__index = DebugOverlay

function DebugOverlay.new(app)
  return setmetatable({ app = app }, DebugOverlay)
end

function DebugOverlay:draw()
  if not self.app.logger.overlayEnabled then
    return
  end

  local currentStateName = self.app.stateGraph:getCurrentName() or "none"
  local stageLabel = currentStateName == "stage" and "Stage" or "Tracked Stage"
  local stageStatusLabel = currentStateName == "stage" and "Stage Status" or "Tracked Stage Status"
  local flipsLabel = currentStateName == "stage" and "Flips Remaining" or "Tracked Flips Remaining"
  local batchLabel = currentStateName == "stage" and "Batch" or "Last Batch"

  local x = love.graphics.getWidth() - 360
  local y = 16
  local width = 344
  local height = love.graphics.getHeight() - 32

  Panel.draw(x, y, width, height, "Debug Overlay")
  local contentArea = Panel.getContentArea(x, y, width, height, "Debug Overlay")

  local lines = {
    string.format("State: %s", currentStateName),
    string.format("Seed: %s", self.app.runState and self.app.runState.seed or "n/a"),
    string.format("Round: %s", self.app.runState and self.app.runState.roundIndex or "n/a"),
    string.format("%s: %s", stageLabel, self.app.stageState and self.app.stageState.stageId or "n/a"),
    string.format("%s: %s", batchLabel, self.app.lastBatchResult and self.app.lastBatchResult.batchId or "n/a"),
    string.format("%s: %s", stageStatusLabel, self.app.stageState and self.app.stageState.stageStatus or "n/a"),
    string.format("%s: %s", flipsLabel, self.app.stageState and self.app.stageState.flipsRemaining or "n/a"),
    string.format("Loadout Key: %s", self.app:getCurrentLoadoutKey()),
    "",
    "Forced Result Queue:",
  }

  for _, line in ipairs(self.app:getPendingForcedResultLines()) do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "Stage End Evaluation:")

  for _, line in ipairs(self.app:getStageEndEvaluationLines()) do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "Last Batch:")

  local drawY = contentArea.y
  Theme.applyColor(Theme.colors.text)

  for _, line in ipairs(lines) do
    drawY = Layout.drawWrappedText(line, contentArea.x, drawY, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight)
  end

  for _, line in ipairs(self.app:getLastBatchSummaryLines(8)) do
    drawY = Layout.drawWrappedText(line, contentArea.x, drawY, contentArea.width, Theme.colors.mutedText, Theme.spacing.lineHeight)

    if drawY > y + height - Theme.spacing.lineHeight then
      break
    end
  end

  if drawY <= y + height - (Theme.spacing.lineHeight * 2) then
    drawY = Layout.drawWrappedText("Recent Logs:", contentArea.x, drawY, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight)
  end

  for _, entry in ipairs(self.app.logger:getEntries()) do
    local text = string.format("[%s] %s", entry.level, entry.message)
    drawY = Layout.drawWrappedText(text, contentArea.x, drawY, contentArea.width, Theme.colors.mutedText, Theme.spacing.lineHeight)

    if drawY > y + height - Theme.spacing.lineHeight then
      break
    end
  end
end

return DebugOverlay
