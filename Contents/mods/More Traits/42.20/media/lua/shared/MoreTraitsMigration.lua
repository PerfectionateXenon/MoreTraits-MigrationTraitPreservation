local ETW_Registry = require("ETW_Registry")
local ETWTraits = ETW_Registry.traits
local MTTraits = ToadTraitsRegistries

local MIGRATION_MODULE = "MoreTraitsMigration"
local MIGRATION_COMMAND = "migrateTraits"

---Maps legacy More Traits traits to their Evolving Traits World analogues.
---Legacy traits absent from this table are removed without replacement.
---@type table<CharacterTrait, CharacterTrait>
local traitReplacements = {
	[MTTraits.actionhero] = ETWTraits.ACTION_HERO,
	[MTTraits.albino] = ETWTraits.SUN_SENSITIVITY,
	[MTTraits.anemic] = ETWTraits.ANEMIC,
	[MTTraits.antigun] = ETWTraits.ANTI_GUN_ACTIVIST,
	[MTTraits.ascetic] = ETWTraits.ASCETIC,
	[MTTraits.badteeth] = ETWTraits.BAD_TEETH,
	[MTTraits.bladetwirl] = ETWTraits.PRACTICED_SWORDSMAN,
	[MTTraits.blissful] = ETWTraits.BLISSFUL,
	[MTTraits.blunttwirl] = ETWTraits.THUGGISH,
	[MTTraits.bouncer] = ETWTraits.BOUNCER,
	[MTTraits.butterfingers] = ETWTraits.BUTTERFINGERS,
	[MTTraits.depressive] = ETWTraits.DEPRESSIVE,
	[MTTraits.fitted] = ETWTraits.WELL_FITTED,
	[MTTraits.glassbody] = ETWTraits.MADE_OF_GLASS,
	[MTTraits.gordanite] = ETWTraits.GORDONITE,
	[MTTraits.gourmand] = ETWTraits.GOURMAND,
	[MTTraits.gunspecialist] = CharacterTrait.TARGET_SHOOTER,
	[MTTraits.gymgoer] = ETWTraits.GYM_RAT,
	[MTTraits.hardy] = ETWTraits.HARDY,
	[MTTraits.idealweight] = ETWTraits.IDEAL_WEIGHT,
	[MTTraits.immunocompromised] = ETWTraits.IMMUNOCOMPROMISED,
	[MTTraits.indefatigable] = ETWTraits.INDEFATIGABLE,
	[MTTraits.leadfoot] = ETWTraits.LEAD_FOOT,
	[MTTraits.mundane] = ETWTraits.MUNDANE,
	[MTTraits.natural] = ETWTraits.NATURAL_EATER,
	[MTTraits.noodlelegs] = ETWTraits.NOODLE_LEGS,
	[MTTraits.olympian] = ETWTraits.OLYMPIAN,
	[MTTraits.packmouse] = ETWTraits.PACK_MOUSE,
	[MTTraits.packmule] = ETWTraits.PACK_MULE,
	[MTTraits.paranoia] = ETWTraits.PARANOIA,
	[MTTraits.problade] = ETWTraits.PROWESS_BLADE,
	[MTTraits.problunt] = ETWTraits.PROWESS_BLUNT,
	[MTTraits.progun] = ETWTraits.PROWESS_GUNS,
	[MTTraits.prospear] = ETWTraits.PROWESS_SPEAR,
	[MTTraits.quickrest] = ETWTraits.QUICK_REST,
	[MTTraits.quiet] = ETWTraits.QUIET,
	[MTTraits.scrapper] = ETWTraits.SCRAPPER,
	[MTTraits.selfdestructive] = ETWTraits.SELF_DESTRUCTIVE,
	[MTTraits.superimmune] = ETWTraits.SUPER_IMMUNE,
	[MTTraits.tavernbrawler] = ETWTraits.TAVERN_BRAWLER,
	[MTTraits.terminator] = ETWTraits.TERMINATOR,
	[MTTraits.thickblood] = ETWTraits.THICK_BLOODED,
	[MTTraits.unwavering] = ETWTraits.UNWAVERING,
}

---Removes all legacy More Traits traits and adds mapped ETW replacements.
---Trait collection operations are used directly so equivalent XP boosts are not
---applied a second time during this identifier-only migration.
---@param player IsoPlayer
---@return integer removedCount
---@return integer replacementCount
local function migrateTraits(player)
	if not player then
		return 0, 0
	end

	local characterTraits = player:getCharacterTraits()
	local removedCount = 0
	local replacementCount = 0

	for _, oldTrait in pairs(MTTraits) do
		if player:hasTrait(oldTrait) then
			local replacement = traitReplacements[oldTrait]
			characterTraits:remove(oldTrait)
			removedCount = removedCount + 1

			if replacement and not player:hasTrait(replacement) then
				characterTraits:add(replacement)
				replacementCount = replacementCount + 1
			end
		end
	end

	if removedCount > 0 then
		print(
			"More Traits migration | Player "
				.. tostring(player:getUsername())
				.. ": removed "
				.. removedCount
				.. " legacy traits and added "
				.. replacementCount
				.. " ETW replacements"
		)
	end

	return removedCount, replacementCount
end

if isServer() then
	local function onClientCommand(module, command, player, args)
		if module == MIGRATION_MODULE and command == MIGRATION_COMMAND then
			migrateTraits(player)
		end
	end

	Events.OnClientCommand.Add(onClientCommand)
else
	---@type table<IsoPlayer, true>
	local pendingServerMigrations = {}
	local sendPendingServerMigrations

	---@param playerIndex integer
	---@param player IsoPlayer
	local function onCreatePlayer(playerIndex, player)
		local removedCount = migrateTraits(player)
		if isClient() and removedCount > 0 then
			pendingServerMigrations[player] = true
			Events.OnTick.Remove(sendPendingServerMigrations)
			Events.OnTick.Add(sendPendingServerMigrations)
		end
	end

	function sendPendingServerMigrations()
		Events.OnTick.Remove(sendPendingServerMigrations)

		for player in pairs(pendingServerMigrations) do
			sendClientCommand(player, MIGRATION_MODULE, MIGRATION_COMMAND, {})
			pendingServerMigrations[player] = nil
		end
	end

	Events.OnCreatePlayer.Add(onCreatePlayer)
end
