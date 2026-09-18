//*********************************************************//
//														   //
//	Block Types ; BlockTypes[x] <-- spawnicon position	   //
//				; NEVER change any blockIDs !!!			   //
//*********************************************************//

BlockTypes = {};

local blockCounter = 1;
local function addBlock( blockModel, blockId )
	BlockTypes[blockCounter] = {}
	BlockTypes[blockCounter].model = blockModel;
	if (blockId != nil) then
		BlockTypes[blockCounter].blockID = blockId
	else
		BlockTypes[blockCounter].blockID = blockCounter;
	end
	blockCounter = blockCounter + 1;
end

//DO NOT modify the order of how blocks are added here, ONLY add new blocks at the bottom!
//because certain things like auto block rotation rely on the blockID supplied by blockCounter
addBlock("models/MCModelPack/blocks/dirt.mdl")
addBlock("models/MCModelPack/blocks/grass.mdl")
addBlock("models/MCModelPack/blocks/farmland.mdl")
addBlock("models/MCModelPack/blocks/gravel.mdl")
addBlock("models/MCModelPack/blocks/clay.mdl")
addBlock("models/MCModelPack/blocks/sand.mdl")
addBlock("models/MCModelPack/blocks/sandstone.mdl")
addBlock("models/MCModelPack/blocks/cobblestone.mdl")
addBlock("models/MCModelPack/blocks/stone.mdl")
addBlock("models/MCModelPack/blocks/ore.mdl")
addBlock("models/MCModelPack/blocks/stoneslabs.mdl")
addBlock("models/MCModelPack/blocks/stonebrick.mdl")
addBlock("models/MCModelPack/blocks/obsidian.mdl")
addBlock("models/MCModelPack/blocks/bedrock.mdl")
addBlock("models/MCModelPack/blocks/brick.mdl")
addBlock("models/MCModelPack/blocks/solidblock.mdl")
addBlock("models/MCModelPack/blocks/snowblock.mdl")
addBlock("models/MCModelPack/blocks/sponge.mdl")
addBlock("models/MCModelPack/blocks/netherrack.mdl")
addBlock("models/MCModelPack/blocks/soulsand.mdl")
addBlock("models/MCModelPack/blocks/glowstone.mdl")
addBlock("models/MCModelPack/blocks/glass.mdl")
addBlock("models/MCModelPack/blocks/dispencer.mdl")
addBlock("models/MCModelPack/blocks/furnace.mdl")
addBlock("models/MCModelPack/blocks/chest.mdl")
addBlock("models/MCModelPack/blocks/jukebox.mdl")
addBlock("models/MCModelPack/blocks/noteblock.mdl")
addBlock("models/MCModelPack/blocks/bookshelf.mdl")
addBlock("models/MCModelPack/blocks/planks.mdl")
addBlock("models/MCModelPack/blocks/workbench.mdl")
addBlock("models/MCModelPack/blocks/wood.mdl")
addBlock("models/MCModelPack/blocks/cactus.mdl")
addBlock("models/MCModelPack/blocks/melon.mdl")
addBlock("models/MCModelPack/blocks/pumpkin.mdl")
addBlock("models/MCModelPack/blocks/giantmushroom-base.mdl")
addBlock("models/MCModelPack/blocks/giantmushroom-head.mdl")
addBlock("models/MCModelPack/blocks/spawner.mdl")
addBlock("models/MCModelPack/blocks/leaves.mdl")
addBlock("models/MCModelPack/blocks/tnt.mdl")
addBlock("models/MCModelPack/blocks/ice.mdl")
addBlock("models/MCModelPack/blocks/water.mdl")
addBlock("models/MCModelPack/blocks/lava.mdl")
addBlock("models/MCModelPack/blocks/nullblock.mdl")
addBlock("models/MCModelPack/other_blocks/piston.mdl")
addBlock("models/MCModelPack/other_blocks/stairs-stone.mdl")
addBlock("models/MCModelPack/other_blocks/stairs-brick.mdl")
addBlock("models/MCModelPack/other_blocks/stairs-wood.mdl")
addBlock("models/MCModelPack/other_blocks/cake.mdl")
addBlock("models/MCModelPack/other_blocks/brickslab.mdl")
addBlock("models/MCModelPack/other_blocks/cobblestoneslab.mdl")
addBlock("models/MCModelPack/other_blocks/stonebrickslab.mdl")
addBlock("models/MCModelPack/other_blocks/stoneslab.mdl")
addBlock("models/MCModelPack/other_blocks/sandstoneslab.mdl")
addBlock("models/MCModelPack/other_blocks/woodenslab.mdl")
addBlock("models/MCModelPack/other_blocks/trapdoor.mdl")
addBlock("models/MCModelPack/other_blocks/snow.mdl")
addBlock("models/MCModelPack/other_blocks/repeater-off.mdl")
addBlock("models/MCModelPack/other_blocks/repeater-on.mdl")
addBlock("models/MCModelPack/other_blocks/portal.mdl")
addBlock("models/MCModelPack/other_blocks/ironbars.mdl")
addBlock("models/MCModelPack/other_blocks/glasspane.mdl")
addBlock("models/MCModelPack/other_blocks/door-wood.mdl")
addBlock("models/MCModelPack/other_blocks/door-iron.mdl")
addBlock("models/MCModelPack/entities/sign.mdl")
addBlock("models/MCModelPack/entities/wallsign.mdl")
addBlock("models/MCModelPack/entities/torch.mdl")
addBlock("models/MCModelPack/entities/torch-redstone.mdl")
addBlock("models/MCModelPack/entities/lever.mdl")
addBlock("models/MCModelPack/entities/fire.mdl")
addBlock("models/MCModelPack/other_blocks/decoration.mdl")
addBlock("models/MCModelPack/other_blocks/crops.mdl")
addBlock("models/MCModelPack/other_blocks/ladder.mdl")
addBlock("models/MCModelPack/other_blocks/rail.mdl")
addBlock("models/MCModelPack/other_blocks/rail-turn.mdl")
addBlock("models/MCModelPack/other_blocks/rail-detector.mdl")
addBlock("models/MCModelPack/other_blocks/rail-powered.mdl")
addBlock("models/MCModelPack/other_blocks/bigchest.mdl")
addBlock("models/MCModelPack/entities/bed.mdl")
addBlock("models/MCModelPack/blocks/cloth-old.mdl")
addBlock("models/MCModelPack/blocks/cloth-new.mdl")
addBlock("models/MCModelPack/other_blocks/cobweb.mdl")
addBlock("models/MCModelPack/other_blocks/vines.mdl")


