//********************************//
//   	 Minecraft SWEP GUI       //  Do NOT redistribute!
//			(c) McKay			  //
//********************************//

include( 'shared.lua' )

//client only
if (SERVER) then return end




//********************************//
//   	  MC_BlockPanel.lua       //
//********************************//

local PANEL = {}
local mbackup = Vector(-1,-1,0)

/*---------------------------------------------------------
   Name: Init
---------------------------------------------------------*/
function PANEL:Init()
	
	self.IconList = vgui.Create( "DPanelList", self )
	self.IconList:EnableVerticalScrollbar( true )
	self.IconList:EnableHorizontal( true )
	self.IconList:SetPadding( 4 )
	
	self.PropList = vgui.Create( "DListView", self )
	self.PropList:SetDataHeight( 16 )
	self.PropList:AddColumn( "#Name" )
	self.PropList.DoDoubleClick = function( PropList, RowNumber, Line ) self:OnRowClick( RowNumber, Line ) end
	
	// Icon by default: todo: Cookie
	self:SetViewMode( "Icon" )
	
	self:SetIconSize( 64 ) // todo: Cookie!
	
	self.Models = {}
	
end

function PANEL:SetParent( parent )
	self.Parent = parent
end


/*---------------------------------------------------------
   Name: Init
---------------------------------------------------------*/
function PANEL:AddModel( strModel, iSkin, blockID )
	iSkin = iSkin or 0
	
	// Make icon 
	local icon = vgui.Create( "SpawnIcon", self )
	icon:SetModel( strModel, iSkin )
	icon.DoClick = function( icon ) self:OnRowClick(icon.ID, icon.Skintype) end
	icon.OpenMenu = function( icon ) 
		local menu = DermaMenu()
		menu:AddOption( "BlockID = "..tostring(blockID), function() print("blockID = "..tostring(blockID)) end )
		menu:AddOption( "Copy to Clipboard", function() SetClipboardText( strModel ) end )
		local submenu = menu:AddSubMenu( "Re-Render", function() icon:RebuildSpawnIcon() end )
			  submenu:AddOption( "This Icon", function() icon:RebuildSpawnIcon() end )
			  submenu:AddOption( "All Icons", function() self:RebuildAll() end )
		//menu:AddSpacer()
		//menu:AddOption( "Add Block", function() self:AddBlock() end )
		menu:Open()
						
	end
					
	icon.ID = blockID
	icon.Skintype = iSkin
	icon:InvalidateLayout( true )
	
	self.IconList:AddItem( icon )
	
	local Line = self.PropList:AddLine( strModel )
	Line.Model = strModel
	
	icon.LineID = Line:GetID()
	
	self.PropList:InvalidateLayout()
end

function PANEL:AddBlock()

end

/*---------------------------------------------------------
   Name: DeleteIcon
---------------------------------------------------------*/
function PANEL:DeleteIcon( category, icon, model )
	self.PropList:RemoveLine( icon.LineID )
		
	self.IconList:RemoveItem( icon )
	self.IconList:InvalidateLayout()
	
	spawnmenu.RemoveProp( category, model )
	
	SpawnMenuEnableSave()
end


/*---------------------------------------------------------
   Name: OnRowClick
---------------------------------------------------------*/
function PANEL:OnRowClick(ID, skin)
	surface.PlaySound( "ui/buttonclickrelease.wav")

	RunConsoleCommand("minecraft_blocktype",tostring(ID))
	RunConsoleCommand("minecraft_blockskin",tostring(skin))
	
	net.Start("MinecraftSwepBlockChange");
	net.SendToServer();
	
	mbackup.x = gui.MouseX();
	mbackup.y = gui.MouseY();
	self.Parent:Close()
	
	m_bBlockNewPanel = false
end



/*---------------------------------------------------------
   Name: SetViewMode
---------------------------------------------------------*/
function PANEL:SetViewMode( strName )
	self.IconList:SetVisible( false )
	self.PropList:SetVisible( false )

	if ( strName == "Icon" ) then
		self.IconList:SetVisible( true )
	end
	
	if ( strName == "List" ) then
		self.PropList:SetVisible( true )
	end
end

