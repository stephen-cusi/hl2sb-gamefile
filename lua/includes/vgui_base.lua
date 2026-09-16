--[[----------------------------------------------------------------------------
	lua/includes/vgui_base.lua  --  HL2SB derma control list.

	NOT Garry's Mod's file: GMod's ships 54 copied control includes; this one
	includes this fork's own controls, written for the hl2sb derma framework
	(lua/derma/hl2sb_derma.lua).  Order matters only for the inheritance chain:
	a control's base must be registered before it is created, so DPanel leads.

	New controls land here when they are written.  Files that do not exist are
	skipped by the loader with a warning, never fatal.
-----------------------------------------------------------------------------]]

include( "vgui/DPanel.lua" )
include( "vgui/DLabel.lua" )
include( "vgui/DButton.lua" )
include( "vgui/DImageButton.lua" )
include( "vgui/DTextEntry.lua" )
include( "vgui/DCheckBox.lua" )
include( "vgui/DCheckBoxLabel.lua" )
include( "vgui/DScrollBar.lua" )
include( "vgui/DScrollPanel.lua" )
include( "vgui/DScroller.lua" )
include( "vgui/DSlider.lua" )
include( "vgui/DNumSlider.lua" )
include( "vgui/DFrame.lua" )
include( "vgui/DListView.lua" )
include( "vgui/DListView_Line.lua" )
include( "vgui/DMenu.lua" )
include( "vgui/DMenuBar.lua" )
include( "vgui/DTooltip.lua" )
include( "vgui/DCollapsibleCategory.lua" )
include( "vgui/DCategoryList.lua" )
include( "vgui/DPropertySheet.lua" )
-- HL2SB: the containers the GMod-style spawnmenu is built on (wiki contracts:
-- DImage, DIconLayout, DListLayout, DSizeToContents).  They must come after the
-- controls they inherit from: DPanel.
include( "vgui/DImage.lua" )
include( "vgui/DIconLayout.lua" )
include( "vgui/DListLayout.lua" )
include( "vgui/DSizeToContents.lua" )
include( "vgui/DNotify.lua" )
