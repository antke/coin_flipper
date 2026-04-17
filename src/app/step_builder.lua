local Utils = require("src.core.utils")

local StepBuilder = {}

local function cloneStep(step)
  return Utils.clone(step)
end

local function cloneStepList(steps)
  local cloned = {}

  for _, step in ipairs(steps or {}) do
    table.insert(cloned, cloneStep(step))
  end

  return cloned
end

local function appendSteps(target, steps)
  for _, step in ipairs(steps or {}) do
    table.insert(target, cloneStep(step))
  end

  return target
end

local function hasTerminalStep(steps)
  for _, step in ipairs(steps or {}) do
    if step.terminal == true then
      return true
    end
  end

  return false
end

local function buildInsertedFlow(insertedSteps, defaultSteps)
  local steps = cloneStepList(insertedSteps)

  if not hasTerminalStep(steps) then
    appendSteps(steps, defaultSteps)
  end

  return steps
end

local function createMacroContext(currentStateName, transitionPayload, app)
  if app and app.buildMacroContext then
    return app:buildMacroContext(currentStateName, transitionPayload)
  end

  return {
    currentStateName = currentStateName,
    event = transitionPayload and transitionPayload.event or nil,
    insertedSteps = {},
    postResultDestinationState = "summary",
  }
end

local RULES = {
  {
    from = "boot",
    event = "boot_complete",
    build = function()
      return {
        { type = "state", state = "menu" },
      }
    end,
  },
  {
    from = "menu",
    event = "continue_run",
    build = function(context)
      if not context.continueRunState then
        return {}
      end

      return {
        { type = "action", action = "resume_run" },
        { type = "state", state = context.continueRunState, payload = context.continueRunPayload or {} },
      }
    end,
  },
  {
    from = "menu",
    event = "start_run",
    build = function()
      return {
        { type = "action", action = "start_new_run" },
        { type = "state", state = "loadout" },
      }
    end,
  },
  {
    from = "menu",
    event = "open_meta",
    build = function(_, app)
      return {
        {
          type = "state",
          state = "meta",
          payload = {
            metaFlowContext = app and app.createMenuMetaFlowContext and app:createMenuMetaFlowContext() or {
              source = "menu",
              returnState = "menu",
              allowStartRun = false,
            },
          },
        },
      }
    end,
  },
  {
    from = "meta",
    event = "back",
    build = function(context)
      return {
        { type = "state", state = context.metaReturnState or "menu" },
      }
    end,
  },
  {
    from = "meta",
    event = "start_next_run",
    build = function(context)
      if context.metaAllowStartRun ~= true then
        return {}
      end

      return {
        { type = "action", action = "start_new_run" },
        { type = "state", state = "loadout" },
      }
    end,
  },
  {
    from = "loadout",
    event = "stage_ready",
    build = function(context)
      return buildInsertedFlow(context.insertedSteps and context.insertedSteps.pre_stage, {
        { type = "state", state = "stage" },
      })
    end,
  },
  {
    from = "loadout",
    event = "cancel_to_menu",
    build = function()
      return {
        { type = "action", action = "return_to_menu" },
        { type = "state", state = "menu" },
      }
    end,
  },
  {
    from = "boss_warning",
    event = "continue",
    build = function()
      return {
        { type = "state", state = "stage" },
      }
    end,
  },
  {
    from = "boss_warning",
    event = "back",
    build = function()
      return {
        { type = "state", state = "loadout" },
      }
    end,
  },
  {
    from = "stage",
    event = "back_to_loadout",
    build = function()
      return {
        { type = "state", state = "loadout" },
      }
    end,
  },
  {
    from = "stage",
    event = "stage_complete",
    build = function()
      return {
        { type = "action", action = "finalize_current_stage" },
        { type = "state", state = "result" },
      }
    end,
  },
  {
    from = "result",
    event = "continue",
    build = function(context)
      return buildInsertedFlow(context.insertedSteps and context.insertedSteps.post_result, {
        {
          type = "state",
          state = context.postResultDestinationState or "summary",
        },
      })
    end,
  },
  {
    from = "post_stage_analytics",
    event = "continue",
    build = function(context)
      return {
        {
          type = "state",
          state = context.postResultDestinationState or "summary",
        },
      }
    end,
  },
  {
    from = "reward_preview",
    event = "continue",
    build = function(context)
      local steps = {
        { type = "action", action = "claim_reward_choice" },
      }

      appendSteps(steps, buildInsertedFlow(context.insertedSteps and context.insertedSteps.pre_shop, {
        { type = "action", action = "prepare_shop" },
        { type = "state", state = "shop" },
      }))

      return steps
    end,
  },
  {
    from = "encounter",
    event = "continue",
    build = function()
      return {
        { type = "action", action = "claim_encounter_choice" },
        { type = "action", action = "prepare_shop" },
        { type = "state", state = "shop" },
      }
    end,
  },
  {
    from = "boss_reward",
    event = "continue",
    build = function()
      return {
        { type = "action", action = "claim_reward_choice" },
        { type = "state", state = "summary" },
      }
    end,
  },
  {
    from = "shop",
    event = "continue",
    build = function()
      return {
        { type = "action", action = "advance_after_shop" },
        { type = "state", state = "loadout" },
      }
    end,
  },
  {
    from = "summary",
    event = "open_meta",
    build = function(_, app)
      return {
        {
          type = "state",
          state = "meta",
          payload = {
            metaFlowContext = app and app.createSummaryMetaFlowContext and app:createSummaryMetaFlowContext() or {
              source = "summary",
              returnState = "summary",
              allowStartRun = true,
            },
          },
        },
      }
    end,
  },
  {
    from = "summary",
    event = "return_to_menu",
    build = function()
      return {
        { type = "action", action = "return_to_menu" },
        { type = "state", state = "menu" },
      }
    end,
  },
}

function StepBuilder.buildNextSteps(currentStateName, transitionPayload, app)
  local context = createMacroContext(currentStateName, transitionPayload, app)

  for _, rule in ipairs(RULES) do
    if rule.from == context.currentStateName and rule.event == context.event then
      return rule.build(context, app)
    end
  end

  return {}
end

return StepBuilder