/*---------------------------------------------------------
   Name: PerformLayout
---------------------------------------------------------*/
function PANEL:PerformLayout()
	self.IconList:StretchToParent( 0, 0, 0, 0 )
	self.IconList:InvalidateLayout()
	
	self.PropList:StretchToParent( 0, 0, 0, 0 )
	self.PropList:InvalidateLayout()
end

/*---------------------------------------------------------
   Name: RebuildAll
---------------------------------------------------------*/
function PANEL:RebuildAll( proppanel )
	local items = self.IconList:GetItems()
	for k, v in pairs( items ) do
	
		v:RebuildSpawnIcon()
	
	end
end

/*---------------------------------------------------------
   Name: GetCount
---------------------------------------------------------*/
function PANEL:GetCount()
	local items = self.IconList:GetItems()
	return #items
end


/*---------------------------------------------------------
   Name: SetIconSize
---------------------------------------------------------*/
function PANEL:SetIconSize( iconSize )
	self.m_iIconSize = iconSize
	
	local items = self.IconList:GetItems()
	
	for k, v in pairs( items ) do
	
		v:SetIconSize( self.m_iIconSize )
		v:InvalidateLayout( true )
	
	end
	
	self.IconList:InvalidateLayout()
end

/*---------------------------------------------------------
   Name: SetIconSize
---------------------------------------------------------*/
function PANEL:Clear()
	self.IconList:Clear()
	self.PropList:Clear()
	
	m_bBlockNewPanel = false
end

//register the panel
vgui.Register( "MCBlockPanel", PANEL, "DPanel" )



//********************************//
//   	     Block Menu           //
//********************************//

//now with 20% less lag
local mc_frame
local mc_blockPanel
local mc_rotationLabel1,mc_rotationLabel2
local mc_blockCounter
local mc_crashCounter
local mc_options
local mc_left,mc_right,mc_up_mc_down
local mc_removemenu

function openBlockMenu( ply, cmd, args )
	//only create the menu once
	if (mc_frame == nil || mc_frame == NULL || mc_blockPanel == NULL || mc_blockPanel == nil) then
		createBlockMenu(ply,cmd,args)
	end

	//set block counts
    local blockcount = GetCSConVarI( "cl_minecraft_blockcount", ply )
	local crashcount = 0
	for k, v in pairs( ents.GetAll() ) do
        if ( v:IsValid() ) then
			if (v:GetClass() != "minecraft_block" && v:GetClass() != "minecraft_block_waterized" && v:GetClass() != "mc_tnt" && v:GetClass() != "mc_cake") then
				crashcount = crashcount + 1
			end
        end  
    end
	crashcount = 2048 - crashcount
	mc_blockCounter:SetText( "Placed Blocks : "..blockcount )
	mc_blockCounter:SizeToContents()
	mc_crashCounter:SetText( "Would crash at "..crashcount.."." )
	mc_crashCounter:SizeToContents()

	//update the checkbox with the current ConVar value
	if ( GetConVar( "minecraft_blockrotation_force" ):GetInt() >= 1 ) then
		mc_rotationLabel1:SetValue( 1 )
	end
	if ( GetConVar( "minecraft_blockrotation_force" ):GetInt() < 1 ) then
		mc_rotationLabel1:SetValue( 0 )
	end
	mc_rotationLabel1:SizeToContents()	
	
	//set size
	if ( GetConVar( "minecraft_menu_huge" ):GetBool() ) then
		mc_frame:SetSize( ScrW()-100, ScrH()-(20*2) )
	else
		if (ScrW() < 890) then
			mc_frame:SetSize( ScrW()-20, ScrH()-(20*2) )
		else
			mc_frame:SetSize( 890, ScrH()-(20*2) )
		end	
	end
	mc_blockPanel:SetSize(mc_frame:GetSize()-165, ScrH()-(20*2)-25-5)
	
	//center all right ui elements
	local w,h = mc_frame:GetSize()
	local bw = mc_blockPanel:GetSize()
	local bm = bw + (w-bw)/2
	
	//center
	mc_rotationLabel1:SetPos( bm-(mc_rotationLabel1:GetSize()/2), 350 )
	mc_rotationLabel2:SetPos( mc_rotationLabel1:GetPos()+2, 370 )
	mc_options:SetPos( bm-(80/2), 270 )
	mc_up:SetPos( bm-(mc_up:GetSize()/2), 390 )
	mc_left:SetPos( bm-(mc_left:GetSize()/2)-40, 430 )
	mc_right:SetPos( bm-(mc_right:GetSize()/2)+40, 430 )
	mc_down:SetPos( bm-(mc_down:GetSize()/2), 470 )
	mc_blockCounter:SetPos( bm-(mc_blockCounter:GetSize()/2), 150 )
	mc_crashCounter:SetPos( bm-(mc_crashCounter:GetSize()/2), 164 )
	mc_removemenu:SetPos( bm-(mc_removemenu:GetSize()/2), 100 )

	//open
	mc_frame:SetVisible( true )
	mc_frame:Center()
	mc_frame:MakePopup()
	
	//restore mouse position
	if (mbackup.x != -1 && GetConVar("minecraft_menu_savemousepos"):GetBool()) then
		gui.SetMousePos(mbackup.x,mbackup.y)
	end
