-- Keep context focus cleanup outside the original Sandbox and Derma files.
if ( !CLIENT or !vgui.GetControlTable ) then return end

local frame = vgui.GetControlTable( "DFrame" )
if ( !frame or frame.HL2SBContextCloseInstalled ) then return end

local close = rawget( frame, "Close" )
if ( !isfunction( close ) ) then return end
frame.HL2SBContextCloseInstalled = true

function frame:Close()
    local parent = self:GetParent()
    close( self )

    if ( !IsValid( parent ) or parent != g_ContextMenu ) then return end

    for _, child in ipairs( parent:GetChildren() ) do
        if ( child != self and IsValid( child ) and child.ClassName == "DFrame" and child:IsVisible() ) then return end
    end

    parent:KillFocus()
    parent:SetHangOpen( false )
    parent:Close()
end
