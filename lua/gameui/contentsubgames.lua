--[[
    HL2SB: Content dialog -- shows detected Source games as checkboxes.

    List comes from _G.HL2SB_DetectedGames (autorun).
    Selections saved to gamecontent.txt as plain text:
        220
        320
        (one AppId per line)
]]

include( "../includes/extensions/table.lua" )
include( "../includes/extensions/vgui.lua" )

local vgui = vgui

-- Read selected AppIds from gamecontent.txt as plain lines.
local function ReadSelectedAppIds()
    local ids = {}
    local path = engine.GetGameDirectory() .. "/gamecontent.txt"
    local f = io.open( path, "r" )
    if ( not f ) then return ids end
    for line in f:lines() do
        local id = tonumber( line:match( "%s*(%d+)%s*" ) )
        if ( id ) then ids[ id ] = true end
    end
    f:close()
    return ids
end

-- Write selected AppIds as plain lines.
local function WriteSelectedAppIds( ids )
    local path = engine.GetGameDirectory() .. "/gamecontent.txt"
    local f = io.open( path, "w" )
    if ( not f ) then return end
    for _, entry in ipairs( m_CheckBoxes ) do
        if ( entry.panel:IsSelected() and entry.appId > 0 ) then
            f:write( tostring( entry.appId ), "\n" )
        end
    end
    f:close()
end

local CContentSubGames = {}
local m_CheckBoxes = {}

function CContentSubGames:Init( parent )
    m_CheckBoxes = {}

    local games = _G.HL2SB_DetectedGames or {}
    local y = 12

    for i, game in ipairs( games ) do
        local cb = vgui.CheckButton( self, "game_" .. i, game.name )
        cb:SetPos( 20, y )
        cb:SetSize( 380, 24 )
        cb.OnCheckButtonChecked = function( btn )
            local dialog = self:GetParent():GetParent():GetParent()
            if ( dialog and dialog.EnableApplyButton ) then
                dialog:EnableApplyButton( true )
            end
        end
        m_CheckBoxes[ i ] = { panel = cb, folder = game.folder, appId = game.appId }
        y = y + 26
    end

    if ( #games == 0 ) then
        local lbl = vgui.Create( "Label", self )
        lbl:SetPos( 20, y )
        lbl:SetSize( 380, 40 )
        lbl:SetText( "No other Source games found next to this install." )
        y = y + 44
    end

    local note = vgui.Create( "Label", self )
    note:SetPos( 20, y + 20 )
    note:SetSize( 380, 32 )
    note:SetWrap( true )
    note:SetFont( "DefaultSmall" )
    note:SetText( "#GameUI_GamesRestartNote" )
end

function CContentSubGames:OnResetData()
    local ids = ReadSelectedAppIds()
    for _, entry in ipairs( m_CheckBoxes ) do
        if ( entry.appId > 0 and ids[ entry.appId ] ) then
            entry.panel:SetSelected( true )
        end
    end
end

function CContentSubGames:OnApplyChanges()
    WriteSelectedAppIds()
    print( "[HL2SB] gamecontent.txt saved; restart to apply mounts\n" )
end

function CContentSubGames:OnOK( applyOnly )
    self:OnApplyChanges()
end

vgui.register( CContentSubGames, "CContentSubGames", "PropertyPage" )