end

function createBlockMenu( ply, cmd, args )
	//create main frame
    mc_frame = vgui.Create( "DFrame" )
	mc_frame:SetMouseInputEnabled( true )
	mc_frame:SetKeyboardInputEnabled( true )
	if ( GetConVar( "minecraft_menu_huge" ):GetBool() ) then
		mc_frame:SetSize( ScrW()-100, ScrH()-(20*2) )
	else
		if (ScrW() < 890) then
			mc_frame:SetSize( ScrW()-20, ScrH()-(20*2) )
		else
			mc_frame:SetSize( 890, ScrH()-(20*2) )
		end	
	end
	mc_frame:SetTitle( "Block Menu" )
	mc_frame:SetDeleteOnClose( false )
	
	//create BlockPanel
	mc_blockPanel = vgui.Create("MCBlockPanel", mc_frame)
	local border = 5
	mc_blockPanel:SetParent( mc_frame )  
	mc_blockPanel:SetPos( border, 20+border )
	mc_blockPanel:SetSize(mc_frame:GetSize()-165, ScrH()-(20*2)-25-border)
	mc_blockPanel:SetViewMode("Icon")
	mc_blockPanel:PerformLayout() 
	//add every block in the global table 'BlockTypes'
	for i,c in ipairs( BlockTypes ) do
		mc_blockPanel:AddModel( BlockTypes[i].model,0,BlockTypes[i].blockID )
		
		local test = util.GetModelInfo( BlockTypes[i].model )

		local skinCount = test["SkinCount"]
		if (test["SkinCount"] > 1) then
			for skn=1, test["SkinCount"]-1, 1 do
				mc_blockPanel:AddModel( BlockTypes[i].model,skn,BlockTypes[i].blockID )
			end
		end
	end
	
	//center all right ui elements
	local w,h = mc_frame:GetSize()
	local bw = mc_blockPanel:GetSize()
	local bm = bw + (w-bw)/2
	
	//create options menu button
	mc_options = vgui.Create( "DButton", mc_frame )
		mc_options:SetText( "Options" )
		mc_options:SetPos( bm-(80/2), 270 )
		mc_options:SetSize( 80, 30 )
		mc_options.DoClick = function ( btn )
			RunConsoleCommand( "mc_options" )
		end
		
	//force block rotation checkbox
	mc_rotationLabel1 = vgui.Create( "DCheckBoxLabel", DermaPanel )
	mc_rotationLabel1:SetParent( mc_frame )
	mc_rotationLabel1:SetText( "Force block rotation" )
	mc_rotationLabel1:SizeToContents()
	mc_rotationLabel1:SetPos( bm-(mc_rotationLabel1:GetSize()/2), 350 )
	mc_rotationLabel1.OnChange = function( chkBox )
		if ( mc_rotationLabel1:GetChecked() == true ) then
			RunConsoleCommand( "minecraft_blockrotation_force", "1" )
		else
			RunConsoleCommand( "minecraft_blockrotation_force", "0" )
		end
	end    
	
	//helptext
	mc_rotationLabel2 = vgui.Create( "DLabel", mc_frame )
	mc_rotationLabel2:SetText( "( Down arrow is default )" )
	mc_rotationLabel2:SizeToContents()
	mc_rotationLabel2:SetPos( mc_rotationLabel1:GetPos()+2, 370 )
	mc_rotationLabel2:SizeToContents()

	//up button
	mc_up = vgui.Create( "DButton", mc_frame )
	mc_up:SetSize( 40, 40 )
	mc_up:SetPos( bm-(mc_up:GetSize()/2), 390 )
	mc_up:SetText( "^" )
	mc_up.DoClick = function()
		RunConsoleCommand( "minecraft_blockrotation", "180" );
	end

	//left button
	mc_left = vgui.Create( "DButton", mc_frame )
	mc_left:SetSize( 40, 40 )
	mc_left:SetPos( bm-(mc_left:GetSize()/2)-40, 430 )
	mc_left:SetText( "<" )
	mc_left.DoClick = function()
		RunConsoleCommand( "minecraft_blockrotation", "-90" );
	end

	//right button
	mc_right = vgui.Create( "DButton", mc_frame )
	mc_right:SetSize( 40, 40 )
	mc_right:SetPos( bm-(mc_right:GetSize()/2)+40, 430 )
	mc_right:SetText( ">" )
	mc_right.DoClick = function()
		RunConsoleCommand( "minecraft_blockrotation", "90" );
	end

	//down button
	mc_down = vgui.Create( "DButton", mc_frame )
	mc_down:SetSize( 40, 40 )
	mc_down:SetPos( bm-(mc_down:GetSize()/2), 470 )
	mc_down:SetText( "v" )
	mc_down.DoClick = function()
		RunConsoleCommand( "minecraft_blockrotation", "0" );
	end
	
	//block counter label, set text to blockcount
	mc_blockCounter = vgui.Create( "DLabel", mc_frame )
		mc_blockCounter:SetText( "Placed Blocks : " )
		mc_blockCounter:SizeToContents()
		mc_blockCounter:SetPos( bm-(mc_blockCounter:GetSize()/2), 150 ) //560 
		
	//max entity counter, set text to crashcount
	mc_crashCounter = vgui.Create( "DLabel", mc_frame )
		mc_crashCounter:SetText( "Would crash at " )
		mc_crashCounter:SizeToContents()
		mc_crashCounter:SetPos( bm-(mc_crashCounter:GetSize()/2), 164 ) //574
		
	//cleanup button and submenu
    mc_removemenu = vgui.Create( "DButton" )
		mc_removemenu:SetParent( mc_frame )
		mc_removemenu:SetText( "Cleanup Blocks" )
		mc_removemenu:SetSize( 95, 35 )
		mc_removemenu:SetPos( bm-(mc_removemenu:GetSize()/2), 100 )
		mc_removemenu.DoClick = function ( btn ) 
			local menu1 = DermaMenu()
			menu1:AddOption( "Remove ALL the blocks!", function()
				mc_blockCounter:SetText( "Placed Blocks : 0" )
				RunConsoleCommand("cl_minecraft_removeallblocks", "1")
				m_bBlockNewPanel = false
			end )
			menu1:AddOption( "Remove all blocks of the selected type", function()
				RunConsoleCommand("cl_minecraft_removeallselectedblocks", "1")
				m_bBlockNewPanel = false
			end )
			menu1:Open()
		end
