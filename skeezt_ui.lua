--[[ ════════════════════════════════════════════════════════════════════════
    skeezt_ui — Skeet.cc 2019 menu, 1:1 in Roblox
    Drop-in API-compatible with nachtara_ui.lua v2.

    Loads at runtime:
      • menuBg PNG  — https://raw.githubusercontent.com/sanyoner/misc/main/skeezt_menu_bg.png
      • Verdana TTF — https://raw.githubusercontent.com/sanyoner/fonts/main/Verdana-Font.ttf
      • Tahoma Bold — https://raw.githubusercontent.com/sanyoner/fonts/main/Tahoma-Modern-Bold.ttf
    via game:HttpGet + writefile + getcustomasset (sanyui pattern).

    Visual spec mirrors Skeet's imgui:
      • Outer 660×560 window, ChildBg(17,17,17), border outer (10,10,10) inner (48,48,48)
      • Unicorn ColorBar at top of content: cyan(55,177,218)→pink(201,84,192)→yellow(204,227,54)
      • Vertical left tab strip, 75 wide, icons in big font
      • Two-column groupbox layout, 258 wide groupboxes
      • Title gray (170,170,170) breaking the top border
      • Toggles, sliders, dropdowns, color pickers, keypickers, dependency boxes
═════════════════════════════════════════════════════════════════════════ ]]

local _cloneref = (type(cloneref) == "function") and cloneref or function(x) return x end
local Players          = _cloneref(game:GetService("Players"))
local RunService       = _cloneref(game:GetService("RunService"))
local UserInputService = _cloneref(game:GetService("UserInputService"))
local TweenService     = _cloneref(game:GetService("TweenService"))
local HttpService      = _cloneref(game:GetService("HttpService"))
local LocalPlayer      = Players.LocalPlayer

