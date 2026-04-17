local ShopContent = {
  rarityPrices = {
    common = 3,
    uncommon = 5,
    rare = 8,
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
