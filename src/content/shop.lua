local ShopContent = {
  rarityPrices = {
    common = 8,
    uncommon = 15,
    rare = 25,
  },
}

function ShopContent.resolvePrice(offerType, definition)
  if definition.price then
    return definition.price
  end

  local basePrice = ShopContent.rarityPrices[definition.rarity or "common"] or 4

  if offerType == "upgrade" then
    return basePrice + 1
  end

  return basePrice
end

return ShopContent
