local Coins = require("src.content.coins")
local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local ShopActions = {}

local SHOP_OPS = {
  add_shop_offer = true,
  adjust_shop_price = true,
  block_purchase = true,
  add_shop_message = true,
  mark_shop_offer_purchased = true,
  record_purchase = true,
  add_shop_rerolls = true,
}

local function ensureShopContext(context)
  context.shopOffers = context.shopOffers or {}
  context.shopMessages = context.shopMessages or {}
end

local function cloneActionForTrace(action)
  local tracedAction = Utils.clone(action)
  tracedAction._trace = tracedAction._trace or nil
  return tracedAction
end

function ShopActions.isShopOp(op)
  return SHOP_OPS[op] == true
end

function ShopActions.validate(action)
  if action.op == "add_shop_rerolls" then
    if not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
      return false, "add_shop_rerolls requires integer amount"
    end

    return true
  end

  if action.op == "add_shop_offer" then
    if action.offerType ~= "coin" and action.offerType ~= "trick" and action.offerType ~= "upgrade" then
      return false, "add_shop_offer requires offerType=coin|trick"
    end

    if type(action.contentId) ~= "string" or action.contentId == "" then
      return false, "add_shop_offer requires contentId"
    end

    if action.price ~= nil and type(action.price) ~= "number" then
      return false, "add_shop_offer price must be numeric"
    end

    if action.price ~= nil and action.price < 0 then
      return false, "add_shop_offer price must be non-negative"
    end

    local definition = action.offerType == "coin" and Coins.getById(action.contentId) or Upgrades.getById(action.contentId)

    if not definition then
      return false, string.format("add_shop_offer references unknown %s %s", action.offerType, tostring(action.contentId))
    end
  elseif action.op == "adjust_shop_price" then
    if type(action.delta) ~= "number" then
      return false, "adjust_shop_price requires numeric delta"
    end

    if action.offerType ~= nil and action.offerType ~= "coin" and action.offerType ~= "trick" and action.offerType ~= "upgrade" then
      return false, "adjust_shop_price offerType must be coin|trick"
    end

    if action.contentId ~= nil and (type(action.contentId) ~= "string" or action.contentId == "") then
      return false, "adjust_shop_price contentId must be non-empty string"
    end

    if action.rarity ~= nil and (type(action.rarity) ~= "string" or action.rarity == "") then
      return false, "adjust_shop_price rarity must be non-empty string"
    end
  elseif action.op == "block_purchase" then
    if action.reason ~= nil and type(action.reason) ~= "string" then
      return false, "block_purchase reason must be a string"
    end
  elseif action.op == "add_shop_message" then
    if type(action.message) ~= "string" then
      return false, "add_shop_message requires a message"
    end
  elseif action.op == "record_purchase" then
    if action.purchaseType ~= "coin" and action.purchaseType ~= "trick" and action.purchaseType ~= "upgrade" then
      return false, "record_purchase requires purchaseType=coin|trick"
    end

    if type(action.contentId) ~= "string" or action.contentId == "" then
      return false, "record_purchase requires contentId"
    end

    if type(action.price) ~= "number" then
      return false, "record_purchase requires numeric price"
    end

    if action.price < 0 then
      return false, "record_purchase price must be non-negative"
    end

    if action.purchaseType == "coin" and not Coins.getById(action.contentId) then
      return false, string.format("record_purchase references unknown coin %s", tostring(action.contentId))
    end

    if (action.purchaseType == "trick" or action.purchaseType == "upgrade") and not Upgrades.getById(action.contentId) then
      return false, string.format("record_purchase references unknown Trick %s", tostring(action.contentId))
    end
  end

  return true
end

function ShopActions.apply(runState, context, action)
  if action.op == "add_shop_rerolls" then
    runState.shopRerollsRemaining = math.max(0, (runState.shopRerollsRemaining or 0) + action.amount)
  elseif action.op == "add_shop_offer" then
    ensureShopContext(context)

    local canonicalOfferType = action.offerType == "upgrade" and "trick" or action.offerType
    local definition = canonicalOfferType == "coin" and Coins.getById(action.contentId) or Upgrades.getById(action.contentId)

    if definition then
      local ownedList = canonicalOfferType == "coin" and runState.collectionCoinIds or (runState.ownedTrickIds or runState.ownedUpgradeIds)
      local alreadyOffered = false

      for _, offer in ipairs(context.shopOffers) do
        if offer.contentId == action.contentId then
          alreadyOffered = true
          break
        end
      end

      local grantable = true

      if canonicalOfferType == "trick" then
        grantable = Upgrades.canGrantUpgrade(ownedList, action.contentId)
      else
        grantable = not Utils.contains(ownedList, action.contentId)
      end

      if grantable and not alreadyOffered then
        table.insert(context.shopOffers, {
          type = canonicalOfferType,
          contentId = action.contentId,
          name = definition.name,
          rarity = definition.rarity,
          price = action.price or ShopContent.resolvePrice(canonicalOfferType, definition),
          purchased = false,
          injectedBy = Utils.clone(action._trace),
          tags = Utils.copyArray(definition.tags or {}),
        })
      end
    end
  elseif action.op == "adjust_shop_price" then
    ensureShopContext(context)

    local targets = {}

    if context.currentOffer then
      targets = { context.currentOffer }
    else
      targets = context.shopOffers
    end

    for _, offer in ipairs(targets) do
      local canonicalOfferType = action.offerType == "upgrade" and "trick" or action.offerType
      local canonicalCurrentType = offer.type == "upgrade" and "trick" or offer.type
      local matchesType = action.offerType == nil or canonicalCurrentType == canonicalOfferType
      local matchesContent = action.contentId == nil or offer.contentId == action.contentId
      local matchesRarity = action.rarity == nil or offer.rarity == action.rarity

      if matchesType and matchesContent and matchesRarity then
        offer.price = math.max(0, (offer.price or 0) + action.delta)
        offer.priceAdjustments = offer.priceAdjustments or {}
        table.insert(offer.priceAdjustments, cloneActionForTrace(action))
      end
    end
  elseif action.op == "block_purchase" then
    context.purchaseBlocked = true
    context.purchaseBlockReason = action.reason or "purchase_blocked"
  elseif action.op == "add_shop_message" then
    ensureShopContext(context)
    table.insert(context.shopMessages, action.message)
  elseif action.op == "mark_shop_offer_purchased" then
    if context.currentOffer then
      context.currentOffer.purchased = true
    end
  elseif action.op == "record_purchase" then
    table.insert(runState.history.purchases, {
      type = action.purchaseType == "upgrade" and "trick" or action.purchaseType,
      contentId = action.contentId,
      price = action.price,
    })
  else
    return false
  end

  return true
end

return ShopActions
