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
    if props then for k, v in pairs(props) do pcall(function() inst[k] = v end) end end
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
    for _, s in ipairs(set) do
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
            for _, cb in ipairs(self._listeners) do pcall(cb, self.Value) end
        end
    end
    -- ColorPicker exposes a second setter for the SaveManager (RGB + alpha).
    -- Fire listeners after that path too so config-load handlers run.
    if widget.SetValueRGB then
        local origRGB = widget.SetValueRGB
        widget.SetValueRGB = function(self, c, t, supp)
            origRGB(self, c, t)
            if not supp then
                for _, cb in ipairs(self._listeners) do pcall(cb, self.Value) end
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
    for _, fn in ipairs(Library.DepRefreshers) do pcall(fn) end
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

        local toggle = { Value = opt.Default and true or false, Callback = opt.Callback }

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

        local slider = { Value = val, Callback = opt.Callback,
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

        local dd = { Value = multi and {} or opt.Default, Callback = opt.Callback,
                     Values = values, Multi = multi }
        local function fmtV()
            if multi then
                local sel = {}
                for k in pairs(dd.Value) do sel[#sel + 1] = tostring(k) end
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
                if type(v) == "table" then for _, k in pairs(v) do t[k] = true end end
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
        local function refreshRows() for v, r in pairs(rows) do applyRowVisual(v, r) end end

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
        for _, v in ipairs(values) do addRow(v) end
        refreshRows()

        -- SaveManager parity: replaces the dropdown's value list at runtime
        -- (config-list rebuilds after Create/Delete) and clears the current
        -- selection so the caller can drive a fresh pick via SetValue.
        function dd:SetValues(newValues)
            for _, item in pairs(rows) do pcall(function() item:Destroy() end) end
            for k in pairs(rows) do rows[k] = nil end
            values = newValues or {}
            self.Values = values
            for _, v in ipairs(values) do addRow(v) end
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

        local cp = { Value = default, Transparency = opt.Transparency or 0,
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

        local kp = { Value = defaultKey, Mode = defaultMode,
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
            for m, r in pairs(modeRows) do
                if m == kp.Mode then
                    r.TextColor3 = Theme.Accent
                    applyFont(r, "bold")
                else
                    r.TextColor3 = Theme.TextDim
                    applyFont(r, "reg")
                end
            end
        end
        for _, m in ipairs(modesList) do
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

        local input = { Value = opt.Default or "", Callback = opt.Callback }

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
                for _, d in ipairs(deps) do
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
                for _, t in ipairs(tabs) do
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

        local leftCol = mk("ScrollingFrame", { Parent = tabContent,
            Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.BorderHi,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ClipsDescendants = false })
        local rightCol = mk("ScrollingFrame", { Parent = tabContent,
            Size = UDim2.new(0.5, -6, 1, 0),
            Position = UDim2.new(0.5, 6, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.BorderHi,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ClipsDescendants = false })
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
        for _, t in ipairs(self._tabs) do
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
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
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
    for _, d in pairs(ScreenGui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            pcall(function() d.FontFace = f end)
        end
    end
    for _, cb in ipairs(Library.FontListeners) do pcall(cb, f) end
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
    for _, name in ipairs(list) do
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
    for _, child in ipairs(NotifyArea:GetChildren()) do
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
        for _, s in ipairs(set) do
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
        for _, s in ipairs(set) do
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
    for _, c in ipairs(lbl:GetChildren()) do
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
    for _, st in ipairs(outerStrokes) do
        TweenService:Create(st, TI_IN, { Transparency = 0 }):Play()
    end
    for _, st in ipairs(innerStrokes) do
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
        for _, st in ipairs(outerStrokes) do
            TweenService:Create(st, TI_OUT, { Transparency = 1 }):Play()
        end
        for _, st in ipairs(innerStrokes) do
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
-- SHOW LOADER — centered modal shown during script-init (font fetch, etc).
-- main.lua calls Library:ShowLoader({ Title=…, Text=…, … }) before the
-- main window appears.
-- ══════════════════════════════════════════════════════════════════════════
function Library:ShowLoader(config)
    config = config or {}
    local titleStr = config.Title or "loading"
    local textStr  = config.Text  or "Loading…"

    if Library._Loader then
        pcall(function() Library._Loader:Destroy() end)
    end

    local loader = mk("Frame", { Parent = ScreenGui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 90),
        BackgroundColor3 = Theme.WindowBg, BorderSizePixel = 0, ZIndex = 250 })
    applyLayeredStrokes(loader, "outer")
    -- Rainbow strip at top (same as the main window)
    mk("Frame", { Parent = loader,
        Size = UDim2.new(1, -12, 0, 1), Position = UDim2.fromOffset(6, 8),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5,
        BorderSizePixel = 0, ZIndex = 251 })
    local rb = mk("Frame", { Parent = loader,
        Size = UDim2.new(1, -12, 0, 2), Position = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 252 })
    local rbGrad = Instance.new("UIGradient"); rbGrad.Name = "\0"
    rbGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Theme.RainbowA),
        ColorSequenceKeypoint.new(0.5, Theme.RainbowB),
        ColorSequenceKeypoint.new(1, Theme.RainbowC),
    }
    rbGrad.Parent = rb

    mkText("TextLabel", { Parent = loader,
        Size = UDim2.fromOffset(300, 14), Position = UDim2.fromOffset(10, 20),
        BackgroundTransparency = 1, Text = titleStr, TextSize = 12,
        TextColor3 = Theme.TextActive,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 253,
    }, "bold")
    local body = mkText("TextLabel", { Parent = loader,
        Size = UDim2.fromOffset(300, 14), Position = UDim2.fromOffset(10, 38),
        BackgroundTransparency = 1, Text = textStr, TextSize = 11,
        TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 253,
    }, "reg")

    Library._Loader = loader

    return {
        SetText = function(_, s) body.Text = tostring(s or "") end,
        Close   = function() pcall(function() loader:Destroy() end)
                  Library._Loader = nil end,
    }
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
    for n in pairs(self.Fonts or {}) do names[#names + 1] = n end
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
        local n = 0; for _ in pairs(self.Fonts or {}) do n = n + 1 end
        n = n + 1   -- "Default"
        if n ~= lastCount and Library.Options.LibraryFont then
            lastCount = n
            local updated = { "Default" }
            for k in pairs(self.Fonts or {}) do updated[#updated + 1] = k end
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
            for i, l in ipairs(labels) do
                if l == lbl then table.remove(labels, i); break end
            end
            pcall(function() lbl:Destroy() end)
            refreshVisibility()
        end
        return handle
    end

    function box:Clear()
        for _, lbl in ipairs(labels) do pcall(function() lbl:Destroy() end) end
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

return Library