-- ──────────────────────────────────────────────────────────────────────────
-- THEME (Skeet colors, sampled directly from imgui source)
-- ──────────────────────────────────────────────────────────────────────────
local Theme = {
    -- frames (from user's base reference)
    BaseFill        = Color3.fromRGB(18, 18, 18),     -- outer window background
    TabFill         = Color3.fromRGB(25, 25, 25),     -- tab content frame
    GroupFill       = Color3.fromRGB(36, 36, 36),     -- groupbox background
    OuterFill       = Color3.fromRGB(18, 18, 18),     -- alias for compat
    InnerFill       = Color3.fromRGB(25, 25, 25),
    TabsFill        = Color3.fromRGB(25, 25, 25),
    BorderOuter     = Color3.fromRGB(13, 13, 13),
    BorderInner     = Color3.fromRGB(61, 61, 61),
    BorderBlack     = Color3.fromRGB(0, 0, 0),
    -- text
    Title           = Color3.fromRGB(170, 170, 170),
    Text            = Color3.fromRGB(200, 200, 200),
    SubText         = Color3.fromRGB(140, 140, 140),
    TextShadow      = Color3.fromRGB(0, 0, 0),
    -- widgets
    CheckboxOffTop  = Color3.fromRGB(76, 76, 76),
    CheckboxOffBot  = Color3.fromRGB(51, 51, 51),
    SliderTrackTop  = Color3.fromRGB(52, 52, 52),
    SliderTrackBot  = Color3.fromRGB(68, 68, 68),
    ComboFill       = Color3.fromRGB(47, 47, 47),
    PopupFill       = Color3.fromRGB(12, 12, 12),
    -- unicorn rainbow (from user's base reference UIGradient stops)
    UCcyan          = Color3.fromRGB(56,  181, 221),
    UCpink          = Color3.fromRGB(201, 81,  201),
    UCyellow        = Color3.fromRGB(201, 201, 51),
    -- toggle accent (pink — middle of the unicorn gradient)
    Accent          = Color3.fromRGB(201, 81,  201),
}

-- ──────────────────────────────────────────────────────────────────────────
-- ASSET LOADER (sanyui pattern: HttpGet → writefile → getcustomasset)
-- ──────────────────────────────────────────────────────────────────────────
local CACHE_DIR = "skeezt_ui"
local FONT_BASE = "https://raw.githubusercontent.com/sanyoner/fonts/main/"
local PNG_URL   = "https://raw.githubusercontent.com/sanyoner/misc/main/skeezt_menu_bg.png"

local function ensureFolder(p)
    pcall(function()
        local parts = p:split("/")
        local cur = ""
        for i = 1, #parts do
            cur = (i == 1) and parts[i] or (cur .. "/" .. parts[i])
            if isfolder and not isfolder(cur) then makefolder(cur) end
        end
    end)
end
ensureFolder(CACHE_DIR)

local function fetchToFile(url, relPath)
    if isfile and isfile(relPath) then return relPath end
    local ok, body = pcall(game.HttpGet, game, url)
    if not ok or type(body) ~= "string" or #body < 32 then return nil end
    local ok2 = pcall(writefile, relPath, body)
    return ok2 and relPath or nil
end

local function loadFont(name, url)
    if type(Font) ~= "table" or type(Font.new) ~= "function" then return nil end
    if type(getcustomasset) ~= "function" or type(writefile) ~= "function" then return nil end
    local ttfPath  = CACHE_DIR .. "/" .. name .. ".ttf"
    local jsonPath = CACHE_DIR .. "/" .. name .. ".json"
    if not fetchToFile(url, ttfPath) then return nil end
    local okA, ttfAsset = pcall(getcustomasset, ttfPath)
    if not okA or type(ttfAsset) ~= "string" then return nil end
    local jsonBody = ('{"name":"%s","faces":[{"name":"Regular","weight":400,"style":"normal","assetId":"%s"}]}'):format(name, ttfAsset)
    pcall(writefile, jsonPath, jsonBody)
    local okJ, jsonAsset = pcall(getcustomasset, jsonPath)
    if not okJ then return nil end
    local okF, fnt = pcall(Font.new, jsonAsset, Enum.FontWeight.Regular)
    return okF and fnt or nil
end

local function loadImage(url, relPath)
    if not fetchToFile(url, relPath) then return nil end
    if type(getcustomasset) ~= "function" then return nil end
    local ok, asset = pcall(getcustomasset, relPath)
    return ok and asset or nil
end

local FontRegular = loadFont("Verdana",     FONT_BASE .. "Verdana-Font.ttf")
local FontBold    = loadFont("TahomaBold",  FONT_BASE .. "Tahoma-Modern-Bold.ttf")
-- PNG background no longer used (Linoria-style tabs replace the image-mode UI)
pcall(function()
    local warn_ = rconsolewarn or warn
    if not FontRegular then warn_("[skeezt_ui] Verdana font fetch FAILED — falling back to Enum.Font.Code") end
    if not FontBold    then warn_("[skeezt_ui] Tahoma Bold font fetch FAILED — falling back to Code (no bold)") end
end)

-- Fallbacks if asset fetch fails (rbxlx, no executor):
local function applyFont(inst, bold)
    pcall(function()
        if bold and FontBold then inst.FontFace = FontBold; return end
        if FontRegular then inst.FontFace = FontRegular; return end
        inst.Font = bold and Enum.Font.Code or Enum.Font.Code
    end)
end

-- ──────────────────────────────────────────────────────────────────────────
-- PRIMITIVE HELPERS — all instances named "\0" for stealth
-- ──────────────────────────────────────────────────────────────────────────
local function mk(class, props)
    local i = Instance.new(class); i.Name = "\0"
    if props then for k, v in props do pcall(function() i[k] = v end) end end
    return i
end
local function stroke(inst, color, thick, mode)
    local s = Instance.new("UIStroke"); s.Name = "\0"
    s.Color = color or Theme.BorderOuter; s.Thickness = thick or 1
    s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border; s.Parent = inst
    return s
end
local function uiList(parent, dir, pad)
    local l = Instance.new("UIListLayout"); l.Name = "\0"
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, pad or 0); l.Parent = parent
    return l
end
local function uiPad(parent, l, r, t, b)
    local p = Instance.new("UIPadding"); p.Name = "\0"
    p.PaddingLeft = UDim.new(0, l or 0); p.PaddingRight = UDim.new(0, r or 0)
    p.PaddingTop = UDim.new(0, t or 0); p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = parent; return p
end
local function dropShadowText(label, shadowColor)
    -- Use TextStrokeTransparency for a cheap 1px shadow
    label.TextStrokeColor3 = shadowColor or Theme.TextShadow
    label.TextStrokeTransparency = 0
end
local function safeCallback(fn, ...) if type(fn) == "function" then pcall(fn, ...) end end
local function track(t, c) t[#t + 1] = c end

-- Skeet's 5-stroke deep border. Pattern from user reference:
--   1st RGB(13,13,13) thick 1 offset  0   outer dark line
--   2nd RGB(61,61,61) thick 1 offset -1   gray
--   3rd RGB(41,41,41) thick 3 offset -4   thick dim band (Tab/GroupBox use -2)
--   4th RGB(61,61,61) thick 1 offset -5   gray
--   5th RGB(13,13,13) thick 1 offset -6   inner dark line
-- The user's Base frame uses depth 6 (-0/-1/-4/-5/-6); Tab+GroupBox use depth 4 (-0/-1/-2/-3/-4).
-- UIStroke.BorderOffset only exists on newer Roblox builds; we pcall-set it.
local function multiStroke(frame, depth)
    depth = depth or "deep"   -- "deep" = base, "shallow" = tab/groupbox
    local spec
    if depth == "deep" then
        spec = {
            { Color3.fromRGB(13, 13, 13), 1,  0 },
            { Color3.fromRGB(61, 61, 61), 1, -1 },
            { Color3.fromRGB(41, 41, 41), 3, -4 },
            { Color3.fromRGB(61, 61, 61), 1, -5 },
            { Color3.fromRGB(13, 13, 13), 1, -6 },
        }
    else
        spec = {
            { Color3.fromRGB(13, 13, 13), 1,  0 },
            { Color3.fromRGB(61, 61, 61), 1, -1 },
            { Color3.fromRGB(41, 41, 41), 1, -2 },
            { Color3.fromRGB(61, 61, 61), 1, -3 },
            { Color3.fromRGB(13, 13, 13), 1, -4 },
        }
    end
    for _, s in spec do
        local st = Instance.new("UIStroke"); st.Name = "\0"
        st.Color = s[1]; st.Thickness = s[2]
        st.LineJoinMode = Enum.LineJoinMode.Miter
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        st.Parent = frame
        pcall(function() st.BorderOffset = UDim.new(0, s[3]) end)
    end
end

-- Legacy double-border kept for popups / color-picker swatch area
local function doubleBorder(frame, outerColor, innerColor)
    local sOut = stroke(frame, outerColor or Theme.BorderOuter, 1)
    local inner = mk("Frame", {
        Parent = frame, BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2),
        ZIndex = (frame.ZIndex or 1),
    })
    stroke(inner, innerColor or Theme.BorderInner, 1)
    return sOut, inner
end

-- ──────────────────────────────────────────────────────────────────────────
-- SCREENGUI (CoreGui via gethui if available)
-- ──────────────────────────────────────────────────────────────────────────
local function getContainer()
    local ok, hui = pcall(function() if type(gethui) == "function" then return gethui() end end)
    if ok and hui then return hui end
    local cg = _cloneref(game:GetService("CoreGui"))
    if cg then return cg end
    return LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = mk("ScreenGui", {
    DisplayOrder = 50000,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    IgnoreGuiInset = true, ResetOnSpawn = false,
})
pcall(function() ScreenGui.Parent = getContainer() end)

-- ──────────────────────────────────────────────────────────────────────────
-- LIBRARY TABLE
-- ──────────────────────────────────────────────────────────────────────────
local Library = {
    Theme       = Theme,
    Toggles     = {},
    Options     = {},
    Connections = {},
    DepRefreshers = {},
    Visible     = true,
    Unloaded    = false,
    ToggleKey   = Enum.KeyCode.End,
    ActivePopup = nil,
    ActiveKeyPicker = nil,
    ScreenGui   = ScreenGui,
    Fonts = { Regular = FontRegular, Bold = FontBold },
}

local function notifyDepChange()
    for _, fn in Library.DepRefreshers do pcall(fn) end
end
local function closeActivePopup()
    if Library.ActivePopup then
        local p = Library.ActivePopup; Library.ActivePopup = nil
        if p.OnClose then pcall(p.OnClose) end
    end
end
local function trackConn(c) Library.Connections[#Library.Connections + 1] = c; return c end

-- Global click-outside-to-close-popup
trackConn(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        if Library.ActivePopup and Library.ActivePopup.IgnoreNext then
            Library.ActivePopup.IgnoreNext = false; return
        end
        closeActivePopup()
    end
end))

-- ──────────────────────────────────────────────────────────────────────────
-- WIDGET BUILDERS — attachWidgets(target, body)
--   target = the table that gets :AddToggle/:AddSlider/...
--   body   = the parent Frame where rows are inserted
-- ──────────────────────────────────────────────────────────────────────────
local attachWidgets
local function buildColorPicker(rowOverride, id, opt, inline) end -- forward
local function buildKeyPicker(rowOverride, id, opt, inline) end   -- forward

attachWidgets = function(target, body)

    -- ── TOGGLE ───────────────────────────────────────────────────────────
    function target:AddToggle(id, opt)
        opt = opt or {}
        local row = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1 })

        -- 9px checkbox at left, vertically centered in a 15-tall row
        local box = mk("Frame", { Parent = row, BorderSizePixel = 0,
            Size = UDim2.fromOffset(9, 9), Position = UDim2.fromOffset(0, 3),
            BackgroundColor3 = Theme.CheckboxOffBot })
        stroke(box, Theme.BorderOuter, 1)
        local boxGrad = Instance.new("UIGradient"); boxGrad.Name = "\0"
        boxGrad.Rotation = 90
        boxGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Theme.CheckboxOffTop),
            ColorSequenceKeypoint.new(1, Theme.CheckboxOffBot)}
        boxGrad.Parent = box

        local label = mk("TextLabel", { Parent = row, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -14, 1, 0),
            Text = opt.Text or id, TextSize = 11,
            TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center })
        applyFont(label, false); dropShadowText(label)

        local btn = mk("TextButton", { Parent = row, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false })

        local toggle = { Value = not not opt.Default, _row = row, _box = box }
        local function paint()
            local cb = opt.Callback
            if toggle.Value then
                boxGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Theme.Accent),
                    ColorSequenceKeypoint.new(1, Color3.new(
                        math.max(0, Theme.Accent.R - 0.18),
                        math.max(0, Theme.Accent.G - 0.18),
                        math.max(0, Theme.Accent.B - 0.18)))}
            else
                boxGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, Theme.CheckboxOffTop),
                    ColorSequenceKeypoint.new(1, Theme.CheckboxOffBot)}
            end
            safeCallback(cb, toggle.Value)
            notifyDepChange()
        end
        function toggle:SetValue(v) self.Value = not not v; paint() end
        trackConn(btn.MouseButton1Click:Connect(function()
            toggle.Value = not toggle.Value; paint()
        end))
        Library.Toggles[id] = toggle
        paint()

        -- chainable AddColorPicker / AddKeyPicker on toggle row
        function toggle:AddColorPicker(cid, copt) return buildColorPicker(row, cid, copt, true) end
        function toggle:AddKeyPicker(kid, kopt)   return buildKeyPicker(row, kid, kopt, true)   end
        return toggle
    end

    -- ── BUTTON ───────────────────────────────────────────────────────────
    function target:AddButton(id, opt)
        opt = opt or {}
        local row = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 })
        local b = mk("TextButton", { Parent = row, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.CheckboxOffBot,
            AutoButtonColor = false, Text = opt.Text or id, TextSize = 11,
            TextColor3 = Theme.Text })
        applyFont(b, false); dropShadowText(b)
        stroke(b, Theme.BorderOuter, 1)
        local g = Instance.new("UIGradient"); g.Name = "\0"; g.Rotation = 90
        g.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Theme.CheckboxOffTop),
            ColorSequenceKeypoint.new(1, Theme.CheckboxOffBot)}
        g.Parent = b
        trackConn(b.MouseEnter:Connect(function()
            g.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(86,86,86)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(61,61,61))}
        end))
        trackConn(b.MouseLeave:Connect(function()
            g.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Theme.CheckboxOffTop),
                ColorSequenceKeypoint.new(1, Theme.CheckboxOffBot)}
        end))
        trackConn(b.MouseButton1Click:Connect(function() safeCallback(opt.Callback) end))
        return { _row = row, _btn = b }
    end

    -- ── LABEL ────────────────────────────────────────────────────────────
    function target:AddLabel(text)
        local l = mk("TextLabel", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
            Text = text or "", TextSize = 11,
            TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            AutomaticSize = Enum.AutomaticSize.Y })
        applyFont(l, false); dropShadowText(l)
        return { _label = l, SetText = function(self, s) l.Text = s or "" end }
    end

    -- ── DIVIDER ──────────────────────────────────────────────────────────
    function target:AddDivider()
        local wrap = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1 })
        local d1 = mk("Frame", { Parent = wrap, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.BorderOuter })
        local d2 = mk("Frame", { Parent = wrap, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.BorderInner })
        return { _wrap = wrap }
    end

    -- ── SLIDER ───────────────────────────────────────────────────────────
    function target:AddSlider(id, opt)
        opt = opt or {}
        local mn, mx = opt.Min or 0, opt.Max or 100
        local rounding = opt.Rounding or 0
        -- Skeet macro uses printf format like "%1.f%%" where %% means literal %.
        -- In Lua plain string concat, leave %% alone -> render single %.
        local suffix = (opt.Suffix or ""):gsub("%%%%", "%%")
        local val = math.clamp(opt.Default or mn, mn, mx)

        local row = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })

        local title = mk("TextLabel", { Parent = row, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 12),
            Text = opt.Text or id, TextSize = 11,
            TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center })
        applyFont(title, false); dropShadowText(title)

        -- Track
        local track = mk("Frame", { Parent = row, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 11),
            BackgroundColor3 = Theme.SliderTrackTop })
        stroke(track, Theme.BorderOuter, 1)
        local trackGrad = Instance.new("UIGradient"); trackGrad.Name = "\0"; trackGrad.Rotation = 90
        trackGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Theme.SliderTrackTop),
            ColorSequenceKeypoint.new(1, Theme.SliderTrackBot)}
        trackGrad.Parent = track

        -- Fill
        local fill = mk("Frame", { Parent = track, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Accent })
        local fillGrad = Instance.new("UIGradient"); fillGrad.Name = "\0"; fillGrad.Rotation = 90
        fillGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Color3.new(
                math.max(0, Theme.Accent.R - 0.18),
                math.max(0, Theme.Accent.G - 0.18),
                math.max(0, Theme.Accent.B - 0.18)))}
        fillGrad.Parent = fill

        -- Value text overlaid, Bold, slightly smaller than label
        local valLbl = mk("TextLabel", { Parent = track, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, -1), Size = UDim2.fromScale(1, 1),
            TextSize = 10,
            TextColor3 = Color3.fromRGB(230,230,230),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 5 })
        applyFont(valLbl, true); dropShadowText(valLbl)

        local opt_obj = { Value = val }
        local function fmt(v)
            if rounding <= 0 then return tostring(math.floor(v + 0.5)) .. suffix end
            local mult = 10 ^ rounding
            return tostring(math.floor(v * mult + 0.5) / mult) .. suffix
        end
        local function paint()
            local f = (opt_obj.Value - mn) / math.max(mx - mn, 0.0001)
            fill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
            valLbl.Text = fmt(opt_obj.Value)
            safeCallback(opt.Callback, opt_obj.Value)
        end
        function opt_obj:SetValue(v)
            v = math.clamp(v or mn, mn, mx)
            if rounding <= 0 then v = math.floor(v + 0.5)
            else local m = 10^rounding; v = math.floor(v*m+0.5)/m end
            self.Value = v; paint()
        end
        Library.Options[id] = opt_obj
        paint()

        local dragging = false
        local function setFromPos(px)
            local abs = track.AbsolutePosition.X
            local w = math.max(track.AbsoluteSize.X, 1)
            local frac = math.clamp((px - abs) / w, 0, 1)
            opt_obj:SetValue(mn + frac * (mx - mn))
        end
        trackConn(track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; setFromPos(input.Position.X)
            end
        end))
        trackConn(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                          or input.UserInputType == Enum.UserInputType.Touch) then
                setFromPos(input.Position.X)
            end
        end))
        trackConn(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end))

        return opt_obj
    end

    -- ── DROPDOWN ─────────────────────────────────────────────────────────
    function target:AddDropdown(id, opt)
        opt = opt or {}
        local values = opt.Values or {}
        local default = opt.Default
        if type(default) == "number" then default = values[default] end
        if default == nil then default = values[1] end

        local row = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
        local title = mk("TextLabel", { Parent = row, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 12),
            Text = opt.Text or id, TextSize = 11,
            TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center })
        applyFont(title, false); dropShadowText(title)

        local btn = mk("TextButton", { Parent = row, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 13),
            BackgroundColor3 = Theme.ComboFill, AutoButtonColor = false,
            Text = "", TextSize = 11, TextColor3 = Theme.Text })
        stroke(btn, Theme.BorderOuter, 1)
        local btnLbl = mk("TextLabel", { Parent = btn, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -16, 1, 0),
            Text = tostring(default or ""), TextSize = 11,
            TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center })
        applyFont(btnLbl, false); dropShadowText(btnLbl)
        local arrow = mk("TextLabel", { Parent = btn, BackgroundTransparency = 1,
            Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(10, 13),
            Text = "▾", TextSize = 11, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Center })
        applyFont(arrow, false)

        local opt_obj = { Value = default }
        function opt_obj:SetValue(v)
            self.Value = v; btnLbl.Text = tostring(v or "")
            safeCallback(opt.Callback, v)
        end
        Library.Options[id] = opt_obj

        local popup
        local function closePopup()
            if popup then popup:Destroy(); popup = nil end
            if Library.ActivePopup and Library.ActivePopup.Owner == btn then
                Library.ActivePopup = nil
            end
        end
        local function openPopup()
            closeActivePopup()
            local abs = btn.AbsolutePosition; local sz = btn.AbsoluteSize
            popup = mk("Frame", { Parent = ScreenGui, BorderSizePixel = 0,
                Position = UDim2.fromOffset(abs.X, abs.Y + sz.Y + 1),
                Size = UDim2.fromOffset(sz.X, math.min(#values * 14 + 2, 160)),
                BackgroundColor3 = Theme.PopupFill, ZIndex = 100 })
            stroke(popup, Theme.BorderInner, 1)
            doubleBorder(popup, Theme.BorderInner, Theme.BorderBlack)
            local sf = mk("ScrollingFrame", { Parent = popup, BorderSizePixel = 0,
                Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2),
                BackgroundTransparency = 1, ScrollBarThickness = 2,
                CanvasSize = UDim2.new(0,0,0,0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 101 })
            uiList(sf, Enum.FillDirection.Vertical, 0)
            for _, v in values do
                local row2 = mk("TextButton", { Parent = sf, BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 14), AutoButtonColor = false,
                    BackgroundColor3 = Theme.PopupFill, Text = "", ZIndex = 102 })
                local rl = mk("TextLabel", { Parent = row2, BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -4, 1, 0),
                    Text = tostring(v), TextSize = 11,
                    TextColor3 = (v == opt_obj.Value) and Theme.Accent or Theme.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 103 })
                applyFont(rl, false); dropShadowText(rl)
                trackConn(row2.MouseEnter:Connect(function() row2.BackgroundColor3 = Color3.fromRGB(30,30,30) end))
                trackConn(row2.MouseLeave:Connect(function() row2.BackgroundColor3 = Theme.PopupFill end))
                trackConn(row2.MouseButton1Click:Connect(function()
                    opt_obj:SetValue(v); closePopup()
                end))
            end
            local rec = { Owner = btn, IgnoreNext = true, OnClose = closePopup }
            Library.ActivePopup = rec
        end
        trackConn(btn.MouseButton1Click:Connect(function()
            if popup then closePopup() else openPopup() end
        end))
        opt_obj:SetValue(default)
        return opt_obj
    end

    -- ── COLORPICKER (standalone, with own row + optional left label) ────
    function target:AddColorPicker(id, opt)
        opt = opt or {}
        local row = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1 })
        if opt.Text and opt.Text ~= "" then
            local l = mk("TextLabel", { Parent = row, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -30, 1, 0),
                Text = opt.Text, TextSize = 11, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center })
            applyFont(l, false); dropShadowText(l)
        end
        return buildColorPicker(row, id, opt, false)
    end

    -- ── KEYPICKER (standalone, with own row + left label) ───────────────
    function target:AddKeyPicker(id, opt)
        opt = opt or {}
        local row = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1 })
        if opt.Text and opt.Text ~= "" then
            local l = mk("TextLabel", { Parent = row, BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -54, 1, 0),
                Text = opt.Text, TextSize = 11, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center })
            applyFont(l, false); dropShadowText(l)
        end
        return buildKeyPicker(row, id, opt, true)
    end

    -- ── DEPENDENCYBOX ────────────────────────────────────────────────────
    function target:AddDependencyBox()
        local depBody = mk("Frame", { Parent = body, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y, Visible = true })
        uiList(depBody, Enum.FillDirection.Vertical, 4)
        -- 8px left indent like nachtara_ui
        local p = Instance.new("UIPadding"); p.Name = "\0"
        p.PaddingLeft = UDim.new(0, 8); p.Parent = depBody

        local depBox = {}
        attachWidgets(depBox, depBody)

        function depBox:SetupDependencies(deps)
            local function refresh()
                local show = true
                for _, d in deps do
                    local tog, expected = d[1], d[2]
                    if tog and tog.Value ~= expected then show = false; break end
                end
                depBody.Visible = show
            end
            Library.DepRefreshers[#Library.DepRefreshers + 1] = refresh
            refresh()
        end
        return depBox
    end
end

-- ──────────────────────────────────────────────────────────────────────────
-- COLOR PICKER (popup HSV + brightness slider + alpha slider)
-- ──────────────────────────────────────────────────────────────────────────
function buildColorPicker(row, id, opt, inline)
    opt = opt or {}
    local default = opt.Default or Color3.fromRGB(255, 255, 255)
    assert(row and row.Parent, "buildColorPicker: row missing")
    -- Place swatch at right edge of row (Skeet SameLine(219))
    local swatch = mk("TextButton", { Parent = row, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.fromOffset(22, 9),
        BackgroundColor3 = default,
        AutoButtonColor = false, Text = "" })
    stroke(swatch, Theme.BorderOuter, 1)
    local swGrad = Instance.new("UIGradient"); swGrad.Name = "\0"
    swGrad.Rotation = 90
    swGrad.Parent = swatch

    local opt_obj = { Value = default }
    local function applySwatchGradient(c)
        swGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, c),
            ColorSequenceKeypoint.new(1, Color3.new(
                math.max(0, c.R - 0.4),
                math.max(0, c.G - 0.4),
                math.max(0, c.B - 0.4)))}
    end
    applySwatchGradient(default)

    function opt_obj:SetValue(c)
        if typeof(c) ~= "Color3" then return end
        self.Value = c
        swatch.BackgroundColor3 = c
        applySwatchGradient(c)
        safeCallback(opt.Callback, c)
    end
    Library.Options[id] = opt_obj

    -- Popup: SV box + Hue strip + RGB readout
    local popup
    local function closePopup()
        if popup then popup:Destroy(); popup = nil end
        if Library.ActivePopup and Library.ActivePopup.Owner == swatch then
            Library.ActivePopup = nil
        end
    end
    local function openPopup()
        closeActivePopup()
        local abs = swatch.AbsolutePosition; local sz = swatch.AbsoluteSize
        local W, H = 180, 160
        popup = mk("Frame", { Parent = ScreenGui, BorderSizePixel = 0,
            Position = UDim2.fromOffset(abs.X + sz.X - W, abs.Y + sz.Y + 2),
            Size = UDim2.fromOffset(W, H),
            BackgroundColor3 = Theme.PopupFill, ZIndex = 100 })
        doubleBorder(popup, Theme.BorderInner, Theme.BorderBlack)

        local h, s, v = Color3.toHSV(opt_obj.Value)

        -- SV picker (left ~110x110)
        local sv = mk("Frame", { Parent = popup, BorderSizePixel = 0,
            Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(110, 110),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1), ZIndex = 101 })
        local satGrad = Instance.new("UIGradient"); satGrad.Name = "\0"
        satGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))}
        satGrad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1)}
        satGrad.Parent = sv
        local valGrad = Instance.new("Frame"); valGrad.Name = "\0"
        valGrad.Parent = sv; valGrad.Size = UDim2.fromScale(1,1)
        valGrad.BorderSizePixel = 0; valGrad.BackgroundColor3 = Color3.new(0,0,0)
        valGrad.BackgroundTransparency = 0; valGrad.ZIndex = 102
        local vGrad = Instance.new("UIGradient"); vGrad.Name = "\0"; vGrad.Rotation = 90
        vGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0))}
        vGrad.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0)}
        vGrad.Parent = valGrad

        local svDot = mk("Frame", { Parent = sv, BorderSizePixel = 0,
            Size = UDim2.fromOffset(5, 5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255,255,255), ZIndex = 110 })
        local svDotCorner = Instance.new("UICorner"); svDotCorner.Name = "\0"
        svDotCorner.CornerRadius = UDim.new(1, 0); svDotCorner.Parent = svDot
        stroke(svDot, Theme.BorderBlack, 1)

        -- Hue strip (vertical, right ~12x110)
        local hue = mk("Frame", { Parent = popup, BorderSizePixel = 0,
            Position = UDim2.fromOffset(124, 6), Size = UDim2.fromOffset(12, 110),
            BackgroundColor3 = Color3.fromRGB(255,0,0), ZIndex = 101 })
        local hueGrad = Instance.new("UIGradient"); hueGrad.Name = "\0"; hueGrad.Rotation = 90
        hueGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255,0,0)),
            ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255,255,0)),
            ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0,255,0)),
            ColorSequenceKeypoint.new(0.500, Color3.fromRGB(0,255,255)),
            ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0,0,255)),
            ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255,0,255)),
            ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255,0,0))}
        hueGrad.Parent = hue
        local hueMark = mk("Frame", { Parent = hue, BorderSizePixel = 0,
            Position = UDim2.new(0, 0, h, -1), Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Color3.fromRGB(255,255,255), ZIndex = 110 })

        -- RGB readout
        local rgbLbl = mk("TextLabel", { Parent = popup, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(6, 122), Size = UDim2.fromOffset(W-12, 14),
            Text = "", TextSize = 11, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 102 })
        applyFont(rgbLbl, false); dropShadowText(rgbLbl)
        local hexLbl = mk("TextLabel", { Parent = popup, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(6, 138), Size = UDim2.fromOffset(W-12, 14),
            Text = "", TextSize = 11, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 102 })
        applyFont(hexLbl, false); dropShadowText(hexLbl)

        local function refresh()
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            svDot.Position = UDim2.new(s, 0, 1 - v, 0)
            hueMark.Position = UDim2.new(0, 0, h, -1)
            local c = Color3.fromHSV(h, s, v)
            opt_obj:SetValue(c)
            local r8 = math.floor(c.R*255+0.5); local g8 = math.floor(c.G*255+0.5); local b8 = math.floor(c.B*255+0.5)
            rgbLbl.Text = ("RGB  %d, %d, %d"):format(r8, g8, b8)
            hexLbl.Text = ("HEX  #%02X%02X%02X"):format(r8, g8, b8)
        end
        refresh()

        local dragSV, dragHue
        local function pickSV(px, py)
            local a = sv.AbsolutePosition; local z = sv.AbsoluteSize
            s = math.clamp((px - a.X) / math.max(z.X,1), 0, 1)
            v = 1 - math.clamp((py - a.Y) / math.max(z.Y,1), 0, 1)
            refresh()
        end
        local function pickHue(py)
            local a = hue.AbsolutePosition; local z = hue.AbsoluteSize
            h = math.clamp((py - a.Y) / math.max(z.Y,1), 0, 1)
            refresh()
        end
        trackConn(sv.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragSV = true; pickSV(input.Position.X, input.Position.Y)
            end
        end))
        trackConn(hue.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragHue = true; pickHue(input.Position.Y)
            end
        end))
        trackConn(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch then
                if dragSV then pickSV(input.Position.X, input.Position.Y) end
                if dragHue then pickHue(input.Position.Y) end
            end
        end))
        trackConn(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragSV, dragHue = false, false
            end
        end))

        local rec = { Owner = swatch, IgnoreNext = true, OnClose = closePopup }
        Library.ActivePopup = rec
    end
    trackConn(swatch.MouseButton1Click:Connect(function()
        if popup then closePopup() else openPopup() end
    end))

    -- Chain another color picker (Skeet does this: toggle + 2 color pickers)
    function opt_obj:AddColorPicker(cid, copt) return buildColorPicker(row, cid, copt, true) end

    return opt_obj
