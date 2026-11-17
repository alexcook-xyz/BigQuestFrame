-- Scales the whole gossip/quest windows (frame + parchment + text) with clickable buttons.
local DEFAULT = 1.4
local MIN, MAX, STEP = 0.8, 2.2, 0.1
local FRAMES = { "GossipFrame", "QuestFrame" }
local db
local replay -- set below: re-opens the step-by-step reader

local function apply()
  for _, n in ipairs(FRAMES) do
    local f = _G[n]
    if f then f:SetScale(db.scale) end
  end
end

local function setScale(v)
  db.scale = math.max(MIN, math.min(MAX, v))
  apply()
end

local function makeButtons(f)
  local function btn(label, y, tip, onclick)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(34, 24)
    b:SetText(label)
    b:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, y)
    b:SetScript("OnClick", onclick)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(tip); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  btn("+", -10, "Bigger window and text", function() setScale(db.scale + STEP) end)
  btn("-", -38, "Smaller window and text", function() setScale(db.scale - STEP) end)
  btn("R", -66, "Reset size", function() setScale(DEFAULT) end)
  btn("Rd", -94, "Read this one piece at a time", function() if replay then replay(f) end end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  BigQuestFrameDB = BigQuestFrameDB or {}
  db = BigQuestFrameDB
  db.scale = db.scale or DEFAULT
  if db.reader == nil then db.reader = false end
  for _, n in ipairs(FRAMES) do
    local f = _G[n]
    if f then makeButtons(f) end
  end
  apply()
end)

SLASH_BIGQUESTFRAME1 = "/bqf"
SlashCmdList.BIGQUESTFRAME = function(msg)
  local v = tonumber(strtrim(msg or ""))
  if strtrim(msg or "") == "reader" then
    db.reader = not db.reader
    print("BigQuestFrame reader " .. (db.reader and "ON" or "OFF"))
  elseif v then setScale(v) else print("|cffffd100BigQuestFrame|r /bqf <0.8-2.2>, /bqf reader, or use the + - R buttons on the window") end
end

