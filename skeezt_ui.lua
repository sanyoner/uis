--[[ ════════════════════════════════════════════════════════════════════════
    nachtara | UI v3-gs — GameSense IMGUI port, top tabs (no icons)
    Date: 2026-05-26

    BASIS:
      Widget pixel-cadence cloned 1:1 from skeezt's imgui_widgets.cpp / imgui.cpp:
        Checkbox    → imgui_widgets.cpp:1459 (8x8 inset, vertical gradient,
                       inactive 76/51, hover 86/61, checked = MenuTheme/alpha)
        Slider      → imgui_widgets.cpp:3068 (52/68 track, 62/78 hover,
                       MenuTheme fill, centered bold value, label above)
        GroupBox    → imgui.cpp:4764 GroupBoxTitleEx (title chip OVER border)
        MenuTheme   → imgui_draw.cpp:181  RGB(147, 197, 57) — lime green
      Window outline pulled from sanyo's GameScat base (5-stroke layered
      via UIStroke.BorderOffset, palette 13/61/41/61/13).

    LAYOUT DEVIATION:
      Tabs are HORIZONTAL at the TOP of the window (Linoria style, no icons)
      instead of GS's left-side vertical icon sidebar. Rainbow strip + 1px
      shadow live at Y=6 of the OUTER window (not inside any padding area).

    ASSETS — three local font caches in this workspace are preferred over
    HTTP fetches (already present from prior scripts):
        VerdanaBoldAF.font     — Bold (groupbox titles, slider values, tabs)
        VerdanaNomarl_AF.font  — Regular (widget labels, dropdowns)
        SmallestPixel.font     — Tiny pixel font (keybind text "[F]" / "[-]")
      Falls back to github (sanyoner/fonts) then to Roblox builtin Verdana.
      Background image (skeezt_menu_bg.png) cached locally too, github fallback.

    PUBLIC API (parity with nachtara_ui.lua v2 — drop-in compatible):
      Library:CreateWindow{Title=…, Size=…}
      Window:AddTab(name)
      Tab:AddLeftGroupbox(name)  /  AddRightGroupbox(name)
      Groupbox:AddToggle / AddSlider / AddButton / AddDropdown
              AddColorPicker / AddKeyPicker / AddLabel / AddDivider
              AddDependencyBox
      Toggle's chain: AddColorPicker / AddKeyPicker (inline next to row)
      Library.Toggles[id].Value / :SetValue(v)
      Library.Options[id].Value / :SetValue(v)
      Library:Toggle() / :Unload() / :SetToggleKey(key)
═════════════════════════════════════════════════════════════════════════ ]]

local _cloneref = (type(cloneref) == "function") and cloneref or function(x) return x end
local Players          = _cloneref(game:GetService("Players"))
local CoreGui          = _cloneref(game:GetService("CoreGui"))
local RunService       = _cloneref(game:GetService("RunService"))
local UserInputService = _cloneref(game:GetService("UserInputService"))
local TextService      = _cloneref(game:GetService("TextService"))
local LocalPlayer      = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════
-- THEME — exact RGBs from skeezt imgui source + sanyo's base.
-- ══════════════════════════════════════════════════════════════════════════
local Theme = {
    -- Layered surface fills (base script G2L["2"]/d/13/19/1f)
    WindowBg    = Color3.fromRGB(18, 18, 18),
    TabBg       = Color3.fromRGB(25, 25, 25),
    GroupBg     = Color3.fromRGB(36, 36, 36),

    -- 5-stroke layered border palette (base G2L["7"]-["b"])
    BorderDark  = Color3.fromRGB(13, 13, 13),
    BorderHi    = Color3.fromRGB(61, 61, 61),
    BorderMid   = Color3.fromRGB(41, 41, 41),
    BorderInk   = Color3.fromRGB(10, 10, 10),     -- imgui_widgets.cpp:1503,3122

    -- Checkbox gradient (imgui_widgets.cpp:1504-1509)
    ChkTop      = Color3.fromRGB(76, 76, 76),
    ChkBottom   = Color3.fromRGB(51, 51, 51),
    ChkTopHov   = Color3.fromRGB(86, 86, 86),
    ChkBotHov   = Color3.fromRGB(61, 61, 61),

    -- Slider gradient (imgui_widgets.cpp:3123-3128)
    SliderTop      = Color3.fromRGB(52, 52, 52),
    SliderBottom   = Color3.fromRGB(68, 68, 68),
    SliderTopHov   = Color3.fromRGB(62, 62, 62),
    SliderBotHov   = Color3.fromRGB(78, 78, 78),

    -- Text
    Text        = Color3.fromRGB(225, 225, 225),
    TextDim     = Color3.fromRGB(135, 135, 140),
    TextActive  = Color3.fromRGB(255, 255, 255),

    -- MenuTheme accent (imgui_draw.cpp:181 ImColor(147,197,57))
    Accent      = Color3.fromRGB(147, 197, 57),

    -- Hover bg in selectables (imgui_widgets.cpp:5942 → ImColor(24,24,24))
    HoverBg     = Color3.fromRGB(24, 24, 24),

    -- Rainbow strip stops (base G2L["6"])
    RainbowA    = Color3.fromRGB(56, 181, 221),
    RainbowB    = Color3.fromRGB(201, 81,  201),
    RainbowC    = Color3.fromRGB(201, 201, 51),
}

-- Returns (accent, accent_darker) for slider/checkbox fill gradients —
-- "MenuTheme - alpha120" in skeezt source ≈ Value reduced by ~47%.
local function accentGradStops()
    local h, s, v = Color3.toHSV(Theme.Accent)
    return Theme.Accent, Color3.fromHSV(h, s, math.max(0, v - 0.18))
end

-- ══════════════════════════════════════════════════════════════════════════
-- EXTERNAL ASSETS — only the 3 custom fonts we actually need + bg image.
-- Priority:
--   1. Workspace cache (already present from earlier scripts):
--        VerdanaBoldAF.font    — Bold (titles, slider values, tabs)
--        VerdanaNomarl_AF.font — Regular (widget labels, dropdowns)
--        SmallestPixel.font    — Pixel (keybind "[F]" / "[-]")
--        skeezt_menu_bg.png    — window background texture
--   2. HTTPS-download from github.com/sanyoner/fonts +
--      github.com/sanyoner/misc, write to workspace, register via
--      getcustomasset, build a one-face Font.new per weight.
--   NO Roblox-builtin font fallback. If a custom font fails to load,
--   applyFont uses whichever other custom font IS available.
-- ══════════════════════════════════════════════════════════════════════════
local FONTS_REPO = "https://raw.githubusercontent.com/sanyoner/fonts/main/"
local BG_URL     = "https://raw.githubusercontent.com/sanyoner/misc/main/skeezt_menu_bg.png"

local function customAsset(path)
    if type(getcustomasset) == "function" then
        local ok, r = pcall(getcustomasset, path)
        if ok and type(r) == "string" then return r end
    end
    if type(getsynasset) == "function" then
        local ok, r = pcall(getsynasset, path)
        if ok and type(r) == "string" then return r end
    end
    return nil
end

local function ensureFile(localPath, url)
    if type(writefile) ~= "function" then return false end
    if type(isfile) == "function" and isfile(localPath) then return true end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" or #body < 256 then return false end
    return (pcall(writefile, localPath, body)) and true or false
end

-- Wraps a TTF asset URL in a one-face FontFamily JSON descriptor with
-- weight=400 / style="Normal", writes it to disk, and registers via
-- customAsset(). Returns a Font.new bound to Enum.FontWeight.Regular,
-- which matches the weight we just wrote.
--
-- We DON'T reuse the existing workspace .font wrappers because those
-- declare weight=100 (Thin) and Roblox's Font.new(family, Regular)
-- silently fails to find a matching face there → blank text.
local function buildSingleFaceFont(ttfAsset, family)
    if not ttfAsset or type(writefile) ~= "function" then return nil end
    local json = string.format(
        '{"name":"%s","faces":[{"name":"Regular","weight":400,"style":"Normal","assetId":"%s"}]}',
        family, ttfAsset)
    local jpath = "nachtara_" .. family .. ".json"
    pcall(writefile, jpath, json)
    local ja = customAsset(jpath)
    if not ja then return nil end
    local ok, f = pcall(Font.new, ja, Enum.FontWeight.Regular)
    return ok and f or nil
end

-- Try the raw TTF in the workspace first (always weight=400 when we
-- wrap it ourselves). Falls back to a fresh github download.
local function loadCustomFont(cachedTtfPath, ghTtfName, familyName)
    if cachedTtfPath then
        local ca = customAsset(cachedTtfPath)
        if ca then
            local f = buildSingleFaceFont(ca, familyName)
            if f then return f end
        end
    end
    local localTtf = "nachtara_" .. ghTtfName
    if ensureFile(localTtf, FONTS_REPO .. ghTtfName) then
        local ttfAsset = customAsset(localTtf)
        if ttfAsset then
            return buildSingleFaceFont(ttfAsset, familyName)
        end
    end
    return nil
end

local FONT_REG, FONT_BOLD, FONT_PIXEL, BG_ASSET
FONT_REG   = loadCustomFont("VerdanaNormal.ttf",  "Verdana-Font.ttf",     "Verdana")
FONT_BOLD  = loadCustomFont("VerdanaBold.ttf",    "Verdana-Bold.ttf",     "VerdanaBold")
FONT_PIXEL = loadCustomFont("SmallestPixel.ttf",  "smallest_pixel-7.ttf", "SmallestPixel")

-- Background image — workspace cache first, github fallback.
BG_ASSET = customAsset("skeezt_menu_bg.png")
if not BG_ASSET then
    if ensureFile("skeezt_menu_bg.png", BG_URL) then
        BG_ASSET = customAsset("skeezt_menu_bg.png")
    end
end

-- applyFont — picks the requested font kind; degrades GRACEFULLY between
-- our 3 custom fonts (never falls back to Roblox built-in). If literally
-- no custom font loaded, leaves the Font property at its default so text
-- still renders (worst case: Roblox Legacy, but only if HTTPS + workspace
-- caches both failed which should never happen in practice).
local function applyFont(textInst, kind)
    local f
    if kind == "bold" then
        f = FONT_BOLD or FONT_REG or FONT_PIXEL
    elseif kind == "pixel" then
        f = FONT_PIXEL or FONT_REG or FONT_BOLD
    else
        f = FONT_REG or FONT_BOLD or FONT_PIXEL
    end
    if f then textInst.FontFace = f end
end

-- ══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════════════════════
local function mk(class, props)
    local inst = Instance.new(class)
    inst.Name = "\0"
    if props then for k, v in props do pcall(function() inst[k] = v end) end end
    return inst
end

-- Adds a 1px UIStroke to every text instance (replaces the legacy
-- TextStrokeTransparency property). 1px black outline at the edge of
-- each glyph — the GameSense pixel-shadow look that reads cleanly over
-- both the bg image and any flat dropdown/button surface.
local function applyTextOutline(textInst)
    local s = Instance.new("UIStroke"); s.Name = "\0"
    s.Color = Color3.new(0, 0, 0)
    s.Thickness = 1
    s.Transparency = 0
    s.LineJoinMode = Enum.LineJoinMode.Miter
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    s.Parent = textInst
    return s
end

-- mkText with auto-outline. fontKind = "bold"/"pixel"/"reg". `noOutline=true`
-- on the props table opts out (used by e.g. the slider value text which
-- carries its own stroke styling).
local function mkText(class, props, fontKind)
    local skip = props and props._noOutline
    if props then props._noOutline = nil end
    local t = mk(class, props)
    applyFont(t, fontKind)
    if not skip then applyTextOutline(t) end
    return t
end

-- 5-stroke layered border via UIStroke.BorderOffset.
-- "outer" = thicker (7px composite), "inner" = thinner (5px composite).
local function applyLayeredStrokes(host, kind)
    local set
    if kind == "outer" then
        set = {
            { off =  0, t = 1, c = Theme.BorderDark },
            { off = -1, t = 1, c = Theme.BorderHi   },
            { off = -4, t = 3, c = Theme.BorderMid  },
            { off = -5, t = 1, c = Theme.BorderHi   },
            { off = -6, t = 1, c = Theme.BorderDark },
        }
    else
        set = {
            { off =  0, t = 1, c = Theme.BorderDark },
            { off = -1, t = 1, c = Theme.BorderHi   },
            { off = -2, t = 1, c = Theme.BorderMid  },
            { off = -3, t = 1, c = Theme.BorderHi   },
            { off = -4, t = 1, c = Theme.BorderDark },
        }
    end
    for _, s in set do
        local st = Instance.new("UIStroke"); st.Name = "\0"
        st.Color = s.c
        st.Thickness = s.t
        st.LineJoinMode = Enum.LineJoinMode.Miter
        st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        st.BorderOffset = UDim.new(0, s.off)
        st.Parent = host
    end
end

local function listLayout(parent, dir, p, align)
    local l = Instance.new("UIListLayout"); l.Name = "\0"
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, p or 4)
    if align then l.VerticalAlignment = align end
    l.Parent = parent
    return l
end

local function uipad(parent, t, r, b, l)
    if r == nil then r = t; b = t; l = t end
    local up = Instance.new("UIPadding"); up.Name = "\0"
    up.PaddingTop    = UDim.new(0, t)
    up.PaddingRight  = UDim.new(0, r)
    up.PaddingBottom = UDim.new(0, b)
    up.PaddingLeft   = UDim.new(0, l)
    up.Parent = parent
    return up
end

-- Apply a vertical gradient (top→bottom). Returns the UIGradient.
local function vGradient(parent, topC, bottomC)
    local g = Instance.new("UIGradient"); g.Name = "\0"
    g.Rotation = 90
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, topC),
        ColorSequenceKeypoint.new(1, bottomC),
    }
    g.Parent = parent
    return g
end

-- 1px dark ink border (skeezt RGB(10,10,10) line around inputs).
local function inkBorder(parent)
    local s = Instance.new("UIStroke"); s.Name = "\0"
    s.Color = Theme.BorderInk
    s.Thickness = 1
    s.LineJoinMode = Enum.LineJoinMode.Miter
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function safeCallback(fn, ...) if type(fn) == "function" then pcall(fn, ...) end end
local function hsv(c) return Color3.toHSV(c) end

