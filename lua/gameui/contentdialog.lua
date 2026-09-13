--========= Copyleft 2010-2013, Team Sandbox, Some rights reserved. ============--
--
-- Purpose: Content dialog -- mount extra Source games.
--
--===========================================================================--

include( "../includes/extensions/table.lua" )
include( "../includes/extensions/vgui.lua" )

local vgui = vgui

local CContentDialog = {}

function CContentDialog:Init( parent, panelName )
	self:SetDeleteSelfOnClose( true )
	self:SetBounds( 0, 0, 460, 380 )
	self:SetSizeable( false )

	self:SetTitle( "#GameUI_Content", true )

	-- The page itself builds its checkboxes from the detected game list.
	self:AddPage( vgui.CContentSubGames( self, "" ), "#GameUI_Games" )

	self:SetApplyButtonVisible( true )
end

function CContentDialog:Run()
	self:SetTitle( "#GameUI_Content", true )
	self:Activate()
end

vgui.register( CContentDialog, "CContentDialog", "PropertyDialog" )