//NEW

//random
addBlock("models/MCModelPack/mobs/slime.mdl")
addBlock("models/MCModelPack/mobs/slime-big.mdl")

//blocks
addBlock("models/MCModelPack/blocks/lamp.mdl")
addBlock("models/MCModelPack/blocks/netherbrick.mdl")
addBlock("models/MCModelPack/other_blocks/brewing_stand.mdl")
addBlock("models/MCModelPack/other_blocks/cauldron.mdl")
addBlock("models/MCModelPack/other_blocks/cocoa_plant-1.mdl")
addBlock("models/MCModelPack/other_blocks/cocoa_plant-2.mdl")
addBlock("models/MCModelPack/other_blocks/cocoa_plant-3.mdl")

//ents
addBlock("models/MCModelPack/entities/chest-new.mdl")
addBlock("models/MCModelPack/entities/bigchest-new.mdl")
addBlock("models/MCModelPack/entities/enderchest.mdl")
addBlock("models/MCModelPack/entities/pressure_plate-stone.mdl")
addBlock("models/MCModelPack/entities/pressure_plate-wood.mdl")
addBlock("models/MCModelPack/entities/pressure_plate-wood.mdl")
addBlock("models/MCModelPack/entities/button.mdl")

//fences
addBlock("models/MCModelPack/fences/fence-1side.mdl")
addBlock("models/MCModelPack/fences/fence-2sides.mdl")
addBlock("models/MCModelPack/fences/fence-3sides.mdl")
addBlock("models/MCModelPack/fences/fence-4sides.mdl")
addBlock("models/MCModelPack/fences/fence-corner.mdl")
addBlock("models/MCModelPack/fences/fence-gate.mdl")
addBlock("models/MCModelPack/fences/fence-gate-open.mdl")
addBlock("models/MCModelPack/fences/fence-post.mdl")

//other blocks
addBlock("models/MCModelPack/other_blocks/netherbrickslab.mdl")
addBlock("models/MCModelPack/other_blocks/nethervart.mdl")
addBlock("models/MCModelPack/other_blocks/tripwire.mdl")

//paintins
addBlock("models/MCModelPack/paintings/painting1x1.mdl")
addBlock("models/MCModelPack/paintings/painting1x2.mdl")
addBlock("models/MCModelPack/paintings/painting2x1.mdl")
addBlock("models/MCModelPack/paintings/painting2x2.mdl")
addBlock("models/MCModelPack/paintings/painting2x4.mdl")
addBlock("models/MCModelPack/paintings/painting3x4.mdl")
addBlock("models/MCModelPack/paintings/painting4x4.mdl")

//redstone
addBlock("models/MCModelPack/redstone/wire0.mdl")
addBlock("models/MCModelPack/redstone/wire1.mdl")
addBlock("models/MCModelPack/redstone/wire2.mdl")
addBlock("models/MCModelPack/redstone/wire3.mdl")
addBlock("models/MCModelPack/redstone/wire4.mdl")
addBlock("models/MCModelPack/redstone/wire-side.mdl")

//carrots
addBlock("models/MCModelPack/other_blocks/carrots.mdl")