-- Manual text width approximation — TextService:GetTextSize requires an
-- Enum.Font argument which we deliberately don't use (the user's UI is
-- 100% custom-font; pulling in Enum.Font.SourceSans here would dilute that
-- intent). Multipliers tuned per font kind for Verdana + SmallestPixel.
local function measureText(str, size, kind)
    str = tostring(str or "")
    size = size or 11
    local mult = 0.57    -- Verdana Regular avg char width
    if kind == "bold" then
        mult = 0.62      -- Verdana Bold slightly wider
    elseif kind == "pixel" then
        mult = 0.42      -- SmallestPixel monospace-ish, narrower
    end
    return math.ceil(#str * size * mult), size + 2
end

-- Wraps a widget table so it exposes `:OnChanged(cb)` and fires every
-- registered listener whenever SetValue runs (unless `supp=true` is passed).
-- Drop-in for sanyui parity — SaveManager / ESPPreview / per-feature code in
-- main.lua all chain `Toggles.X:OnChanged(...)` after registration.
local function withOnChanged(widget)
    widget._listeners = widget._listeners or {}
    local origSetValue = widget.SetValue
    widget.SetValue = function(self, v, supp, ...)
        origSetValue(self, v, supp, ...)
        if not supp then
            for _, cb in self._listeners do pcall(cb, self.Value) end
        end
    end
    -- ColorPicker exposes a second setter for the SaveManager (RGB + alpha).
    -- Fire listeners after that path too so config-load handlers run.
    if widget.SetValueRGB then
        local origRGB = widget.SetValueRGB
        widget.SetValueRGB = function(self, c, t, supp)
            origRGB(self, c, t)
            if not supp then
                for _, cb in self._listeners do pcall(cb, self.Value) end
            end
        end
    end
    function widget:OnChanged(cb)
        if type(cb) == "function" then
            self._listeners[#self._listeners + 1] = cb
        end
        return self
    end
    return widget
end

-- ══════════════════════════════════════════════════════════════════════════
-- LIBRARY ROOT + SCREENGUI
-- ══════════════════════════════════════════════════════════════════════════
local Library = {
    Theme = Theme,
    Toggles = {}, Options = {},
    Connections = {}, DepRefreshers = {},
    Visible = true, Unloaded = false,
    ToggleKey = Enum.KeyCode.End,
    ActivePopup = nil, ActiveKeyPicker = nil,

    _AssetStatus = {
        FontReg    = (FONT_REG    ~= nil),
        FontBold   = (FONT_BOLD   ~= nil),
        FontPixel  = (FONT_PIXEL  ~= nil),
        Background = (BG_ASSET    ~= nil),
        Source     = "Potassium workspace cache + github.com/sanyoner fallback",
    },
}

-- sanyui parity: main.lua + addons (SaveManager / ESPPreview / feature code)
-- read widget state via bare `Toggles.X` / `Options.X` globals (no Library
-- prefix). sanyui.lua exports them at line 23-24; without these the first
-- unguarded `Toggles.X` access throws nil-index and halts construction
-- mid-tab. Bound to Library.Toggles/Library.Options so AddToggle/AddSlider/
-- AddDropdown writes are immediately visible through the globals.
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        env.Toggles = Library.Toggles
        env.Options = Library.Options
    end
end

local function getContainer()
    local okH, hui = pcall(function() if type(gethui) == "function" then return gethui() end end)
    if okH and hui then return hui end
    return _cloneref(game:GetService("CoreGui"))
end
local CONTAINER = getContainer()

-- Sibling ZIndexBehavior: children always render above their parents,
-- siblings sort by ZIndex within the same parent. Avoids the Global-mode
-- bug where Content (ZIndex 4) covers groupbox widgets at default ZIndex.
local ScreenGui = mk("ScreenGui", {
    DisplayOrder = 50000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true, ResetOnSpawn = false,
})
pcall(function() ScreenGui.Parent = CONTAINER end)
Library.ScreenGui = ScreenGui

local function track(c) Library.Connections[#Library.Connections + 1] = c; return c end

local function notifyDepChange()
    for _, fn in Library.DepRefreshers do pcall(fn) end
end

local function closeActivePopup()
    if Library.ActivePopup then
        local p = Library.ActivePopup
        Library.ActivePopup = nil
        if p.OnClose then pcall(p.OnClose) end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- WIDGET BUILDER
-- ══════════════════════════════════════════════════════════════════════════
local function attachWidgets(target, body)

    ------------------------------------------------------------------ Toggle
    -- Pixel-cadence from imgui_widgets.cpp:1459 (Checkbox):
    --   click square = 14x14, visible filled box at (3,3)..(11,11) = 8x8
    --   Inactive grad: 76,76,76 → 51,51,51   (top to bottom)
    --   Hover    grad: 86,86,86 → 61,61,61
    --   Checked  grad: MenuTheme → MenuTheme darker
    --   1px dark border (10,10,10) around the inner 8x8
    --   Label text: 5px to right of box, baseline -3 (sits centered vertically)
    function target:AddToggle(id, opt)
        opt = opt or {}
        local row = mk("Frame", { Parent = body,
            Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
            LayoutOrder = opt.LayoutOrder or 0 })

        -- 12x12 click region (still comfortable to click, sized down to
        -- fit the 6x6 visible checkbox per user's GS-spec).
        local clickArea = mk("TextButton", { Parent = row,
            Size = UDim2.fromOffset(12, 14), Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "" })

        -- Visible 6x6 box centered in click area at (3, 4). Outline NOT
        -- counted in the 6x6 — inkBorder adds 1px on each side externally.
        local box = mk("Frame", { Parent = clickArea,
            Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(3, 4),
            BackgroundColor3 = Theme.ChkTop, BorderSizePixel = 0 })
        local boxGrad = vGradient(box, Theme.ChkTop, Theme.ChkBottom)
        inkBorder(box)

        -- Label sits to the right of the click area (+5px gap). If
        -- opt.Risky=true the label gets a red asterisk suffix — common
        -- GameSense convention to mark detection-risk features.
        local displayText = opt.Text or id
        if opt.Risky then displayText = displayText .. " *" end
        local lbl = mkText("TextLabel", { Parent = row,
            Position = UDim2.fromOffset(15, 0),
            Size = UDim2.new(1, -15, 1, 0), BackgroundTransparency = 1,
            Text = displayText, TextSize = 12,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, "reg")
        if opt.Risky then
            -- The asterisk gets a red TextColor3 via a TextLabel overlay
            -- — Roblox doesn't support per-character coloring without
            -- RichText. Using RichText keeps it one widget.
            lbl.RichText = true
            lbl.Text = (opt.Text or id) ..
                "  <font color=\"#dd4444\">*</font>"
        end

        local toggle = { Type = "Toggle", Value = opt.Default and true or false, Callback = opt.Callback }

        local function setGrad(hov)
            local a, b = Theme.ChkTop, Theme.ChkBottom
            if toggle.Value then
                a, b = accentGradStops()
            elseif hov then
                a, b = Theme.ChkTopHov, Theme.ChkBotHov
            end
            boxGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, a),
                ColorSequenceKeypoint.new(1, b),
            }
        end
        local function applyVisual()
            setGrad(false)
            if toggle.Value then
                lbl.TextColor3 = Theme.TextActive
                applyFont(lbl, "bold")
            else
                lbl.TextColor3 = Theme.TextDim
                applyFont(lbl, "reg")
            end
        end

        function toggle:SetValue(v, supp)
            self.Value = not not v
            applyVisual()
            if not supp then safeCallback(self.Callback, self.Value) end
            notifyDepChange()
        end
        toggle:SetValue(toggle.Value, true)

        track(clickArea.MouseButton1Click:Connect(function()
            toggle:SetValue(not toggle.Value)
        end))
        track(clickArea.MouseEnter:Connect(function()
            setGrad(true)
            if not toggle.Value then lbl.TextColor3 = Theme.Text end
        end))
        track(clickArea.MouseLeave:Connect(function()
            setGrad(false)
            if not toggle.Value then lbl.TextColor3 = Theme.TextDim end
        end))

        Library.Toggles[id] = withOnChanged(toggle)

        local chain = {}
        function chain:AddColorPicker(cpid, cpopt)
            return target._addColorPickerInline(row, cpid, cpopt)
        end
        function chain:AddKeyPicker(kpid, kpopt)
            kpopt = kpopt or {}
            -- SyncToggleState=true makes the keypicker's "Toggle"-mode flip
            -- drive THIS parent toggle's value (sanyui parity, used by TP
            -- key + other one-key-one-toggle bindings).
            if kpopt.SyncToggleState then kpopt._parentToggle = toggle end
            return target._addKeyPickerInline(row, kpid, kpopt)
        end
        return chain
    end

    ------------------------------------------------------------------ Button
    -- Flat button per real GameSense — solid dark fill (no slider-style
    -- gradient), 1px ink border, bold centered text. Hover = slight
    -- brightness lift on the BG color.
    function target:AddButton(id, opt)
        if type(opt) == "function" then opt = { Callback = opt } end
        opt = opt or {}
        local FLAT      = Color3.fromRGB(34, 34, 34)
        local FLAT_HOV  = Color3.fromRGB(44, 44, 44)
        local btn = mkText("TextButton", { Parent = body,
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundColor3 = FLAT, BorderSizePixel = 0,
            Text = opt.Text or id, TextSize = 12,
            TextColor3 = Theme.TextActive, AutoButtonColor = false,
            LayoutOrder = opt.LayoutOrder or 0,
        }, "bold")
        inkBorder(btn)

        track(btn.MouseEnter:Connect(function() btn.BackgroundColor3 = FLAT_HOV end))
        track(btn.MouseLeave:Connect(function() btn.BackgroundColor3 = FLAT end))
        track(btn.MouseButton1Click:Connect(function() safeCallback(opt.Callback) end))
        return { _btn = btn }
    end

    ------------------------------------------------------------------- Label
    -- Wraps the text in a row frame so chained inline widgets
    -- (AddKeyPicker / AddColorPicker) can attach right-anchored on the
    -- same line — matches sanyui pattern used in main.lua:
    --     dep:AddLabel('Hold key'):AddKeyPicker('K', { Mode = 'Hold' })
    function target:AddLabel(text)
        local row = mk("Frame", { Parent = body,
            Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1,
            BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y })
        local lbl = mkText("TextLabel", { Parent = row,
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            Text = text or "", TextSize = 12,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
        }, "reg")
        local o = { _lbl = lbl, _row = row }
        function o:SetText(s) lbl.Text = s or "" end
        function o:AddKeyPicker(id, opt)
            return target._addKeyPickerInline(row, id, opt)
        end
        function o:AddColorPicker(id, opt)
            return target._addColorPickerInline(row, id, opt)
        end
        return o
    end

    ----------------------------------------------------------------- Divider
    function target:AddDivider()
        local d = mk("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Theme.BorderInk, BorderSizePixel = 0 })
        return { _frame = d }
    end

    ------------------------------------------------------------------ Slider
    -- Pixel-cadence from imgui_widgets.cpp:3068 (SliderScalar):
    --   Label rendered ABOVE bar (offset -18 from frame.Min.y in skeezt).
    --   Bar: vertical gradient 52,52,52 → 68,68,68 inactive,
    --                          62,62,62 → 78,78,78 hover
    --   Fill: MenuTheme top → MenuTheme - alpha120 bottom
    --   Border: 1px RGB(10,10,10) thickness 0.4
    --   Value text: centered on bar, boldMenuFont, multi-pass shadow
    function target:AddSlider(id, opt)
        opt = opt or {}
        local minV, maxV = opt.Min or 0, opt.Max or 100
        local rd, sfx = opt.Rounding or 0, opt.Suffix or ""
        local val = math.clamp(opt.Default or minV, minV, maxV)

        -- 5-px bar + 12-px label above + 1-px gap = 18-px row (tight GS spacing).
        local row = mk("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1, LayoutOrder = opt.LayoutOrder or 0 })

        -- Label above the bar
        mkText("TextLabel", { Parent = row,
            Size = UDim2.new(1, 0, 0, 11), Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, Text = opt.Text or id, TextSize = 11,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, "reg")

        -- 5-px tall bar (outline not counted). Active=true so InputBegan
        -- fires on the Frame.
        local bar = mk("Frame", { Parent = row,
            Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 13),
            BackgroundColor3 = Theme.SliderTop, BorderSizePixel = 0,
            Active = true })
        local barGrad = vGradient(bar, Theme.SliderTop, Theme.SliderBottom)
        inkBorder(bar)

        local function setBarGrad(hovered)
            local a, b = Theme.SliderTop, Theme.SliderBottom
            if hovered then a, b = Theme.SliderTopHov, Theme.SliderBotHov end
            barGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, a),
                ColorSequenceKeypoint.new(1, b),
            }
        end

        local fill = mk("Frame", { Parent = bar, Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })
        local at, ab = accentGradStops()
        vGradient(fill, at, ab)

        -- Value text — anchored at the fill's right edge (the grab tip),
        -- centered on it per skeezt source. We re-position the label every
        -- SetValue() so the text rides the grab as it moves.
        local valTxt = mkText("TextLabel", { Parent = bar,
            Size = UDim2.fromOffset(60, 11),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundTransparency = 1,
            Text = "", TextSize = 11, TextColor3 = Theme.TextActive,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2,
        }, "bold")

        local slider = { Type = "Slider", Value = val, Callback = opt.Callback,
                         Min = minV, Max = maxV, Rounding = rd }
        local function fmt(v)
            if rd <= 0 then return tostring(math.floor(v + 0.5)) end
            local m = 10 ^ rd; return tostring(math.floor(v * m + 0.5) / m)
        end
        function slider:SetValue(v, supp)
            v = math.clamp(v, minV, maxV)
            if rd <= 0 then v = math.floor(v + 0.5)
            else local m = 10 ^ rd; v = math.floor(v * m + 0.5) / m end
            self.Value = v
            local frac = (v - minV) / math.max(maxV - minV, 1e-9)
            fill.Size = UDim2.fromScale(frac, 1)
            valTxt.Text = fmt(v) .. sfx
            -- Center on the grab tip (right edge of fill). Anchor (0.5, 0.5)
            -- means valTxt.Position.X.Scale = fillFrac sits its center on
            -- the fill's right edge.
            valTxt.Position = UDim2.new(frac, 0, 0.5, 0)
            if not supp then safeCallback(self.Callback, v) end
        end
        slider:SetValue(val, true)

        local dragging = false
        local function upd(input)
            local abs = bar.AbsolutePosition.X
            local sz = bar.AbsoluteSize.X
            local frac = math.clamp((input.Position.X - abs) / math.max(sz, 1), 0, 1)
            slider:SetValue(minV + (maxV - minV) * frac)
        end
        track(bar.MouseEnter:Connect(function() setBarGrad(true) end))
        track(bar.MouseLeave:Connect(function() setBarGrad(false) end))
        track(bar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; upd(input)
            end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                            or input.UserInputType == Enum.UserInputType.Touch) then upd(input) end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end))

        Library.Options[id] = withOnChanged(slider)
        return slider
    end

    ---------------------------------------------------------------- Dropdown
    function target:AddDropdown(id, opt)
        opt = opt or {}
        local values = opt.Values or {}
        local multi = opt.Multi == true

        -- sanyui convention: numeric Default on a SINGLE-select dropdown is
        -- a 1-based INDEX into Values, not a literal value. main.lua uses this
        -- pattern heavily (`Default = 1` ≈ "first item, whatever it is"). For
        -- MULTI-select, Default is always an array of value-strings, so leave
        -- it untouched. Resolve at construction so the rest of the dropdown
        -- code compares by string equality like it expects.
        if not multi and type(opt.Default) == "number" and values[opt.Default] ~= nil then
            opt.Default = values[opt.Default]
        end

        local hasLabel = opt.Text ~= nil
        local row = mk("Frame", { Parent = body,
            Size = UDim2.new(1, 0, 0, hasLabel and 28 or 16),
            BackgroundTransparency = 1, LayoutOrder = opt.LayoutOrder or 0 })

        if hasLabel then
            mkText("TextLabel", { Parent = row, Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1, Text = opt.Text, TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left }, "reg")
        end

        -- Flat dropdown per GameSense — solid dark fill, 1px ink border,
        -- right-side indicator is a "-" character (NOT an arrow).
        local DD_FLAT     = Color3.fromRGB(34, 34, 34)
        local DD_FLAT_HOV = Color3.fromRGB(44, 44, 44)
        local mainBtn = mk("TextButton", { Parent = row,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.fromOffset(0, hasLabel and 14 or 0),
            BackgroundColor3 = DD_FLAT, BorderSizePixel = 0,
            Text = "", AutoButtonColor = false })
        inkBorder(mainBtn)

        local valLbl = mkText("TextLabel", { Parent = mainBtn,
            Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(5, 0),
            BackgroundTransparency = 1, Text = "", TextSize = 12,
            TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, "reg")
        -- GS-style "-" indicator on the right (real GS uses a minus glyph,
        -- not a triangle arrow, for dropdowns)
        mkText("TextLabel", { Parent = mainBtn, Size = UDim2.fromOffset(10, 14),
            Position = UDim2.new(1, -10, 0, 0), BackgroundTransparency = 1,
            Text = "-", TextSize = 14, TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, "bold")

        track(mainBtn.MouseEnter:Connect(function() mainBtn.BackgroundColor3 = DD_FLAT_HOV end))
        track(mainBtn.MouseLeave:Connect(function() mainBtn.BackgroundColor3 = DD_FLAT end))

        local dd = { Type = "Dropdown", Value = multi and {} or opt.Default,
                     Callback = opt.Callback, Values = values, Multi = multi }
        local function fmtV()
            if multi then
                local sel = {}
                for k in dd.Value do sel[#sel + 1] = tostring(k) end
                if #sel == 0 then return "None" end
                if #sel <= 3 then return table.concat(sel, ", ") end
                return tostring(#sel) .. " selected"
            end
            return tostring(dd.Value or "None")
        end
        local function refresh() valLbl.Text = fmtV() end

        function dd:SetValue(v, supp)
            if multi then
                local t = {}
                if type(v) == "table" then for _, k in v do t[k] = true end end
                self.Value = t
            else self.Value = v end
            refresh()
            if not supp then safeCallback(self.Callback, self.Value) end
        end
        if opt.Default ~= nil then dd:SetValue(opt.Default, true) else refresh() end

        local popupOuter = mk("Frame", { Parent = ScreenGui,
            Size = UDim2.fromOffset(160, 120),
            BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
            Visible = false, ZIndex = 80 })
        applyLayeredStrokes(popupOuter, "outer")
        uipad(popupOuter, 8)
        local popupInner = mk("Frame", { Parent = popupOuter,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0, ZIndex = 81 })
        applyLayeredStrokes(popupInner, "inner")
        local scroll = mk("ScrollingFrame", { Parent = popupInner,
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.BorderHi,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 82, ScrollingDirection = Enum.ScrollingDirection.Y })
        listLayout(scroll, Enum.FillDirection.Vertical, 1)
        uipad(scroll, 4)

        local rows = {}
        local function applyRowVisual(v, item)
            local active = multi and dd.Value[v] or (dd.Value == v)
            if active then
                item.BackgroundColor3 = Theme.HoverBg
                item.BackgroundTransparency = 0
                applyFont(item, "bold")
                item.TextColor3 = Theme.Accent
            else
                item.BackgroundTransparency = 1
                applyFont(item, "reg")
                item.TextColor3 = Theme.TextDim
            end
        end
        local function refreshRows() for v, r in rows do applyRowVisual(v, r) end end

        -- Row builder extracted so :SetValues can rebuild dynamically (used by
        -- SaveManager to refresh the config-list dropdown after Save/Delete).
        local function addRow(v)
            local item = mkText("TextButton", { Parent = scroll,
                Size = UDim2.new(1, -4, 0, 16),
                BackgroundColor3 = Theme.HoverBg, BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Text = " " .. tostring(v), TextSize = 12,
                TextColor3 = Theme.TextDim, AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 83,
            }, "reg")
            rows[v] = item
            track(item.MouseEnter:Connect(function()
                local active = multi and dd.Value[v] or (dd.Value == v)
                if not active then item.TextColor3 = Theme.Text end
            end))
            track(item.MouseLeave:Connect(function()
                local active = multi and dd.Value[v] or (dd.Value == v)
                if not active then item.TextColor3 = Theme.TextDim end
            end))
            track(item.MouseButton1Click:Connect(function()
                if multi then
                    dd.Value[v] = (dd.Value[v] and nil) or true
                    refresh(); safeCallback(dd.Callback, dd.Value)
                else
                    dd:SetValue(v); popupOuter.Visible = false
                    Library.ActivePopup = nil
                end
                refreshRows()
            end))
        end
        for _, v in values do addRow(v) end
        refreshRows()

        -- SaveManager parity: replaces the dropdown's value list at runtime
        -- (config-list rebuilds after Create/Delete) and clears the current
        -- selection so the caller can drive a fresh pick via SetValue.
        function dd:SetValues(newValues)
            for _, item in rows do pcall(function() item:Destroy() end) end
            for k in rows do rows[k] = nil end
            values = newValues or {}
            self.Values = values
            for _, v in values do addRow(v) end
            refreshRows()
        end

        local function openPopup()
            closeActivePopup()
            local abs = mainBtn.AbsolutePosition
            local sz = mainBtn.AbsoluteSize
            popupOuter.Position = UDim2.fromOffset(abs.X - 8, abs.Y + sz.Y + 4)
            local target_h = math.min(160, math.max(36, #values * 17 + 16))
            popupOuter.Size = UDim2.fromOffset(sz.X + 16, target_h + 16)
            popupOuter.Visible = true
            Library.ActivePopup = {
                OnClose = function() popupOuter.Visible = false end,
                InsideCheck = function(input)
                    local p1, p2 = popupOuter.AbsolutePosition, popupOuter.AbsoluteSize
                    return input.Position.X >= p1.X and input.Position.X <= p1.X + p2.X
                       and input.Position.Y >= p1.Y and input.Position.Y <= p1.Y + p2.Y
                end,
            }
        end
        track(mainBtn.MouseButton1Click:Connect(function()
            if popupOuter.Visible then
                popupOuter.Visible = false; Library.ActivePopup = nil
            else openPopup() end
        end))

        Library.Options[id] = withOnChanged(dd)
        return dd
    end

    -------------------------------------------------------------- ColorPicker
    local function buildColorPicker(parentRow, id, opt, asInline)
        opt = opt or {}
        local default = opt.Default or Color3.new(1, 1, 1)
        local h, s, v = hsv(default)

        local chip
        if asInline then
            chip = mk("TextButton", { Parent = parentRow,
                Size = UDim2.fromOffset(12, 6), AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                BackgroundColor3 = default, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false })
        else
            local row = mk("Frame", { Parent = body,
                Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1})
            mkText("TextLabel", { Parent = row, Position = UDim2.fromOffset(0, 0),
                Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1,
                Text = opt.Text or id, TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
            }, "reg")
            chip = mk("TextButton", { Parent = row,
                Size = UDim2.fromOffset(12, 6), AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                BackgroundColor3 = default, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false })
        end
        inkBorder(chip)

        local cp = { Type = "ColorPicker", Value = default,
                     Transparency = opt.Transparency or 0,
                     Callback = opt.Callback, _h = h, _s = s, _v = v }

        local popup = mk("Frame", { Parent = ScreenGui,
            Size = UDim2.fromOffset(196, 200),
            BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
            Visible = false, ZIndex = 90 })
        applyLayeredStrokes(popup, "outer")
        uipad(popup, 10)
        local innerP = mk("Frame", { Parent = popup,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0, ZIndex = 91 })
        applyLayeredStrokes(innerP, "inner")
        uipad(innerP, 8)

        local svSize = 140
        local svBox = mk("ImageLabel", { Parent = innerP,
            Size = UDim2.fromOffset(svSize, svSize),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0,
            Image = "", ZIndex = 92, Active = true })
        inkBorder(svBox)

        local satGrad = mk("Frame", { Parent = svBox, Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 93 })
        local satG = Instance.new("UIGradient"); satG.Name = "\0"
        satG.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }
        satG.Parent = satGrad

        local valGrad = mk("Frame", { Parent = svBox, Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 94 })
        local valG = Instance.new("UIGradient"); valG.Name = "\0"; valG.Rotation = 90
        valG.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }
        valG.Parent = valGrad

        local svDot = mk("Frame", { Parent = svBox, Size = UDim2.fromOffset(5, 5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 95 })
        inkBorder(svDot)

        local hueStrip = mk("Frame", { Parent = innerP,
            Size = UDim2.fromOffset(14, svSize),
            Position = UDim2.fromOffset(svSize + 8, 0),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            ZIndex = 92, Active = true })
        inkBorder(hueStrip)
        local hueG = Instance.new("UIGradient"); hueG.Name = "\0"; hueG.Rotation = 90
        hueG.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0,   Color3.fromHSV(0,   1, 1)),
            ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
            ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
            ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
            ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
            ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
            ColorSequenceKeypoint.new(1,   Color3.fromHSV(1,   1, 1)) }
        hueG.Parent = hueStrip

        local hueDot = mk("Frame", { Parent = hueStrip, Size = UDim2.new(1, 2, 0, 2),
            Position = UDim2.new(0, -1, h, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 96 })
        inkBorder(hueDot)

        local hexLbl = mkText("TextLabel", { Parent = innerP,
            Size = UDim2.new(1, 0, 0, 12),
            Position = UDim2.fromOffset(0, svSize + 6),
            BackgroundTransparency = 1, TextSize = 12,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 92,
        }, "bold")

        local function update(applyCb)
            local col = Color3.fromHSV(cp._h, cp._s, cp._v)
            cp.Value = col
            chip.BackgroundColor3 = col
            svBox.BackgroundColor3 = Color3.fromHSV(cp._h, 1, 1)
            svDot.Position = UDim2.fromScale(cp._s, 1 - cp._v)
            hueDot.Position = UDim2.new(0, -1, cp._h, 0)
            hexLbl.Text = string.format("#%02X%02X%02X",
                math.floor(col.R * 255 + 0.5),
                math.floor(col.G * 255 + 0.5),
                math.floor(col.B * 255 + 0.5))
            if applyCb then safeCallback(cp.Callback, col) end
        end
        update(false)
        function cp:SetValue(c)
            if typeof(c) ~= "Color3" then return end
            self._h, self._s, self._v = hsv(c); update(true)
        end
        -- SaveManager compatibility: takes Color3 + transparency together.
        function cp:SetValueRGB(c, t)
            if typeof(c) == "Color3" then self._h, self._s, self._v = hsv(c) end
            if type(t) == "number" then self.Transparency = math.clamp(t, 0, 1) end
            update(true)
        end

        local svD, hueD = false, false
        local function svUpd(input)
            local abs, sz = svBox.AbsolutePosition, svBox.AbsoluteSize
            cp._s = math.clamp((input.Position.X - abs.X) / sz.X, 0, 1)
            cp._v = 1 - math.clamp((input.Position.Y - abs.Y) / sz.Y, 0, 1)
            update(true)
        end
        local function hueUpd(input)
            local abs, sz = hueStrip.AbsolutePosition, hueStrip.AbsoluteSize
            cp._h = math.clamp((input.Position.Y - abs.Y) / sz.Y, 0, 1); update(true)
        end
        track(svBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then svD = true; svUpd(input) end
        end))
        track(hueStrip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then hueD = true; hueUpd(input) end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch then
                if svD then svUpd(input) end
                if hueD then hueUpd(input) end
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                svD = false; hueD = false
            end
        end))

        local function openPopup()
            closeActivePopup()
            local abs = chip.AbsolutePosition
            popup.Position = UDim2.fromOffset(abs.X - 196 + 20, abs.Y + 14)
            popup.Visible = true
            Library.ActivePopup = {
                OnClose = function() popup.Visible = false end,
                InsideCheck = function(input)
                    local p1, p2 = popup.AbsolutePosition, popup.AbsoluteSize
                    return input.Position.X >= p1.X and input.Position.X <= p1.X + p2.X
                       and input.Position.Y >= p1.Y and input.Position.Y <= p1.Y + p2.Y
                end,
            }
        end
        track(chip.MouseButton1Click:Connect(function()
            if popup.Visible then popup.Visible = false; Library.ActivePopup = nil
            else openPopup() end
        end))

        Library.Options[id] = withOnChanged(cp)
        return cp
    end
    function target:AddColorPicker(id, opt) return buildColorPicker(nil, id, opt, false) end
    function target._addColorPickerInline(row, id, opt) return buildColorPicker(row, id, opt, true) end

    ---------------------------------------------------------------- KeyPicker
    -- Just a small "[F]" / "[-]" text in SmallestPixel font (height ~6px),
    -- accent color when GetState is true, dim color otherwise. NO visible
    -- box — per user spec the keypicker IS the text.
    --
    -- Interaction:
    --   Left-click   → enter rebind mode → next keypress sets the key
    --   Right-click  → open mode-select popup (Always / Toggle / Hold / Off)
    --
    -- SaveManager contract:
    --   Options[id].Value  = "F" / "MouseButton2" / "None"
    --   Options[id].Mode   = "Always" / "Toggle" / "Hold" / "Off"
    --   Options[id]:SetValue({ keyName, modeName })  ← table arg
    local KEY_MODES_DEFAULT = { "Always", "Toggle", "Hold", "Off" }

    local function buildKeyPicker(parentRow, id, opt, asInline)
        opt = opt or {}
        local defaultKey  = opt.Default or "None"
        local defaultMode = opt.Mode    or "Toggle"
        local modesList   = opt.Modes   or KEY_MODES_DEFAULT
        local parentToggle = opt._parentToggle  -- set by AddToggle chain on SyncToggleState

        -- SyncToggleState locks the keypicker into "Toggle" mode and binds its
        -- _toggleState directly to the parent toggle's Value. sanyui parity.
        if parentToggle then
            defaultMode = "Toggle"
            modesList = { "Toggle" }
        end

        local kp = { Type = "KeyPicker", Value = defaultKey, Mode = defaultMode,
                     Callback = opt.Callback, _toggleState = false,
                     _parentToggle = parentToggle }

        local function bracketText(k)
            if not k or k == "" or k == "None" then return "[-]" end
            return "[" .. tostring(k) .. "]"
        end

        -- The keypicker is a single small TextButton — no surrounding box.
        local picker
        if asInline then
            picker = mkText("TextButton", { Parent = parentRow,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                Size = UDim2.fromOffset(40, 2),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = bracketText(defaultKey), TextSize = 7,
                TextColor3 = Theme.TextDim, AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Center,
                AutomaticSize = Enum.AutomaticSize.X,
            }, "pixel")
        else
            local row = mk("Frame", { Parent = body, Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1 })
            mkText("TextLabel", { Parent = row, Position = UDim2.fromOffset(0, 0),
                Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1,
                Text = opt.Text or id, TextSize = 11,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
            }, "reg")
            picker = mkText("TextButton", { Parent = row,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                Size = UDim2.fromOffset(40, 2),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = bracketText(defaultKey), TextSize = 7,
                TextColor3 = Theme.TextDim, AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Center,
                AutomaticSize = Enum.AutomaticSize.X,
            }, "pixel")
        end

        -- Color reflects state: accent when active, dim otherwise.
        local function refreshColor(active)
            if active or kp.Mode == "Always" then
                picker.TextColor3 = Theme.Accent
            else
                picker.TextColor3 = Theme.TextDim
            end
        end

        function kp:SetValue(v, supp)
            local key, mode
            if type(v) == "table" then
                key = v[1] or v.key or "None"
                mode = v[2] or v.mode or self.Mode or "Toggle"
            else
                key = (v == nil or v == "" or v == "None") and "None" or v
                mode = self.Mode
            end
            self.Value = key
            self.Mode  = mode
            picker.Text = bracketText(key)
            refreshColor(false)
            if not supp then safeCallback(self.Callback, self.Value) end
        end
        kp:SetValue({ defaultKey, defaultMode }, true)

        function kp:GetState()
            -- With SyncToggleState, the parent toggle IS the truth source.
            if self._parentToggle then return self._parentToggle.Value and true or false end
            if self.Mode == "Always" then return true end
            if self.Mode == "Off"    then return false end
            if self.Mode == "Toggle" then return self._toggleState and true or false end
            local v = self.Value
            if not v or v == "-" or v == "None" then return false end
            local kc = Enum.KeyCode[v]
            if kc then return UserInputService:IsKeyDown(kc) end
            local mb = Enum.UserInputType[v]
            if mb then return UserInputService:IsMouseButtonPressed(mb) end
            return false
        end

        -- Per-keypicker input listener (Toggle flip + Hold visual)
        track(UserInputService.InputBegan:Connect(function(input, processed)
            if Library.ActiveKeyPicker then return end
            if processed then return end
            local v = kp.Value
            if not v or v == "None" then return end
            local match = false
            if input.UserInputType == Enum.UserInputType.Keyboard then
                match = (input.KeyCode.Name == v)
            else
                match = (input.UserInputType.Name == v)
            end
            if not match then return end
            if kp.Mode == "Toggle" then
                if kp._parentToggle then
                    -- SyncToggleState: flip the parent toggle, parent's
                    -- OnChanged below repaints the keypicker.
                    kp._parentToggle:SetValue(not kp._parentToggle.Value)
                else
                    kp._toggleState = not kp._toggleState
                    refreshColor(kp._toggleState)
                end
            elseif kp.Mode == "Hold" then
                refreshColor(true)
            end
        end))

        -- SyncToggleState wire-up: parent's value drives keypicker color.
        if parentToggle and parentToggle.OnChanged then
            parentToggle:OnChanged(function(v)
                refreshColor(v and true or false)
            end)
            refreshColor(parentToggle.Value and true or false)
        end
        track(UserInputService.InputEnded:Connect(function(input)
            if kp.Mode ~= "Hold" then return end
            local v = kp.Value
            if not v or v == "None" then return end
            local match
            if input.UserInputType == Enum.UserInputType.Keyboard then
                match = (input.KeyCode.Name == v)
            else
                match = (input.UserInputType.Name == v)
            end
            if match then refreshColor(false) end
        end))

        -- Right-click mode popup — small dropdown-style popup parented
        -- to ScreenGui that opens at the keypicker's screen position.
        local modePopup = mk("Frame", { Parent = ScreenGui,
            Size = UDim2.fromOffset(70, #modesList * 14 + 4),
            BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
            Visible = false, ZIndex = 95 })
        applyLayeredStrokes(modePopup, "outer")
        local modeInner = mk("Frame", { Parent = modePopup,
            Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2),
            BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0, ZIndex = 96 })
        applyLayeredStrokes(modeInner, "inner")
        uipad(modeInner, 2)
        listLayout(modeInner, Enum.FillDirection.Vertical, 1)

        local modeRows = {}
        local function refreshModeRows()
            for m, r in modeRows do
                if m == kp.Mode then
                    r.TextColor3 = Theme.Accent
                    applyFont(r, "bold")
                else
                    r.TextColor3 = Theme.TextDim
                    applyFont(r, "reg")
                end
            end
        end
        for _, m in modesList do
            local row = mkText("TextButton", { Parent = modeInner,
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = m, TextSize = 11, TextColor3 = Theme.TextDim,
                AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 97,
            }, "reg")
            modeRows[m] = row
            track(row.MouseEnter:Connect(function()
                if kp.Mode ~= m then row.TextColor3 = Theme.Text end
            end))
            track(row.MouseLeave:Connect(function()
                if kp.Mode ~= m then row.TextColor3 = Theme.TextDim end
            end))
            track(row.MouseButton1Click:Connect(function()
                kp.Mode = m
                kp._toggleState = false
                refreshColor(false)
                refreshModeRows()
                modePopup.Visible = false
                Library.ActivePopup = nil
            end))
        end
        refreshModeRows()

        local function openModePopup()
            closeActivePopup()
            local abs = picker.AbsolutePosition
            local sz = picker.AbsoluteSize
            modePopup.Position = UDim2.fromOffset(abs.X + sz.X - 70, abs.Y + sz.Y + 2)
            refreshModeRows()
            modePopup.Visible = true
            Library.ActivePopup = {
                OnClose = function() modePopup.Visible = false end,
                InsideCheck = function(input)
                    local p1, p2 = modePopup.AbsolutePosition, modePopup.AbsoluteSize
                    return input.Position.X >= p1.X and input.Position.X <= p1.X + p2.X
                       and input.Position.Y >= p1.Y and input.Position.Y <= p1.Y + p2.Y
                end,
            }
        end

        -- Left-click = rebind key, Right-click = open mode popup
        track(picker.MouseButton1Click:Connect(function()
            picker.Text = "[...]"
            Library.ActiveKeyPicker = function(k)
                kp:SetValue({ k, kp.Mode })
                Library.ActiveKeyPicker = nil
            end
        end))
        track(picker.MouseButton2Click:Connect(openModePopup))
        track(picker.MouseEnter:Connect(function()
            if picker.TextColor3 == Theme.TextDim then picker.TextColor3 = Theme.Text end
        end))
        track(picker.MouseLeave:Connect(function() refreshColor(kp._toggleState) end))

        Library.Options[id] = withOnChanged(kp)
        return kp
    end
    function target:AddKeyPicker(id, opt) return buildKeyPicker(nil, id, opt, false) end
    function target._addKeyPickerInline(row, id, opt) return buildKeyPicker(row, id, opt, true) end

    --------------------------------------------------------------------- Input
    -- Single-line text input. Flat dark bg + ink border + bold value text.
    -- Options: Default (string), Text (label above), Placeholder, Callback.
    function target:AddInput(id, opt)
        opt = opt or {}
        local hasLabel = opt.Text ~= nil
        local row = mk("Frame", { Parent = body,
            Size = UDim2.new(1, 0, 0, hasLabel and 26 or 14),
            BackgroundTransparency = 1, LayoutOrder = opt.LayoutOrder or 0 })

        if hasLabel then
            mkText("TextLabel", { Parent = row, Size = UDim2.new(1, 0, 0, 11),
                BackgroundTransparency = 1, Text = opt.Text, TextSize = 11,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left }, "reg")
        end

        local FLAT     = Color3.fromRGB(34, 34, 34)
        local FLAT_HOV = Color3.fromRGB(44, 44, 44)
        local field = mk("TextBox", { Parent = row,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.fromOffset(0, hasLabel and 14 or 0),
            BackgroundColor3 = FLAT, BorderSizePixel = 0,
            Text = opt.Default or "",
            PlaceholderText = opt.Placeholder or "",
            PlaceholderColor3 = Theme.TextDim,
            TextColor3 = Theme.TextActive, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ClearTextOnFocus = false, ClipsDescendants = true })
        applyFont(field, "reg")
        applyTextOutline(field)
        inkBorder(field)
        local pad = Instance.new("UIPadding"); pad.Name = "\0"
        pad.PaddingLeft = UDim.new(0, 5); pad.PaddingRight = UDim.new(0, 5)
        pad.Parent = field

        local input = { Type = "Input", Value = opt.Default or "", Callback = opt.Callback }

        function input:SetValue(v, supp)
            self.Value = tostring(v or "")
            field.Text = self.Value
            if not supp then safeCallback(self.Callback, self.Value) end
        end

        track(field.MouseEnter:Connect(function() field.BackgroundColor3 = FLAT_HOV end))
        track(field.MouseLeave:Connect(function() field.BackgroundColor3 = FLAT end))
        track(field:GetPropertyChangedSignal("Text"):Connect(function()
            input.Value = field.Text
            safeCallback(input.Callback, input.Value)
        end))

        Library.Options[id] = withOnChanged(input)
        return input
    end

    ------------------------------------------------------------ DependencyBox
    function target:AddDependencyBox()
        local depBody = mk("Frame", { Parent = body,
            Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, Visible = true })
        listLayout(depBody, Enum.FillDirection.Vertical, 4)
        local indent = Instance.new("UIPadding"); indent.Name = "\0"
        indent.PaddingLeft = UDim.new(0, 8); indent.Parent = depBody

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

-- ══════════════════════════════════════════════════════════════════════════
-- CREATE WINDOW
-- ══════════════════════════════════════════════════════════════════════════
function Library:CreateWindow(opts)
    opts = opts or {}
    local size = opts.Size or UDim2.fromOffset(600, 540)

    -- Outer frame — NO UIPadding (so absolute positions hold for the rainbow
    -- strip at Y=6, matching the GameScat base 1:1).
    local Window = mk("Frame", { Parent = ScreenGui,
        Size = size,
        BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Active = true })
    applyLayeredStrokes(Window, "outer")

    -- skeezt menu_bg.png — INSET 7px each side so the 7-px composite outer
    -- border (5-stroke layered at offsets 0/-1/-4t3/-5/-6) stays visible.
    -- Without this inset the bg ImageLabel covers the inward strokes.
    if BG_ASSET then
        mk("ImageLabel", { Parent = Window,
            Size = UDim2.new(1, -14, 1, -14),
            Position = UDim2.fromOffset(7, 7),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Image = BG_ASSET, ScaleType = Enum.ScaleType.Stretch,
            ZIndex = 0 })
    end

    -- Rainbow strip at TOP. In the GameScat base the shadow OVERLAPS the
    -- rainbow's bottom pixel (Y=7, ZIndex 2) ON TOP of the rainbow strip
    -- (Y=6,7, ZIndex 1) — the 50% black shadow darkens the rainbow's
    -- bottom row to a thinner highlight line. Re-creating that exact
    -- stack here (shadow ZIndex > rainbow ZIndex).
    local rainbow = mk("Frame", { Parent = Window,
        Size = UDim2.new(1, -12, 0, 2), Position = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 })
    local rainbowShadow = mk("Frame", { Parent = Window,
        Size = UDim2.new(1, -12, 0, 1), Position = UDim2.fromOffset(6, 7),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
        BorderSizePixel = 0, ZIndex = 3 })
    local rainbowGrad = Instance.new("UIGradient"); rainbowGrad.Name = "\0"
    rainbowGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0.0, Theme.RainbowA),
        ColorSequenceKeypoint.new(0.5, Theme.RainbowB),
        ColorSequenceKeypoint.new(1.0, Theme.RainbowC),
    }
    rainbowGrad.Parent = rainbow

    -- Tab bar — horizontal row of bold tab labels, at Y=14 of Window.
    local TabBar = mk("Frame", { Parent = Window,
        Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 14),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4 })
    local tabLayout = listLayout(TabBar, Enum.FillDirection.Horizontal, 0,
        Enum.VerticalAlignment.Center)
    tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

    -- Tab content frame — RGB(25,25,25), 5-stroke INNER border, sits at
    -- Y=36 with width = full minus 40 (20px gutter each side).
    local Content = mk("Frame", { Parent = Window,
        Size = UDim2.new(1, -40, 1, -56),
        Position = UDim2.fromOffset(20, 36),
        BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0, ZIndex = 4 })
    applyLayeredStrokes(Content, "inner")

    local ContentInner = mk("Frame", { Parent = Content,
        Size = UDim2.new(1, -20, 1, -20),
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1, BorderSizePixel = 0 })

    -- Drag handle — covers the rainbow + tab bar area (above content).
    local dragging, dragStart, startPos
    local dragSurface = mk("Frame", { Parent = Window,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5 })
    track(dragSurface.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Window.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            Window.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))

    -- Title text on the right of the tab bar (subtle, GS-style watermark)
    if opts.Title then
        mkText("TextLabel", { Parent = TabBar,
            Size = UDim2.fromOffset(180, 14), AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -2, 0.5, 0), BackgroundTransparency = 1,
            Text = tostring(opts.Title), TextSize = 11,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextYAlignment = Enum.TextYAlignment.Center,
            LayoutOrder = 9999,
        }, "reg")
    end

    local self = { _frame = Window, _tabs = {}, _activeTab = nil,
                   _content = ContentInner, _tabBar = TabBar }

    ----------------------------------------------------------------- GroupBox
    -- skeezt-style: title rendered in the top border of the box.
    -- Implementation: the gb frame holds the BG + 5-stroke border.
    -- The title chip + label are SIBLINGS in the column wrapper, positioned
    -- at the absolute top of gb with the chip in TabBg color "cutting"
    -- through the strokes for the in-border effect.
    local function buildGroupbox(parent, name)
        local titleStr = tostring(name or "")
        local titleW, _ = measureText(titleStr, 11, "bold")
        titleW = titleW + 8   -- 4px breathing each side of chip

        local wrap = mk("Frame", { Parent = parent,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = false })

        local gb = mk("Frame", { Parent = wrap,
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.fromOffset(0, 0),
            BackgroundColor3 = Theme.GroupBg, BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 1,
            ClipsDescendants = false })
        applyLayeredStrokes(gb, "inner")

        -- Title chip — TabBg color spans across the 5-stroke border at the
        -- top of gb so the title text reads cleanly without border lines
        -- passing through the letters. Sibling of gb (under wrap) with
        -- higher ZIndex so it renders OVER gb's strokes.
        mk("Frame", { Parent = wrap,
            Size = UDim2.fromOffset(titleW, 6),
            Position = UDim2.fromOffset(11, -2),
            BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0,
            ZIndex = 6 })
        mkText("TextLabel", { Parent = wrap,
            Size = UDim2.fromOffset(titleW, 12),
            Position = UDim2.fromOffset(11, -5),
            BackgroundTransparency = 1,
            Text = titleStr, TextSize = 11, TextColor3 = Theme.TextActive,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 7,
        }, "bold")

        -- Body — 8-px side inset, 10-px bottom inset, top inset 10 so
        -- widgets don't crowd the in-border title.
        local body_ = mk("Frame", { Parent = gb,
            Size = UDim2.new(1, -16, 0, 0),
            Position = UDim2.fromOffset(8, 10),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2 })
        listLayout(body_, Enum.FillDirection.Vertical, 5)
        mk("UIPadding", { Parent = body_,
            PaddingBottom = UDim.new(0, 10) })

        local group = { _frame = gb, _body = body_, _wrap = wrap }
        attachWidgets(group, body_)
        return group
    end

    ------------------------------------------------------------------ Tabbox
    -- A Tabbox is a single bordered box that hosts MULTIPLE sub-tabs as
    -- horizontal buttons at the top. Each sub-tab's body acts like its own
    -- groupbox (full widget API via attachWidgets). Used heavily in
    -- main.lua's Combat / Anti-Aim / World tabs to compress related
    -- sub-features into one chunk.
    local function buildTabbox(parent)
        local wrap = mk("Frame", { Parent = parent,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = false })

        local box = mk("Frame", { Parent = wrap,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = Theme.GroupBg, BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = false })
        applyLayeredStrokes(box, "inner")

        -- Horizontal tab-button row at the top.
        local tabRow = mk("Frame", { Parent = box,
            Size = UDim2.new(1, -16, 0, 12),
            Position = UDim2.fromOffset(8, 4),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 })
        local tabLay = listLayout(tabRow, Enum.FillDirection.Horizontal, 10)
        tabLay.VerticalAlignment = Enum.VerticalAlignment.Center

        local tabs = {}
        local tabbox = { _frame = box, _wrap = wrap, _tabs = tabs }

        function tabbox:AddTab(name)
            local w = measureText(name, 11, "bold")
            local btn = mkText("TextButton", { Parent = tabRow,
                Size = UDim2.fromOffset(w + 4, 12),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                Text = name, TextSize = 11, TextColor3 = Theme.TextDim,
                AutoButtonColor = false, LayoutOrder = #tabs + 1,
                ZIndex = 4,
            }, "bold")

            local body_ = mk("Frame", { Parent = box,
                Size = UDim2.new(1, -16, 0, 0),
                Position = UDim2.fromOffset(8, 20),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2,
                Visible = false })
            listLayout(body_, Enum.FillDirection.Vertical, 5)
            mk("UIPadding", { Parent = body_, PaddingBottom = UDim.new(0, 10) })

            local sub = { _btn = btn, _body = body_ }
            attachWidgets(sub, body_)
            tabs[#tabs + 1] = sub

            track(btn.MouseButton1Click:Connect(function()
                for _, t in tabs do
                    local active = (t == sub)
                    t._body.Visible = active
                    t._btn.TextColor3 = active and Theme.TextActive or Theme.TextDim
                end
            end))
            track(btn.MouseEnter:Connect(function()
                if not sub._body.Visible then btn.TextColor3 = Theme.Text end
            end))
            track(btn.MouseLeave:Connect(function()
                if not sub._body.Visible then btn.TextColor3 = Theme.TextDim end
            end))

            -- First tab becomes active by default.
            if #tabs == 1 then
                body_.Visible = true
                btn.TextColor3 = Theme.TextActive
            end
            return sub
        end

        return tabbox
    end

    ----------------------------------------------------------------------- Tab
    function self:AddTab(name)
        local btn = mkText("TextButton", { Parent = TabBar,
            Size = UDim2.fromOffset(64, 18),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Text = string.upper(name), TextSize = 12, TextColor3 = Theme.TextDim,
            AutoButtonColor = false, LayoutOrder = #self._tabs + 1,
        }, "bold")
        local w = measureText(string.upper(name), 12, "bold")
        btn.Size = UDim2.fromOffset(w + 14, 18)

        local underline = mk("Frame", { Parent = btn,
            Size = UDim2.new(1, -6, 0, 1), AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
            BackgroundTransparency = 1, ZIndex = 2 })

        local tabContent = mk("Frame", { Parent = ContentInner,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false })

        -- ClipsDescendants=true on the columns is what makes the ScrollingFrame
        -- actually clip overflow at its visible bounds + lets the scrollbar
        -- thumb track properly. With it false (old default) a groupbox taller
        -- than the column rendered OUTSIDE the menu window — the "groupbox
        -- clips out of the main menu" bug. 6px top UIPadding (added below) keeps
        -- the groupbox title chip (Y=-2 inside its wrap) safe from clipping.
        local leftCol = mk("ScrollingFrame", { Parent = tabContent,
            Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.BorderHi,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ClipsDescendants = true })
        local rightCol = mk("ScrollingFrame", { Parent = tabContent,
            Size = UDim2.new(0.5, -6, 1, 0),
            Position = UDim2.new(0.5, 6, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.BorderHi,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ClipsDescendants = true })
        listLayout(leftCol,  Enum.FillDirection.Vertical, 12)
        listLayout(rightCol, Enum.FillDirection.Vertical, 12)
        uipad(leftCol, 6, 6, 6, 4)
        uipad(rightCol, 6, 6, 6, 4)

        local tab = { _btn = btn, _content = tabContent, _left = leftCol,
                      _right = rightCol, _underline = underline }
        function tab:AddLeftGroupbox(n)  return buildGroupbox(leftCol, n)  end
        function tab:AddRightGroupbox(n) return buildGroupbox(rightCol, n) end
        function tab:AddLeftTabbox()     return buildTabbox(leftCol)        end
        function tab:AddRightTabbox()    return buildTabbox(rightCol)       end

        track(btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end))
        track(btn.MouseEnter:Connect(function()
            if self._activeTab ~= tab then btn.TextColor3 = Theme.Text end
        end))
        track(btn.MouseLeave:Connect(function()
            if self._activeTab ~= tab then btn.TextColor3 = Theme.TextDim end
        end))

        self._tabs[#self._tabs + 1] = tab
        if not self._activeTab then self:SelectTab(tab) end
        return tab
    end

    function self:SelectTab(tab)
        for _, t in self._tabs do
            local active = (t == tab)
            t._content.Visible = active
            t._btn.TextColor3 = active and Theme.TextActive or Theme.TextDim
            t._underline.BackgroundTransparency = active and 0 or 1
        end
        self._activeTab = tab
    end

    Library.Window = self
    return self
end

-- ══════════════════════════════════════════════════════════════════════════
-- GLOBAL INPUT
-- ══════════════════════════════════════════════════════════════════════════
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if Library.ActiveKeyPicker then
        local cb = Library.ActiveKeyPicker
        Library.ActiveKeyPicker = nil
        if input.UserInputType == Enum.UserInputType.Keyboard then
            pcall(cb, input.KeyCode.Name)
            return
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            pcall(cb, input.UserInputType.Name)
            return
        end
    end
    if input.UserInputType == Enum.UserInputType.Keyboard
        and input.KeyCode == Library.ToggleKey and not gameProcessed then
        Library:Toggle()
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        local p = Library.ActivePopup
        if p and p.InsideCheck and not p.InsideCheck(input) then closeActivePopup() end
    end
end))

