--[[ HL2SB (2026-10-16): factory stub for the GMod bone-widget class "widget_bonemanip_rotate".

     A GMod SENT class becomes creatable the moment an addon registers it at
     runtime (scripted_ents.Register): the reference engine's entity factory
     falls back to the scripted-entity registry.  This fork's ents.Create only
     knows the factories its entity loader installs, and the loader installs
     one per lua/entities file -- so each runtime-registered widget class the
     bone-manipulation tool spawns needs a file here to carry its factory.

     The real class table is registered from its own (verbatim GMod) file --
     lua/autorun/properties/bone_manipulate.lua (scripted_ents.Register, "widget_bonemanip_rotate").  This stub must not clobber that registration: the loader also
     calls scripted_ents.Register with THIS file's table under the class name,
     so ClassNameOverride redirects that call to a scratch name (nothing ever
     spawns it).  The class -> instance table mirror (scripted_ents entries ->
     the `entity` module a spawned instance copies from) happens once all
     scripts have loaded, from scripted_ents.OnLoaded
     (lua/autorun/hl2sb_gmod_entity_shims.lua). --]]

AddCSLuaFile()

ENT.Base = "widget_axis"

ENT.DisableDuplicator = true
ENT.ClassNameOverride = "widget_bonemanip_rotate_factory_stub"
