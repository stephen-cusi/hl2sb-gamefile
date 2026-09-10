--[[----------------------------------------------------------------------------
    gmod_vgui.lua

    Garry's Mod's vgui/derma surface, on top of HL2SB's scripted controls.

    HL2SB's vgui.register already does almost all of the work: it takes a control
    table, a name and a base class, merges the table into every new panel's Lua
    reference table and installs a factory at vgui[ name ].  The only real
    difference from Garry's Mod is the argument order --

        HL2SB   vgui.register( tPanel, strName, strBaseClass )
        GMod    vgui.Register( strName, tPanel, strBaseClass )

    -- so this file swaps it and adds the Create/GetControlTable helpers GMod code
    calls.  Three things vgui.register does NOT give us, all handled below:

      * panel.BaseClass ends up nil for controls based on a C factory (Frame,
        Label, ...), because register sets it from its own helper table, which only
        holds classes registered through register.  So a Derma control must not call
        self.BaseClass.<method>; calling self:<method> falls through __index to the C
        method anyway.
      * It keeps its helper tables in a local, so GetControlTable needs a registry
        of our own.
      * vgui.Label / vgui.Button take a third "text" argument through
        luaL_checkstring, which errors when omitted.  Create therefore always passes
        one; the other controls ignore it.

    This is deliberately a thin, hand-written first pass: it exists so a Derma
    window can be opened and seen.  GMod's own lua/vgui/*.lua and lua/derma/*.lua
    replace it once they are copied in.

    Loaded every level from lua/includes/modules/.
-----------------------------------------------------------------------------]]

--[[
    Realms.

    _CLIENT is the in-game client state; _GAMEUI is the main menu state, which HL2SB
    creates in luasrc_init_gameui (CHLClient::Init, so it exists before any map).
    GMod runs the same UI framework in both -- its error viewer is part of the main
    menu -- so this file has to as well.

    The two differ in exactly one place: where the root panel lives.
    VGui_GetClientLuaRootPanel is the in-game one, VGui_GetGameUIPanel the menu's.
]]
if ( not _CLIENT and not _GAMEUI ) then return end

local IS_MENU = ( not _CLIENT ) and _GAMEUI

--- GMod's root panel accessor, resolved per realm.
local function rootPanel()
    if ( IS_MENU and VGui_GetGameUIPanel ) then
        return VGui_GetGameUIPanel()
    end
    if ( VGui_GetClientLuaRootPanel ) then
        return VGui_GetClientLuaRootPanel()
    end
    return nil
end

--[[---------------------------------------------------------
    vgui additions
-----------------------------------------------------------]]

local rawRegister = vgui.register

-- Our own class registry: vgui.register keeps its helper tables in a local.
local controlTables = {}
local controlBases  = {}

--- GMod spelling.  HL2SB's register takes the control table first.
---
--- It is deliberately NOT called: its generated factory is the thing that failed,
--- and vgui.Create below performs the same bookkeeping itself.  All this has to do
--- is remember the control table and its base.
function vgui.Register( name, control, base )
    control = control or {}
    base = base or "Panel"

    if ( not vgui[ base ] ) then
        error( "vgui.Register: base class '" .. tostring( base ) .. "' does not exist", 2 )
    end

    controlTables[ name ] = control
    controlBases[ name ] = base

    return control
end