function Library:Toggle()
    self.Visible = not self.Visible
    if self.Window and self.Window._frame then
        self.Window._frame.Visible = self.Visible
    end
end

function Library:SetToggleKey(k)
    if typeof(k) == "EnumItem" then self.ToggleKey = k
    elseif type(k) == "string" then
        self.ToggleKey = Enum.KeyCode[k] or Enum.KeyCode.End
    end
end

function Library:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    if type(self.OnUnloadCallback) == "function" then
        pcall(self.OnUnloadCallback)
    end
    for _, c in self.Connections do pcall(function() c:Disconnect() end) end
    pcall(function() ScreenGui:Destroy() end)
end

function Library:OnUnload(cb)
    -- sanyui parity: stores a single unload callback fired before destroy.
    self.OnUnloadCallback = cb
end

function Library:GiveSignal(con)
    -- sanyui parity: track external RBXScriptConnections for clean unload.
    return track(con)
end

function Library:SafeCallback(fn, ...)
    if type(fn) == "function" then return pcall(fn, ...) end
end

function Library:Create(class, props)
    return mk(class, props)
end

function Library:ApplyTextStroke(textInst)
    return applyTextOutline(textInst)
end

-- ══════════════════════════════════════════════════════════════════════════
-- FONT MANAGEMENT — RegisterFont / SetFont / OnFontChanged. main.lua uses
-- RegisterFontsFromRepo to bulk-load a list from a github base URL.
-- ══════════════════════════════════════════════════════════════════════════
Library.Fonts          = {}
Library.CurrentFont    = FONT_REG   -- start with our loaded Verdana Regular
Library.FontListeners  = {}

