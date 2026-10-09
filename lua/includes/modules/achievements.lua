--[[--------------------------------------------------------------------------
    lua/includes/modules/achievements.lua

    HL2SB shim for GMod's achievements library (a C++ library in GMod; the
    wiki surface is mirrored here as inert stubs so ported gamemodes/addons
    that call achievements.* neither error nor break their flow).  Stateless,
    so the folder-pass double-load that hits hook/concommand is harmless here
    and needs no re-entry guard.
--------------------------------------------------------------------------]]--

module( "achievements", package.seeall )

function Count() return 0 end
function GetCount( achievementID ) return 0 end
function GetDesc( achievementID ) return "" end
function GetGoal( achievementID ) return 1 end
function GetName( achievementID ) return "" end
function IsAchieved( achievementID ) return false end

-- GMod's built-in achievement trackers; no-ops here.
function BalloonPopped() end
function EatBall() end
function IncBaddies() end
function IncBystander() end
function IncGoodies() end
function Remover() end
function SpawnedNPC() end
function SpawnedProp() end
function SpawnedRagdoll() end
function SpawnMenuOpen() end
