-- Engine synchronization for the original GMod player-manager module.
-- The original module remains the owner of model registration and enumeration.

if ( player_manager == nil ) then return end

local addModel = player_manager.AddValidModel
local addHands = player_manager.AddValidHands

local function SyncModel( name, model, hands )
	if ( hl2sb ~= nil and hl2sb.AddPlayerModel ~= nil and isstring( name ) ) then
		hl2sb.AddPlayerModel( name, model, hands )
	end
end

function player_manager.AddValidModel( name, model, title, category )
	addModel( name, model, title, category )
	if ( isstring( model ) ) then SyncModel( name, model ) end
end

function player_manager.AddValidHands( name, model, skin, body, matchBodySkin )
	addHands( name, model, skin, body, matchBodySkin )
	if ( isstring( model ) ) then
		SyncModel( name, nil, model .. "|" .. tostring( skin or 0 ) .. "|" .. tostring( body or "0000000" ) )
	end
end

-- Default registrations already ran before this compatibility file. Register
-- them with the engine without loading their models; selection precaches only
-- the chosen model later.
for name, model in pairs( player_manager.AllValidModels() ) do
	SyncModel( name, model )
end

for name in pairs( player_manager.GetAllPlayerModels() ) do
	local hands = player_manager.TranslatePlayerHands( name )
	if ( istable( hands ) and isstring( hands.model ) ) then
		SyncModel( name, nil, hands.model .. "|" .. tostring( hands.skin or 0 ) .. "|" .. tostring( hands.body or "0000000" ) )
	end
end

local playerMeta = FindMetaTable( "Player" )
if ( playerMeta ~= nil ) then
	if ( playerMeta.SetNoCollideWithTeammates == nil ) then
		function playerMeta:SetNoCollideWithTeammates( enabled ) self.__hl2sbTeammateNoCollide = enabled and true or false end
	end
	if ( playerMeta.SetAvoidPlayers == nil ) then
		function playerMeta:SetAvoidPlayers( enabled ) self.__hl2sbAvoidPlayers = enabled and true or false end
	end
end
include( "hl2sb/compat/player_methods.lua" )
