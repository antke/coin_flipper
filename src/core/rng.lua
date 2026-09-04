local RNG = {}
RNG.__index = RNG

local MODULUS = 2147483647
local MULTIPLIER = 48271

local function hashText(text)
  local hash = 0
  text = tostring(text or "")

  for index = 1, #text do
    hash = (hash * 131 + string.byte(text, index)) % MODULUS
  end

  return hash
end

function RNG.new(seed)
  local numericSeed = math.floor(tonumber(seed) or os.time())
  numericSeed = numericSeed % MODULUS

  if numericSeed <= 0 then
    numericSeed = numericSeed + MODULUS - 1
  end

  return setmetatable({ seed = numericSeed }, RNG)
end

function RNG.seedFromText(text)
  return ((hashText(text) - 1) % (MODULUS - 1)) + 1
end

function RNG.newFromText(text)
  return RNG.new(RNG.seedFromText(text))
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

function RNG:shuffle(values)
  if type(values) ~= "table" then
    return values
  end

  for index = #values, 2, -1 do
    local targetIndex = self:nextInt(1, index)
    values[index], values[targetIndex] = values[targetIndex], values[index]
  end

  return values
end

function RNG:getSeed()
  return self.seed
end

return RNG
