--[[ hl2sb_derma_debug -- runtime probes for the Derma layout/paint chain.

    Set `hl2sb_derma_debug 1` and reopen the window under test.  Controls
    print a ONE-SHOT dump the first time they lay out or paint (so a steady
    state is captured once, not per frame), and every cursor change away
    from "arrow" is reported together with the panel that asked for it.  A
    slow timer also reports the hovered panel, which is how a stray
    hover-reactive panel is found.

    Output goes to the console (and ds_debug.log), prefixed "[HL2SB derma]".
    The wrappers are installed on the registered class tables after load, so
    the control files themselves stay untouched and panels created while the
    convar is off cost nothing.
--]]

if ( SERVER ) then return end

CreateClientConVar( "hl2sb_derma_debug", "0", true, false )

local lastHovered = nil

local function DbgEnabled()
	local cv = GetConVar( "hl2sb_derma_debug" )
	return cv and cv:GetInt() == 1
end

local function Bounds( pnl )
	if ( not IsValid( pnl ) ) then return "invalid" end

	local x, y = pnl:GetPos()

	return string.format( "(%d,%d %dx%d)%s", x, y, pnl:GetWide(), pnl:GetTall(),
		pnl:IsVisible() and "" or " HIDDEN" )
end

local function Dump( strTag, pnl, ... )
	Msg( "[HL2SB derma] " .. strTag .. ": " .. Bounds( pnl ) )

	for i = 1, select( "#", ... ) do
		Msg( " " .. tostring( select( i, ... ) ) )
	end

	Msg( "\n" )
end

--- Wrap one method of one registered control: run it, then let the caller's
--- dump decide what (and how often) to print from the post-call state.
local function WrapAfter( strClass, strMethod, fnDump )
	local cls = vgui.GetControlTable( strClass )

	if ( not cls or not isfunction( cls[ strMethod ] ) ) then
		Msg( "[HL2SB derma] probe skipped: " .. strClass .. ":" .. strMethod .. " missing\n" )
		return
	end

	local old = cls[ strMethod ]

	cls[ strMethod ] = function( self, ... )
		local r = { old( self, ... ) }

		if ( DbgEnabled() ) then
			fnDump( self )
		end

		return unpack( r )
	end
end

local function Once( pnl, strKey )
	if ( pnl.m_bDermaDbgDone == nil ) then pnl.m_bDermaDbgDone = {} end

	if ( pnl.m_bDermaDbgDone[ strKey ] ) then return false end

	pnl.m_bDermaDbgDone[ strKey ] = true
	return true
end

-- symptom: which paint path draws a row's text, and with which alignment
WrapAfter( "DButton", "Paint", function( pnl )
	if ( not Once( pnl, "paint" ) ) then return end

	Dump( "DButton paint", pnl,
		"align=" .. tostring( pnl.m_iContentAlignment ),
		"font=" .. tostring( pnl.m_strFont ),
		"text=" .. string.sub( tostring( pnl.m_strText or "" ), 1, 24 ) )
end )

-- symptom: the DNumSlider row's child layout (label / scratch / slider / entry).
-- Dumps the first three layouts per panel, not just one: a layout that runs once
-- with creation bounds and never again is exactly what we are hunting.
WrapAfter( "DNumSlider", "PerformLayout", function( pnl )
	if ( not pnl.m_bDermaDbgCount ) then pnl.m_bDermaDbgCount = 0 end
	pnl.m_bDermaDbgCount = pnl.m_bDermaDbgCount + 1

	if ( pnl.m_bDermaDbgCount > 3 ) then return end

	Dump( "DNumSlider pass " .. pnl.m_bDermaDbgCount, pnl,
		"Label" .. Bounds( pnl.Label ),
		"Scratch" .. Bounds( pnl.Scratch ),
		"Slider" .. Bounds( pnl.Slider ),
		"TextArea" .. Bounds( pnl.TextArea ),
		"label='" .. tostring( pnl.Label and pnl.Label.GetText and pnl.Label:GetText() or "" ) .. "'" )
end )

