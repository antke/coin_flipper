local RunHistorySystem = require("src.systems.run_history_system")
local ShopSystem = require("src.systems.shop_system")
local Validator = require("src.core.validator")

local ShopFlowSystem = {}

local function isVisitReady(visit)
  return visit.shopSession
    and type(visit.shopSession.offerSets) == "table"
    and #visit.shopSession.offerSets > 0
    and type(visit.offers) == "table"
    and #visit.offers > 0
end

function ShopFlowSystem.createVisit(runState, stageState, metaProjection, rng, options)
  options = options or {}

  local visit = {
    runState = runState,
    stageState = stageState,
    metaProjection = metaProjection,
    rng = rng,
    shopSession = options.shopSession,
    offers = options.offers or {},
    lastGenerationTrace = options.lastGenerationTrace,
    lastPurchaseTrace = options.lastPurchaseTrace,
  }

  if not visit.shopSession then
    assert(type(options.sourceStageId) == "string" and options.sourceStageId ~= "", "Shop visit creation requires sourceStageId")
    assert(type(options.roundIndex) == "number", "Shop visit creation requires roundIndex")

    visit.shopSession = RunHistorySystem.createShopSession(
      runState,
      options.sourceStageId,
      options.roundIndex
    )
  end

  return visit
end

function ShopFlowSystem.refreshOffers(visit, reason)
  visit.offers, visit.lastGenerationTrace = ShopSystem.generateOffers(
    visit.runState,
    visit.stageState,
    visit.metaProjection,
    visit.rng
  )

  RunHistorySystem.recordShopOfferRefresh(visit.shopSession, visit.offers, visit.lastGenerationTrace, reason)

  Validator.assertRuntimeInvariants("shop_flow.refreshOffers", visit.runState, visit.stageState, {
    shopOffers = visit.offers,
    history = true,
  })

  return visit.offers, visit.lastGenerationTrace
end

function ShopFlowSystem.ensureOffers(visit)
  if visit.offers and #visit.offers > 0 then
    return visit.offers, visit.lastGenerationTrace
  end

  return ShopFlowSystem.refreshOffers(visit, "initial")
end

function ShopFlowSystem.reroll(visit)
  if not isVisitReady(visit) then
    return nil, "shop_visit_not_ready"
  end

  local rerollMode, errorMessage = ShopSystem.consumeReroll(
    visit.runState,
    visit.stageState,
    visit.metaProjection
  )

  if not rerollMode then
    Validator.assertRuntimeInvariants("shop_flow.reroll.rejected", visit.runState, visit.stageState, {
      shopOffers = visit.offers,
      history = true,
    })
    return nil, errorMessage
  end

  RunHistorySystem.recordReroll(visit.shopSession, rerollMode)
  ShopFlowSystem.refreshOffers(visit, "reroll_" .. rerollMode)

  return rerollMode
end

function ShopFlowSystem.purchase(visit, offerIndex)
  if not isVisitReady(visit) then
    return false, { reason = "shop_visit_not_ready", trace = nil }, nil
  end

  local offer = visit.offers[offerIndex]

  if not offer then
    return false, { reason = "offer_not_found", trace = nil }, nil
  end

  local ok, result = ShopSystem.purchaseOffer(
    visit.runState,
    offer,
    visit.stageState,
    visit.metaProjection
  )

  if not ok then
    visit.lastPurchaseTrace = result and result.trace or nil
    RunHistorySystem.recordPurchaseFailure(visit.shopSession, offer, result)
    Validator.assertRuntimeInvariants("shop_flow.purchase.rejected", visit.runState, visit.stageState, {
      shopOffers = visit.offers,
      history = true,
    })
    return false, result, offer
  end

  visit.lastPurchaseTrace = result.trace
  RunHistorySystem.recordPurchaseSuccess(visit.shopSession, offer, result)

  Validator.assertRuntimeInvariants("shop_flow.purchase", visit.runState, visit.stageState, {
    shopOffers = visit.offers,
    history = true,
  })

  return true, result, offer
end

function ShopFlowSystem.findOfferIndex(visit, offerType, contentId)
  for index, offer in ipairs(visit.offers or {}) do
    if not offer.purchased and offer.type == offerType and offer.contentId == contentId then
      return index, offer
    end
  end

  return nil, nil
end

function ShopFlowSystem.isVisitReady(visit)
  return isVisitReady(visit)
end

return ShopFlowSystem