end

-- ──────────────────────────────────────────────────────────────────────────
-- KEY PICKER
-- ──────────────────────────────────────────────────────────────────────────
function buildKeyPicker(row, id, opt, inline)
    opt = opt or {}
    assert(row and row.Parent, "buildKeyPicker: row missing")

    local function keyText(k)
        if not k then return "[None]" end
        if typeof(k) == "EnumItem" then return ("[%s]"):format(k.Name) end
        return ("[%s]"):format(tostring(k))
    end
    local key = opt.Default
    if typeof(key) == "string" then
        local ok, en = pcall(function() return Enum.KeyCode[key] end)
        if ok and en then key = en end
    end

    local lbl = mk("TextButton", { Parent = row, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.fromOffset(48, 13),
        BackgroundColor3 = Theme.ComboFill, AutoButtonColor = false,
        Text = keyText(key), TextSize = 11, TextColor3 = Theme.Text })
    stroke(lbl, Theme.BorderOuter, 1)
    applyFont(lbl, false); dropShadowText(lbl)

    if not inline then
        mk("TextLabel", { Parent = row, BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -54, 1, 0),
            Text = opt.Text or id, TextSize = 11, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center })
    end

    local opt_obj = { Value = key, _label = lbl }
    function opt_obj:SetValue(k) self.Value = k; lbl.Text = keyText(k); safeCallback(opt.Callback, k) end
    Library.Options[id] = opt_obj

    local listening
    local function startListen()
        if listening then return end
        listening = true
        lbl.Text = "[...]"
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                opt_obj:SetValue(input.KeyCode)
                listening = false
                if conn then conn:Disconnect() end
            end
        end)
    end
    trackConn(lbl.MouseButton1Click:Connect(startListen))
    return opt_obj
