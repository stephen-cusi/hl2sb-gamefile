-- Legacy entry names are kept outside the original dispatch libraries.
if ( hook and hook.Call ) then
    hook.add = hook.Add
    hook.remove = hook.Remove
    hook.call = hook.Call
    function hook.gethooks( event )
        local hooks = hook.GetTable()
        if ( event ~= nil ) then return hooks[ event ] end
        return hooks
    end
end

if ( concommand and concommand.Add ) then
    function concommand.Create( name, callback, help, flags, complete )
        return concommand.Add( name, callback, complete, help, flags )
    end

    function concommand.Dispatch( player, command, arguments )
        local commands = concommand.GetTable()
        local callback = commands[ string.lower( command ) ]
        if ( callback == nil ) then return false end
        callback( player, command, arguments )
        return true
    end
end