--- GMod spelling: vgui.Create( class, parent, name ).
---
---[[
--- This does the three steps vgui.register performs, instead of calling through the
--- factory it installs.
---
--- vgui.register's generated factory is
---
---     local panel = vgui[ helper.__base ]( ... )
---     table.merge( panel:GetRefTable(), helper )
---
--- and both call sites that used it died on the second line with
--- "attempt to call a nil value (method 'GetRefTable')" -- while a direct
--- vgui.Panel(nil, "diag") / vgui.Frame(nil, "diag2") in the console returns a
--- panel whose GetRefTable is a real function.  So the factories and metatables are
--- fine and something about the wrapper's argument passing is not; doing the steps
--- here keeps the panel we created in our own hands and never goes through it.
---
--- The trailing argument is per base and is not optional for Label:
---
---     Label / Button   text    (string)
---     Panel / Frame    nothing / bShowCloseButton (bool)
---
--- and the name is required by Label's factory (luaL_checkstring( L, 2 )).
---]]
function vgui.Create( name, parent, panelName, text )
    local base = controlBases[ name ]
    if ( not base ) then
        error( "vgui.Create: no control registered as '" .. tostring( name ) .. "'", 2 )
    end

    local factory = vgui[ base ]
    if ( not factory ) then
        error( "vgui.Create: base class '" .. tostring( base ) .. "' has no factory", 2 )
    end

    local trailing
    if ( base == "Label" or base == "Button" ) then
        -- Button has no SetText in this engine -- the text can only be given at
        -- construction -- so it has to be threaded through here.
        trailing = text or ""
    elseif ( base == "Frame" or base == "EditablePanel" ) then
        trailing = true
    end

    local panel = factory( parent, panelName or name, trailing )
    if ( not panel ) then
        error( "vgui.Create: '" .. base .. "' factory returned nothing", 2 )
    end

    local control = controlTables[ name ]
    if ( control ) then
        -- Name the class in the failure.  "attempt to call a nil value (method
        -- 'GetRefTable')" pointed at this line but not at *which* factory produced
        -- the panel, and the factories do not all answer the same way: a console
        -- vgui.Panel( nil, "diag" ) hands back a panel whose GetRefTable is a real
        -- function, while something on this path does not.
        if ( panel.GetRefTable == nil ) then
            error( string.format(
                "vgui.Create( %s ): the %s factory returned a %s whose metatable has no GetRefTable (metatable = %s)",
                tostring( name ), tostring( base ), type( panel ),
                tostring( getmetatable( panel ) ) ), 2 )
        end

        local refTable = panel:GetRefTable()
        if ( refTable ) then
            table.merge( refTable, control )
        end
    end

    if ( panel.Init ) then
        -- The text goes through Init because a control's own SetText may not exist
        -- yet (and C Button has none at all in this engine).
        panel:Init( text )
    end

    return panel
end

function vgui.GetControlTable( name )
    return controlTables[ name ]
end

--- GMod's root panel accessors.
function vgui.GetWorldPanel()
    return rootPanel()
end

function vgui.GetHoveredPanel()
    if ( input and input.GetMouseOver ) then return input.GetMouseOver() end
    return nil
end

--[[---------------------------------------------------------
    derma
-----------------------------------------------------------]]

derma = derma or {}

--- GMod calls this from every control's Paint/Think to let the skin draw.  HL2SB
--- has no skins, so it is a no-op -- but it has to exist, because GMod's control
--- tables assign it as a function value at load time.
function derma.SkinHook( hook, type, panel, ... )
    return false
end

function derma.DefineControl( name, description, control, base )
    return vgui.Register( name, control, base )
end

function derma.GetControlTable( name )
    return vgui.GetControlTable( name )
end

function derma.GetControlList()
    return controlTables
end

--[[---------------------------------------------------------
    Minimal Derma controls, so GMod scripts that name them work.
-----------------------------------------------------------]]

-- DPanel: just a Panel.
vgui.Register( "DPanel", {}, "Panel" )

--[[
    DFrame is built on "Panel", not on "Frame".

    vgui.Frame's metatable in this engine does not carry the Panel methods:
    creating one and calling :SetPos() or :GetRefTable() fails with
    "attempt to call a nil value", which breaks vgui.register's own
    `table.merge( panel:GetRefTable(), helper )` step before Init is ever reached.

    The player model menu -- the one window in this mod that already works -- takes
    the same route: every control it registers is based on "Panel" and draws its own
    chrome.  So DFrame does too: a background and a title, drawn in Paint, with a
    title Label and a close Button as children.
]]
local DFrame = {}