end



//********************************//
//   	    Options Menu          //
//********************************//

local function addConVarCheckbox( convarname, text, y, parent )
    local checkbox = vgui.Create( "DCheckBoxLabel", parent )
		checkbox:SetParent( parent )
		checkbox:SetPos( 10,y ) //y + 20
		checkbox:SetText( text )
		checkbox.OnChange = function( chkBox )
			if ( checkbox:GetChecked() == true ) then
				RunConsoleCommand( convarname, "1" )
			end
			if ( checkbox:GetChecked() == false ) then
				RunConsoleCommand( convarname, "0" )
			end
		end    
		if ( GetConVar( convarname ):GetInt() > 0 ) then
			checkbox:SetValue( 1 )
		end
		if ( GetConVar( convarname ):GetInt() < 1 ) then
			checkbox:SetValue( 0 )
		end
		checkbox:SizeToContents()		
end
	
function optionspanel()
	local width = 250;
	local height = 450;
	
    local options = vgui.Create("DFrame")
	options:SetMouseInputEnabled(true)
	options:SetKeyboardInputEnabled(true)
    options:SetPos(550, 320)
    options:SetSize(width, height)
    options:SetTitle( "Options" )
    
	//general swep settings
	addConVarCheckbox( "minecraft_swapattack", "Swap destroy/create mouse buttons", 30, options )
	addConVarCheckbox( "minecraft_disablesounds", "Disable sounds", 50, options )
	addConVarCheckbox( "minecraft_deletemconly", "Delete Minecraft blocks only", 70, options )
	addConVarCheckbox( "minecraft_distancelimit", "Distance limit", 96, options )
    
    local NumSlider = vgui.Create( "DNumSlider", options )
		NumSlider:SetPos( 106,75 )
		NumSlider:SetWide( 130 )
		NumSlider:SetText( "" )
		NumSlider:SetMin( 0 ) -- Minimum number of the slider
		NumSlider:SetMax( 1000 ) -- Maximum number of the slider
		NumSlider:SetDecimals( 0 ) -- Sets a decimal. Zero means it's a whole number
		NumSlider:SetConVar( "minecraft_maxspawndist" ) -- Set the convar  
    
    local bh = vgui.Create( "DCheckBoxLabel", options )
		bh:SetParent( options )
		bh:SetPos( 10,133 ) //y + 20
		bh:SetText( "Block health" )
    local lasthealth = 0
		bh.OnChange = function(chkBox)
			if (bh:GetChecked() == true) then
				lasthealth = GetConVar("minecraft_blockhealth"):GetInt()
				if (lasthealth < 0) then
					lasthealth = 101
				end
				RunConsoleCommand("minecraft_blockhealth", tostring(lasthealth))
			end
			if (bh:GetChecked() == false) then
				RunConsoleCommand("minecraft_blockhealth", "-1") //invincible blocks
			end
		end    
		if ( GetConVar("minecraft_blockhealth" ):GetInt() > 0 ) then
			bh:SetValue( 1 )
		end
		if ( GetConVar( "minecraft_blockhealth") :GetInt() < 0 ) then
			bh:SetValue( 0 )
		end
		bh:SizeToContents()
    
    local NumSlider2 = vgui.Create( "DNumSlider", options )
		NumSlider2:SetPos( 106, 112 )
		NumSlider2:SetWide( 130 )
		NumSlider2:SetText( "" )
		NumSlider2:SetMin( -1 )
		NumSlider2:SetMax( 999 )
		NumSlider2:SetDecimals( 0 )
		NumSlider2:SetConVar( "minecraft_blockhealth" )
		NumSlider2.OnValueChanged = function ( pSelf, fValue )
			if (tonumber(fValue) < 0) then
				bh:SetValue(0)
			end
			if (tonumber(fValue) > 0) then
				bh:SetValue(1)
			end
			RunConsoleCommand( "minecraft_blockhealth", tostring(fValue) )
		end

	//fluid settings
	addConVarCheckbox( "minecraft_lavaigniteplayer", "Lava ignites the player", 159, options )
	addConVarCheckbox( "minecraft_lavaigniteblocks", "Lava ignites other blocks", 179, options )
	
	/*
	addConVarCheckbox( "minecraft_water_spread", "Water and lava spread", 205, options )
    
    local spreadslider = vgui.Create( "DNumSlider", options )
		spreadslider:SetPos( 10,230 )
		spreadslider:SetWide( 110 )
		spreadslider:SetText( "Water spread" )
		spreadslider:SetMin( 0 ) -- Minimum number of the slider
		spreadslider:SetMax( GetConVar("minecraft_water_spread_LIMIT"):GetInt() ) -- Maximum number of the slider
		spreadslider:SetDecimals( 0 ) -- Sets a decimal. Zero means it's a whole number
		spreadslider:SetConVar( "minecraft_water_maxspread" ) -- Set the convar 
		
    local spreadslider2 = vgui.Create( "DNumSlider", options )
		spreadslider2:SetPos( 130,230 )
		spreadslider2:SetWide( 110 )
		spreadslider2:SetText( "Lava spread" )
		spreadslider2:SetMin( 0 ) -- Minimum number of the slider
		spreadslider2:SetMax( GetConVar("minecraft_water_spread_LIMIT"):GetInt() ) -- Maximum number of the slider
		spreadslider2:SetDecimals( 0 ) -- Sets a decimal. Zero means it's a whole number
		spreadslider2:SetConVar( "minecraft_lava_maxspread" ) -- Set the convar 
	*/
		
	//block settings
	addConVarCheckbox( "minecraft_vines_grow", "Vines grow", 270, options )
	addConVarCheckbox( "minecraft_particles", "Particles", 290, options )
	addConVarCheckbox( "minecraft_doors_disablecollision", "No Collide doors if open", 310, options )
	addConVarCheckbox( "minecraft_flipstairs", "Flip stairs", 330, options )
	addConVarCheckbox( "minecraft_fliplogs", "Flip logs", 350, options )
	
	
	//addConVarCheckbox( "minecraft_menu_huge", "Huge menu", 370, options )
    local huge_menu = vgui.Create( "DCheckBoxLabel", options )
		huge_menu:SetParent( options )
		huge_menu:SetPos( 10,370 )
		huge_menu:SetText( "Huge menu" )
		if ( GetConVar( "minecraft_menu_huge" ):GetInt() > 0 ) then
			huge_menu:SetValue( 1 )
		end
		if ( GetConVar( "minecraft_menu_huge" ):GetInt() < 1 ) then
			huge_menu:SetValue( 0 )
		end
		huge_menu.OnChange = function( chkBox )
			if ( huge_menu:GetChecked() == true ) then
				options:Close()
				RunConsoleCommand( "minecraft_menu_huge", "1" )
				mc_frame:Close()
				RunConsoleCommand("mc_menu")
			end
			if ( huge_menu:GetChecked() == false ) then
				options:Close()
				RunConsoleCommand( "minecraft_menu_huge", "0" )
				mc_frame:Close()
				RunConsoleCommand("mc_menu")
			end
		end    
		huge_menu:SizeToContents()	
		
		
	addConVarCheckbox( "minecraft_debug", "Debug info", height-32, options )
   
    local tomenu = vgui.Create("DButton")
		tomenu:SetParent( options )
		tomenu:SetText( "Close" )
		tomenu:SetPos( 90, height-40 )
		tomenu:SetSize( 80, 30 )
		tomenu.DoClick = function( btn )

        options:Close()
    end
	
    options:SetVisible( true )
	options:Center()
    options:MakePopup()
