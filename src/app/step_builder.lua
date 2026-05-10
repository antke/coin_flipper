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
        { type = "state", state = "run_setup", payload = { returnState = "menu" } },
      }
    end,
  },
  {
    from = "run_setup",
    event = "back_to_menu",
    build = function()
      return {
        { type = "state", state = "menu" },
      }
    end,
  },
  {
    from = "run_setup",
    event = "back_to_meta",
    build = function(context)
      local payload = context.payload or {}
      return {
        {
          type = "state",
          state = "meta",
          payload = {
            metaFlowContext = payload.metaFlowContext or context.metaFlowContext,
          },
        },
      }
    end,
  },
  {
    from = "run_setup",
    event = "start_run",
    build = function(context)
      return {
        { type = "action", action = "start_new_run", payload = context.payload or {} },
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
    from = "menu",
    event = "open_help",
    build = function()
      return {
        { type = "state", state = "help" },
      }
    end,
  },
  {
    from = "menu",
    event = "open_collection",
    build = function()
      return {
        { type = "state", state = "collection", payload = { returnState = "menu" } },
      }
    end,
  },
  {
    from = "menu",
    event = "open_records",
    build = function()
      return {
        { type = "state", state = "records", payload = { returnState = "menu" } },
      }
    end,
  },
  {
    from = "help",
    event = "back",
    build = function()
      return {
        { type = "state", state = "menu" },
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
    build = function(context, app)
      if context.metaAllowStartRun ~= true then
        return {}
      end

      return {
        {
          type = "state",
          state = "run_setup",
          payload = {
            returnState = "meta",
            metaFlowContext = app and app.getMetaFlowContext and app:getMetaFlowContext() or nil,
          },
        },
      }
    end,
  },
  {
    from = "meta",
    event = "open_collection",
    build = function()
      return {
        { type = "state", state = "collection", payload = { returnState = "meta" } },
      }
    end,
  },
  {
    from = "meta",
    event = "open_records",
    build = function(_, app)
      return {
        {
          type = "state",
          state = "records",
          payload = {
            returnState = "meta",
            metaFlowContext = app and app.getMetaFlowContext and app:getMetaFlowContext() or nil,
          },
        },
      }
    end,
  },
  {
    from = "collection",
    event = "back_to_menu",
    build = function()
      return {
        { type = "state", state = "menu" },
      }
    end,
  },
  {
    from = "records",
    event = "back_to_menu",
    build = function()
      return {
        { type = "state", state = "menu" },
      }
    end,
  },
  {
    from = "records",
    event = "back_to_meta",
    build = function(context)
      local payload = context.payload or {}
      return {
        {
          type = "state",
          state = "meta",
          payload = {
            metaFlowContext = payload.metaFlowContext or context.metaFlowContext,
          },
        },
      }
    end,
  },
  {
    from = "records",
    event = "back_to_summary",
    build = function()
      return {
        { type = "state", state = "summary" },
      }
    end,
  },
  {
    from = "collection",
    event = "back_to_meta",
    build = function(_, app)
      return {
        {
          type = "state",
          state = "meta",
          payload = {
            metaFlowContext = app and app.getMetaFlowContext and app:getMetaFlowContext() or nil,
          },
        },
      }
    end,
  },
  {
    from = "loadout",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "loadout" } },
        { type = "state", state = "pause" },
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
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "boss_warning" } },
        { type = "state", state = "pause" },
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
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "stage" } },
        { type = "state", state = "pause" },
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
    from = "result",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "result" } },
        { type = "state", state = "pause" },
      }
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
    from = "post_stage_analytics",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "post_stage_analytics" } },
        { type = "state", state = "pause" },
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
    from = "reward_preview",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "reward_preview" } },
        { type = "state", state = "pause" },
      }
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
    from = "encounter",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "encounter" } },
        { type = "state", state = "pause" },
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
    from = "boss_reward",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "boss_reward" } },
        { type = "state", state = "pause" },
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
    from = "shop",
    event = "open_pause",
    build = function()
      return {
        { type = "action", action = "prepare_pause", payload = { returnState = "shop" } },
        { type = "state", state = "pause" },
      }
    end,
  },
  {
    from = "pause",
    event = "resume",
    build = function(context)
      if not context.pauseReturnState then
        return {
          { type = "state", state = "menu" },
        }
      end

      return {
        { type = "state", state = context.pauseReturnState, payload = context.pauseReturnPayload or {} },
      }
    end,
  },
  {
    from = "pause",
    event = "save_quit_to_menu",
    build = function()
      return {
        { type = "action", action = "save_quit_to_menu" },
        { type = "state", state = "menu" },
      }
    end,
  },
  {
    from = "pause",
    event = "abandon_run",
    build = function()
      return {
        { type = "action", action = "abandon_run" },
        { type = "state", state = "menu" },
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
    event = "open_records",
    build = function()
      return {
        { type = "state", state = "records", payload = { returnState = "summary" } },
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