-- symptom: what the DPanelList gave its canvas, bar and rows (first pass only)
WrapAfter( "DPanelList", "PerformLayout", function( pnl )
	if ( not Once( pnl, "layout" ) ) then return end

	local canvas = pnl.GetCanvas and pnl:GetCanvas()
	local bar = pnl.GetVBar and pnl:GetVBar()
	local items = pnl.GetItems and pnl:GetItems() or {}

	Dump( "DPanelList", pnl,
		"canvas" .. Bounds( canvas ),
		"bar" .. Bounds( bar ) .. " enabled=" .. tostring( bar and bar.Enabled ),
		"items=" .. tostring( #items ) )

	for i = 1, math.min( 8, #items ) do
		Dump( "DPanelList item " .. i, items[ i ] )
	end
end )

-- symptom: where the window divider and its drag bar actually sit
WrapAfter( "DHorizontalDivider", "PerformLayout", function( pnl )
	if ( not Once( pnl, "layout" ) ) then return end

	Dump( "DHorizontalDivider", pnl,
		"bar" .. Bounds( pnl.m_pBar ),
		"left" .. Bounds( pnl.m_pLeft ),
		"right" .. Bounds( pnl.m_pRight ),
		"leftWidth=" .. tostring( pnl.m_iLeftWidth ) )
end )

--- Skin paint probes: prove which of a row's painters actually run.  One-shot
--- per panel per hook, so a laid-out-and-painted row prints each line once.
--- derma.SkinHook dispatches through the registered skin table by reference,
--- so wrapping it here intercepts every control's paint.
local function WrapSkin( strHook )
	local skin = derma.GetDefaultSkin and derma.GetDefaultSkin()

	if ( not skin or not isfunction( skin[ strHook ] ) ) then
		Msg( "[HL2SB derma] probe skipped: skin " .. strHook .. " missing\n" )
		return
	end

	local old = skin[ strHook ]

	skin[ strHook ] = function( self, pnl, ... )
		if ( DbgEnabled() and IsValid( pnl ) ) then
			local key = strHook .. "_" .. tostring( pnl )

			if ( not pnl.m_bDermaDbg ) then
				pnl.m_bDermaDbg = {}
			end

			if ( not pnl.m_bDermaDbg[ key ] ) then
				pnl.m_bDermaDbg[ key ] = true
				Dump( "skin " .. strHook, pnl, "class=" .. tostring( pnl.ClassName ) )
			end
		end

		return old( self, pnl, ... )
	end
end

WrapSkin( "PaintSlider" )
WrapSkin( "PaintSliderKnob" )
WrapSkin( "PaintNumSlider" )
WrapSkin( "PaintButton" )
WrapSkin( "PaintTextEntry" )

--- Every cursor change away from "arrow" is reported with the panel that
--- asked for it: the sizewe holders are DNumberScratch (Init + drag release)
--- and the divider bar paths, so a sizewe somewhere else is a wrong panel.
local PanelMeta = FindMetaTable( "Panel" )

if ( PanelMeta and PanelMeta.SetCursor ) then
	local EngineSetCursor = PanelMeta.SetCursor

	PanelMeta.SetCursor = function( self, strCursor )
		if ( DbgEnabled() and strCursor ~= "arrow" and not self.m_bDermaDbgCursor ) then
			self.m_bDermaDbgCursor = true
			Dump( "SetCursor('" .. tostring( strCursor ) .. "')", self,
				"class=" .. tostring( self.ClassName ) )
		end

		return EngineSetCursor( self, strCursor )
	end
end

--- Slow hovered-panel tracer: names the panel actually under the cursor, so
--- a hover-reactive stray (white bar + foreign cursor) identifies itself.
timer.Create( "hl2sb_derma_dbg_hover", 0.5, 0, function()
	if ( not DbgEnabled() ) then return end
	if ( surface.IsCursorVisible and not surface.IsCursorVisible() ) then return end

	local hovered = vgui.GetHoveredPanel and vgui.GetHoveredPanel()

	if ( not IsValid( hovered ) ) then return end
	if ( hovered == lastHovered ) then return end

	lastHovered = hovered

	Dump( "hover", hovered, "class=" .. tostring( hovered.ClassName ) )
end )
