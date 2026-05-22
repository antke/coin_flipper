local EconomyContent = require("src.content.economy")

local ShopContent = {}

function ShopContent.resolvePrice(offerType, definition)
  return EconomyContent.resolveOfferPrice(offerType, definition)
end

return ShopContent
