local RNG = {}
RNG.__index = RNG

local MODULUS = 2147483647
local MULTIPLIER = 48271

function RNG.new(seed)
  local numericSeed = math.floor(tonumber(seed) or os.time())
  numericSeed = numericSeed % MODULUS

  if numericSeed <= 0 then
    numericSeed = numericSeed + MODULUS - 1
  end

  return setmetatable({ seed = numericSeed }, RNG)
end

function RNG:nextFloat()
  self.seed = (self.seed * MULTIPLIER) % MODULUS
  return self.seed / MODULUS
end

function RNG:nextInt(minimum, maximum)
  local roll = self:nextFloat()
  return minimum + math.floor(roll * ((maximum - minimum) + 1))
end

function RNG:choose(values)
  if not values or #values == 0 then
    return nil, nil
  end

  local index = self:nextInt(1, #values)
  return values[index], index
end

function RNG:getSeed()
  return self.seed
end

return RNG
