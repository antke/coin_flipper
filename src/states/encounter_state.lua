local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local EncounterState = {}
EncounterState.__index = EncounterState

local function formatEncounterError(errorMessage)
  if errorMessage == "encounter_choice_index_invalid" then
    return "That encounter option is not available."
  end

  if errorMessage == "encounter_session_unavailable" then
    return "No encounter is currently active."
  end

  if errorMessage == "encounter_choice_required" then
    return "Choose an encounter option before continuing."
  end

  if errorMessage == "encounter_choice_not_selected" then
    return "Choose an encounter option before continuing."
  end

  if errorMessage == "encounter_unavailable" or errorMessage == "encounter_session_missing" then
    return "No encounter is currently active."
  end

  if errorMessage == "encounter_choice_already_claimed" then
    return "This encounter choice has already been claimed."
  end

  return tostring(errorMessage)
end

local function selectEncounterChoice(app, index)
  local ok, result = app:selectEncounterChoice(index)

  if ok then
    local cards = app:getEncounterOptionCards()
    local choice = cards[index]
    return true, string.format("Selected encounter choice: %s.", choice and (choice.name or choice.id) or tostring(index))
  end

  return false, formatEncounterError(result)
end

local function tryContinue(app)
  if not app:canContinueEncounter() then
    return false, "Choose an encounter option before continuing."
  end

  local ok, result = app.stateGraph:request("continue")
  if ok == false then
    return false, tostring(result)
  end

  return true
end

function EncounterState.new()
  return setmetatable({
    statusMessage = "Choose one encounter option, then continue to the shop.",
    optionButtons = {},
    buttons = {},
  }, EncounterState)
end

function EncounterState:getLayout(app)
  local width, height = love.graphics.getWidth(), love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local footerMetrics = Layout.getFooterMetrics(height)
  local topY = 96
  local availableHeight = math.max(260, footerMetrics.contentBottomY - topY)
  local topHeight = math.max(150, math.floor((availableHeight - gap) * 0.4))
  local bottomY = topY + topHeight + gap
  local bottomHeight = math.max(170, footerMetrics.contentBottomY - bottomY)
  local bottomPanelWidth = math.floor((width - (padding * 2) - gap) / 2)

  return {
    width = width,
    height = height,
    padding = padding,
    gap = gap,
    footerMetrics = footerMetrics,
    topY = topY,
    topHeight = topHeight,
    topWidth = width - (padding * 2),
    bottomY = bottomY,
    bottomHeight = bottomHeight,
    bottomPanelWidth = bottomPanelWidth,
  }
end

function EncounterState:getOptionArea(app)
  local layout = self:getLayout(app)
  local topContent = Panel.getContentArea(layout.padding, layout.topY, layout.topWidth, layout.topHeight, "Special Encounter")
  local cards = app:getEncounterOptionCards()
  local buttonHeight = 40
  local gap = Theme.spacing.itemGap
  local buttonsHeight = #cards > 0 and ((#cards * buttonHeight) + (math.max(0, #cards - 1) * gap)) or 0

  return {
    x = topContent.x,
    y = topContent.y + topContent.height - buttonsHeight,
    width = topContent.width,
    height = buttonsHeight,
    buttonHeight = buttonHeight,
    gap = gap,
    cards = cards,
    topContent = topContent,
    layout = layout,
  }
end

function EncounterState:buildOptionButtons(app, area)
  local cards = area.cards or app:getEncounterOptionCards()
  local buttons = {}

  if #cards == 0 then
    self.optionButtons = buttons
    return buttons
  end

  local gap = area.gap or Theme.spacing.itemGap
  local buttonHeight = area.buttonHeight or 40
  local buttonWidth = area.width
  local x = area.x
  local y = area.y

  for _, card in ipairs(cards) do
    local optionIndex = card.index
    table.insert(buttons, {
      id = string.format("encounter_option_%d", optionIndex),
      x = x,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = string.format("%d. %s", optionIndex, card.name or card.id or string.format("Option %d", optionIndex)),
      variant = card.selected and "success" or "primary",
      focused = card.selected,
      disabled = card.claimed == true,
      onClick = function()
        local ok, message = selectEncounterChoice(app, optionIndex)
        self.statusMessage = message or self.statusMessage
        return ok
      end,
    })
    y = y + buttonHeight + gap
  end

  self.optionButtons = buttons
  return buttons
end

function EncounterState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local width = 280
  local x = math.floor((love.graphics.getWidth() - width) / 2)
  local buttons = {
    {
      id = "encounter_continue",
      x = x,
      y = metrics.buttonY,
      width = width,
      height = metrics.buttonHeight,
      label = app:getEncounterContinueLabel(),
      variant = "accent",
      disabled = not app:canContinueEncounter(),
      onClick = function()
        local ok, message = tryContinue(app)
        if message then
          self.statusMessage = message
        end
        return ok
      end,
    },
  }

  self.buttons = buttons
  return buttons
end

