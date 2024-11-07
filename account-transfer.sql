-- old databases are:
-- * classicrealmd
-- * classiccharacters
-- * classicmangos
-- * classiclogs
-- new databases are:
-- * classic_realmd
-- * classic_characters
-- * classic_mangos
-- * classic_logs

----------------------
-- realmd database
----------------------
SET @account_name = 'SERGEI';
SET @account_id = (SELECT id FROM classicrealmd.account WHERE username = @account_name);
SET @account_characters_count = (SELECT numchars FROM classicrealmd.realmcharacters where acctid = @account_id);

INSERT INTO classic_realmd.account (SELECT * FROM classicrealmd.account WHERE username = @account_name);
INSERT INTO classic_realmd.realmcharacters (SELECT * FROM classicrealmd.realmcharacters where acctid = @account_id);

----------------------
-- characters database
----------------------
-- account's macro
INSERT INTO classic_characters.account_data (SELECT * FROM classiccharacters.account_data where account = @account_id);

-- all account character's ids are
-- SELECT guid from classiccharacters.characters where account = @account_id;

-- per-character settings (macro, etc..)
INSERT INTO classic_characters.character_account_data (
	SELECT * FROM classiccharacters.character_account_data WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character buttons placement
INSERT INTO classic_characters.character_action (
	SELECT * FROM classiccharacters.character_action WHERE guid IN (
		SELECT guid FROM classiccharacters.characters where account = @account_id
	)
);

-- per-character home binding
INSERT INTO classic_characters.character_homebind (
	SELECT * FROM classiccharacters.character_homebind WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character honor ?
INSERT INTO classic_characters.character_honor_cp (
	SELECT * FROM classiccharacters.character_honor_cp WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character inventory
INSERT INTO classic_characters.character_inventory (
	SELECT * FROM classiccharacters.character_inventory WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character pets
INSERT INTO classic_characters.character_pet (
	SELECT * FROM classiccharacters.character_pet WHERE owner IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character quests statuses
INSERT INTO classic_characters.character_queststatus (
	SELECT * FROM classiccharacters.character_queststatus WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character reputation at factions
INSERT INTO classic_characters.character_reputation (
	SELECT * FROM classiccharacters.character_reputation WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character skills
INSERT INTO classic_characters.character_skills (
	SELECT * FROM classiccharacters.character_skills WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character friends
INSERT INTO classic_characters.character_social (
	SELECT * FROM classiccharacters.character_social WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character spells
INSERT INTO classic_characters.character_spell (
	SELECT * FROM classiccharacters.character_spell WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- per-character spells cooldowns
INSERT INTO classic_characters.character_spell_cooldown (
	SELECT * FROM classiccharacters.character_spell_cooldown WHERE guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- account tutorial status
INSERT INTO classic_characters.character_tutorial (
	SELECT * FROM classiccharacters.character_tutorial WHERE account = @account_id
);

-- account's characters
INSERT INTO classic_characters.characters (
	SELECT * FROM classiccharacters.characters WHERE account = @account_id
);

-- if there any guild owner - tranfer guild too (without members)
INSERT INTO classic_characters.guild (
	SELECT * FROM classiccharacters.guild WHERE leaderguid in (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- and those guilds custom ranks
INSERT INTO classic_characters.guild_rank (
	SELECT * FROM classiccharacters.guild_rank WHERE guildid IN (
		SELECT guildid FROM classiccharacters.guild WHERE leaderguid IN (
			SELECT guid FROM classiccharacters.characters WHERE account = @account_id
		)
	)
);

-- items owned by characters
INSERT INTO classic_characters.item_instance (
	SELECT * FROM classiccharacters.item_instance WHERE owner_guid IN (
		SELECT guid FROM classiccharacters.characters WHERE account = @account_id
	)
);

-- character's pet's spells
INSERT INTO classic_characters.pet_spell (
	SELECT * FROM classiccharacters.pet_spell WHERE guid IN (
		SELECT id FROM classiccharacters.character_pet WHERE owner IN (
			SELECT guid from classiccharacters.characters WHERE account = @account_id
		)
	)
);

-- character's pet's spell's cooldowns
INSERT INTO classic_characters.pet_spell_cooldown (
	SELECT * FROM classiccharacters.pet_spell_cooldown WHERE guid IN (
		SELECT id FROM classiccharacters.character_pet WHERE owner IN (
			SELECT guid from classiccharacters.characters WHERE account = @account_id
		)
	)
);

