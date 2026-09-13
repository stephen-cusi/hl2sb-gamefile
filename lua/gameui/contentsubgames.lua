--[[
    HL2SB: Content dialog -- shows detected Source games as checkboxes.

    The list comes from _G.HL2SB_DetectedGames, populated by
    lua/autorun/detect_source_games.lua (which has the file library).
    This file runs in the gameui Lua state where 'file' is nil, so it
    must not touch the filesystem itself.
]]

include( "../includes/extensions/table.lua" )
include( "../includes/extensions/vgui.lua" )
include( "../includes/extensions/keyvalues.lua" )

local vgui = vgui

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
    local kv = KeyValues( "GameContent" )
    if ( not kv:LoadFromFile( engine.GetGameDirectory() .. "/gamecontent.txt", "MOD" ) ) then
        kv:deleteThis()
        return
    end

    local fs = kv:GetData( "FileSystem" )
    if ( fs ) then
        local appIds = {}
        local appId = fs:GetFirstSubKey()
        while ( appId ) do
            local id = tonumber( appId:GetString() )
            if ( id ) then appIds[ id ] = true end
            appId = appId:GetNextKey()
        end
        for _, entry in ipairs( m_CheckBoxes ) do
            if ( entry.appId > 0 and appIds[ entry.appId ] ) then
                entry.panel:SetSelected( true )
            end
        end
    end
    kv:deleteThis()
end

function CContentSubGames:OnApplyChanges()
    local kv = KeyValues( "GameContent" )
    local fs  = kv:CreateNewKey()
    fs:SetName( "FileSystem" )

    for _, entry in ipairs( m_CheckBoxes ) do
        if ( entry.panel:IsSelected() and entry.appId > 0 ) then
            local appKv = KeyValues( "AppId" )
            appKv:SetStringValue( tostring( entry.appId ) )
            fs:AddSubKey( appKv )
        end
    end

    kv:SaveToFile( "gamecontent.txt", "MOD" )
    kv:deleteThis()
    print( "[HL2SB] gamecontent.txt saved; restart to apply mounts\n" )
end

function CContentSubGames:OnOK( applyOnly )
    self:OnApplyChanges()
end

vgui.register( CContentSubGames, "CContentSubGames", "PropertyPage" )
