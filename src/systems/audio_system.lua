local GameConfig = require("src.app.config")

local AudioSystem = {}
AudioSystem.__index = AudioSystem

local TAU = math.pi * 2

local CUES = {
  batch_match = {
    volume = 0.22,
    cooldown = 0.04,
    sequence = {
      { wave = "sine", frequency = 660, duration = 0.06, attack = 0.004, release = 0.018 },
    },
  },
  batch_perfect = {
    volume = 0.24,
    cooldown = 0.05,
    sequence = {
      { wave = "square", frequency = 740, duration = 0.05, attack = 0.003, release = 0.012 },
      { wave = "square", frequency = 988, duration = 0.07, attack = 0.003, release = 0.018 },
    },
  },
  batch_miss = {
    volume = 0.18,
    cooldown = 0.04,
    sequence = {
      { wave = "triangle", frequency = 240, duration = 0.08, attack = 0.002, release = 0.03, glide = -30 },
    },
  },
  shop_gain = {
    volume = 0.20,
    cooldown = 0.05,
    sequence = {
      { wave = "triangle", frequency = 360, duration = 0.05, attack = 0.003, release = 0.02 },
      { wave = "triangle", frequency = 480, duration = 0.06, attack = 0.003, release = 0.02 },
    },
  },
  stage_clear = {
    volume = 0.26,
    cooldown = 0.08,
    sequence = {
      { wave = "square", frequency = 740, duration = 0.06, attack = 0.003, release = 0.018 },
      { wave = "square", frequency = 988, duration = 0.08, attack = 0.003, release = 0.022 },
    },
  },
  stage_fail = {
    volume = 0.22,
    cooldown = 0.08,
    sequence = {
      { wave = "saw", frequency = 220, duration = 0.07, attack = 0.002, release = 0.025, glide = -40 },
      { wave = "triangle", frequency = 160, duration = 0.08, attack = 0.002, release = 0.04, glide = -25 },
    },
  },
  boss_warning = {
    volume = 0.24,
    cooldown = 0.60,
    sequence = {
      { wave = "saw", frequency = 150, duration = 0.12, attack = 0.002, release = 0.04, glide = -10 },
      { wave = "square", frequency = 190, duration = 0.12, attack = 0.002, release = 0.04, glide = -12 },
    },
  },
  boss_defeat = {
    volume = 0.28,
    cooldown = 0.14,
    sequence = {
      { wave = "square", frequency = 440, duration = 0.05, attack = 0.003, release = 0.016 },
      { wave = "square", frequency = 660, duration = 0.06, attack = 0.003, release = 0.018 },
      { wave = "square", frequency = 990, duration = 0.09, attack = 0.003, release = 0.022 },
    },
  },
  shop_purchase = {
    volume = 0.22,
    cooldown = 0.05,
    sequence = {
      { wave = "square", frequency = 620, duration = 0.05, attack = 0.002, release = 0.016 },
      { wave = "triangle", frequency = 780, duration = 0.05, attack = 0.002, release = 0.018 },
    },
  },
  shop_reroll = {
    volume = 0.20,
    cooldown = 0.06,
    sequence = {
      { wave = "triangle", frequency = 300, duration = 0.04, attack = 0.002, release = 0.016 },
      { wave = "triangle", frequency = 420, duration = 0.05, attack = 0.002, release = 0.018 },
    },
  },
  meta_purchase = {
    volume = 0.20,
    cooldown = 0.06,
    sequence = {
      { wave = "sine", frequency = 700, duration = 0.05, attack = 0.003, release = 0.016 },
      { wave = "sine", frequency = 880, duration = 0.06, attack = 0.003, release = 0.02 },
    },
  },
  run_win = {
    volume = 0.26,
    cooldown = 0.20,
    sequence = {
      { wave = "square", frequency = 660, duration = 0.06, attack = 0.003, release = 0.018 },
      { wave = "square", frequency = 880, duration = 0.06, attack = 0.003, release = 0.018 },
      { wave = "square", frequency = 1100, duration = 0.10, attack = 0.003, release = 0.022 },
    },
  },
  run_loss = {
    volume = 0.20,
    cooldown = 0.20,
    sequence = {
      { wave = "triangle", frequency = 260, duration = 0.08, attack = 0.002, release = 0.025, glide = -30 },
      { wave = "triangle", frequency = 190, duration = 0.10, attack = 0.002, release = 0.04, glide = -20 },
    },
  },
}

local function hasLoveAudio()
  return type(love) == "table"
    and type(love.audio) == "table"
    and type(love.sound) == "table"
    and type(love.audio.newSource) == "function"
    and type(love.sound.newSoundData) == "function"
end

local function clampSample(value)
  if value > 1 then
    return 1
  end

  if value < -1 then
    return -1
  end

  return value
