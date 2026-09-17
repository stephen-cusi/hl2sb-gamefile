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
include( "vgui/DLabelEditable.lua" )	-- https://wiki.facepunch.com/gmod/DLabelEditable (needs DLabel)
include( "vgui/DLabelURL.lua" )		-- https://wiki.facepunch.com/gmod/DLabelURL (needs DLabel)
include( "vgui/DButton.lua" )
include( "vgui/DBinder.lua" )		-- https://wiki.facepunch.com/gmod/DBinder (needs DButton)
include( "vgui/DImageButton.lua" )
include( "vgui/DNumberScratch.lua" )	-- https://wiki.facepunch.com/gmod/DNumberScratch (needs DImageButton)
include( "vgui/DTextEntry.lua" )
include( "vgui/DCheckBox.lua" )
include( "vgui/DCheckBoxLabel.lua" )
-- ⚠️ DComboBox.lua existed on disk but was NEVER included here (found by
-- D:\project\luacheck\test_vgui_controls.lua, which flags any lua/vgui file the list
-- leaves behind): vgui.Create( "DComboBox" ) silently fell through to the engine
-- factory and answered nil, so every addon that builds one died on the next line.
include( "vgui/DComboBox.lua" )
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
-- DImage, DIconLayout, DSizeToContents).  They must come after the controls they
-- inherit from: DPanel.  ⚠️ DListLayout is NOT here: it derives from DDragBase now
-- (GMod's parent), so it is included after DDragBase below - this fork's
-- vgui.Register resolves the base AT REGISTRATION TIME, so a derived control listed
-- before its base silently fails to register (that is exactly what happened here and
-- how the in-game hl2sb_derma_list ended up missing DListLayout while the offline
-- scan still said "96/96" - see AGENTS.md 5.0.16).
include( "vgui/DImage.lua" )
include( "vgui/DIconLayout.lua" )
include( "vgui/DSizeToContents.lua" )
include( "vgui/DNotify.lua" )

-- ---------------------------------------------------------------------------
-- The control list the GMod wiki documents on VGUI_Element_List, ported one at a
-- time (each file cites its own wiki page).  Order still only matters for
-- inheritance: everything here derives from Panel or DPanel, both registered above.
-- ---------------------------------------------------------------------------
include( "vgui/DProgress.lua" )		-- https://wiki.facepunch.com/gmod/DProgress
include( "vgui/DShape.lua" )		-- https://wiki.facepunch.com/gmod/DShape
include( "vgui/DGrid.lua" )		-- https://wiki.facepunch.com/gmod/DGrid
include( "vgui/DPanelOverlay.lua" )	-- https://wiki.facepunch.com/gmod/DPanelOverlay
include( "vgui/DHorizontalDivider.lua" )	-- https://wiki.facepunch.com/gmod/DHorizontalDivider
include( "vgui/DVerticalDivider.lua" )		-- https://wiki.facepunch.com/gmod/DVerticalDivider

-- the colour family (wiki: VGUI_Element_List -> "Color Panels")
include( "vgui/DColorButton.lua" )	-- https://wiki.facepunch.com/gmod/DColorButton
include( "vgui/DAlphaBar.lua" )		-- https://wiki.facepunch.com/gmod/DAlphaBar
include( "vgui/DRGBPicker.lua" )	-- https://wiki.facepunch.com/gmod/DRGBPicker
include( "vgui/DColorPalette.lua" )	-- https://wiki.facepunch.com/gmod/DColorPalette  (needs DColorButton)
include( "vgui/DColorCube.lua" )	-- https://wiki.facepunch.com/gmod/DColorCube     (needs DSlider)
include( "vgui/DColorMixer.lua" )	-- https://wiki.facepunch.com/gmod/DColorMixer
include( "vgui/DColorCombo.lua" )	-- https://wiki.facepunch.com/gmod/DColorCombo

-- model previews (wiki: "Base Panels" -> DModelPanel / DAdjustableModelPanel)
include( "vgui/DModelPanel.lua" )	-- https://wiki.facepunch.com/gmod/DModelPanel
include( "vgui/DAdjustableModelPanel.lua" )	-- https://wiki.facepunch.com/gmod/DAdjustableModelPanel

-- containers / utility (wiki: "Utility Panels" + the deprecated DPanelList)
include( "vgui/DPanelList.lua" )	-- https://wiki.facepunch.com/gmod/DPanelList (needs DScrollPanel)
include( "vgui/DExpandButton.lua" )	-- https://wiki.facepunch.com/gmod/DExpandButton
include( "vgui/DDrawer.lua" )		-- https://wiki.facepunch.com/gmod/DDrawer

-- drag & drop rearrangement (wiki: "Drag & Drop" -> DDragBase, DTileLayout,
-- DHorizontalScroller).  DDragBase must come first: the other two derive from it.
include( "vgui/DDragBase.lua" )		-- https://wiki.facepunch.com/gmod/DDragBase
-- ⚠️ DListLayout must be registered AFTER DDragBase: this fork's vgui.Register
-- resolves the base when the control is registered (lua/derma/hl2sb_derma.lua:136),
-- so "base not registered yet" aborts the whole file.
include( "vgui/DListLayout.lua" )	-- https://wiki.facepunch.com/gmod/DListLayout (base: DDragBase)
include( "vgui/DTileLayout.lua" )	-- https://wiki.facepunch.com/gmod/DTileLayout
include( "vgui/DHorizontalScroller.lua" )	-- https://wiki.facepunch.com/gmod/DHorizontalScroller

-- small leaf controls (wiki: "Utility Panels" / "Misc").  Material must be here
-- before ImageCheckBox: the checkbox creates one Material panel per instance.
include( "vgui/Material.lua" )		-- https://wiki.facepunch.com/gmod/Material
include( "vgui/DSprite.lua" )		-- https://wiki.facepunch.com/gmod/DSprite
include( "vgui/DKillIcon.lua" )		-- https://wiki.facepunch.com/gmod/DKillIcon
include( "vgui/DBubbleContainer.lua" )	-- https://wiki.facepunch.com/gmod/DBubbleContainer
include( "vgui/ImageCheckBox.lua" )	-- https://wiki.facepunch.com/gmod/ImageCheckBox
include( "vgui/ContextBase.lua" )	-- https://wiki.facepunch.com/gmod/ContextBase

-- the scrollbar pair (wiki: "Scroll Panels" -> DVScrollBar, DScrollBarGrip) and
-- the select family (DPanelSelect -> DModelSelect/DModelSelectMulti).
-- DPanelSelect needs DPanelList (above); DVScrollBar creates a DScrollBarGrip.
include( "vgui/DScrollBarGrip.lua" )
-- the horizontal scrollbar is the twin of DVScrollBar and needs the same grip
include( "vgui/DHScrollBar.lua" )	-- https://wiki.facepunch.com/gmod/DHScrollBar
-- the divider drag handles (GMod keeps them as separate tiny controls)
include( "vgui/DHorizontalDividerBar.lua" )	-- https://wiki.facepunch.com/gmod/DHorizontalDividerBar
include( "vgui/DVerticalDividerBar.lua" )	-- https://wiki.facepunch.com/gmod/DVerticalDividerBar
-- category header button (DButton based; see the file's note about DCollapsibleCategory)
include( "vgui/DCategoryHeader.lua" )	-- https://wiki.facepunch.com/gmod/DCategoryHeader
-- the tab strip control (DPropertySheet:AddSheet creates one per tab, so this has
-- to be registered before the sheet is used)
include( "vgui/DTab.lua" )		-- https://wiki.facepunch.com/gmod/DTab
-- the list box (its row control has to be registered first) and the icon browser
include( "vgui/DListBox.lua" )		-- https://wiki.facepunch.com/gmod/DListBox (defines DListBox + DListBoxItem)
include( "vgui/DIconBrowser.lua" )	-- https://wiki.facepunch.com/gmod/DIconBrowser (needs DIconLayout)
include( "vgui/MatSelect.lua" )		-- https://wiki.facepunch.com/gmod/MatSelect (needs ContextBase + DPanelList)
-- the DListView pieces GMod keeps in lua/vgui/dlistview_column.lua / dlistview_line.lua
include( "vgui/DListView_Column.lua" )	-- registers DListViewHeaderLabel, DListView_DraggerBar, DListView_Column, DListView_ColumnPlain
-- ⚠️ only DListViewLine is registered here (GMod's file also registers the legacy
-- alias DListView_Line, which this fork's own DListView rows already own - see the
-- file header)
include( "vgui/DListViewLine.lua" )	-- registers DListViewLabel + DListViewLine
include( "vgui/DFileBrowser.lua" )	-- https://wiki.facepunch.com/gmod/DFileBrowser (tree + list, needs DTree/DListView/DIconBrowser)
include( "vgui/DVScrollBar.lua" )	-- https://wiki.facepunch.com/gmod/DVScrollBar
include( "vgui/DPanelSelect.lua" )	-- https://wiki.facepunch.com/gmod/DPanelSelect (needs DPanelList)
include( "vgui/DMenuOptionCVar.lua" )	-- https://wiki.facepunch.com/gmod/DMenuOptionCVar (needs DMenuOption, from DMenu.lua)

-- numeric input + tab column (wiki: "Utility Panels").  DNumberWang needs
-- DTextEntry (above); DColumnSheet creates DScrollPanel/DImageButton/DButton.
include( "vgui/DNumPad.lua" )		-- https://wiki.facepunch.com/gmod/DNumPad
include( "vgui/DNumberWang.lua" )	-- https://wiki.facepunch.com/gmod/DNumberWang (needs DTextEntry)
include( "vgui/DColumnSheet.lua" )	-- https://wiki.facepunch.com/gmod/DColumnSheet

-- model pickers (wiki: "Spawnmenu" / DPanelSelect family).  SpawnIcon needs
-- DButton (and the engine's "ModelImage"); DModelSelect derives from DPanelSelect
-- and DModelSelectMulti from DPropertySheet, both registered above.
include( "vgui/SpawnIcon.lua" )		-- https://wiki.facepunch.com/gmod/SpawnIcon
include( "vgui/DModelSelect.lua" )	-- https://wiki.facepunch.com/gmod/DModelSelect (needs DPanelSelect + SpawnIcon)
include( "vgui/DModelSelectMulti.lua" )	-- https://wiki.facepunch.com/gmod/DModelSelectMulti (needs DPropertySheet)

-- the property system (wiki: "DProperties" and its editors).  The editors are the
-- base of DProperties' rows, so they come first; DProperty_Int derives from
-- DProperty_Float.
include( "vgui/DProperty_Generic.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_Generic
include( "vgui/DProperty_Boolean.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_Boolean
include( "vgui/DProperty_Float.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_Float (needs DNumSlider)
include( "vgui/DProperty_Int.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_Int
include( "vgui/DProperty_Combo.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_Combo (needs DComboBox)
include( "vgui/DProperties.lua" )	-- https://wiki.facepunch.com/gmod/DProperties

-- the rest of the property family + the entity sheet + the quick form.
-- PropSelect is a ContextBase (above); DProperty_Entity / _VectorColor are
-- DProperty_Generic; DEntityProperties is a DProperties.
include( "vgui/DProperty_Entity.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_Entity
include( "vgui/DProperty_VectorColor.lua" )	-- https://wiki.facepunch.com/gmod/DProperty_VectorColor
include( "vgui/PropSelect.lua" )	-- https://wiki.facepunch.com/gmod/PropSelect (needs ContextBase)
include( "vgui/DEntityProperties.lua" )	-- https://wiki.facepunch.com/gmod/DEntityProperties (needs DProperties)
include( "vgui/DForm.lua" )		-- https://wiki.facepunch.com/gmod/DForm (needs DCollapsibleCategory)

-- the tree (wiki: "Tree View").  A node's caption button has to be registered
-- before the node that creates it, and the node before the tree.
include( "vgui/DTree_Node_Button.lua" )	-- https://wiki.facepunch.com/gmod/DTree_Node_Button
include( "vgui/DTree_Node.lua" )	-- https://wiki.facepunch.com/gmod/DTree_Node (needs DListLayout + DTree_Node_Button)
include( "vgui/DTree.lua" )		-- https://wiki.facepunch.com/gmod/DTree (needs DScrollPanel)
