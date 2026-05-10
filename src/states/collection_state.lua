local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Coins = require("src.content.coins")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local Layout = require("src.ui.layout")
local MetaUpgrades = require("src.content.meta_upgrades")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local CollectionState = {}
CollectionState.__index = CollectionState

local CATEGORIES = {
  { id = "coins", label = "Coins" },
  { id = "upgrades", label = "Upgrades" },
  { id = "meta_upgrades", label = "Meta Upgrades" },
}

local ENTRY_BUTTON_HEIGHT = 30
local ENTRY_BUTTON_GAP = 6
local SCROLL_BUTTON_HEIGHT = 24

local function getVisibleRowCount(height)
  return math.max(1, math.floor((height + ENTRY_BUTTON_GAP) / (ENTRY_BUTTON_HEIGHT + ENTRY_BUTTON_GAP)))
end

local function buildUnlockSources(unlockField)
  local sources = {}

  for _, definition in ipairs(MetaUpgrades.getAll()) do
    for _, contentId in ipairs(definition[unlockField] or {}) do
      sources[contentId] = sources[contentId] or {}
      table.insert(sources[contentId], definition.name)
    end
  end

  for _, names in pairs(sources) do
    table.sort(names)
  end

  return sources
end

local COIN_UNLOCK_SOURCES = buildUnlockSources("unlockCoinIds")
local UPGRADE_UNLOCK_SOURCES = buildUnlockSources("unlockUpgradeIds")

function CollectionState.new()
  return setmetatable({
    categoryIndex = 1,
    selectedIndex = 1,
    scrollOffset = 1,
    categoryButtons = {},
    entryButtons = {},
    actionButtons = {},
    returnState = "menu",
  }, CollectionState)
end

function CollectionState:getCategory()
  return CATEGORIES[self.categoryIndex]
end

function CollectionState:getBackLabel()
  return self.returnState == "meta" and "Back to Meta" or "Back to Menu"
end

function CollectionState:getBackEvent()
  return self.returnState == "meta" and "back_to_meta" or "back_to_menu"
end