end

local function waveSample(wave, phase)
  if wave == "square" then
    return math.sin(TAU * phase) >= 0 and 1 or -1
  end

  if wave == "triangle" then
    return (2 / math.pi) * math.asin(math.sin(TAU * phase))
  end

  if wave == "saw" then
    return 2 * (phase - math.floor(phase + 0.5))
  end

  return math.sin(TAU * phase)
end

local function buildCueSource(name, definition, sampleRate)
  local totalSamples = 0

  for _, segment in ipairs(definition.sequence or {}) do
    totalSamples = totalSamples + math.max(1, math.floor((segment.duration or 0.05) * sampleRate))
  end

  local soundData = love.sound.newSoundData(totalSamples, sampleRate, 16, 1)
  local cursor = 0

  for _, segment in ipairs(definition.sequence or {}) do
    local sampleCount = math.max(1, math.floor((segment.duration or 0.05) * sampleRate))
    local attackSamples = math.max(1, math.floor((segment.attack or 0.002) * sampleRate))
    local releaseSamples = math.max(1, math.floor((segment.release or 0.018) * sampleRate))
    local startFrequency = segment.frequency or 440
    local glide = segment.glide or 0
    local amplitude = segment.amplitude or 1.0

    for sampleIndex = 0, sampleCount - 1 do
      local position = sampleIndex / sampleRate
      local progress = sampleCount > 1 and (sampleIndex / (sampleCount - 1)) or 0
      local frequency = startFrequency + (glide * progress)
      local phase = position * math.max(1, frequency)
      local envelope = 1.0

      if sampleIndex < attackSamples then
        envelope = sampleIndex / attackSamples
      elseif sampleIndex > (sampleCount - releaseSamples) then
        envelope = math.max(0, (sampleCount - sampleIndex) / releaseSamples)
      end

      local sample = waveSample(segment.wave, phase) * amplitude * envelope
      soundData:setSample(cursor + sampleIndex, clampSample(sample))
    end

    cursor = cursor + sampleCount
  end

  local source = love.audio.newSource(soundData, "static")
  source:setVolume((definition.volume or 0.2) * 0.5)
  source:setLooping(false)
  return source
end

function AudioSystem.new(options)
  local config = options or {}

  return setmetatable({
    enabled = config.enabled ~= false,
    masterVolume = config.masterVolume or GameConfig.get("audio.masterVolume", 0.45),
    sampleRate = config.sampleRate or GameConfig.get("audio.sampleRate", 22050),
    maxVoices = config.maxVoices or GameConfig.get("audio.maxVoices", 8),
    sourceCache = {},
    activeVoices = {},
    cooldowns = {},
    loadFailed = false,
  }, AudioSystem)
end

function AudioSystem:update(dt)
  for cueName, remaining in pairs(self.cooldowns) do
    local nextRemaining = remaining - dt

    if nextRemaining <= 0 then
      self.cooldowns[cueName] = nil
    else
      self.cooldowns[cueName] = nextRemaining
    end
  end

  local nextVoices = {}

  for _, voice in ipairs(self.activeVoices) do
    if voice and voice:isPlaying() then
      table.insert(nextVoices, voice)
    end
  end

  self.activeVoices = nextVoices
end

function AudioSystem:getCueDefinition(cueName)
  return CUES[cueName]
end

function AudioSystem:isAvailable()
  return self.enabled and not self.loadFailed and hasLoveAudio()
end

function AudioSystem:getBaseSource(cueName)
  local definition = self:getCueDefinition(cueName)

  if not definition or not self:isAvailable() then
    return nil
  end

  if self.sourceCache[cueName] then
    return self.sourceCache[cueName]
  end

  local ok, source = pcall(buildCueSource, cueName, definition, self.sampleRate)

  if not ok then
    self.loadFailed = true
    return nil
  end

  self.sourceCache[cueName] = source
  return source
end

function AudioSystem:playCue(cueName)
  local definition = self:getCueDefinition(cueName)

  if not definition or not self:isAvailable() then
    return false
  end

  if self.cooldowns[cueName] then
    return false
  end

  local baseSource = self:getBaseSource(cueName)

  if not baseSource then
    return false
  end

  local ok, voice = pcall(baseSource.clone, baseSource)

  if not ok or not voice then
    return false
  end

  voice:setVolume((definition.volume or 0.2) * self.masterVolume)

  if #self.activeVoices >= self.maxVoices then
    local oldest = table.remove(self.activeVoices, 1)
    if oldest then
      oldest:stop()
    end
  end

  local played = pcall(function()
    love.audio.play(voice)
  end)

  if not played then
    return false
  end

  table.insert(self.activeVoices, voice)
  self.cooldowns[cueName] = definition.cooldown or 0.05
  return true
end

return AudioSystem