function DFrame:Init()
    self:SetSize( 400, 300 )
    self:SetPos( 120, 120 )
    self:SetVisible( true )
    self:SetMouseInputEnabled( true )
    self:SetKeyBoardInputEnabled( true )
    self:MakePopup()

    local title = vgui.Create( "DLabel", self, "Title" )
    title:SetPos( 8, 6 )
    title:SetSize( self:GetWide() - 44, 20 )
    title:SetText( self.m_strTitle or "DFrame" )
    self.m_pTitleLabel = title

    local close = vgui.Create( "DButton", self, "Close", "X" )
    -- Sized to the title bar (26 tall) and inset the same as the padding, so the X
    -- sits inside the bar instead of half outside it.
    close:SetSize( 20, 20 )
    close:SetPos( self:GetWide() - 24, 3 )
    close.DoClick = function() self:Close() end
    self.m_pCloseButton = close
end

--- Dragging.
---
--- Not through DFrame:Think: LPanel::OnThink calls the Lua method named "OnThink",
--- not "Think", and vgui only delivers think at all to panels that registered a tick
--- signal.  A module-level "Think" hook avoids both -- timer.lua already relies on
--- that hook firing, so it is known to work -- and moving the frame from there also
--- keeps working once the cursor leaves the panel, which OnCursorMoved would not.
local draggingFrame = nil

hook.add( "Think", "hl2sb_ui_drag", function()
    if ( not draggingFrame ) then return end
    if ( not draggingFrame.GetPos or not draggingFrame.SetPos ) then
        draggingFrame = nil
        return
    end

    local x, y = input.GetCursorPosition()
    if ( not x or not y ) then return end

    draggingFrame:SetPos( draggingFrame.m_nPanelStartX + ( x - draggingFrame.m_nDragStartX ),
                          draggingFrame.m_nPanelStartY + ( y - draggingFrame.m_nDragStartY ) )
end )

function DFrame:OnMousePressed()
    local x, y = input.GetCursorPosition()
    local px, py = self:GetPos()

    self.m_nDragStartX = x or 0
    self.m_nDragStartY = y or 0
    self.m_nPanelStartX = px or 0
    self.m_nPanelStartY = py or 0

    draggingFrame = self
end

function DFrame:OnMouseReleased()
    draggingFrame = nil
end

function DFrame:SetTitle( text )
    self.m_strTitle = text
    if ( self.m_pTitleLabel ) then self.m_pTitleLabel:SetText( text ) end
end

function DFrame:GetTitle()
    return self.m_strTitle or ""
end

--- GMod's Frame has Close(); HL2SB's Panel metatable does not, so provide it.
--- Hiding plus MarkForDeletion is what the Panel API actually offers.
function DFrame:Close()
    self:SetVisible( false )
    if ( self.MarkForDeletion ) then self:MarkForDeletion() end
end

--- GMod's controls call this to let the skin draw; without a skin we draw the
--- frame ourselves so the window is actually visible.
---
--- The width and height do NOT arrive as arguments: HL2SB invokes the Lua Paint
--- with no parameters, so a Paint( w, h ) signature gets nils and every
--- surface.Draw* call fails with
---   bad argument #4 to 'DrawFilledRect' (number expected, got nil)
--- once per frame.  They are taken from the panel instead.
function DFrame:Paint( w, h )
    w = w or self:GetWide()
    h = h or self:GetTall()

    surface.DrawSetColor( 60, 60, 60, 240 )
    surface.DrawFilledRect( 0, 0, w, h )

    surface.DrawSetColor( 30, 120, 200, 255 )
    surface.DrawFilledRect( 0, 0, w, 26 )

    surface.DrawSetColor( 20, 20, 20, 255 )
    surface.DrawOutlinedRect( 0, 0, w, h )
end

vgui.Register( "DFrame", DFrame, "Panel" )

--- Apply the UI font after the panel joins the hierarchy.
---
--- Setting it straight from Init does not stick: vgui runs ApplySchemeSettings when
--- a panel is attached to a visible parent, and HL2SB's LLabel::ApplySchemeSettings
--- calls the Lua hook *first* and BaseClass::ApplySchemeSettings *after*, so the
--- scheme's default font lands on top of ours.  Deferring by one frame puts the call
--- after that.
local pendingFonts = 0
local function applyFontDeferred( panel )
    if ( not panel.SetFont ) then return end

    local font = uiFont()
    pendingFonts = pendingFonts + 1

    hook.add( "Think", "hl2sb_ui_font_" .. tostring( pendingFonts ), function()
        hook.remove( "Think", "hl2sb_ui_font_" .. tostring( pendingFonts ) )
        if ( panel.SetFont ) then
            panel:SetFont( font )
        end
    end )
