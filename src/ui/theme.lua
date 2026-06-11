local Colors = {
	background = { 0.08, 0.08, 0.13, 1.0 },
	screen = { 0.15, 0.14, 0.18, 1.0 },
	panel = { 0.15, 0.14, 0.18, 0.94 },
	panelRaised = { 0.16, 0.21, 0.35, 0.96 },
	panelBorder = { 0.20, 0.27, 0.44, 1.0 },

	text = { 0.96, 0.96, 0.95, 1.0 },
	mutedText = { 0.68, 0.80, 0.84, 1.0 },

	primary = { 0.94, 0.56, 0.22, 1.0 },
	accent = { 0.36, 0.57, 0.72, 1.0 },
	deepMagic = { 0.40, 0.11, 0.25, 1.0 },
	magic = { 0.93, 0.45, 0.60, 1.0 },
	warning = { 0.94, 0.56, 0.22, 1.0 },

	success = { 0.41, 0.81, 0.41, 1.0 },
	danger = { 0.79, 0.33, 0.33, 1.0 },
	shadow = { 0.08, 0.08, 0.13, 0.30 },
	outline = { 0.08, 0.08, 0.13, 0.82 },
}

Colors.highlight = Colors.magic

Colors.overlay = {
	shadow = Colors.outline,
	surface = Colors.panelRaised,
	border = Colors.accent,
}

Colors.button = {
	default = {
		fill = Colors.panel,
		border = Colors.panelBorder,
		text = Colors.text,
	},
	primary = {
		fill = Colors.primary,
		border = Colors.warning,
		text = Colors.background,
	},
	success = {
		fill = Colors.success,
		border = Colors.primary,
		text = Colors.background,
	},
	danger = {
		fill = Colors.danger,
		border = Colors.warning,
		text = Colors.text,
	},
	warning = {
		fill = Colors.warning,
		border = Colors.magic,
		text = Colors.background,
	},
	accent = {
		fill = Colors.accent,
		border = Colors.mutedText,
		text = Colors.background,
	},
}

Colors.rarity = {
	common = Colors.mutedText,
	uncommon = Colors.success,
	rare = Colors.warning,
	epic = Colors.magic,
	legendary = Colors.primary,
}

Colors.tag = {
	heads = Colors.warning,
	tails = Colors.accent,
	combo = Colors.primary,
	safety = Colors.success,
	danger = Colors.danger,
	magic = Colors.deepMagic,
}

local Theme = {
	colors = Colors,

	fontSizes = {
		title = 64,
		heading = 48,
		body = 32,
		small = 16,
		outcomeBurst = 128,
	},

	fontSizeTiers = {
		compact = { title = 64, heading = 48, body = 32, small = 16, outcomeBurst = 128 },
		standard = { title = 64, heading = 48, body = 32, small = 16, outcomeBurst = 160 },
		large = { title = 80, heading = 64, body = 48, small = 32, outcomeBurst = 192 },
		max = { title = 96, heading = 64, body = 48, small = 32, outcomeBurst = 224 },
	},

	fontFamily = "boldPixels",

	fontFamilies = {
		boldPixels = {
			path = "src/resources/fonts/BoldPixels.ttf",
			sizeScale = 1.0,
		},
		monogram = {
			path = "src/resources/fonts/monogram.ttf",
			sizeScale = 1.0,
		},
		monogramExtended = {
			path = "src/resources/fonts/monogram-extended.ttf",
			sizeScale = 1.0,
		},
		monogramExtendedItalic = {
			path = "src/resources/fonts/monogram-extended-italic.ttf",
			sizeScale = 1.0,
		},
	},

	fontPaths = {},

	outcomeBurst = {
		duration = 1.05,
		flashInDuration = 0.12,
		fadeOutDuration = 0.32,
		popScale = 1.28,
		labels = {
			[0] = "OUCH",
			[2] = "NICE",
			[3] = "SUPER",
			[4] = "JACKPOT",
			[5] = "LEGENDARY",
			default = "LEGENDARY",
			clutch = "CLUTCH",
			combo = "COMBO",
			jackpot = "JACKPOT",
			overkill = "OVERKILL",
		},
	},

	scoreFloaty = {
		duration = 1.15,
		fadeOutDuration = 0.34,
		distance = 58,
		damageDistance = 46,
		popScale = 1.34,
		outline = 3,
		fontName = "heading",
		outlineColor = { 0, 0, 0, 0.88 },
		shadowColor = { 0, 0, 0, 0.58 },
	},

	spacing = {
		screenPadding = 28,
		blockGap = 20,
		itemGap = 12,
		lineHeight = 32,
		panelPadding = 18,
		panelTitleHeight = 32,
		statusPadding = 16,
	},

	spacingTiers = {
		compact = {
			screenPadding = 28,
			blockGap = 20,
			itemGap = 12,
			lineHeight = 32,
			panelPadding = 18,
			panelTitleHeight = 32,
			statusPadding = 16,
		},
		standard = {
			screenPadding = 35,
			blockGap = 25,
			itemGap = 15,
			lineHeight = 32,
			panelPadding = 23,
			panelTitleHeight = 48,
			statusPadding = 20,
		},
		large = {
			screenPadding = 42,
			blockGap = 30,
			itemGap = 18,
			lineHeight = 48,
			panelPadding = 27,
			panelTitleHeight = 64,
			statusPadding = 24,
		},
		max = {
			screenPadding = 56,
			blockGap = 40,
			itemGap = 24,
			lineHeight = 48,
			panelPadding = 36,
			panelTitleHeight = 64,
			statusPadding = 32,
		},
	},

	componentMetricTiers = {
		compact = { buttonHeight = 48, cardMinWidth = 82, cardMaxWidth = 190 },
		standard = { buttonHeight = 48, cardMinWidth = 103, cardMaxWidth = 238 },
		large = { buttonHeight = 64, cardMinWidth = 123, cardMaxWidth = 285 },
		max = { buttonHeight = 80, cardMinWidth = 164, cardMaxWidth = 380 },
	},

	componentMetrics = {
		buttonHeight = 48,
		cardMinWidth = 82,
		cardMaxWidth = 190,
	},

	uiScale = 1,
}

function Theme.applyViewportMetrics(metrics)
	local tier = metrics and metrics.tier or "standard"
	Theme.fontSizes = Theme.fontSizeTiers[tier]
	Theme.spacing = Theme.spacingTiers[tier]
	Theme.componentMetrics = Theme.componentMetricTiers[tier]
	Theme.uiScale = metrics and metrics.scale or 1
end

function Theme.getFontConfig()
	return Theme.fontFamilies[Theme.fontFamily]
end

function Theme.getFontPath(name)
	local fontConfig = Theme.getFontConfig()
	return Theme.fontPaths[name] or fontConfig.path
end

function Theme.getFontSize(_, baseSize)
	local fontConfig = Theme.getFontConfig()
	return math.max(1, math.floor((baseSize or 1) * fontConfig.sizeScale + 0.5))
end

function Theme.scale(value)
	return math.floor((value or 0) * (Theme.uiScale or 1) + 0.5)
end

function Theme.applyColor(color)
	love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
end

function Theme.clearColor(color)
	love.graphics.clear(color[1], color[2], color[3], color[4] or 1.0)
end

return Theme