function Library:GetActiveFont()
    return self.CurrentFont or FONT_REG
end

function Library:OnFontChanged(cb)
    self.FontListeners[#self.FontListeners + 1] = cb
end

local function dispatchFontChange()
    -- Re-apply the active font to every text instance under our ScreenGui
    -- so the change is visible immediately. External script-owned text
    -- (ESP billboards, watermark) gets the change via the listener fanout.
    local f = Library:GetActiveFont()
    if not f then return end
    for _, d in ScreenGui:GetDescendants() do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            pcall(function() d.FontFace = f end)
        end
    end
    for _, cb in Library.FontListeners do pcall(cb, f) end
end

-- Register a single font (TTF URL or local path) under a chosen name.
function Library:RegisterFont(name, urlOrPath)
    local local_path = "nachtara_font_" .. name .. ".ttf"
    local ok = ensureFile(local_path, urlOrPath)
    local ttfAsset = ok and customAsset(local_path) or nil
    if not ttfAsset then return nil end
    local f = buildSingleFaceFont(ttfAsset, name)
    if f then self.Fonts[name] = f end
    return f
end

-- Bulk-load. `list` is an array of font names that exist as <baseUrl>/<name>.ttf
-- (matches sanyoner/Nachtara/fonts repo structure exactly).
function Library:RegisterFontsFromRepo(baseUrl, list)
    for _, name in list do
        -- name like "Verdana-Font" or "Light Modern" — URL-encode the space.
        local encoded = string.gsub(name, " ", "%%20")
        self:RegisterFont(name, baseUrl .. encoded .. ".ttf")
    end
    return self.Fonts
end

-- Switch the active font. main.lua + ESP code uses this to keep UI and
-- world labels in sync with a user-picked option.
function Library:SetFont(name)
    if name == nil then
        self.CurrentFont = FONT_REG
    else
        local f = (typeof(name) == "Font") and name or self.Fonts[name]
        if not f then return end
        self.CurrentFont = f
    end
    dispatchFontChange()
end

-- ══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS — base-watermark-styled toast (5-stroke outer + inner Main
-- + rainbow strip + shadow), sanyui-style animations (TweenSize grow +
-- fade in + countdown bar drain + shrink). Position configurable via
-- Library:SetNotificationPosition('TopLeft' | 'TopRight' | 'Middle').
-- ══════════════════════════════════════════════════════════════════════════
Library.NotificationPosition = "TopRight"
local TweenService = game:GetService("TweenService")

local NotifyArea = mk("Frame", { Parent = ScreenGui,
    Position = UDim2.new(1, -10, 0, 40), AnchorPoint = Vector2.new(1, 0),
    Size = UDim2.fromOffset(320, 400),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 200 })
local NotifyLayout = listLayout(NotifyArea, Enum.FillDirection.Vertical, 6,
    Enum.VerticalAlignment.Top)
NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
Library.NotificationArea = NotifyArea
Library.NotificationLayout = NotifyLayout

function Library:SetNotificationPosition(pos)
    if pos ~= "TopLeft" and pos ~= "TopRight" and pos ~= "Middle" then return end
    Library.NotificationPosition = pos
    if pos == "TopLeft" then
        NotifyArea.AnchorPoint = Vector2.new(0, 0)
        NotifyArea.Position = UDim2.new(0, 100, 0, 40)
        NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    elseif pos == "TopRight" then
        NotifyArea.AnchorPoint = Vector2.new(1, 0)
        NotifyArea.Position = UDim2.new(1, -10, 0, 40)
        NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    elseif pos == "Middle" then
        NotifyArea.AnchorPoint = Vector2.new(0.5, 0)
        NotifyArea.Position = UDim2.new(0.5, 0, 0.5, 50)
        NotifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end
    -- Re-anchor any currently-live notifications so they don't drift away
    -- from the new alignment.
    for _, child in NotifyArea:GetChildren() do
        if child:IsA("Frame") then
            local ax = 0
            if pos == "TopRight" then ax = 1
            elseif pos == "Middle" then ax = 0.5 end
            child.AnchorPoint = Vector2.new(ax, 0)
        end
    end
end

function Library:Notify(text, duration)
    duration = duration or 5
    text = tostring(text or "")
    -- Width = approx text width + 16px breathing.
    local w = math.max(80, measureText(text, 11, "reg") + 16)
    local h = 24

    -- Anchor follows NotificationPosition so the grow-from-edge feels right.
    local ax = 0
    if Library.NotificationPosition == "TopRight" then ax = 1
    elseif Library.NotificationPosition == "Middle" then ax = 0.5 end

    -- Outer: WindowBg with 5-stroke OUTER pattern (matches BASE watermark)
    local outer = mk("Frame", { Parent = NotifyArea,
        AnchorPoint = Vector2.new(ax, 0),
        BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, h), ZIndex = 200 })
    -- Strokes are pre-built but we keep them transparent until fade-in.
    local outerStrokes = {}
    do
        local set = {
            { off =  0, t = 1, c = Theme.BorderDark },
            { off = -1, t = 1, c = Theme.BorderHi   },
            { off = -4, t = 3, c = Theme.BorderMid  },
            { off = -5, t = 1, c = Theme.BorderHi   },
            { off = -6, t = 1, c = Theme.BorderDark },
        }
        for _, s in set do
            local st = Instance.new("UIStroke"); st.Name = "\0"
            st.Color = s.c; st.Thickness = s.t; st.Transparency = 1
            st.LineJoinMode = Enum.LineJoinMode.Miter
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.BorderOffset = UDim.new(0, s.off)
            st.Parent = outer
            outerStrokes[#outerStrokes + 1] = st
        end
    end

    -- Inner Main: TabBg with 5-stroke INNER pattern (the watermark "main" sub).
    local main = mk("Frame", { Parent = outer,
        BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.fromOffset(1, 1), ZIndex = 201 })
    local innerStrokes = {}
    do
        local set = {
            { off =  0, t = 1, c = Theme.BorderDark },
            { off = -1, t = 1, c = Theme.BorderHi   },
            { off = -2, t = 1, c = Theme.BorderMid  },
            { off = -3, t = 1, c = Theme.BorderHi   },
            { off = -4, t = 1, c = Theme.BorderDark },
        }
        for _, s in set do
            local st = Instance.new("UIStroke"); st.Name = "\0"
            st.Color = s.c; st.Thickness = s.t; st.Transparency = 1
            st.LineJoinMode = Enum.LineJoinMode.Miter
            st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.BorderOffset = UDim.new(0, s.off)
            st.Parent = main
            innerStrokes[#innerStrokes + 1] = st
        end
    end

    -- Rainbow strip + shadow (base-watermark parity).
    local rb = mk("Frame", { Parent = main, ZIndex = 202,
        Size = UDim2.new(1, -12, 0, 2), Position = UDim2.fromOffset(6, 4),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        BackgroundTransparency = 1 })
    local rbGrad = Instance.new("UIGradient"); rbGrad.Name = "\0"
    rbGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Theme.RainbowA),
        ColorSequenceKeypoint.new(0.5, Theme.RainbowB),
        ColorSequenceKeypoint.new(1,   Theme.RainbowC),
    }
    rbGrad.Parent = rb
    local rbShadow = mk("Frame", { Parent = main, ZIndex = 203,
        Size = UDim2.new(1, -12, 0, 1), Position = UDim2.fromOffset(6, 5),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0 })

    -- Label
    local lbl = mkText("TextLabel", { Parent = main, ZIndex = 204,
        Position = UDim2.fromOffset(8, 9),
        Size = UDim2.new(1, -16, 0, 12),
        BackgroundTransparency = 1, Text = text,
        TextSize = 11, TextColor3 = Theme.TextActive,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd, TextTransparency = 1,
    }, "reg")
    -- Label outline is auto-added by mkText; fade it with the label.
    local lblStroke
    for _, c in lbl:GetChildren() do
        if c:IsA("UIStroke") then lblStroke = c; lblStroke.Transparency = 1; break end
    end

    -- Bottom progress/countdown bar
    local progress = mk("Frame", { Parent = main, ZIndex = 204,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
        BackgroundTransparency = 1 })

    -- ─── Animations (sanyui-style two-phase) ────────────────────────────
    local TI_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out)
    local TI_OUT = TweenInfo.new(0.5,  Enum.EasingStyle.Quad,
        Enum.EasingDirection.In)

    -- Phase 1: width-grow + fade in
    pcall(outer.TweenSize, outer, UDim2.fromOffset(w, h),
        Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.35, true)
    for _, st in outerStrokes do
        TweenService:Create(st, TI_IN, { Transparency = 0 }):Play()
    end
    for _, st in innerStrokes do
        TweenService:Create(st, TI_IN, { Transparency = 0 }):Play()
    end
    TweenService:Create(outer,    TI_IN, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(main,     TI_IN, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(rb,       TI_IN, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(rbShadow, TI_IN, { BackgroundTransparency = 0.5 }):Play()
    TweenService:Create(progress, TI_IN, { BackgroundTransparency = 0 }):Play()
    TweenService:Create(lbl,      TI_IN, { TextTransparency = 0 }):Play()
    if lblStroke then
        TweenService:Create(lblStroke, TI_IN, { Transparency = 0 }):Play()
    end

    task.spawn(function()
        -- Drain countdown bar after the fade-in finishes.
        task.wait(0.35)
        TweenService:Create(progress,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            { Size = UDim2.new(0, 0, 0, 1) }):Play()

        task.wait(duration)
        if not outer.Parent then return end

        -- Phase 3: fade out + width-shrink
        pcall(outer.TweenSize, outer, UDim2.fromOffset(0, h),
            Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.5, true)
        for _, st in outerStrokes do
            TweenService:Create(st, TI_OUT, { Transparency = 1 }):Play()
        end
        for _, st in innerStrokes do
            TweenService:Create(st, TI_OUT, { Transparency = 1 }):Play()
        end
        TweenService:Create(outer,    TI_OUT, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(main,     TI_OUT, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(rb,       TI_OUT, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(rbShadow, TI_OUT, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(progress, TI_OUT, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(lbl,      TI_OUT, { TextTransparency = 1 }):Play()
        if lblStroke then
            TweenService:Create(lblStroke, TI_OUT, { Transparency = 1 }):Play()
        end

        task.wait(0.5)
        pcall(function() outer:Destroy() end)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
-- SHOW LOADER — sanyui-parity loader honoring the full contract:
--   { Title, Subtitle, ScriptName, GameName, Version, LoadTime, Callback,
--     Patchnotes = { {Version, Date, Changes={...}}, ... },
--     Stages = { {progress01, text}, ... },  -- optional
--     IntroDuration, IntroKey }              -- optional
--
-- Layout:
--   • Left panel (300px): Title / Subtitle, then a Script/Game/Version
--     metadata box, version label, Load button (or progress + status after
--     the button is pressed).
--   • Right panel (only when Patchnotes is non-empty): scrollable changelog,
--     widening the whole loader from 320 → 580px.
--
-- After Load is pressed:
--   • Button fades out, progress + status replace it.
--   • Stages advance over LoadTime seconds (default 3s, 6 default stages).
--   • Entire loader fades out.
--   • Optional intro: dim + blur + 3 title labels, then fades.
--   • SafeCallback(config.Callback) — this is what main.lua hangs on; it
--     builds the actual Window inside that callback.
--
-- This call YIELDS until Load is pressed + animations finish, matching
-- sanyui's contract so the caller can write linear `ShowLoader{…}` → next.
-- ══════════════════════════════════════════════════════════════════════════
function Library:ShowLoader(config)
    config = config or {}
    config.Title       = tostring(config.Title       or "Loader")
    config.Subtitle    = tostring(config.Subtitle    or "")
    config.ScriptName  = tostring(config.ScriptName  or "Script")
    config.GameName    = tostring(config.GameName    or "Game")
    config.Version     = tostring(config.Version     or "1.0.0")
    config.LoadTime    = tonumber(config.LoadTime) or 3
    config.Callback    = config.Callback or function() end
    config.Patchnotes  = config.Patchnotes or {}

    if Library._Loader then
        pcall(function() Library._Loader:Destroy() end)
        Library._Loader = nil
    end

    local hasPatch = #config.Patchnotes > 0
    -- Match Window's padding cadence: rainbow at (6,6) directly on outer +
    -- Content frame inset at (20, 36) like CreateWindow does. Loader height
    -- bumped to 260 so the inner Content has the same headroom as Window's
    -- tab area (36px) + a comfortable bottom margin.
    local W = hasPatch and 580 or 320
    local H = 260
    -- Inside-Content layout offsets (relative to the inner Content frame).
    -- LeftPanelW = the "main" column with title-info-button when patchnotes
    -- are present; sits at left of Content, separator at x=LeftPanelW.
    local LeftPanelW = hasPatch and 280 or nil

    -- Outer frame: WindowBg + 5-stroke OUTER border, centered (Window parity).
    local loader = mk("Frame", { Parent = ScreenGui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(W, H),
        BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0, ZIndex = 250 })
    applyLayeredStrokes(loader, "outer")

    -- Rainbow strip at Y=6 directly on outer (same as CreateWindow), with
    -- the 1px black shadow at Y=7 overlapping the rainbow's bottom row.
    local rb = mk("Frame", { Parent = loader, ZIndex = 252,
        Size = UDim2.new(1, -12, 0, 2), Position = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
    local rbGrad = Instance.new("UIGradient"); rbGrad.Name = "\0"
    rbGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Theme.RainbowA),
        ColorSequenceKeypoint.new(0.5, Theme.RainbowB),
        ColorSequenceKeypoint.new(1,   Theme.RainbowC),
    }
    rbGrad.Parent = rb
    mk("Frame", { Parent = loader, ZIndex = 253,
        Size = UDim2.new(1, -12, 0, 1), Position = UDim2.fromOffset(6, 7),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
        BorderSizePixel = 0 })

    -- Header area — title + subtitle sit between the rainbow and the Content
    -- frame (where CreateWindow's tab bar lives at Y=14).
    mkText("TextLabel", { Parent = loader, ZIndex = 254,
        Position = UDim2.fromOffset(20, 14),
        Size = UDim2.new(1, -40, 0, 16),
        BackgroundTransparency = 1, Text = config.Title, TextSize = 14,
        TextColor3 = Theme.TextActive,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, "bold")
    mkText("TextLabel", { Parent = loader, ZIndex = 254,
        Position = UDim2.fromOffset(20, 30),
        Size = UDim2.new(1, -40, 0, 12),
        BackgroundTransparency = 1, Text = config.Subtitle, TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, "reg")

    -- Content frame — exact Window parity: 20px horiz gutter, 46px top
    -- (4 more than Window since the loader doesn't have a tab bar but does
    -- have title+subtitle), 20px bottom. Inner 5-stroke border + TabBg fill.
    local Content = mk("Frame", { Parent = loader, ZIndex = 254,
        Position = UDim2.fromOffset(20, 46),
        Size = UDim2.new(1, -40, 1, -66),
        BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0 })
    applyLayeredStrokes(Content, "inner")

    -- Inside-Content widths/positions are now relative to Content (not loader).
    local CW = W - 40  -- inner content width
    local CH = H - 66  -- inner content height
    local L  = hasPatch and LeftPanelW or CW

    -- Info container — Script/Game rows with separator (sits in the left panel).
    local infoBox = mk("Frame", { Parent = Content, ZIndex = 255,
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.fromOffset(L - 28, 52),
        BackgroundColor3 = Theme.GroupBg, BorderSizePixel = 0 })
    applyLayeredStrokes(infoBox, "inner")

    -- Script row
    mkText("TextLabel", { Parent = infoBox, ZIndex = 256,
        Position = UDim2.fromOffset(8, 4),
        Size = UDim2.new(0.4, 0, 0, 18),
        BackgroundTransparency = 1, Text = "Script", TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, "reg")
    mkText("TextLabel", { Parent = infoBox, ZIndex = 256,
        Position = UDim2.new(0.4, 0, 0, 4),
        Size = UDim2.new(0.6, -8, 0, 18),
        BackgroundTransparency = 1, Text = config.ScriptName, TextSize = 11,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, "bold")

    -- Mid separator
    mk("Frame", { Parent = infoBox, ZIndex = 256,
        Position = UDim2.fromOffset(6, 26),
        Size = UDim2.new(1, -12, 0, 1),
        BackgroundColor3 = Theme.BorderHi, BorderSizePixel = 0 })

    -- Game row
    mkText("TextLabel", { Parent = infoBox, ZIndex = 256,
        Position = UDim2.fromOffset(8, 28),
        Size = UDim2.new(0.4, 0, 0, 18),
        BackgroundTransparency = 1, Text = "Game", TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, "reg")
    mkText("TextLabel", { Parent = infoBox, ZIndex = 256,
        Position = UDim2.new(0.4, 0, 0, 28),
        Size = UDim2.new(0.6, -8, 0, 18),
        BackgroundTransparency = 1, Text = config.GameName, TextSize = 11,
        TextColor3 = Theme.Accent,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, "bold")

    -- Version label
    mkText("TextLabel", { Parent = Content, ZIndex = 255,
        Position = UDim2.fromOffset(14, 76),
        Size = UDim2.fromOffset(L - 28, 14),
        BackgroundTransparency = 1, Text = "v" .. config.Version, TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, "reg")

    -- Load button (sits near the bottom of Content, in the left panel).
    local btnOuter = mk("TextButton", { Parent = Content, ZIndex = 255,
        Position = UDim2.fromOffset(14, CH - 36),
        Size = UDim2.fromOffset(L - 28, 22),
        BackgroundColor3 = Theme.SliderTop, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, Active = true })
    local btnGrad = vGradient(btnOuter, Theme.SliderTop, Theme.SliderBottom)
    applyLayeredStrokes(btnOuter, "inner")
    local btnLabel = mkText("TextLabel", { Parent = btnOuter, ZIndex = 256,
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "Load", TextSize = 12, TextColor3 = Theme.TextActive,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, "bold")
    -- Hover swap to brighter gradient
    btnOuter.MouseEnter:Connect(function()
        if btnGrad then
            btnGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Theme.SliderTopHov),
                ColorSequenceKeypoint.new(1, Theme.SliderBotHov),
            }
        end
    end)
    btnOuter.MouseLeave:Connect(function()
        if btnGrad then
            btnGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Theme.SliderTop),
                ColorSequenceKeypoint.new(1, Theme.SliderBottom),
            }
        end
    end)

    -- Progress bar (hidden until Load is pressed) — sits at the button's slot.
    local progOuter = mk("Frame", { Parent = Content, ZIndex = 255,
        Position = UDim2.fromOffset(14, CH - 36),
        Size = UDim2.fromOffset(L - 28, 8),
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        Visible = false })
    applyLayeredStrokes(progOuter, "inner")
    local progFill = mk("Frame", { Parent = progOuter, ZIndex = 256,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })

    -- Status label below the progress bar
    local statusLbl = mkText("TextLabel", { Parent = Content, ZIndex = 255,
        Position = UDim2.fromOffset(14, CH - 22),
        Size = UDim2.fromOffset(L - 28, 12),
        BackgroundTransparency = 1, Text = "", TextSize = 11,
        TextColor3 = Theme.TextDim, TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Center,
        Visible = false,
    }, "reg")

    -- ── RIGHT PANEL: PATCHNOTES (only when present) ───────────────────────
    if hasPatch then
        -- Vertical separator down the middle of Content.
        mk("Frame", { Parent = Content, ZIndex = 255,
            Position = UDim2.fromOffset(L, 10),
            Size = UDim2.new(0, 1, 1, -20),
            BackgroundColor3 = Theme.BorderHi, BorderSizePixel = 0 })

        -- Changelog header (bold)
        mkText("TextLabel", { Parent = Content, ZIndex = 255,
            Position = UDim2.fromOffset(L + 12, 14),
            Size = UDim2.new(1, -(L + 26), 0, 14),
            BackgroundTransparency = 1, Text = "Changelog", TextSize = 12,
            TextColor3 = Theme.TextActive,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, "bold")
        -- Accent underline
        mk("Frame", { Parent = Content, ZIndex = 255,
            Position = UDim2.fromOffset(L + 12, 30),
            Size = UDim2.new(1, -(L + 26), 0, 1),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })

        -- Scrollable list
        local scroll = mk("ScrollingFrame", { Parent = Content, ZIndex = 255,
            Position = UDim2.fromOffset(L + 12, 36),
            Size = UDim2.new(1, -(L + 26), 1, -46),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
        })
        local layout = listLayout(scroll, Enum.FillDirection.Vertical, 8)

        for i, note in config.Patchnotes do
            local changes = note.Changes or note.changes or {}
            local version = tostring(note.Version or note.version or "v?")
            local date    = tostring(note.Date    or note.date    or "")
            -- Per-entry height: 14 header + (n * 13) lines
            local entryH = 14 + #changes * 13 + 2
            local entry = mk("Frame", { Parent = scroll, ZIndex = 255,
                Size = UDim2.new(1, -6, 0, entryH), LayoutOrder = i,
                BackgroundTransparency = 1, BorderSizePixel = 0 })
            mkText("TextLabel", { Parent = entry, ZIndex = 256,
                Size = UDim2.fromOffset(90, 13),
                BackgroundTransparency = 1, Text = version, TextSize = 11,
                TextColor3 = Theme.Accent,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, "bold")
            mkText("TextLabel", { Parent = entry, ZIndex = 256,
                Position = UDim2.fromOffset(92, 0),
                Size = UDim2.new(1, -92, 0, 13),
                BackgroundTransparency = 1, Text = date, TextSize = 10,
                TextColor3 = Color3.fromRGB(80, 80, 80),
                TextXAlignment = Enum.TextXAlignment.Right,
            }, "reg")
            local y = 15
            for _, change in changes do
                mkText("TextLabel", { Parent = entry, ZIndex = 256,
                    Position = UDim2.fromOffset(0, y),
                    Size = UDim2.new(1, 0, 0, 12),
                    BackgroundTransparency = 1,
                    Text = "• " .. tostring(change), TextSize = 10,
                    TextColor3 = Theme.TextDim,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, "reg")
                y = y + 13
            end
        end

        -- Keep CanvasSize in sync with content
        track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 4)
        end))
    end

    Library._Loader = loader

    -- ── LOAD CLICK → PROGRESS → CALLBACK ──────────────────────────────────
    -- Block calling thread until Load is clicked AND progress + fade-out are done.
    local resume = Instance.new("BindableEvent")
    local loading = false

    btnOuter.MouseButton1Click:Connect(function()
        if loading then return end
        loading = true

        -- Fade out the button
        pcall(function()
            TweenService:Create(btnOuter, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
            }):Play()
            TweenService:Create(btnLabel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                TextTransparency = 1,
            }):Play()
        end)
        task.wait(0.2)
        btnOuter.Visible = false

        -- Reveal progress + status
        progOuter.Visible = true
        statusLbl.Visible = true
        pcall(function()
            TweenService:Create(statusLbl, TweenInfo.new(0.25), {
                TextTransparency = 0,
            }):Play()
        end)

        local stages = config.Stages or {
            { 0.15, "Initializing..." },
            { 0.35, "Loading modules..." },
            { 0.55, "Setting up hooks..." },
            { 0.75, "Preparing UI..." },
            { 0.90, "Finalizing..." },
            { 1.00, "Done!" },
        }
        local stageTime = config.LoadTime / #stages
        local fillWidth = progOuter.AbsoluteSize.X - 2
        if fillWidth < 1 then fillWidth = L - 30 end

        for _, st in stages do
            statusLbl.Text = tostring(st[2] or "")
            pcall(function()
                TweenService:Create(progFill,
                    TweenInfo.new(stageTime * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(st[1], 0, 1, -2) }
                ):Play()
            end)
            task.wait(stageTime)
        end
        task.wait(0.25)

        -- Fade loader out
        pcall(function()
            for _, d in loader:GetDescendants() do
                if d:IsA("Frame") or d:IsA("TextButton") or d:IsA("ScrollingFrame") then
                    if d.BackgroundTransparency < 1 then
                        pcall(function()
                            TweenService:Create(d, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                        end)
                    end
                elseif d:IsA("TextLabel") then
                    pcall(function()
                        TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
                    end)
                elseif d:IsA("UIStroke") then
                    pcall(function()
                        TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
                    end)
                end
            end
            TweenService:Create(loader, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        end)
        task.wait(0.35)
        pcall(function() loader:Destroy() end)
        Library._Loader = nil

        resume:Fire()
    end)

    -- Yield until the user clicks Load + animations finish
    resume.Event:Wait()
    resume:Destroy()

    -- ── INTRO (optional cinematic before Callback runs) ───────────────────
    do
        local introInfo = TweenInfo.new(0.9, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        local tint = mk("Frame", { Parent = ScreenGui, ZIndex = 240,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0 })
        local blur
        pcall(function()
            blur = Instance.new("BlurEffect")
            blur.Size = 0
            blur.Parent = game:GetService("Lighting")
        end)

        local function introLabel(text, yOff, color, size)
            local l = mkText("TextLabel", { Parent = tint, ZIndex = 241,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, yOff),
                Size = UDim2.fromOffset(440, size + 6),
                BackgroundTransparency = 1, Text = text, TextSize = size,
                TextColor3 = color, TextTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
            }, "bold")
            local stroke
            for _, c in l:GetChildren() do
                if c:IsA("UIStroke") then stroke = c; stroke.Transparency = 1; break end
            end
            return l, stroke
        end

        local l1, s1 = introLabel(config.Title, -22, Color3.fromRGB(235, 235, 235), 16)
        local l2, s2 = introLabel(config.ScriptName .. " loaded", 0, Theme.Accent, 13)
        local l3, s3 = introLabel("press " .. (config.IntroKey or "End") ..
            " to show/hide menu", 22, Color3.fromRGB(135, 135, 135), 11)

        pcall(function()
            TweenService:Create(tint, introInfo, { BackgroundTransparency = 0.55 }):Play()
            if blur then TweenService:Create(blur, introInfo, { Size = 20 }):Play() end
            local labels = { {l1, s1, 0}, {l2, s2, 0.08}, {l3, s3, 0.16} }
            for _, e in labels do
                task.delay(e[3], function()
                    pcall(function()
                        TweenService:Create(e[1], introInfo, { TextTransparency = 0 }):Play()
                        if e[2] then
                            TweenService:Create(e[2], introInfo, { Transparency = 0 }):Play()
                        end
                    end)
                end)
            end
        end)
        task.wait(0.9 + (tonumber(config.IntroDuration) or 1.2))

        pcall(function()
            for _, l in { l1, l2, l3 } do
                pcall(function()
                    TweenService:Create(l, introInfo, { TextTransparency = 1 }):Play()
                end)
            end
            for _, s in { s1, s2, s3 } do
                if s then
                    pcall(function()
                        TweenService:Create(s, introInfo, { Transparency = 1 }):Play()
                    end)
                end
            end
            TweenService:Create(tint, introInfo, { BackgroundTransparency = 1 }):Play()
            if blur then TweenService:Create(blur, introInfo, { Size = 0 }):Play() end
        end)
        task.delay(1.0, function()
            pcall(function() tint:Destroy() end)
            if blur then pcall(function() blur:Destroy() end) end
        end)
        -- Overlap intro fade with UI creation
        task.wait(0.35)
    end

    -- Fire the caller's UI-build callback
    Library:SafeCallback(config.Callback)
end

function Library:HideLoader()
    if Library._Loader then
        pcall(function() Library._Loader:Destroy() end)
        Library._Loader = nil
    end
end

-- Watermark — small label at top-right above the main window. Optional;
-- main.lua doesn't currently use it but sanyui exposes the API so we
-- match for drop-in compatibility.
local Watermark = mk("Frame", { Parent = ScreenGui,
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
    Size = UDim2.fromOffset(180, 22),
    BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
    Visible = false, ZIndex = 190 })
applyLayeredStrokes(Watermark, "inner")
local watermarkLbl = mkText("TextLabel", { Parent = Watermark,
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "", TextSize = 11, TextColor3 = Theme.TextActive,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 191,
}, "bold")
-- ══════════════════════════════════════════════════════════════════════════
-- KEYBIND HUD — draggable on-screen panel that auto-shows every KeyPicker's
-- current "[KEY] Name (Mode)" status while the bind is active. main.lua
-- toggles its visibility via `Library.KeybindFrame.Visible = bool`; sanyui
-- parity lets feature code register/unregister ContainerLabels here at
-- KeyPicker construction time (we expose the parent via .KeybindContainer).
-- ══════════════════════════════════════════════════════════════════════════
local KeybindFrame = mk("Frame", { Parent = ScreenGui,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 14, 0.5, 0),
    Size = UDim2.fromOffset(150, 24),
    BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
    AutomaticSize = Enum.AutomaticSize.Y, Visible = true,
    ZIndex = 180, Active = true })
applyLayeredStrokes(KeybindFrame, "inner")
uipad(KeybindFrame, 4)
listLayout(KeybindFrame, Enum.FillDirection.Vertical, 1)

local KeybindTitle = mkText("TextLabel", { Parent = KeybindFrame,
    Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
    Text = "keybinds", TextSize = 11, TextColor3 = Theme.TextActive,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    LayoutOrder = 0, ZIndex = 181 }, "bold")

-- Drag the HUD from anywhere on its surface (the title strip is too small
-- to grab reliably on a 1-line bind list).
do
    local dragging, dragStart, startPos
    track(KeybindFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = KeybindFrame.Position
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            KeybindFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
end

Library.KeybindFrame     = KeybindFrame
Library.KeybindContainer = KeybindFrame   -- sanyui alias

-- ══════════════════════════════════════════════════════════════════════════
-- BUILD FONT SECTION — drop a font-picker dropdown into the caller's
-- container (typically Settings tab Menu groupbox). Pulls names from
-- Library.Fonts (populated by RegisterFontsFromRepo) and calls
-- Library:SetFont on change.
-- ══════════════════════════════════════════════════════════════════════════
function Library:BuildFontSection(container)
    if not container or type(container.AddDropdown) ~= "function" then return end

    -- main.lua RegisterFontsFromRepo runs ASYNC for github downloads; the
    -- dropdown is built BEFORE all entries have populated Library.Fonts.
    -- Snapshot what's loaded now + always include "Default" as a sentinel
    -- that reverts to FONT_REG.
    local names = { "Default" }
    for n in self.Fonts or {} do names[#names + 1] = n end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a < b
    end)

    container:AddDropdown('LibraryFont', {
        Text = 'Font',
        Values = names,
        Default = "Default",
        Callback = function(v)
            if v == "Default" or v == nil then
                self:SetFont(nil)
            elseif self.Fonts[v] then
                self:SetFont(v)
            end
        end,
    })

    -- Re-populate the dropdown whenever a new font finishes loading, so an
    -- async-registered font becomes pickable without a script reload. We
    -- watch Library.Fonts via a simple poll (cheap — 1 Hz, only checks
    -- table size). RegisterFontsFromRepo doesn't fire an event, so polling
    -- is the simplest catch-all without instrumenting the loader.
    local lastCount = #names
    track(RunService.Heartbeat:Connect(function()
        local n = 0; for _ in self.Fonts or {} do n = n + 1 end
        n = n + 1   -- "Default"
        if n ~= lastCount and Library.Options.LibraryFont then
            lastCount = n
            local updated = { "Default" }
            for k in self.Fonts or {} do updated[#updated + 1] = k end
            table.sort(updated, function(a, b)
                if a == "Default" then return true end
                if b == "Default" then return false end
                return a < b
            end)
            pcall(Library.Options.LibraryFont.SetValues, Library.Options.LibraryFont, updated)
        end
    end))
end

-- ══════════════════════════════════════════════════════════════════════════
-- PLACEHOLDER BOX — draggable container the host script fills at runtime
-- (Spectator list, killfeed, custom HUD). main.lua usage (Spectator List):
--     local box = Library:CreatePlaceholderBox{ Title = "SPECTATORS", Width = 200 }
--     box:AddLabel("- " .. name) → handle { SetText / SetColor / Remove }
--     box:Clear(); box:SetVisible(bool); box:SetTitle(text); box:Destroy()
-- Visibility rule: shown when (user-enabled) AND (has labels OR menu open).
-- Empty + menu-closed → hidden so unused HUDs don't clutter in-game.
-- ══════════════════════════════════════════════════════════════════════════
Library._phSpawnCount = 0
function Library:CreatePlaceholderBox(config)
    config = config or {}
    local title = config.Title
    local width = config.Width or 200
    local labelSize = config.LabelSize or 14

    -- Auto-stack vertically when caller doesn't pass Position — matches sanyui
    -- behavior so multiple Spectator/Movement/etc boxes don't overlap.
    local position = config.Position
    if not position then
        local idx = Library._phSpawnCount
        Library._phSpawnCount = idx + 1
        position = UDim2.new(1, -(width + 30), 0, 50 + idx * 120)
    end

    -- Outer with 5-stroke layered border + inner Main (matches the watermark
    -- visual). AutomaticSize.Y so box height tracks its label count.
    local outer = mk("Frame", { Parent = ScreenGui,
        Position = position, Size = UDim2.fromOffset(width, 32),
        BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 195, Active = true })
    applyLayeredStrokes(outer, "outer")

    local main = mk("Frame", { Parent = outer,
        Size = UDim2.new(1, -2, 1, -2),
        Position = UDim2.fromOffset(1, 1),
        BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 196 })
    applyLayeredStrokes(main, "inner")

    local titleLbl
    local headerOffset = 4
    if title then
        titleLbl = mkText("TextLabel", { Parent = main,
            Position = UDim2.fromOffset(8, 4),
            Size = UDim2.new(1, -16, 0, 14),
            BackgroundTransparency = 1, Text = tostring(title),
            TextSize = 11, TextColor3 = Theme.TextActive,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 197 }, "bold")
        headerOffset = 22
    end

    -- Content area — labels stack vertically, AutomaticSize drives main → outer.
    local content = mk("Frame", { Parent = main,
        Position = UDim2.fromOffset(8, headerOffset),
        Size = UDim2.new(1, -16, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 197 })
    listLayout(content, Enum.FillDirection.Vertical, 1)
    mk("UIPadding", { Parent = content, PaddingBottom = UDim.new(0, 4) })

    -- Drag from anywhere on the outer surface.
    do
        local dragging, dragStart, startPos
        track(outer.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = outer.Position
            end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                outer.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end))
    end

    local labels = {}
    local box = {
        Frame = outer, Content = content,
        _labels = labels,
        _userVisible = false,
    }

    local function refreshVisibility()
        local hasLabels = #labels > 0
        local menuOpen = Library.Visible
        outer.Visible = box._userVisible and (hasLabels or menuOpen)
    end

    function box:AddLabel(text, color)
        local lbl = mkText("TextLabel", { Parent = content,
            Size = UDim2.new(1, 0, 0, labelSize),
            BackgroundTransparency = 1,
            Text = tostring(text or ""), TextSize = 11,
            TextColor3 = color or Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 198,
        }, "reg")
        labels[#labels + 1] = lbl
        refreshVisibility()
        local handle = { _lbl = lbl }
        function handle:SetText(t) if lbl and lbl.Parent then lbl.Text = tostring(t or "") end end
        function handle:SetColor(c) if lbl and lbl.Parent then lbl.TextColor3 = c end end
        function handle:Remove()
            for i, l in labels do
                if l == lbl then table.remove(labels, i); break end
            end
            pcall(function() lbl:Destroy() end)
            refreshVisibility()
        end
        return handle
    end

    function box:Clear()
        for _, lbl in labels do pcall(function() lbl:Destroy() end) end
        for i = #labels, 1, -1 do labels[i] = nil end
        refreshVisibility()
    end

    function box:SetVisible(v)
        box._userVisible = v and true or false
        refreshVisibility()
    end

    function box:SetTitle(t)
        if titleLbl then
            titleLbl.Text = tostring(t or "")
        end
    end

    function box:Destroy()
        pcall(function() outer:Destroy() end)
    end

    return box
end

function Library:SetWatermark(text)
    watermarkLbl.Text = tostring(text or "")
    Watermark.Visible = (text ~= nil and text ~= "")
    if Watermark.Visible then
        pcall(function()
            local w = measureText(text, 11, "bold")
            Watermark.Size = UDim2.fromOffset(math.max(80, w + 20), 22)
        end)
    end
end
function Library:SetWatermarkVisibility(b) Watermark.Visible = b and true or false end

-- ══════════════════════════════════════════════════════════════════════════
-- INTEGRATED SUBSYSTEMS — SaveManager / ThemeManager / ESPPreview / Watermark
--
-- These four subsystems used to ship as separate addons fetched from github
-- (sanyoner/Nachtara/addons/{SaveManager,ThemeManager,ESPPreview}.lua). They
-- now live in the library so main.lua doesn't need separate fetch() calls —
-- access them via Library.SaveManager, Library.ThemeManager, etc.
--
-- Compatibility: the public APIs match the standalone addons 1:1 so existing
-- main.lua can simply assign `local SaveManager = Library.SaveManager` etc.
-- in place of the previous fetch() calls and keep working.
-- ══════════════════════════════════════════════════════════════════════════

-- Library color aliases consumed by the integrated theme + preview systems.
-- These mirror specific Theme.* fields under the field names the old addons
-- expect (BackgroundColor / MainColor / AccentColor / OutlineColor / FontColor).
-- Writes to these go through Library:ApplyThemeColor below.
Library.AccentColor     = Theme.Accent
Library.AccentColorDark = (function()
    local h, s, v = Color3.toHSV(Theme.Accent)
    return Color3.fromHSV(h, s, math.max(0, v - 0.2))
end)()
Library.BackgroundColor = Theme.WindowBg
Library.MainColor       = Theme.TabBg
Library.OutlineColor    = Theme.BorderHi
Library.FontColor       = Theme.Text

function Library:GetDarkerColor(c)
    if typeof(c) ~= "Color3" then return c end
    local h, s, v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, math.max(0, v - 0.2))
end

-- TextService wrapper that always uses the active custom font when measuring.
-- The integrated ESP preview uses this to size its label area to whatever
-- font the user picked via Library:SetFont — same code path as in-game
-- notifications.
function Library:GetTextBounds(text, font, size, frame)
    if not text or text == "" then return 0, 0 end
    font = font or self:GetActiveFont()
    frame = frame or Vector2.new(math.huge, math.huge)
    local TS = game:GetService("TextService")
    -- Prefer modern Font-aware overload; fall back to legacy Enum.Font path
    -- on executors whose TextService doesn't accept a Font instance.
    local ok, b = pcall(function()
        return TS:GetTextSize(text, size, font and Enum.Font.Code or Enum.Font.Code, frame)
    end)
    if ok and b then return b.X, b.Y end
    return #text * size * 0.6, size + 2
end

-- ══════════════════════════════════════════════════════════════════════════
-- SaveManager — config persistence with XOR + base64 obfuscation on disk.
-- Each saved config is one opaque alphanumeric blob (`.nch`). Casual inspection
-- of the file reveals nothing about toggle names / slider values / keybinds.
-- ══════════════════════════════════════════════════════════════════════════
do
    local HttpService = game:GetService("HttpService")
    local CIPHER_KEY  = "nachtara_cfg_4f8c2a9e1d7b3f65_sanyui_v1"
    local b64c        = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    local function b64enc(d)
        return ((d:gsub('.', function(x)
            local r, b = '', x:byte()
            for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
            return r
        end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if #x < 6 then return '' end
            local c = 0
            for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
            return b64c:sub(c + 1, c + 1)
        end) .. ({ '', '==', '=' })[#d % 3 + 1])
    end

    local function b64dec(d)
        d = string.gsub(d, '[^' .. b64c .. '=]', '')
        return (d:gsub('.', function(x)
            if x == '=' then return '' end
            local r, f = '', (b64c:find(x) - 1)
            for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
            return r
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if #x ~= 8 then return '' end
            local c = 0
            for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0) end
            return string.char(c)
        end))
    end

    local function xorBytes(data, key)
        local out, klen = table.create(#data), #key
        for i = 1, #data do
            out[i] = string.char(bit32.bxor(data:byte(i), key:byte(((i - 1) % klen) + 1)))
        end
        return table.concat(out)
    end

    local function encrypt(plaintext)  return b64enc(xorBytes(plaintext, CIPHER_KEY)) end
    local function decrypt(ciphertext) return xorBytes(b64dec(ciphertext:gsub('%s+', '')), CIPHER_KEY) end

    local SaveManager = {
        Folder        = "sanyui",
        Ignore        = {},
        PreSaveHooks  = {},
        PostLoadHooks = {},
        Library       = Library,
    }

    -- Per-widget save/load adapters. Save returns a serializable table, Load
    -- restores from one. Dispatched off widget.Type — see Type fields added
    -- at widget construction.
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, o) return { type = "Toggle", idx = idx, value = o.Value } end,
            Load = function(idx, d)
                if Library.Toggles[idx] then Library.Toggles[idx]:SetValue(d.value) end
            end,
        },
        Slider = {
            Save = function(idx, o) return { type = "Slider", idx = idx, value = tostring(o.Value) } end,
            Load = function(idx, d)
                if Library.Options[idx] then Library.Options[idx]:SetValue(tonumber(d.value) or 0) end
            end,
        },
        Dropdown = {
            Save = function(idx, o)
                return { type = "Dropdown", idx = idx, value = o.Value, multi = o.Multi }
            end,
            Load = function(idx, d)
                if Library.Options[idx] then Library.Options[idx]:SetValue(d.value) end
            end,
        },
        ColorPicker = {
            Save = function(idx, o)
                return { type = "ColorPicker", idx = idx,
                    value = o.Value:ToHex(), transparency = o.Transparency or 0 }
            end,
            Load = function(idx, d)
                if Library.Options[idx] then
                    pcall(function()
                        Library.Options[idx]:SetValueRGB(Color3.fromHex(d.value), d.transparency)
                    end)
                end
            end,
        },
        KeyPicker = {
            Save = function(idx, o)
                return { type = "KeyPicker", idx = idx, mode = o.Mode, key = o.Value }
            end,
            Load = function(idx, d)
                if Library.Options[idx] then Library.Options[idx]:SetValue({ d.key, d.mode }) end
            end,
        },
        Input = {
            Save = function(idx, o) return { type = "Input", idx = idx, text = o.Value } end,
            Load = function(idx, d)
                if Library.Options[idx] and type(d.text) == "string" then
                    Library.Options[idx]:SetValue(d.text)
                end
            end,
        },
    }

    function SaveManager:SetLibrary(lib) self.Library = lib end

    function SaveManager:BuildFolderTree()
        for _, p in { self.Folder, self.Folder .. "/themes", self.Folder .. "/settings" } do
            if not isfolder(p) then makefolder(p) end
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in list do self.Ignore[key] = true end
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({
            "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
            "ThemeManager_ThemeList", "ThemeManager_CustomThemeList",
            "ThemeManager_CustomThemeName",
        })
    end

    function SaveManager:AddPreSaveHook(fn)
        if type(fn) == "function" then self.PreSaveHooks[#self.PreSaveHooks + 1] = fn end
    end

    function SaveManager:AddPostLoadHook(fn)
        if type(fn) == "function" then self.PostLoadHooks[#self.PostLoadHooks + 1] = fn end
    end

    function SaveManager:Save(name)
        if not name or name == "" then return false, "no config name" end
        local data = { objects = {} }

        -- Walk Toggles + Options, dispatch via widget.Type, skip ignored keys.
        for idx, w in Library.Toggles do
            if not self.Ignore[idx] and w.Type and self.Parser[w.Type] then
                data.objects[#data.objects + 1] = self.Parser[w.Type].Save(idx, w)
            end
        end
        for idx, w in Library.Options do
            if not self.Ignore[idx] and w.Type and self.Parser[w.Type] then
                data.objects[#data.objects + 1] = self.Parser[w.Type].Save(idx, w)
            end
        end

        for _, fn in self.PreSaveHooks do pcall(fn, data) end

        local okE, json = pcall(HttpService.JSONEncode, HttpService, data)
        if not okE then return false, "encode failed" end
        local okC, payload = pcall(encrypt, json)
        if not okC then return false, "encrypt failed" end

        local fullPath = self.Folder .. "/settings/" .. name .. ".nch"
        local okW, err = pcall(writefile, fullPath, payload)
        if not okW then return false, "writefile failed: " .. tostring(err) end

        -- Drop legacy plain-JSON copy so Load doesn't prefer stale data.
        local legacy = self.Folder .. "/settings/" .. name .. ".json"
        if isfile(legacy) then pcall(delfile, legacy) end
        return true
    end

    function SaveManager:Load(name)
        if not name or name == "" then return false, "no config name" end
        local enc    = self.Folder .. "/settings/" .. name .. ".nch"
        local legacy = self.Folder .. "/settings/" .. name .. ".json"

        local raw
        if isfile(enc) then
            local payload = readfile(enc)
            local okD, plain = pcall(decrypt, payload)
            if not okD or type(plain) ~= "string" then return false, "decrypt failed" end
            raw = plain
        elseif isfile(legacy) then
            raw = readfile(legacy)
        else
            return false, "config not found"
        end

        local okD, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        if not okD or type(decoded) ~= "table" or type(decoded.objects) ~= "table" then
            return false, "decode failed"
        end

        for _, obj in decoded.objects do
            local parser = self.Parser[obj.type]
            if parser then task.spawn(function() parser.Load(obj.idx, obj) end) end
        end
        for _, fn in self.PostLoadHooks do
            task.spawn(function() pcall(fn, decoded) end)
        end
        return true
    end

    function SaveManager:RefreshConfigList()
        local list = pcall(listfiles, self.Folder .. "/settings") and listfiles(self.Folder .. "/settings") or {}
        local out, seen = {}, {}
        for _, file in list do
            local ext = file:sub(-4)
            local isCfg = ext == ".nch" or file:sub(-5) == ".json"
            if isCfg then
                local extLen = ext == ".nch" and 4 or 5
                local stop = #file - extLen
                local pos = stop
                while pos > 0 do
                    local ch = file:sub(pos, pos)
                    if ch == "/" or ch == "\\" then break end
                    pos = pos - 1
                end
                local name = file:sub(pos + 1, stop)
                if not seen[name] then
                    seen[name] = true
                    out[#out + 1] = name
                end
            end
        end
        return out
    end

    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, "SaveManager: SetLibrary first")
        local gb = tab:AddRightGroupbox("Configuration")
        gb:AddInput("SaveManager_ConfigName", { Text = "Config name" })
        gb:AddDropdown("SaveManager_ConfigList", {
            Text = "Config list",
            Values = self:RefreshConfigList(),
            AllowNull = true,
        })
        gb:AddDivider()
        gb:AddButton("Create config", function()
            local name = Library.Options.SaveManager_ConfigName.Value
            if not name or name:gsub(" ", "") == "" then
                return self.Library:Notify("Invalid config name", 2)
            end
            local ok, err = self:Save(name)
            if not ok then return self.Library:Notify("Save failed: " .. tostring(err), 3) end
            self.Library:Notify("Created config '" .. name .. "'", 2)
            Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        end)
        gb:AddButton("Load config", function()
            local name = Library.Options.SaveManager_ConfigList.Value
            if not name or name == "" then
                return self.Library:Notify("Pick a config first", 2)
            end
            local ok, err = self:Load(name)
            if not ok then return self.Library:Notify("Load failed: " .. tostring(err), 3) end
            self.Library:Notify("Loaded config '" .. name .. "'", 2)
            Library._CurrentConfig = name
        end)
        gb:AddButton("Overwrite", function()
            local name = Library.Options.SaveManager_ConfigList.Value
            if not name or name == "" then
                return self.Library:Notify("Pick a config first", 2)
            end
            local ok, err = self:Save(name)
            if not ok then return self.Library:Notify("Save failed: " .. tostring(err), 3) end
            self.Library:Notify("Overwrote '" .. name .. "'", 2)
        end)
        gb:AddButton("Refresh list", function()
            Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
        end)

        self:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
    end

    SaveManager:BuildFolderTree()
    Library.SaveManager = SaveManager
end

-- ══════════════════════════════════════════════════════════════════════════
-- ThemeManager — palette presets + custom theme save/load.
-- Preset colors map to Library's Theme.* fields. Live ColorPicker changes
-- propagate to Library.<slot> fields, but already-rendered widgets keep
-- their construction-time colors — re-running the script applies the new
-- theme everywhere.
-- ══════════════════════════════════════════════════════════════════════════
do
    local HttpService = game:GetService("HttpService")
    local ThemeManager = {
        Folder       = "sanyui",
        Library      = Library,
        DefaultTheme = "Default",
    }

    -- ThemeManager color slots → Library Theme.* field that drives renderer.
    local SLOT_TO_THEME = {
        BackgroundColor = "WindowBg",
        MainColor       = "TabBg",
        AccentColor     = "Accent",
        OutlineColor    = "BorderHi",
        FontColor       = "Text",
    }
    local THEME_FIELDS = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }

    ThemeManager.BuiltInThemes = {
        ["Default"]      = { 1, { FontColor="e1e1e1", MainColor="191919", AccentColor="93c539", BackgroundColor="121212", OutlineColor="3d3d3d" }},
        ["Amethyst"]     = { 2, { FontColor="ffffff", MainColor="1a1625", AccentColor="9b59b6", BackgroundColor="141022", OutlineColor="2b2339" }},
        ["Fatality"]     = { 3, { FontColor="ffffff", MainColor="1e1842", AccentColor="c50754", BackgroundColor="191335", OutlineColor="3c355d" }},
        ["Jester"]       = { 4, { FontColor="ffffff", MainColor="242424", AccentColor="db4467", BackgroundColor="1c1c1c", OutlineColor="373737" }},
        ["Mint"]         = { 5, { FontColor="ffffff", MainColor="242424", AccentColor="3db488", BackgroundColor="1c1c1c", OutlineColor="373737" }},
        ["Tokyo Night"]  = { 6, { FontColor="ffffff", MainColor="191925", AccentColor="6759b3", BackgroundColor="16161f", OutlineColor="323232" }},
        ["Sunset"]       = { 7, { FontColor="ffffff", MainColor="3e3e3e", AccentColor="e2581e", BackgroundColor="323232", OutlineColor="191919" }},
        ["Quartz"]       = { 8, { FontColor="ffffff", MainColor="232330", AccentColor="426e87", BackgroundColor="1d1b26", OutlineColor="27232f" }},
        ["Classic Blue"] = { 9, { FontColor="ffffff", MainColor="1c1c1c", AccentColor="0055ff", BackgroundColor="141414", OutlineColor="323232" }},
    }

    function ThemeManager:SetLibrary(lib) self.Library = lib end

    function ThemeManager:BuildFolderTree()
        local parts = self.Folder:split("/")
        local paths = {}
        for i = 1, #parts do paths[#paths + 1] = table.concat(parts, "/", 1, i) end
        paths[#paths + 1] = self.Folder .. "/themes"
        paths[#paths + 1] = self.Folder .. "/settings"
        for _, p in paths do
            if not isfolder(p) then makefolder(p) end
        end
    end

    function ThemeManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    -- Apply a palette (hex-string table) to the library. Updates BOTH
    -- Library.<slot> aliases AND Theme.<themeField> so subsequent widgets
    -- render with the new colors. Doesn't retroactively repaint existing
    -- widgets (would require a full color registry which the library
    -- intentionally doesn't carry).
    local function applyPalette(palette)
        for slot, hex in palette do
            local col = Color3.fromHex(hex)
            Library[slot] = col
            local themeKey = SLOT_TO_THEME[slot]
            if themeKey then Theme[themeKey] = col end
            if Library.Options[slot] then
                pcall(function() Library.Options[slot]:SetValueRGB(col) end)
            end
        end
        Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
    end

    function ThemeManager:ApplyTheme(name)
        local custom = self:GetCustomTheme(name)
        if custom then applyPalette(custom); return end
        local entry = self.BuiltInThemes[name]
        if entry then applyPalette(entry[2]) end
    end

    function ThemeManager:GetCustomTheme(file)
        if not file or file == "" then return nil end
        local path = self.Folder .. "/themes/" .. file
        if not isfile(path) then return nil end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(path))
        return ok and decoded or nil
    end

    function ThemeManager:SaveCustomTheme(file)
        if not file or file:gsub(" ", "") == "" then
            return self.Library:Notify("Invalid theme name", 3)
        end
        local theme = {}
        for _, field in THEME_FIELDS do
            if Library.Options[field] and Library.Options[field].Value then
                theme[field] = Library.Options[field].Value:ToHex()
            end
        end
        pcall(writefile, self.Folder .. "/themes/" .. file .. ".json",
            HttpService:JSONEncode(theme))
    end

    function ThemeManager:ReloadCustomThemes()
        local out = {}
        local ok, list = pcall(listfiles, self.Folder .. "/themes")
        if not ok then return out end
        for _, file in list do
            if file:sub(-5) == ".json" then
                local pos = #file - 5
                while pos > 0 do
                    local ch = file:sub(pos, pos)
                    if ch == "/" or ch == "\\" then break end
                    pos = pos - 1
                end
                out[#out + 1] = file:sub(pos + 1)
            end
        end
        return out
    end

    function ThemeManager:LoadDefault()
        local path = self.Folder .. "/themes/default.txt"
        local theme = self.DefaultTheme
        if isfile(path) then
            local saved = readfile(path)
            if self.BuiltInThemes[saved] or self:GetCustomTheme(saved) then
                theme = saved
            end
        end
        if Library.Options.ThemeManager_ThemeList then
            Library.Options.ThemeManager_ThemeList:SetValue(theme)
        else
            self:ApplyTheme(theme)
        end
    end

    function ThemeManager:SaveDefault(theme)
        pcall(writefile, self.Folder .. "/themes/default.txt", theme)
    end

    function ThemeManager:CreateThemeManager(gb)
        gb:AddLabel("Background"):AddColorPicker("BackgroundColor", { Default = Library.BackgroundColor })
        gb:AddLabel("Main")      :AddColorPicker("MainColor",       { Default = Library.MainColor })
        gb:AddLabel("Accent")    :AddColorPicker("AccentColor",     { Default = Library.AccentColor })
        gb:AddLabel("Outline")   :AddColorPicker("OutlineColor",    { Default = Library.OutlineColor })
        gb:AddLabel("Font")      :AddColorPicker("FontColor",       { Default = Library.FontColor })

        local names = {}
        for n in self.BuiltInThemes do names[#names + 1] = n end
        table.sort(names, function(a, b)
            return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1]
        end)

        gb:AddDivider()
        gb:AddDropdown("ThemeManager_ThemeList", { Text = "Preset", Values = names, Default = 1 })
        gb:AddButton("Set as default", function()
            self:SaveDefault(Library.Options.ThemeManager_ThemeList.Value)
            self.Library:Notify("Set default theme", 2)
        end)
        Library.Options.ThemeManager_ThemeList:OnChanged(function()
            self:ApplyTheme(Library.Options.ThemeManager_ThemeList.Value)
        end)

        gb:AddDivider()
        gb:AddInput("ThemeManager_CustomThemeName", { Text = "Custom theme name" })
        gb:AddDropdown("ThemeManager_CustomThemeList", {
            Text = "Custom themes",
            Values = self:ReloadCustomThemes(),
            AllowNull = true, Default = 1,
        })
        gb:AddButton("Save theme", function()
            self:SaveCustomTheme(Library.Options.ThemeManager_CustomThemeName.Value)
            Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        end)
        gb:AddButton("Load theme", function()
            local val = Library.Options.ThemeManager_CustomThemeList.Value
            if val and val ~= "" then self:ApplyTheme(val) end
        end)
        gb:AddButton("Refresh list", function()
            Library.Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
        end)

        -- Live updates: changing any ColorPicker updates Library.<slot> + Theme.
        local function refresh()
            for _, field in THEME_FIELDS do
                if Library.Options[field] then
                    Library[field] = Library.Options[field].Value
                    local themeKey = SLOT_TO_THEME[field]
                    if themeKey then Theme[themeKey] = Library.Options[field].Value end
                end
            end
            Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)
        end
        for _, field in THEME_FIELDS do
            if Library.Options[field] then Library.Options[field]:OnChanged(refresh) end
        end

        self:LoadDefault()
    end

    function ThemeManager:ApplyToTab(tab)
        assert(self.Library, "ThemeManager: SetLibrary first")
        local gb = tab:AddLeftGroupbox("Themes")
        self:CreateThemeManager(gb)
    end

    ThemeManager:BuildFolderTree()
    Library.ThemeManager = ThemeManager
end

-- ══════════════════════════════════════════════════════════════════════════
-- ESPPreview — draggable preview window with a 3D rotatable R15 character
-- in a ViewportFrame, surrounded by the same ESP box overlay the real
-- script renders. Lets users dial in ESP settings without needing visible
-- enemies in-game.
--
-- Drag the character: hold MB1 inside the viewport and move the mouse —
-- the character spins on its Y axis (yaw) following horizontal motion,
-- and pitches on the X axis (clamped to ±60°) following vertical motion.
-- Right-click drag pans the camera up/down.
-- ══════════════════════════════════════════════════════════════════════════
do
    local Players      = game:GetService("Players")
    local RunService   = game:GetService("RunService")
    local LocalPlayer  = Players.LocalPlayer

    local ESPPreview = {
        Library      = Library,
        Bound        = {},
        _wantsVisible = false,
        _visible     = false,
        FakeData     = {
            Name           = "EnemyPlayer",
            Distance       = "42m",
            MovementState  = "Move",
            HeldWeapon     = "AK-47",
            Teams          = "Terrorists",
        },
    }

    local ESP_INFO_TYPES = { "Name", "Distance", "MovementState", "HeldWeapon", "Teams" }

    function ESPPreview:SetLibrary(lib) self.Library = lib end
    function ESPPreview:SetFakeData(t)
        if type(t) ~= "table" then return end
        for k, v in t do self.FakeData[k] = v end
    end

    local Outer, Viewport, BoxOverlay, Labels, Healthbars, RotationState
    local boxRot, fillRot = 0, 0

    -- Build a Camera + clone of LocalPlayer.Character (or a placeholder rig)
    -- into a WorldModel inside the ViewportFrame. Returns (worldModel, char,
    -- camera, hrp, head). Rebuilt whenever the character respawns.
    local function buildSceneInto(vp)
        for _, c in vp:GetChildren() do
            if c:IsA("WorldModel") or c:IsA("Camera") then
                pcall(c.Destroy, c)
            end
        end
        local wm = Instance.new("WorldModel")
        wm.Parent = vp

        local cam = Instance.new("Camera")
        cam.FieldOfView = 30
        cam.Parent = vp
        vp.CurrentCamera = cam

        -- Try to clone the local player's character. Falls back to building
        -- a simple block-figure if no character (loadout screen / pre-spawn /
        -- spectator state). Archivable=true on the original is required for
        -- :Clone() to succeed; we set it back to its previous value after.
        local char
        local origChar = LocalPlayer.Character
        if origChar then
            local origArchivable = origChar.Archivable
            pcall(function() origChar.Archivable = true end)
            local ok, clone = pcall(origChar.Clone, origChar)
            pcall(function() origChar.Archivable = origArchivable end)
            if ok and clone then
                char = clone
                -- Strip scripts so the cloned character can't run anything
                -- inside our viewport. Also drop any BillboardGui ESP we
                -- attached to the real character so the preview's overlay
                -- doesn't render twice.
                for _, d in char:GetDescendants() do
                    if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
                       or d:IsA("BillboardGui") then
                        pcall(d.Destroy, d)
                    end
                end
                -- Reset transparency so the cloned char isn't hidden by the
                -- ThirdPerson LTM flips we did on the live one.
                for _, p in char:GetDescendants() do
                    if p:IsA("BasePart") then
                        pcall(function()
                            p.LocalTransparencyModifier = 0
                            p.Anchored = true
                            p.CanCollide = false
                        end)
                    end
                end
            end
        end

        if not char then
            -- Generic R15-ish placeholder. Simple sized capsules so the user
            -- still sees a humanoid silhouette to position ESP around.
            char = Instance.new("Model")
            char.Name = "Placeholder"
            local function part(name, sz, pos, col)
                local p = Instance.new("Part")
                p.Name = name; p.Anchored = true; p.CanCollide = false
                p.Size = sz; p.CFrame = CFrame.new(pos)
                p.Color = col; p.Material = Enum.Material.Plastic
                p.TopSurface = Enum.SurfaceType.Smooth
                p.BottomSurface = Enum.SurfaceType.Smooth
                p.Parent = char
                return p
            end
            local skin = Color3.fromRGB(204, 142, 105)
            part("Head", Vector3.new(1, 1, 1), Vector3.new(0, 4.5, 0), skin)
            local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1),
                Vector3.new(0, 3, 0), Color3.fromRGB(40, 40, 80))
            char.PrimaryPart = hrp
            part("UpperTorso", Vector3.new(2, 1, 1), Vector3.new(0, 3.5, 0), Color3.fromRGB(40, 40, 80))
            part("LowerTorso", Vector3.new(2, 1, 1), Vector3.new(0, 2.5, 0), Color3.fromRGB(40, 40, 80))
            part("LeftUpperArm",  Vector3.new(1, 1.5, 1), Vector3.new(-1.5,  3.25, 0), skin)
            part("RightUpperArm", Vector3.new(1, 1.5, 1), Vector3.new( 1.5,  3.25, 0), skin)
            part("LeftUpperLeg",  Vector3.new(1, 1.5, 1), Vector3.new(-0.5,  1.25, 0), Color3.fromRGB(50, 50, 50))
            part("RightUpperLeg", Vector3.new(1, 1.5, 1), Vector3.new( 0.5,  1.25, 0), Color3.fromRGB(50, 50, 50))
        end

        char.Parent = wm

        local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        local head = char:FindFirstChild("Head")
        if hrp and not char.PrimaryPart then char.PrimaryPart = hrp end

        return wm, char, cam, hrp, head
    end

    -- One-time window build. Called the first time Show() fires.
    local function build()
        if Outer then return end

        -- Outer + 5-stroke composite borders (matches the main Window's chrome).
        local W, H = 280, 360
        Outer = mk("Frame", { Parent = ScreenGui,
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(1, -(W + 80), 0, 80),
            Size = UDim2.fromOffset(W, H),
            BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
            Visible = false, ZIndex = 230, Active = true })
        applyLayeredStrokes(Outer, "outer")

        -- Title bar (drag handle area).
        local titleBar = mk("Frame", { Parent = Outer,
            Size = UDim2.new(1, -14, 0, 22), Position = UDim2.fromOffset(7, 7),
            BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0, ZIndex = 231 })
        mkText("TextLabel", { Parent = titleBar, ZIndex = 232,
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -16, 1, 0),
            BackgroundTransparency = 1, Text = "ESP Preview",
            TextSize = 12, TextColor3 = Theme.TextActive,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, "bold")
        -- Accent underline on the title bar — matches the main window's
        -- rainbow strip but trimmed since the preview is a satellite panel.
        mk("Frame", { Parent = Outer, ZIndex = 233,
            Size = UDim2.new(1, -14, 0, 1), Position = UDim2.fromOffset(7, 29),
            BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })

        -- Inner content frame (inner 5-stroke border + TabBg).
        local content = mk("Frame", { Parent = Outer, ZIndex = 231,
            Position = UDim2.fromOffset(14, 36),
            Size = UDim2.new(1, -28, 1, -50),
            BackgroundColor3 = Theme.TabBg, BorderSizePixel = 0 })
        applyLayeredStrokes(content, "inner")

        -- ViewportFrame in the center. 3D char gets parented inside.
        Viewport = mk("ViewportFrame", { Parent = content, ZIndex = 232,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(140, 240),
            BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
            Ambient = Color3.fromRGB(180, 180, 180),
            LightColor = Color3.fromRGB(255, 255, 255),
            LightDirection = Vector3.new(-0.3, -1, -0.5),
            Active = true,
        })

        -- ESP overlay — drawn ON TOP of the viewport, anchored to its edges.
        -- Mirrors the structure of the real ESP billboard's box layers.
        BoxOverlay = {}

        -- 5-stroke composite box around the viewport.
        local function makeBoxLayer(name, posOff, sizeOff, color, zi)
            local f = mk("Frame", { Parent = content, ZIndex = zi,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(140 + sizeOff, 240 + sizeOff),
                BackgroundColor3 = color, BorderSizePixel = 0,
                BackgroundTransparency = 1 })
            return f
        end

        BoxOverlay.outerBox = makeBoxLayer("outer",  0, 2, Color3.new(0, 0, 0), 233)
        BoxOverlay.colorRing = makeBoxLayer("color", 0, 0, Color3.new(1, 1, 1), 234)
        BoxOverlay.innerBox = makeBoxLayer("inner", 0, -2, Color3.new(0, 0, 0), 235)
        BoxOverlay.fillBox  = mk("Frame", { Parent = content, ZIndex = 234,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(140, 240),
            BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0,
            BackgroundTransparency = 1 })
        local fillGrad = Instance.new("UIGradient"); fillGrad.Enabled = false; fillGrad.Parent = BoxOverlay.fillBox
        local colorRingGrad = Instance.new("UIGradient"); colorRingGrad.Enabled = false; colorRingGrad.Parent = BoxOverlay.colorRing
        BoxOverlay.fillGrad = fillGrad
        BoxOverlay.colorRingGrad = colorRingGrad

        -- Labels (Top / Right / Left / Down) — anchored relative to viewport.
        local function makeLabel(anchor, align, posY, sizeX, sizeY)
            local l = mkText("TextLabel", { Parent = content, ZIndex = 236,
                AnchorPoint = anchor,
                Position = UDim2.new(0.5, 0, 0.5, posY),
                Size = UDim2.fromOffset(sizeX, sizeY),
                BackgroundTransparency = 1, Text = "",
                TextColor3 = Color3.new(1, 1, 1), TextSize = 12,
                TextXAlignment = align, Visible = false,
            }, "reg")
            return l
        end
        Labels = {
            Top   = makeLabel(Vector2.new(0.5, 1), Enum.TextXAlignment.Center, -125, 140, 14),
            Down  = makeLabel(Vector2.new(0.5, 0), Enum.TextXAlignment.Center,  125, 140, 14),
            Left  = makeLabel(Vector2.new(1, 0.5), Enum.TextXAlignment.Right,  0, 50, 240),
            Right = makeLabel(Vector2.new(0, 0.5), Enum.TextXAlignment.Left,   0, 50, 240),
        }
        Labels.Left.Position  = UDim2.new(0.5, -76, 0.5, 0)
        Labels.Right.Position = UDim2.new(0.5,  76, 0.5, 0)

        -- Healthbar (top position only — same default the real ESP uses).
        local hb = mk("Frame", { Parent = content, ZIndex = 235,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 0.5, -123),
            Size = UDim2.fromOffset(140, 2),
            BackgroundColor3 = Color3.fromRGB(12, 255, 93), BorderSizePixel = 0,
            Visible = false })
        Healthbars = { Top = hb }

        -- Drag the WINDOW from the title bar.
        do
            local drag, ds, sp
            track(titleBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                   or input.UserInputType == Enum.UserInputType.Touch then
                    drag = true; ds = input.Position; sp = Outer.Position
                end
            end))
            track(UserInputService.InputChanged:Connect(function(input)
                if not drag then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                   or input.UserInputType == Enum.UserInputType.Touch then
                    local d = input.Position - ds
                    Outer.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X,
                                               sp.Y.Scale, sp.Y.Offset + d.Y)
                end
            end))
            track(UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                   or input.UserInputType == Enum.UserInputType.Touch then drag = false end
            end))
        end

        -- Rotate the CHARACTER inside the viewport. Holding MB1 inside the
        -- viewport spins the character on its Y axis; vertical motion
        -- pitches the camera (clamped ±60°). Releasing MB1 leaves it where
        -- the user left it (no auto-spin), matching what the user asked for.
        RotationState = { yaw = 0, pitch = 0, dist = 8,
            dragging = false, last = nil }
        track(Viewport.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                RotationState.dragging = true
                RotationState.last = input.Position
            end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                RotationState.dragging = false
            end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if not RotationState.dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local last = RotationState.last
            if not last then RotationState.last = input.Position; return end
            local dx = input.Position.X - last.X
            local dy = input.Position.Y - last.Y
            RotationState.last = input.Position
            RotationState.yaw   = (RotationState.yaw + dx * 0.01) % (math.pi * 2)
            RotationState.pitch = math.clamp(RotationState.pitch - dy * 0.01,
                math.rad(-60), math.rad(60))
        end))

        -- Mouse wheel inside viewport = zoom (4..16 stud distance from char).
        track(Viewport.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
            RotationState.dist = math.clamp(RotationState.dist - input.Position.Z * 0.5, 4, 16)
        end))

        ESPPreview._content = content
        ESPPreview._titleBar = titleBar
    end

    -- Rebuild scene whenever requested (initial show + character respawn).
    local function rebuildScene()
        if not Viewport then return end
        local wm, char, cam, hrp, head = buildSceneInto(Viewport)
        ESPPreview._wm   = wm
        ESPPreview._char = char
        ESPPreview._cam  = cam
        ESPPreview._hrp  = hrp
        ESPPreview._head = head
    end

    -- Per-frame: position camera around the character (orbit at RotationState
    -- distance / yaw / pitch) and update ESP overlay colors + label texts
    -- from the live Toggles/Options.
    local function update(dt)
        if not Outer or not Outer.Visible then return end

        -- Auto-rebuild on character respawn.
        if not ESPPreview._char or not ESPPreview._char.Parent then
            rebuildScene()
        end
        local char, cam = ESPPreview._char, ESPPreview._cam
        if not char or not cam then return end

        -- Orbit camera. Center = HRP position (or model PrimaryPart, or
        -- (0, 3, 0) fallback for clones whose HRP got destroyed).
        local center
        if ESPPreview._hrp and ESPPreview._hrp.Parent then
            center = ESPPreview._hrp.Position
        elseif char.PrimaryPart then
            center = char.PrimaryPart.Position
        else
            center = Vector3.new(0, 3, 0)
        end
        local yaw, pitch, dist = RotationState.yaw, RotationState.pitch, RotationState.dist
        local cx = math.cos(pitch) * math.sin(yaw) * dist
        local cz = math.cos(pitch) * math.cos(yaw) * dist
        local cy = math.sin(pitch) * dist + 1.5  -- 1.5 stud uplift so eye-line lands on the head
        cam.CFrame = CFrame.new(center + Vector3.new(cx, cy, cz), center)

        -- ESP overlay reads SAME Toggles/Options the main ESP loop reads,
        -- so the preview reflects the user's exact configured look.
        local boxOn  = Toggles.ESPBox  and Toggles.ESPBox.Value
        local fillOn = Toggles.ESPFill and Toggles.ESPFill.Value
        local hbOn   = Toggles.ESPHealthbar and Toggles.ESPHealthbar.Value

        BoxOverlay.outerBox.BackgroundTransparency  = boxOn and 0 or 1
        BoxOverlay.colorRing.BackgroundTransparency = boxOn and 0 or 1
        BoxOverlay.innerBox.BackgroundTransparency  = boxOn and 0 or 1

        if boxOn then
            local c1 = Options.ESPBoxColor and Options.ESPBoxColor.Value or Color3.new(1, 1, 1)
            if Toggles.ESPBoxGradient and Toggles.ESPBoxGradient.Value then
                local c2 = Options.ESPBoxColor2 and Options.ESPBoxColor2.Value or Color3.new(1, 0, 0)
                BoxOverlay.colorRingGrad.Enabled = true
                BoxOverlay.colorRingGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2),
                }
                if Toggles.ESPBoxRotation and Toggles.ESPBoxRotation.Value then
                    local rs = Options.ESPBoxGradRot and Options.ESPBoxGradRot.Value or 90
                    boxRot = (boxRot + rs * dt) % 360
                    BoxOverlay.colorRingGrad.Rotation = boxRot
                end
                BoxOverlay.colorRing.BackgroundColor3 = Color3.new(1, 1, 1)
            else
                BoxOverlay.colorRingGrad.Enabled = false
                BoxOverlay.colorRing.BackgroundColor3 = c1
            end
        end

        if fillOn and boxOn then
            local fc = Options.ESPFillColor and Options.ESPFillColor.Value or Color3.new(1, 1, 1)
            local ft = Options.ESPFillTrans and Options.ESPFillTrans.Value or 0.8
            BoxOverlay.fillBox.BackgroundColor3 = fc
            BoxOverlay.fillBox.BackgroundTransparency = ft
        else
            BoxOverlay.fillBox.BackgroundTransparency = 1
        end

        -- Healthbar at 100% (preview is static).
        local hb = Healthbars.Top
        if hbOn then
            hb.Visible = true
            local c = Options.ESPHealthbarColor and Options.ESPHealthbarColor.Value or Color3.fromRGB(12, 255, 93)
            hb.BackgroundColor3 = c
        else
            hb.Visible = false
        end

        -- Labels: build per-position text from enabled toggles + fake data,
        -- mirroring the real ESP's per-info dispatch.
        local bufs = { Top = {}, Right = {}, Left = {}, Down = {} }
        local cols = {}
        local sizes = {}
        for _, it in ESP_INFO_TYPES do
            local tn = "ESP" .. it
            if Toggles[tn] and Toggles[tn].Value then
                local pos = Options["ESP" .. it .. "Pos"] and Options["ESP" .. it .. "Pos"].Value or "Top"
                local txt = ESPPreview.FakeData[it] or ""
                if txt ~= "" then
                    local b = bufs[pos]
                    if b then
                        b[#b + 1] = txt
                        cols[pos] = cols[pos] or (Options["ESP" .. it .. "Color"]
                            and Options["ESP" .. it .. "Color"].Value or Color3.new(1, 1, 1))
                        sizes[pos] = Options["ESP" .. it .. "Size"]
                            and Options["ESP" .. it .. "Size"].Value or 12
                    end
                end
            end
        end
        for pos, lbl in Labels do
            local b = bufs[pos]
            if b and #b > 0 then
                local sep = (pos == "Top" or pos == "Down") and " | " or "\n"
                lbl.Text = table.concat(b, sep)
                lbl.TextColor3 = cols[pos] or Color3.new(1, 1, 1)
                lbl.TextSize = sizes[pos] or 12
                lbl.Visible = true
            else
                lbl.Visible = false
            end
        end
    end

    function ESPPreview:Show()
        build()
        if not ESPPreview._char or not ESPPreview._char.Parent then rebuildScene() end
        Outer.Visible = true
        self._visible = true
        if not self._conn then
            self._conn = track(RunService.RenderStepped:Connect(update))
        end
    end

    function ESPPreview:Hide()
        if Outer then Outer.Visible = false end
        self._visible = false
    end

    function ESPPreview:Toggle()
        if self._visible then self:Hide() else self:Show() end
    end

    -- Bind one or more tabs. Preview shows when any bound tab is active +
    -- the menu is open. Hides otherwise.
    function ESPPreview:BindTabs(window, tabs)
        if type(tabs) ~= "table" then tabs = { tabs } end
        for _, tab in tabs do self.Bound[tab] = true end

        local function syncVisibility()
            local shouldShow = false
            if Library.Visible and window._activeTab then
                shouldShow = self.Bound[window._activeTab] or false
            end
            if shouldShow then self:Show() else self:Hide() end
        end

        -- Hook SelectTab so we can poll on every tab change.
        local origSelect = window.SelectTab
        window.SelectTab = function(self_, tab)
            origSelect(self_, tab)
            syncVisibility()
        end
        -- Also re-evaluate on menu open/close.
        track(RunService.Heartbeat:Connect(function()
            -- Cheap visibility check — 60Hz is fine, only flips state on change.
            if Library.Visible then
                if not self._lastMenuOpen then syncVisibility() end
                self._lastMenuOpen = true
            else
                if self._lastMenuOpen then self:Hide() end
                self._lastMenuOpen = false
            end
        end))
        syncVisibility()
    end

    -- Backward-compat: standalone addon had BindTab (singular). Alias both.
    function ESPPreview:BindTab(window, tab) self:BindTabs(window, { tab }) end

    Library.ESPPreview = ESPPreview
end

-- ══════════════════════════════════════════════════════════════════════════
-- Watermark customization — Settings tab gets a Watermark groupbox with a
-- multi-select dropdown of fields: name, playername, clocktime, serverping,
-- object count, fps, script runtime, config loaded. Updates the in-game
-- watermark label every frame from the selected fields.
--
-- Use Library:CreateWatermarkSection(tab) to add the controls to a tab
-- (typically Settings). The Settings handler is created automatically when
-- the user calls it; without it, the watermark stays at whatever was last
-- set via Library:SetWatermark.
-- ══════════════════════════════════════════════════════════════════════════
do
    local RunService = game:GetService("RunService")
    local Stats      = game:GetService("Stats")
    local Players    = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local SCRIPT_START = tick()

    -- Ordered list for the multi-select dropdown. Display labels match the
    -- user's request exactly (lowercase, spaces preserved). Each entry has
    -- a "render()" that returns the live string.
    local FIELDS_ORDER = {
        "name", "playername", "clocktime", "serverping",
        "object count", "fps", "script runtime", "config loaded",
    }

    local lastFrameTime = tick()
    local frameDelta = 1 / 60
    -- Sampled FPS — simple EMA so the readout doesn't flicker.
    local emaFps = 60

    -- Per-field render functions. Defined inside the IIFE so they capture
    -- LocalPlayer / Stats etc. as upvalues.
    local FIELD_PROVIDERS = {
        ["name"] = function()
            return Library._WatermarkName or "nachtara"
        end,
        ["playername"] = function()
            return LocalPlayer.DisplayName or LocalPlayer.Name
        end,
        ["clocktime"] = function()
            return os.date("%H:%M:%S")
        end,
        ["serverping"] = function()
            -- Stats.PerformanceStats:WaitForChild("Ping") is the canonical
            -- read path. Falls back to LocalPlayer:GetNetworkPing()*1000 if
            -- the perf stats aren't accessible on this executor.
            local ok, ping = pcall(function()
                return math.floor(LocalPlayer:GetNetworkPing() * 1000)
            end)
            if ok and ping then return ping .. "ms" end
            return "?ms"
        end,
        ["object count"] = function()
            -- Count immediate workspace descendants (fast). Full
            -- :GetDescendants on workspace would be tens of thousands of
            -- instances and stall the render thread.
            return tostring(#workspace:GetChildren()) .. " objs"
        end,
        ["fps"] = function()
            return tostring(math.floor(emaFps + 0.5)) .. " fps"
        end,
        ["script runtime"] = function()
            local s = tick() - SCRIPT_START
            local h = math.floor(s / 3600)
            local m = math.floor((s % 3600) / 60)
            local sec = math.floor(s % 60)
            if h > 0 then
                return string.format("%d:%02d:%02d", h, m, sec)
            end
            return string.format("%d:%02d", m, sec)
        end,
        ["config loaded"] = function()
            return Library._CurrentConfig or "none"
        end,
    }

    Library._WatermarkConfig = {
        Enabled    = true,
        Name       = "nachtara",
        Fields     = { "name", "playername", "fps" },
        Separator  = " | ",
    }

    -- Render the watermark text from the current selection.
    local function renderWatermark()
        local cfg = Library._WatermarkConfig
        if not cfg.Enabled then
            Library:SetWatermarkVisibility(false)
            return
        end
        local parts = {}
        for _, field in cfg.Fields do
            local provider = FIELD_PROVIDERS[field]
            if provider then
                local ok, value = pcall(provider)
                if ok and value ~= nil and value ~= "" then
                    parts[#parts + 1] = tostring(value)
                end
            end
        end
        if #parts == 0 then
            Library:SetWatermarkVisibility(false)
            return
        end
        local sep = cfg.Separator or " | "
        Library:SetWatermark(table.concat(parts, sep))
    end

    -- Per-frame: update FPS EMA + re-render the watermark. Cheap (a handful
    -- of table reads + a SetWatermark call which itself just sets a Text
    -- property when nothing changed-wise).
    track(RunService.Heartbeat:Connect(function(dt)
        frameDelta = dt
        local instantFps = 1 / math.max(dt, 1/240)
        emaFps = emaFps * 0.9 + instantFps * 0.1
        if not Library.Unloaded then
            pcall(renderWatermark)
        end
    end))

    -- Public API to set the watermark name without going through the UI.
    function Library:SetWatermarkName(name)
        Library._WatermarkName = name
        Library._WatermarkConfig.Name = name
    end

    function Library:GetWatermarkConfig()
        return Library._WatermarkConfig
    end

    -- Builds a "Watermark" groupbox on the given tab with the multi-select
    -- dropdown + custom name input + separator picker. Wires every control
    -- to the live watermark renderer above.
    function Library:CreateWatermarkSection(tab)
        local gb = tab:AddLeftGroupbox("Watermark")
        gb:AddToggle("Watermark_Enabled", { Text = "Show Watermark", Default = true,
            Callback = function(v)
                Library._WatermarkConfig.Enabled = v
                if not v then Library:SetWatermarkVisibility(false) end
            end,
        })
        gb:AddInput("Watermark_Name", {
            Text = "Custom Name", Default = "nachtara", Placeholder = "nachtara",
            Callback = function(v)
                Library._WatermarkName = (v and v ~= "") and v or "nachtara"
                Library._WatermarkConfig.Name = Library._WatermarkName
            end,
        })
        gb:AddDropdown("Watermark_Fields", {
            Text   = "Fields",
            Values = FIELDS_ORDER,
            Default = { "name", "playername", "fps" },
            Multi  = true,
            Callback = function(v)
                -- v is a {[fieldName] = true} table. Convert to ordered
                -- array following FIELDS_ORDER so the watermark layout
                -- reflects the canonical sequence regardless of click
                -- order in the dropdown.
                local picked = {}
                for _, name in FIELDS_ORDER do
                    if v[name] then picked[#picked + 1] = name end
                end
                Library._WatermarkConfig.Fields = picked
            end,
        })
        gb:AddDropdown("Watermark_Separator", {
            Text = "Separator",
            Values = { " | ", " - ", " · ", " // ", "  " },
            Default = " | ",
            Callback = function(v)
                Library._WatermarkConfig.Separator = v or " | "
            end,
        })

        -- Apply initial selection so the watermark starts populated from
        -- the toggle defaults (rather than empty until the user clicks).
        Library._WatermarkConfig.Enabled   = true
        Library._WatermarkConfig.Fields    = { "name", "playername", "fps" }
        Library._WatermarkConfig.Separator = " | "
        Library._WatermarkName             = "nachtara"
    end
end

return Library
