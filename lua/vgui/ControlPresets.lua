-- HL2SB: minimal GMod-compatible ControlPresets.
-- Implements the surface used by addons: SetPreset / AddOption / AddConVar /
-- GetConVars / Update. Preset persistence is intentionally not required for the
-- control to work; choosing an option applies its convar table immediately.

local PANEL = {}

function PANEL:Init()
        self.Options = {}
        self.ConVars = {}
        self.m_strPreset = "Presets"

        self.DropDown = vgui.Create( "DComboBox", self )
        self.DropDown:Dock( FILL )
        self.DropDown:SetText( self.m_strPreset )
        self.DropDown.OnSelect = function( _, _, _, data )
                if ( not data ) then return end
                for k, v in pairs( data ) do
                        RunConsoleCommand( k, v )
                end
        end

        self:SetTall( 22 )
end

function PANEL:AddOption( name, data )
        self.Options[ name ] = data
        self.DropDown:AddChoice( name, data )
end

function PANEL:SetOptions( options )
        if ( not options ) then return end
        for k, v in pairs( options ) do
                self:AddOption( k, v )
        end
end

function PANEL:AddConVar( convar )
        if ( not convar ) then return end
        for _, existing in ipairs( self.ConVars ) do
                if ( existing == convar ) then return end
        end
        table.insert( self.ConVars, convar )
end

function PANEL:GetConVars()
        return self.ConVars
end

function PANEL:SetPreset( name )
        self.m_strPreset = tostring( name or "Presets" )
        self.DropDown:SetText( self.m_strPreset )
end

function PANEL:GetPreset()
        return self.m_strPreset
end

function PANEL:Clear()
        self.DropDown:Clear()
end

function PANEL:ReloadPresets()
        local options = self.Options
        self:Clear()
        self.Options = {}
        for k, v in pairs( options ) do
                self:AddOption( k, v )
        end
end

function PANEL:Update()
        self:ReloadPresets()
end

vgui.Register( "ControlPresets", PANEL, "DPanel" )