end

-- ──────────────────────────────────────────────────────────────────────────
-- GROUPBOX — 258 wide, double border, title breaking the top edge
-- ──────────────────────────────────────────────────────────────────────────
local function buildGroupbox(parent, name)
    local box = mk("Frame", { Parent = parent, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.GroupFill,
        AutomaticSize = Enum.AutomaticSize.Y })
    multiStroke(box, "shallow")

    -- Title — sits ON the top border, masks the 5-stroke band beneath it
    -- by using a matching fill background. Skeet's "title-break rect".
    local titleLbl = mk("TextLabel", { Parent = box,
        BackgroundColor3 = Theme.GroupFill, BorderSizePixel = 0,
        Position = UDim2.fromOffset(9, -6), Size = UDim2.fromOffset(0, 11),
        Text = "  " .. (name or "") .. "  ", TextSize = 11,
        TextColor3 = Theme.Title,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        AutomaticSize = Enum.AutomaticSize.X, ZIndex = 5 })
    applyFont(titleLbl, true); dropShadowText(titleLbl)

    -- Body inside box, tight Skeet-style padding (6px each side to clear 5-stroke band).
    -- Y component MUST be 0 here — pairing (1, -12) with AutomaticSize.Y causes
    -- Roblox to treat the Y scale as a minimum that collapses everything to 0.
    local body = mk("Frame", { Parent = box, BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 0),
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y })
    uiList(body, Enum.FillDirection.Vertical, 2)
    -- Top spacer below title (Skeet CustomSpacing(9.f) accounts for title height)
    local topSpacer = mk("Frame", { Parent = body, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1, LayoutOrder = -1 })

    local gb = { _frame = box, _body = body, _title = titleLbl }
    attachWidgets(gb, body)
    return gb