end




//add the concommands
concommand.Add("mc_menu", openBlockMenu )
concommand.Add("mc_options", optionspanel )


//********************************//
//   	 	 All ConVars		  //
//********************************//
CreateClientConVar( "minecraft_menu_savemousepos", "1", true, true )
CreateClientConVar( "minecraft_menu_huge", "1", false, true )
CreateClientConVar( "minecraft_debug", "0", false, true )

CreateClientConVar( "minecraft_maxspawndist", "300", true, true )
CreateClientConVar( "minecraft_lavaigniteplayer", "0", true, true )
CreateClientConVar( "minecraft_lavaigniteblocks", "0", true, true )
CreateClientConVar( "minecraft_deletemconly", "1", true, true )

CreateClientConVar( "minecraft_blocktype", "1", true, true )
local function blockTypeCallback( cvar, prevValue, newValue )
	if ( tonumber(newValue) > #BlockTypes ) then
		RunConsoleCommand( "minecraft_blocktype", tostring(#BlockTypes) )
		print("BlockType ",newValue," does not exist! You can add new blocks to minecraft_blocktypes.lua")
	end
	if ( tonumber(newValue) < 0 ) then
		RunConsoleCommand( "minecraft_blocktype", tostring(0) )
		print("nope.avi")
	end
end
cvars.AddChangeCallback( "minecraft_blocktype", blockTypeCallback )

CreateClientConVar( "minecraft_blockskin", "0", true, true )

CreateClientConVar( "minecraft_disablesounds", "0", true, true )
CreateClientConVar( "minecraft_distancelimit", "1", true, true )
CreateClientConVar( "minecraft_blockhealth", "101", true, true )
CreateClientConVar( "minecraft_blockhealth_auto", "1", true, true )

CreateClientConVar( "minecraft_spawntype", "2", false, true )
CreateClientConVar( "minecraft_swapattack", "0", true, true )
CreateClientConVar( "minecraft_blockrotation", "0", true, true )
CreateClientConVar( "minecraft_blockrotation_force", "0", true, true )

CreateClientConVar( "minecraft_force_block_spawn", "0", false, true )

CreateClientConVar( "cl_minecraft_removeallblocks", "0", false, true )
CreateClientConVar( "cl_minecraft_removeallselectedblocks", "0", false, true )
CreateClientConVar( "cl_minecraft_blockcount", "0", false, true )


//general waterized
CreateClientConVar( "minecraft_water_spread", "1", true, true )
CreateClientConVar( "minecraft_water_spread_LIMIT", "25", true, true )
CreateClientConVar( "minecraft_water_worldcollision_trl", "14", false, true )

//lava specific
CreateClientConVar( "minecraft_lava_maxspread", "3", true, true )
CreateClientConVar( "minecraft_lava_spreadspeed", "0.5", true, true )
CreateClientConVar( "minecraft_lava_residuetime", "2", true, true )

//water specific
CreateClientConVar( "minecraft_water_maxspread", "7", true, true )
CreateClientConVar( "minecraft_water_spreadspeed", "0.2", true, true )

//vines
CreateClientConVar( "minecraft_vines_growspeed", "0.5", true, true )
CreateClientConVar( "minecraft_vines_grow", "1", true, true )

//stairs and logs
CreateClientConVar( "minecraft_flipstairs", "0", true, true )
CreateClientConVar( "minecraft_fliplogs", "0", true, true )

//doors
CreateClientConVar( "minecraft_doors_disablecollision", "1", true, true )


//Particles
CreateClientConVar( "minecraft_particles", "1", true, true )

CreateClientConVar( "minecraft_particles_outwardforce", "240", true, true )

CreateClientConVar( "minecraft_particles_count", "32", true, true )
CreateClientConVar( "minecraft_particles_lifetime_min", "0.25", true, true )
CreateClientConVar( "minecraft_particles_lifetime_max", "0.35", true, true )

CreateClientConVar( "minecraft_particles_dietime_min", "0.5", true, true )
CreateClientConVar( "minecraft_particles_dietime_max", "2.5", true, true )
CreateClientConVar( "minecraft_particles_gravity", "700", true, true )
CreateClientConVar( "minecraft_particles_airresistance", "100", true, true )

CreateClientConVar( "minecraft_particles_startsize_min", "4", true, true )
CreateClientConVar( "minecraft_particles_startsize_max", "7", true, true )



CreateClientConVar( "mc_viewmodel_x", "-100", false, true )
CreateClientConVar( "mc_viewmodel_y", "-28", false, true )
CreateClientConVar( "mc_viewmodel_z", "-79", false, true )

CreateClientConVar( "mc_viewmodel_dx", "0", false, true )
CreateClientConVar( "mc_viewmodel_dy", "90", false, true )
CreateClientConVar( "mc_viewmodel_dz", "-90", false, true )

CreateClientConVar( "mc_viewmodel_rot_x", "9", false, true )
CreateClientConVar( "mc_viewmodel_rot_y", "-4", false, true )
CreateClientConVar( "mc_viewmodel_rot_z", "230", false, true )

CreateClientConVar( "mc_viewmodel_rot_dx", "-70", false, true )
CreateClientConVar( "mc_viewmodel_rot_dy", "20", false, true )
CreateClientConVar( "mc_viewmodel_rot_dz", "10", false, true )

CreateClientConVar( "mc_viewmodel_animtest", "0", false, true )
CreateClientConVar( "mc_viewmodel_animspeed", "0.1", false, true )
CreateClientConVar( "mc_viewmodel_animspeed_back", "0.22", false, true )
CreateClientConVar( "mc_viewmodel_doAnim", "0", false, true )