end

-- DLabel / DTextEntry: the C controls, plus a sane default font.
--
-- Without SetFont they pick up the scheme's default, which is far too large for a
-- window this size -- the text overflows its labels and the title bar, and CJK
-- glyphs in particular get clipped.  Fonts here are handles, not names:
-- surface.CreateFont() allocates one and surface.SetFontGlyphSet fills it in, the
-- pattern the player model menu uses.  0x010 is FONTFLAG_ANTIALIAS.
local UI_FONT
local function uiFont()
    if ( not UI_FONT ) then
        UI_FONT = surface.CreateFont()
        surface.SetFontGlyphSet( UI_FONT, "Default", 14, 0, 0, 0, 0x010 )
    end
    return UI_FONT
end

--[[
    DLabel draws its own text, and is Panel-based because of it.

    Setting a font on the C Label does not hold: vgui re-runs ApplySchemeSettings
    whenever a panel joins a visible parent, and HL2SB's LLabel::ApplySchemeSettings
    invokes the Lua hook first and BaseClass::ApplySchemeSettings after, so the
    scheme's default lands on top of whatever we set -- a deferred set one frame later
    did not help either.  The result was 14px text rendering at roughly twice that,
    with CJK glyphs clipped.

    The player model menu never has this problem because it does not use Label's text
    at all: it draws with surface.DrawSetTextFont / DrawSetTextPos / DrawPrintText.
    This does the same, with the identical font setup it uses (FONT_SIZE 14, "Default",
    FONTFLAG_ANTIALIAS).
]]
local DLabel = {}

function DLabel:Init( text )
    self.m_strText = text or ""
    self.m_clrText = { 235, 235, 235, 255 }
    self:SetMouseInputEnabled( false )
end

function DLabel:SetText( text )
    self.m_strText = text or ""
end

function DLabel:GetText()
    return self.m_strText or ""
end

function DLabel:SetTextStyleColor( clr )
    self.m_clrText = clr
end

function DLabel:Paint( w, h )
    if ( not self.m_strText or self.m_strText == "" ) then return end

    local clr = self.m_clrText or { 235, 235, 235, 255 }

    surface.DrawSetTextFont( uiFont() )
    surface.DrawSetTextColor( clr[1] or clr.r or 235, clr[2] or clr.g or 235, clr[3] or clr.b or 235, clr[4] or clr.a or 255 )
    surface.DrawSetTextPos( 0, 0 )
    surface.DrawPrintText( self.m_strText )
end

vgui.Register( "DLabel", DLabel, "Panel" )

local DTextEntry = {}

function DTextEntry:Init()
    if ( self.SetFont ) then self:SetFont( uiFont() ) end
    if ( self.SetKeyBoardInputEnabled ) then self:SetKeyBoardInputEnabled( true ) end
    if ( self.SetMouseInputEnabled ) then self:SetMouseInputEnabled( true ) end
    applyFontDeferred( self )
end

--- LTextEntry runs the base scheme settings first and this hook after (see the port
--- in scripted_controls/lTextEntry.h), so setting the font here is what sticks.
function DTextEntry:ApplySchemeSettings()
    if ( self.SetFont ) then self:SetFont( uiFont() ) end
end

--- Clicking has to hand the entry the keyboard focus; a vgui control only receives
--- typed characters once it is the focused panel, and nothing does that automatically
--- for a panel created from Lua.
function DTextEntry:OnMousePressed()
    if ( self.RequestFocus ) then self:RequestFocus() end
end

vgui.Register( "DTextEntry", DTextEntry, "TextEntry" )