------------------------------------------------------------------
-- Step-by-step reader: shows a couple of sentences at a time.
-- Click anywhere (or Next) to advance. After the last page the normal
-- window is revealed so you can Accept / Complete / pick options.
------------------------------------------------------------------
local MAXCHARS = 150
local function chunk(text)
  local pages = {}
  text = (text or ""):gsub("\13", "")
  for para in text:gmatch("[^\10]+") do
    local cur = ""
    for sent in para:gmatch("[^%.%!%?]+[%.%!%?]*[\"']?%s*") do
      sent = strtrim(sent)
      if sent ~= "" then
        if cur ~= "" and #cur + #sent > MAXCHARS then
          pages[#pages + 1] = cur; cur = sent
        else
          cur = (cur == "") and sent or (cur .. " " .. sent)
        end
      end
    end
    if cur ~= "" then pages[#pages + 1] = cur end
  end
  return pages
end

local R, pages, idx, rtitle

local function build()
  R = CreateFrame("Frame", "BigQuestFrameReader", UIParent)
  R:EnableMouse(true)
  local bg = R:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.92, 0.82, 0.58, 1)
  local edge = R:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", -2, 2); edge:SetPoint("BOTTOMRIGHT", 2, -2)
  edge:SetColorTexture(0.35, 0.22, 0.08, 1)
  edge:SetDrawLayer("BACKGROUND", -1)

  R.title = R:CreateFontString(nil, "OVERLAY")
  R.title:SetFont("Fonts\\MORPHEUS.TTF", 26, "")
  R.title:SetPoint("TOPLEFT", 24, -20); R.title:SetPoint("TOPRIGHT", -24, -20)
  R.title:SetJustifyH("LEFT"); R.title:SetTextColor(0.25, 0.1, 0.02)

  R.text = R:CreateFontString(nil, "OVERLAY")
  R.text:SetFont("Fonts\\FRIZQT__.TTF", 22, "")
  R.text:SetPoint("LEFT", 28, 10); R.text:SetPoint("RIGHT", -28, 10)
  R.text:SetJustifyH("LEFT"); R.text:SetJustifyV("MIDDLE")
  R.text:SetSpacing(8); R.text:SetTextColor(0.12, 0.07, 0.02)

  R.count = R:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  R.count:SetPoint("BOTTOM", 0, 14); R.count:SetTextColor(0.35, 0.22, 0.08)

  local function mk(label, w, point, x)
    local b = CreateFrame("Button", nil, R, "UIPanelButtonTemplate")
    b:SetSize(w, 28); b:SetText(label); b:SetPoint(point, x, 10)
    return b
  end
  R.back = mk("< Back", 90, "BOTTOMLEFT", 20)
  R.skip = mk("Show all", 100, "BOTTOMLEFT", 120)
  R.next = mk("Next >", 110, "BOTTOMRIGHT", -20)

  R.hint = R:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  R.hint:SetPoint("BOTTOM", R.count, "TOP", 0, 4)
  R.hint:SetText("click anywhere to continue"); R.hint:SetTextColor(0.45, 0.32, 0.18)

  local function show()
    R.title:SetText(rtitle or "")
    R.text:SetText(pages[idx])
    R.count:SetText(idx .. " / " .. #pages)
    R.back:SetEnabled(idx > 1)
    R.next:SetText(idx == #pages and "Finish" or "Next >")
  end
  R.show = show
  function R.advance()
    if idx >= #pages then R:Hide() else idx = idx + 1; show() end
  end
  R.next:SetScript("OnClick", R.advance)
  R.back:SetScript("OnClick", function() if idx > 1 then idx = idx - 1; show() end end)
  R.skip:SetScript("OnClick", function() R:Hide() end)
  R:SetScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then R.advance() end end)
  R:Hide()
end

local function start(f, title, ...)
  if not db or not db.reader or not f or not f:IsShown() then return end
  local all = {}
  for i = 1, select("#", ...) do
    local t = select(i, ...)
    if t and t ~= "" then
      for _, p in ipairs(chunk(t)) do all[#all + 1] = p end
    end
  end
  if #all == 0 then return end
  if not R then build() end
  pages, idx, rtitle = all, 1, title
  R:SetParent(f)
  R:ClearAllPoints()
  R:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -72)
  R:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 46)
  R:SetFrameStrata(f:GetFrameStrata())
  R:SetFrameLevel(f:GetFrameLevel() + 100)
  R.show()
  R:Show()
end

local current = {} -- last reader args per frame, for the "Rd" button
local function launch(f, title, ...)
  local args = { n = select("#", ...), ... }
  current[f] = { title = title, args = args }
  C_Timer.After(0, function() start(f, title, unpack(args, 1, args.n)) end)
end
replay = function(f)
  local c = current[f]
  if c then start(f, c.title, unpack(c.args, 1, c.args.n)) end
end

local rev = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
                     "GOSSIP_SHOW", "QUEST_FINISHED", "GOSSIP_CLOSED" }) do
  pcall(rev.RegisterEvent, rev, e)
end
rev:SetScript("OnEvent", function(_, e)
  if e == "QUEST_FINISHED" or e == "GOSSIP_CLOSED" then
    if R then R:Hide() end
  elseif e == "QUEST_DETAIL" then
    local obj = GetObjectiveText and GetObjectiveText()
    launch(QuestFrame, GetTitleText(), GetQuestText(), obj and obj ~= "" and ("Objective: " .. obj) or nil)
  elseif e == "QUEST_PROGRESS" then
    launch(QuestFrame, GetTitleText(), GetProgressText())
  elseif e == "QUEST_COMPLETE" then
    launch(QuestFrame, GetTitleText(), GetRewardText())
  elseif e == "QUEST_GREETING" then
    launch(QuestFrame, UnitName("npc"), GetGreetingText())
  elseif e == "GOSSIP_SHOW" then
    launch(GossipFrame, UnitName("npc"), GetGossipText())
  end
end)