end

-- ──────────────────────────────────────────────────────────────────────────
-- CREATE WINDOW
-- ──────────────────────────────────────────────────────────────────────────
function Library:CreateWindow(opts)
    opts = opts or {}
    -- User base = 350×450. Header (title + tabs) needs +40px → total 350×490.
    -- Base structure (5-stroke deep, UIPadding 20, Tab frame, GroupBox) is preserved
    -- verbatim from user's reference; we only ADD a header strip above.
    local BASE_W, BASE_H = 350, 490
    if opts.Size then BASE_W = opts.Size.X.Offset; BASE_H = opts.Size.Y.Offset end
    local HEADER = 40    -- top strip that holds rainbow + title + tab row

    -- ── BASE (350×490, RGB 18,18,18, 5 deep strokes) ─────────────────────
    local Window = mk("Frame", { Parent = ScreenGui,
        Size = UDim2.fromOffset(BASE_W, BASE_H),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.BaseFill,
        BorderSizePixel = 0, Active = true })
    multiStroke(Window, "deep")

    -- Window drag handle (covers top header strip, including title area)
    local dragging, dragStart, startPos
    local dragLayer = mk("TextButton", { Parent = Window, BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 18), ZIndex = 2 })
    trackConn(dragLayer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Window.Position
        end
    end))
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    -- ── RAINBOW BAR (exact user-reference positioning) ───────────────────
    -- Shadow 1px black @ 0.5 transparency at (6, 7)
    mk("Frame", { Parent = Window, BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 7),
        Size = UDim2.fromOffset(BASE_W - 12, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.5, ZIndex = 3 })
    -- Rainbow 2px at (6, 6)
    local rainbow = mk("Frame", { Parent = Window, BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(BASE_W - 12, 2),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 4 })
    local rainbowGrad = Instance.new("UIGradient"); rainbowGrad.Name = "\0"
    rainbowGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.000, Theme.UCcyan),
        ColorSequenceKeypoint.new(0.500, Theme.UCpink),
        ColorSequenceKeypoint.new(1.000, Theme.UCyellow)}
    rainbowGrad.Parent = rainbow

    -- ── HEADER: title (top-left) + tab row (below title) ─────────────────
    local titleLbl = mk("TextLabel", { Parent = Window,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 12),
        Size = UDim2.fromOffset(BASE_W - 16, 12),
        Text = opts.Title or "skeezt", TextSize = 11, TextColor3 = Theme.Title,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 3 })
    applyFont(titleLbl, true); dropShadowText(titleLbl)

    local TabRow = mk("Frame", { Parent = Window, BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, 26),
        Size = UDim2.new(0, BASE_W - 40, 0, 14),
        BackgroundTransparency = 1, ZIndex = 3 })
    uiList(TabRow, Enum.FillDirection.Horizontal, 14)

    -- ── TAB FRAME (user-reference 310×408, positioned at (20, HEADER+20)
    --     to reproduce the user's padded-inner placement WITHOUT applying a
    --     UIPadding to Window (which would shift the rainbow/title/tabRow).
    local TabFrame = mk("Frame", { Parent = Window, BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, HEADER + 20),
        Size = UDim2.fromOffset(BASE_W - 40, BASE_H - HEADER - 40),
        BackgroundColor3 = Theme.TabFill, ZIndex = 2 })
    multiStroke(TabFrame, "shallow")

    local self_ = { _window = Window, _tabs = {}, _activeTab = nil, _tabRow = TabRow }

    function self_:AddTab(name)
        local idx = #self_._tabs + 1

        -- ── Tab button: text-only, no underline (per user) ──────────────
        local tabBtn = mk("TextButton", { Parent = TabRow, BorderSizePixel = 0,
            Size = UDim2.fromOffset(0, 14), BackgroundTransparency = 1,
            AutoButtonColor = false, AutomaticSize = Enum.AutomaticSize.X,
            Text = "", ZIndex = 3 })

        local nameLbl = mk("TextLabel", { Parent = tabBtn, BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0), Position = UDim2.fromOffset(0, 0),
            Text = name or "?", TextSize = 12, TextColor3 = Theme.SubText,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            AutomaticSize = Enum.AutomaticSize.X, ZIndex = 4 })
        applyFont(nameLbl, true); dropShadowText(nameLbl)

        -- ── Tab content: 2-column groupbox grid, matches user's GroupBox
        --     position (20px in from Tab edge) but split into Left + Right.
        --     Inside Tab frame (310×N), inner area = 310-40 = 270 wide.
        --     Two columns @ 132 wide with 6px gap between them.
        local page = mk("Frame", { Parent = TabFrame, BorderSizePixel = 0,
            Position = UDim2.fromOffset(20, 20),
            Size = UDim2.new(1, -40, 1, -40),
            BackgroundTransparency = 1, Visible = false, ZIndex = 3 })

        local leftCol = mk("ScrollingFrame", { Parent = page, BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(0.5, -3, 1, 0),
            BackgroundTransparency = 1, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.BorderInner,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 })
        local rightCol = mk("ScrollingFrame", { Parent = page, BorderSizePixel = 0,
            Position = UDim2.new(0.5, 3, 0, 0),
            Size = UDim2.new(0.5, -3, 1, 0),
            BackgroundTransparency = 1, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.BorderInner,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 })
        uiList(leftCol,  Enum.FillDirection.Vertical, 6)
        uiList(rightCol, Enum.FillDirection.Vertical, 6)

        local tab = { _page = page, _btn = tabBtn, _name = nameLbl,
                      _left = leftCol, _right = rightCol }

        function tab:AddLeftGroupbox(nm)  return buildGroupbox(leftCol,  nm) end
        function tab:AddRightGroupbox(nm) return buildGroupbox(rightCol, nm) end

        self_._tabs[idx] = tab
        trackConn(tabBtn.MouseButton1Click:Connect(function() self_:SelectTab(tab) end))
        if not self_._activeTab then self_:SelectTab(tab) end
        return tab
    end

    function self_:SelectTab(tab)
        for _, t in self_._tabs do
            local sel = (t == tab)
            t._page.Visible = sel
            -- Selected = bright white (full color), unselected = dim subtext.
            -- NO glow / underline (per user feedback).
            t._name.TextColor3 = sel and Color3.fromRGB(245, 245, 245) or Theme.SubText
        end
        self_._activeTab = tab
    end

    return self_
end

-- ──────────────────────────────────────────────────────────────────────────
-- TOGGLE / KEYBIND / UNLOAD
-- ──────────────────────────────────────────────────────────────────────────
function Library:Toggle()
    self.Visible = not self.Visible
    ScreenGui.Enabled = self.Visible
end
function Library:SetToggleKey(k)
    if typeof(k) == "EnumItem" then self.ToggleKey = k
    elseif type(k) == "string" then
        local ok, en = pcall(function() return Enum.KeyCode[k] end)
        if ok and en then self.ToggleKey = en end
    end
end
trackConn(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Library.ToggleKey then
        Library:Toggle()
    end
end))

function Library:Unload()
    self.Unloaded = true
    for _, c in self.Connections do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    pcall(function() ScreenGui:Destroy() end)
end

return Library