--[[
    DButton is a Panel-based control, not vgui.Button.

    HL2SB's Button_DoClick calls the *C++* Button::DoClick() -- it never looks for a
    Lua `DoClick` field -- so `button.DoClick = function() ... end`, which is how all
    GMod code works, would never fire on a C Button.  A click that does nothing is
    exactly what that looks like.

    The player model menu solved this the same way: its buttons are Panel-based and
    handle their own mouse input, because LPanel forwards OnMousePressed and
    OnMouseReleased to Lua.  So this does too, and the text is a child DLabel since
    the Lua-visible surface API here has no simple text draw.
]]
local DButton = {}

function DButton:Init( text )
    self.m_strText = text or ""
    self:SetMouseInputEnabled( true )
end

function DButton:SetText( text )
    self.m_strText = text or ""
end

function DButton:GetText()
    return self.m_strText or ""
end

function DButton:OnMousePressed()
    self.m_bArmed = true
end

function DButton:OnMouseReleased()
    if ( not self.m_bArmed ) then return end
    self.m_bArmed = false

    if ( self.DoClick ) then
        self.DoClick( self )
    end
end

--- Draws its own text.
---
--- A child DLabel was sized from self:GetWide() during Init, but the caller has not
--- called SetSize yet at that point -- vgui.Create runs Init before it returns -- so the
--- label was laid out against a 0x0 parent and its text came out clipped or missing.
--- Drawing here uses the size Paint actually receives, so the geometry is always right
--- and the close button's X lands where it should.
function DButton:Paint( w, h )
    w = w or self:GetWide()
    h = h or self:GetTall()

    if ( self.m_bArmed ) then
        surface.DrawSetColor( 40, 90, 160, 255 )
    else
        surface.DrawSetColor( 75, 75, 75, 255 )
    end
    surface.DrawFilledRect( 0, 0, w, h )

    surface.DrawSetColor( 130, 130, 130, 255 )
    surface.DrawOutlinedRect( 0, 0, w, h )

    local text = self.m_strText
    if ( not text or text == "" ) then return end

    surface.DrawSetTextFont( uiFont() )

    local tw, th = surface.GetTextSize( uiFont(), text )
    surface.DrawSetTextColor( 235, 235, 235, 255 )
    surface.DrawSetTextPos( math.floor( ( w - ( tw or 0 ) ) / 2 ),
                            math.floor( ( h - ( th or 0 ) ) / 2 ) )
    surface.DrawPrintText( text )
end

vgui.Register( "DButton", DButton, "Panel" )

--[[---------------------------------------------------------
    A command that shows a window, so this can be seen working.
-----------------------------------------------------------]]

local function UITest()
    local frame = vgui.Create( "DFrame" )
    frame:SetSize( 460, 260 )
    frame:SetPos( ScrW() / 2 - 230, ScrH() / 2 - 130 )
    frame:SetTitle( "HL2SB - GMod vgui test" )

    local label = vgui.Create( "DLabel", frame )
    label:SetPos( 20, 50 )
    label:SetSize( 420, 24 )
    label:SetText( "vgui.Create( DFrame ) -> type = " .. type( frame ) )

    local entry = vgui.Create( "DTextEntry", frame )
    entry:SetPos( 20, 90 )
    entry:SetSize( 420, 28 )
    entry:SetText( "editable text" )

    local button = vgui.Create( "DButton", frame, "DoThing", "改文字" )
    button:SetPos( 20, 140 )
    button:SetSize( 180, 28 )
    button.DoClick = function()
        entry:SetText( "clicked at " .. tostring( math.floor( CurTime() ) ) )
    end

    local close = vgui.Create( "DButton", frame, "DoClose", "关闭" )
    close:SetPos( 320, 200 )
    close:SetSize( 120, 28 )
    close.DoClick = function() frame:Close() end

    print( "[HL2SB] DFrame created: " .. tostring( frame ) )
    return frame
end

concommand.Create( "hl2sb_uitest", function()
    UITest()
end, "Open a GMod-style Derma window" )

print( "[HL2SB] gmod_vgui.lua loaded - run 'hl2sb_uitest'" )