//walls
addBlock("models/MCModelPack/fences/wall-1side.mdl")
addBlock("models/MCModelPack/fences/wall-2sides.mdl")
addBlock("models/MCModelPack/fences/wall-3sides.mdl")
addBlock("models/MCModelPack/fences/wall-4sides.mdl")
addBlock("models/MCModelPack/fences/wall-corner.mdl")
addBlock("models/MCModelPack/fences/wall-post.mdl")

//end stuff
addBlock("models/MCModelPack/entities/anvil.mdl")
addBlock("models/MCModelPack/other_blocks/ench_table.mdl")
addBlock("models/MCModelPack/other_blocks/endportal.mdl")
addBlock("models/MCModelPack/other_blocks/beacon.mdl")
addBlock("models/MCModelPack/other_blocks/dragon_egg.mdl")

//items
addBlock("models/MCModelPack/items/apple.mdl")
addBlock("models/MCModelPack/items/arrow.mdl")
addBlock("models/MCModelPack/items/axe.mdl")
addBlock("models/MCModelPack/items/biscuit.mdl")
addBlock("models/MCModelPack/items/body.mdl")
addBlock("models/MCModelPack/items/bone.mdl")
addBlock("models/MCModelPack/items/boots.mdl")
addBlock("models/MCModelPack/items/bottle.mdl")
addBlock("models/MCModelPack/items/bow.mdl")
addBlock("models/MCModelPack/items/bread.mdl")
addBlock("models/MCModelPack/items/cake.mdl")
addBlock("models/MCModelPack/items/clock.mdl")
addBlock("models/MCModelPack/items/coal.mdl")
addBlock("models/MCModelPack/items/carrot.mdl")
addBlock("models/MCModelPack/items/diamond.mdl")
addBlock("models/MCModelPack/items/dust.mdl")
addBlock("models/MCModelPack/items/egg.mdl")
addBlock("models/MCModelPack/items/emerald.mdl")
addBlock("models/MCModelPack/items/fish.mdl")
addBlock("models/MCModelPack/items/fishing_rod.mdl")
addBlock("models/MCModelPack/items/flint.mdl")
addBlock("models/MCModelPack/items/flint_steel.mdl")
addBlock("models/MCModelPack/items/helm.mdl")
addBlock("models/MCModelPack/items/hoe.mdl")
addBlock("models/MCModelPack/items/ignot.mdl")
addBlock("models/MCModelPack/items/leggings.mdl")
addBlock("models/MCModelPack/items/meat.mdl")
addBlock("models/MCModelPack/items/melon.mdl")
addBlock("models/MCModelPack/items/pearl.mdl")
addBlock("models/MCModelPack/items/pickaxe.mdl")
addBlock("models/MCModelPack/items/record.mdl")
addBlock("models/MCModelPack/items/ruby.mdl")
addBlock("models/MCModelPack/items/shears.mdl")
addBlock("models/MCModelPack/items/shovel.mdl")
addBlock("models/MCModelPack/items/snowball.mdl")
addBlock("models/MCModelPack/items/spawnegg.mdl")
addBlock("models/MCModelPack/items/sword.mdl")

//new blocks
addBlock("models/MCModelPack/other_blocks/sunflower.mdl")
addBlock("models/MCModelPack/other_blocks/bigplant.mdl")
addBlock("models/MCModelPack/other_blocks/comparator-off.mdl")
addBlock("models/MCModelPack/other_blocks/comparator-on.mdl")
addBlock("models/MCModelPack/other_blocks/repeater-blocked.mdl")
addBlock("models/MCModelPack/other_blocks/hopper.mdl")
addBlock("models/MCModelPack/other_blocks/hopper-side.mdl")
addBlock("models/MCModelPack/other_blocks/string.mdl")
addBlock("models/MCModelPack/other_blocks/quartzslab.mdl")
addBlock("models/MCModelPack/other_blocks/stairs-quartz.mdl")
addBlock("models/MCModelPack/other_blocks/pot.mdl")
addBlock("models/MCModelPack/blocks/hay.mdl")
addBlock("models/MCModelPack/blocks/command.mdl")
addBlock("models/MCModelPack/blocks/reactor.mdl")
addBlock("models/MCModelPack/blocks/ore-quartz.mdl")
addBlock("models/MCModelPack/other_blocks/detector-daylight.mdl")
addBlock("models/MCModelPack/other_blocks/frame.mdl")
addBlock("models/MCModelPack/other_blocks/heads.mdl")
addBlock("models/MCModelPack/other_blocks/sprout1.mdl")
addBlock("models/MCModelPack/other_blocks/sprout2.mdl")
addBlock("models/MCModelPack/other_blocks/lily.mdl")
addBlock("models/MCModelPack/items/star.mdl")
addBlock("models/MCModelPack/items/rocket.mdl")
addBlock("models/MCModelPack/fences/lead.mdl")
addBlock("models/MCModelPack/entities/beam.mdl")
addBlock("models/MCModelPack/entities/crystal-stand.mdl")
addBlock("models/MCModelPack/entities/crystal.mdl")
addBlock("models/MCModelPack/entities/camera.mdl")

//feel free to add more blocks; the blocksize is 36.5 units