function CollectionState:getEntries(app)
  local category = self:getCategory()

  if category.id == "coins" then
    local entries = {}

    for _, definition in ipairs(Coins.getAll()) do
      local unlocked = Coins.isUnlocked(definition, app.metaState.unlockedCoinIds)
      local unlockSource = definition.unlockedByDefault ~= false
        and "Available by default"
        or (#(COIN_UNLOCK_SOURCES[definition.id] or {}) > 0 and ("Unlock via: " .. table.concat(COIN_UNLOCK_SOURCES[definition.id], ", ")) or "Unlock through progression")

      table.insert(entries, {
        id = definition.id,
        name = definition.name,
        status = unlocked and "Unlocked" or "Locked",
        detailLines = {
          definition.description,
          "",
          string.format("Rarity: %s", definition.rarity or "unknown"),
          string.format("Tags: %s", table.concat(definition.tags or {}, ", ")),
          string.format("Status: %s", unlocked and "Unlocked" or "Locked"),
          unlockSource,
        },
      })
    end

    return entries
  end

  if category.id == "upgrades" then
    local entries = {}

    for _, definition in ipairs(Upgrades.getAll()) do
      local unlocked = Upgrades.isUnlocked(definition, app.metaState.unlockedUpgradeIds)
      local unlockSource = definition.unlockedByDefault ~= false
        and "Available by default"
        or (#(UPGRADE_UNLOCK_SOURCES[definition.id] or {}) > 0 and ("Unlock via: " .. table.concat(UPGRADE_UNLOCK_SOURCES[definition.id], ", ")) or "Unlock through progression")

      table.insert(entries, {
        id = definition.id,
        name = definition.name,
        status = unlocked and "Unlocked" or "Locked",
        detailLines = {
          definition.description,
          "",
          string.format("Rarity: %s", definition.rarity or "unknown"),
          string.format("Tags: %s", table.concat(definition.tags or {}, ", ")),
          string.format("Status: %s", unlocked and "Unlocked" or "Locked"),
          unlockSource,
        },
      })
    end

    return entries
  end

  local entries = {}
  for _, definition in ipairs(MetaUpgrades.getAll()) do
    local purchased = Utils.contains(app.metaState.purchasedMetaUpgradeIds, definition.id)
    local detailLines = {
      definition.description,
      "",
      string.format("Cost: %d meta point(s)", definition.cost or 0),
      string.format("Status: %s", purchased and "Purchased" or "Available"),
      string.format("Tags: %s", table.concat(definition.tags or {}, ", ")),
    }

    if #(definition.unlockCoinIds or {}) > 0 or #(definition.unlockUpgradeIds or {}) > 0 then
      table.insert(detailLines, "")
      table.insert(detailLines, "Unlocks:")

      for _, coinId in ipairs(definition.unlockCoinIds or {}) do
        table.insert(detailLines, "- Coin: " .. app:getCoinName(coinId))
      end

      for _, upgradeId in ipairs(definition.unlockUpgradeIds or {}) do
        table.insert(detailLines, "- Upgrade: " .. app:getUpgradeName(upgradeId))
      end
    end

    local effectLines = app:getEffectiveValueLines(EffectiveValueSystem.getDefinitionEffectiveValues(definition))
    if #effectLines > 0 and not (#effectLines == 1 and effectLines[1] == "No persistent run modifiers yet.") then
      table.insert(detailLines, "")
      table.insert(detailLines, "Run effect:")
      for _, line in ipairs(effectLines) do
        table.insert(detailLines, "- " .. line)
      end
    end

    table.insert(entries, {
      id = definition.id,
      name = definition.name,
      status = purchased and "Purchased" or "Available",
      detailLines = detailLines,
    })
  end

  return entries
end

function CollectionState:getSummaryLines(app)
  local unlockedCoinCount = #(Coins.getUnlockedIds(app.metaState.unlockedCoinIds or {}) or {})
  local unlockedUpgradeCount = #(Upgrades.getUnlockedIds(app.metaState.unlockedUpgradeIds or {}) or {})
  return {
    string.format("Unlocked Coins: %d/%d", unlockedCoinCount, #(Coins.getAll() or {})),
    string.format("Unlocked Upgrades: %d/%d", unlockedUpgradeCount, #(Upgrades.getAll() or {})),
    string.format("Purchased Meta Upgrades: %d/%d", #(app.metaState.purchasedMetaUpgradeIds or {}), #(MetaUpgrades.getAll() or {})),
    string.format("Viewing: %s", self:getCategory().label),
    "Use 1/2/3 or Left/Right to change category.",
    "Use Up/Down or click entries to inspect details.",
    string.format("Press Esc or Backspace, or click %s, to leave the compendium.", self:getBackLabel()),
  }
end

function CollectionState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height, { statusHeight = 28 })
  local topY = 108
  local summaryHeight = 138
  local tabsY = topY + summaryHeight + gap
  local tabsHeight = 42
  local contentY = tabsY + tabsHeight + gap
  local contentHeight = math.max(260, footerMetrics.contentBottomY - contentY)
  local listWidth = math.floor((width - (padding * 2) - gap) * 0.40)
  local detailWidth = width - (padding * 2) - gap - listWidth

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    footerMetrics = footerMetrics,
    summary = { x = padding, y = topY, width = width - (padding * 2), height = summaryHeight },
    tabs = { x = padding, y = tabsY, width = width - (padding * 2), height = tabsHeight },
    list = { x = padding, y = contentY, width = listWidth, height = contentHeight },
    detail = { x = padding + listWidth + gap, y = contentY, width = detailWidth, height = contentHeight },
  }
end

function CollectionState:clampSelection(app)
  local entries = self:getEntries(app)
  self.selectedIndex = math.max(1, math.min(self.selectedIndex, math.max(1, #entries)))
end

function CollectionState:clampScroll(app, visibleRows)
  local entries = self:getEntries(app)
  local maxOffset = math.max(1, #entries - visibleRows + 1)
  self.scrollOffset = math.max(1, math.min(self.scrollOffset, maxOffset))
end

function CollectionState:ensureSelectionVisible(app, visibleRows)
  self:clampScroll(app, visibleRows)
  if self.selectedIndex < self.scrollOffset then
    self.scrollOffset = self.selectedIndex
  elseif self.selectedIndex > (self.scrollOffset + visibleRows - 1) then
    self.scrollOffset = self.selectedIndex - visibleRows + 1
  end
  self:clampScroll(app, visibleRows)
end

function CollectionState:selectCategory(app, index)
  self.categoryIndex = math.max(1, math.min(index, #CATEGORIES))
  self.selectedIndex = 1
  self.scrollOffset = 1
  self:clampSelection(app)
  return true
end

function CollectionState:selectEntry(app, index)
  local entries = self:getEntries(app)
  self.selectedIndex = math.max(1, math.min(index, math.max(1, #entries)))
  self:ensureSelectionVisible(app, self.visibleRows or 1)
  return true
end

function CollectionState:scrollEntries(app, direction)
  local entries = self:getEntries(app)
  local visibleRows = self.visibleRows or 1
  self.scrollOffset = self.scrollOffset + direction
  self:clampScroll(app, visibleRows)

  local newSelection = self.scrollOffset
  if direction > 0 then
    newSelection = math.min(#entries, self.scrollOffset + visibleRows - 1)
  end

  self.selectedIndex = math.max(1, math.min(newSelection, math.max(1, #entries)))
  return true
end

function CollectionState:buildCategoryButtons(app, area)
  local gap = Theme.spacing.itemGap
  local buttonWidth = math.floor((area.width - (gap * (#CATEGORIES - 1))) / #CATEGORIES)
  local buttons = {}
  for index, category in ipairs(CATEGORIES) do
    table.insert(buttons, {
      x = area.x + ((index - 1) * (buttonWidth + gap)),
      y = area.y,
      width = buttonWidth,
      height = area.height,
      label = category.label,
      variant = index == self.categoryIndex and "primary" or "default",
      focused = index == self.categoryIndex,
      onClick = function()
        return self:selectCategory(app, index)
      end,
    })
  end
  self.categoryButtons = buttons
  return buttons
end

function CollectionState:buildEntryButtons(app, area)
  local entries = self:getEntries(app)
  local buttons = {}
  local currentY = area.y
  local availableHeight = area.height
  local overflow = #entries > getVisibleRowCount(area.height)

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = currentY,
      width = area.width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Up",
      variant = "warning",
      disabled = self.scrollOffset <= 1,
      onClick = function()
        return self:scrollEntries(app, -1)
      end,
    })
    currentY = currentY + SCROLL_BUTTON_HEIGHT + ENTRY_BUTTON_GAP
    availableHeight = availableHeight - ((SCROLL_BUTTON_HEIGHT + ENTRY_BUTTON_GAP) * 2)
  end

  local visibleRows = getVisibleRowCount(availableHeight)
  self.visibleRows = visibleRows
  self:ensureSelectionVisible(app, visibleRows)
  local startIndex = self.scrollOffset
  local endIndex = math.min(#entries, startIndex + visibleRows - 1)

  for index = startIndex, endIndex do
    local entry = entries[index]
    table.insert(buttons, {
      x = area.x,
      y = currentY,
      width = area.width,
      height = ENTRY_BUTTON_HEIGHT,
      label = string.format("%s [%s]", entry.name, entry.status),
      variant = index == self.selectedIndex and "primary" or "default",
      focused = index == self.selectedIndex,
      onClick = function()
        return self:selectEntry(app, index)
      end,
    })
    currentY = currentY + ENTRY_BUTTON_HEIGHT + ENTRY_BUTTON_GAP
  end

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = area.y + area.height - SCROLL_BUTTON_HEIGHT,
      width = area.width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Down",
      variant = "warning",
      disabled = endIndex >= #entries,
      onClick = function()
        return self:scrollEntries(app, 1)
      end,
    })
  end

  self.entryButtons = buttons
  return buttons
end

function CollectionState:buildButtons(app)
  local width = love.graphics.getWidth()
  local footerMetrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 240
  local buttonHeight = footerMetrics.buttonHeight
  local x = math.floor((width - buttonWidth) / 2)

  self.actionButtons = {
    {
      x = x,
      y = footerMetrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = self:getBackLabel(),
      variant = "warning",
      onClick = function()
        return app.stateGraph:request(self:getBackEvent())
      end,
    },
  }

  return self.actionButtons
end

function CollectionState:enter(app, payload)
  self.returnState = payload and payload.returnState == "meta" and "meta" or "menu"
  self.selectedIndex = 1
  self.scrollOffset = 1
  self:clampSelection(app)
end

function CollectionState:keypressed(app, key)
  if key == "escape" or key == "backspace" then
    app.stateGraph:request(self:getBackEvent())
    return
  end

  if key == "left" then
    self:selectCategory(app, self.categoryIndex - 1)
    return
  end

  if key == "right" then
    self:selectCategory(app, self.categoryIndex + 1)
    return
  end

  if key == "1" then
    self:selectCategory(app, 1)
    return
  end

  if key == "2" then
    self:selectCategory(app, 2)
    return
  end

  if key == "3" then
    self:selectCategory(app, 3)
    return
  end

  if key == "up" then
    self:selectEntry(app, self.selectedIndex - 1)
    return
  end

  if key == "down" then
    self:selectEntry(app, self.selectedIndex + 1)
    return
  end
end

function CollectionState:wheelmoved(app, _, y)
  if y == 0 then
    return
  end

  local mouseX, mouseY = love.mouse.getPosition()
  local layout = self:getLayout(app)
  local listContent = Panel.getContentArea(layout.list.x, layout.list.y, layout.list.width, layout.list.height, self:getCategory().label)

  if not Button.containsPoint({
    x = listContent.x,
    y = listContent.y,
    width = listContent.width,
    height = listContent.height,
  }, mouseX, mouseY) then
    return
  end

   local visibleRows = getVisibleRowCount(listContent.height)
   if #self:getEntries(app) > visibleRows then
     visibleRows = getVisibleRowCount(listContent.height - ((SCROLL_BUTTON_HEIGHT + ENTRY_BUTTON_GAP) * 2))
   end
   self.visibleRows = visibleRows

  self:scrollEntries(app, y > 0 and -1 or 1)
end

function CollectionState:draw(app)
  local layout = self:getLayout(app)
  local summaryLines = self:getSummaryLines(app)
  local entries = self:getEntries(app)
  local selected = entries[self.selectedIndex]
  local detailLines = selected and selected.detailLines or { "No entry selected." }

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Collection", 62, app.fonts.title, Theme.colors.text)
  love.graphics.setFont(app.fonts.heading)
  Layout.centeredText(self:getCategory().label, 100, app.fonts.heading, Theme.colors.accent)

  Panel.draw(layout.summary.x, layout.summary.y, layout.summary.width, layout.summary.height, "Progress")
  Panel.draw(layout.list.x, layout.list.y, layout.list.width, layout.list.height, self:getCategory().label)
  Panel.draw(layout.detail.x, layout.detail.y, layout.detail.width, layout.detail.height, "Details")

  local summaryContent = Panel.getContentArea(layout.summary.x, layout.summary.y, layout.summary.width, layout.summary.height, "Progress")
  local tabsButtons = self:buildCategoryButtons(app, layout.tabs)
  local listContent = Panel.getContentArea(layout.list.x, layout.list.y, layout.list.width, layout.list.height, self:getCategory().label)
  local detailContent = Panel.getContentArea(layout.detail.x, layout.detail.y, layout.detail.width, layout.detail.height, "Details")

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(summaryLines, summaryContent.x, summaryContent.y, summaryContent.width, Theme.colors.text, Theme.spacing.lineHeight, summaryContent.height)
  Button.drawButtons(tabsButtons, love.mouse.getX(), love.mouse.getY())
  Button.drawButtons(self:buildEntryButtons(app, listContent), love.mouse.getX(), love.mouse.getY())
  local detailTextY = detailContent.y
  local detailTextHeight = detailContent.height

  if self:getCategory().id == "coins" and selected then
    local coinDefinition = Coins.getById(selected.id)
    local artSize = math.min(128, math.max(72, math.floor(detailContent.width * 0.22)))
    CoinArt.draw(coinDefinition or selected.id, detailContent.x, detailContent.y, artSize, {
      selected = selected.status == "Unlocked",
      alpha = selected.status == "Unlocked" and 1.0 or 0.45,
      tilt = -0.06,
    })

    love.graphics.setFont(app.fonts.heading)
    Theme.applyColor(Theme.colors.text)
    love.graphics.print(selected.name, detailContent.x + artSize + Theme.spacing.itemGap, detailContent.y + 6)
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.print(selected.status, detailContent.x + artSize + Theme.spacing.itemGap, detailContent.y + 34)

    detailTextY = detailContent.y + artSize + Theme.spacing.itemGap
    detailTextHeight = detailContent.height - artSize - Theme.spacing.itemGap
  end

  Layout.drawWrappedLines(detailLines, detailContent.x, detailTextY, detailContent.width, Theme.colors.text, Theme.spacing.lineHeight, detailTextHeight)
  Button.drawButtons(self:buildButtons(app), love.mouse.getX(), love.mouse.getY())
end

function CollectionState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)
  local listContent = Panel.getContentArea(layout.list.x, layout.list.y, layout.list.width, layout.list.height, self:getCategory().label)

  if Button.handleMousePressed(self:buildCategoryButtons(app, layout.tabs), x, y) then
    return
  end

  if Button.handleMousePressed(self:buildEntryButtons(app, listContent), x, y) then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return CollectionState
