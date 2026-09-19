-- SPDX-License-Identifier: GPL-3.0-or-later

-- test_pve_mode: a minimal 1v1 PVE smoke-test mode (human vs robot).
-- Design rationale lives in the sibling freekill-asio repo:
--   .scratch/test_pve_mode/ (spec + tickets), docs/adr/0002-custom-choosegenerals-required.md
--   (mechanism; supersedes docs/adr/0001-test-pve-mode-minimal-smoke-test.md).

local extension = Package:new("test_pve_mode")

-- Two custom generals. Their skills are reused from the `standard` package
-- (wusheng, luoyi, qingguo, fankui); no new skill logic is defined here.
-- Both are marked hidden so they never enter the general pile of any other
-- mode: Engine:canUseGeneral excludes hidden generals unconditionally, so
-- they cannot pollute standard modes. The custom GameLogic below deals them
-- directly, bypassing the pile (setPlayerGeneral does not check `hidden`).
local pve_warrior = General(extension, "pve_warrior", "shu", 4, 4)
pve_warrior.hidden = true
pve_warrior:addSkills { "wusheng", "luoyi" }

local pve_guardian = General(extension, "pve_guardian", "wei", 4, 4)
pve_guardian.hidden = true
pve_guardian:addSkills { "qingguo", "fankui" }

-- Custom game logic. The default GameLogic:chooseGenerals draws from
-- room.general_pile (built by makeGeneralPile via canUseGeneral), which
-- excludes hidden generals — so our two custom generals would never be
-- dealt. Override chooseGenerals to deal directly from a local pool.
-- Modeled on rougelike1v1/logic.lua; no shop/talent/draw-pile machinery.
--
-- GameLogic is not available at package-load time, so the subclass is built
-- lazily on the first game start (when mode.logic() is called) and cached.
local _logic_cls

local test_pve_mode = fk.CreateGameMode {
  name = "test_pve_mode",
  minPlayer = 2,
  maxPlayer = 2,
  -- No mode-level whitelist: a GameMode.whitelist would disable every other
  -- package for this mode, including the standard card packages, breaking
  -- the draw pile. The custom chooseGenerals restricts generals; cards stay
  -- available via the default buildDrawPile.
  logic = function()
    if not _logic_cls then
      _logic_cls = GameLogic:subclass("test_pve_mode_logic")
      function _logic_cls:chooseGenerals()
        local room = self.room
        local lord = room:getLord()
        room:setCurrent(lord)
        local players = room.players

        -- The only two generals this mode ever deals.
        local pool = { "pve_warrior", "pve_guardian" }

        local req = Request:new(players, "AskForGeneral")
        req.timeout = room:getSettings('generalTimeout')
        for _, p in ipairs(players) do
          -- offer both custom generals to each player; pick 1
          req:setData(p, { pool, 1 })
          -- robot / idle-player default: a random general from the pool
          req:setDefaultReply(p, { pool[math.random(1, #pool)] })
        end
        req:ask()

        for _, p in ipairs(players) do
          local chosen = req:getResult(p)[1]
          room:setPlayerGeneral(p, chosen, true, true)
        end

        room:askToChooseKingdom(players)
        for _, p in ipairs(players) do
          room:broadcastProperty(p, "general")
        end
      end
    end
    return _logic_cls
  end,
}
extension:addGameMode(test_pve_mode)

Fk:loadTranslationTable {
  ["test_pve_mode"] = "PVE测试模式",
  [":test_pve_mode"] = "1v1对战机器人（冒烟测试）",
  ["pve_warrior"] = "PVE勇士",
  ["#pve_warrior"] = "试炼之刃",
  ["~pve_warrior"] = "测试结束……",
  ["pve_guardian"] = "PVE守卫",
  ["#pve_guardian"] = "试炼之盾",
  ["~pve_guardian"] = "测试结束……",
}

return extension