function EncounterState:enter(app)
  local session = app:ensureEncounterSession()

  if session and #(session.choices or {}) > 0 then
    if session.claimed == true and session.choice then
      self.statusMessage = string.format("Chosen encounter option: %s.", session.choice.label or session.choice.id)
    elseif session.selectedIndex ~= nil and session.choices[session.selectedIndex] then
      self.statusMessage = string.format("Selected encounter option: %s.", session.choices[session.selectedIndex].label or session.choices[session.selectedIndex].id)
    else
      self.statusMessage = "Choose one encounter option, then continue to the shop."
    end
  else
    self.statusMessage = "No encounter choices remain. Continue to the shop."
  end
end

function EncounterState:keypressed(app, key)
  local cards = app:getEncounterOptionCards()
  local session = app:getEncounterSession()
  local selectedIndex = session and session.selectedIndex or nil
  local numericIndex = tonumber(key)

  if #cards == 0 and (numericIndex or key == "left" or key == "up" or key == "right" or key == "down") then
    return
  end

  if numericIndex and numericIndex >= 1 then
    local ok, message = selectEncounterChoice(app, numericIndex)
    self.statusMessage = message or self.statusMessage
    return ok
  elseif key == "left" or key == "up" then
    local nextIndex = selectedIndex and math.max(1, selectedIndex - 1) or 1
    local ok, message = selectEncounterChoice(app, nextIndex)
    self.statusMessage = message or self.statusMessage
    return ok
  elseif key == "right" or key == "down" then
    local nextIndex = selectedIndex and math.min(#cards, selectedIndex + 1) or 1
    local ok, message = selectEncounterChoice(app, nextIndex)
    self.statusMessage = message or self.statusMessage
    return ok
  elseif key == "return" or key == "space" or key == "kpenter" then
    local ok, message = tryContinue(app)
    self.statusMessage = message or self.statusMessage
    return ok
  end
end

function EncounterState:draw(app)
  local optionArea = self:getOptionArea(app)
  local layout = optionArea.layout
  local width = layout.width
  local padding = layout.padding
  local gap = layout.gap

  local encounterLines = app:getEncounterLines()
  local projectedOutcome = app:getProjectedEncounterOutcome()
  local impactLines = app:getProjectedEncounterImpactLines(projectedOutcome)
  local shopLines = app:getProjectedEncounterShopPreviewLines(projectedOutcome)

  love.graphics.setColor(Theme.colors.accent)
  Layout.centeredText("Encounter", 72, app.fonts.title, Theme.colors.accent)

  Panel.draw(padding, layout.topY, layout.topWidth, layout.topHeight, "Special Encounter")
  local topContent = optionArea.topContent
  local topTextHeight = math.max(0, topContent.height - optionArea.height - Theme.spacing.itemGap)
  local topLines = {}
  for _, line in ipairs(encounterLines) do
    table.insert(topLines, line)
  end
  table.insert(topLines, "")
  table.insert(topLines, self.statusMessage)
  if #(app:getEncounterOptionCards()) > 0 then
    table.insert(topLines, "Encounter Choices:")
    table.insert(topLines, "Use number keys, arrow keys, or click to compare and choose.")

    for _, card in ipairs(app:getEncounterOptionCards()) do
      local marker = card.selected and "*" or "-"
      table.insert(topLines, string.format("%s %d. %s — %s", marker, card.index, card.name or card.id or "Unknown", card.description or "No description."))
    end
  end
  Layout.drawWrappedLines(topLines, topContent.x, topContent.y, topContent.width, Theme.colors.text, Theme.spacing.lineHeight, topTextHeight)
  Button.drawButtons(self:buildOptionButtons(app, optionArea), love.mouse.getX(), love.mouse.getY())

  Panel.draw(padding, layout.bottomY, layout.bottomPanelWidth, layout.bottomHeight, "Projected Impact")
  local projectedContent = Panel.getContentArea(padding, layout.bottomY, layout.bottomPanelWidth, layout.bottomHeight, "Projected Impact")
  Layout.drawWrappedLines(impactLines, projectedContent.x, projectedContent.y, projectedContent.width, Theme.colors.text, Theme.spacing.lineHeight, projectedContent.height)

  local shopX = padding + layout.bottomPanelWidth + gap
  Panel.draw(shopX, layout.bottomY, layout.bottomPanelWidth, layout.bottomHeight, "Shop Outlook")
  local shopContent = Panel.getContentArea(shopX, layout.bottomY, layout.bottomPanelWidth, layout.bottomHeight, "Shop Outlook")
  Layout.drawWrappedLines(shopLines, shopContent.x, shopContent.y, shopContent.width, Theme.colors.text, Theme.spacing.lineHeight, shopContent.height)

  Button.drawButtons(self:buildButtons(app), love.mouse.getX(), love.mouse.getY())
end

function EncounterState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local optionArea = self:getOptionArea(app)

  if Button.handleMousePressed(self:buildOptionButtons(app, optionArea), x, y) then
    return true
  end

  if Button.handleMousePressed(self:buildButtons(app), x, y) then
    return true
  end
end

return {
  new = function()
    return EncounterState.new()
  end,
}
