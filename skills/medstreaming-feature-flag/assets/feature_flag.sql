-- Task <id> - <feature name>
-- Feature flag template.
--
-- Replace:
--   EnableYourFeature   the ConfigProperty.ShortString, also used by the RepositoryLookup accessor
--   HL7Messaging        the ConfigType.TargetComponent that owns it
--   'False'             the seeded default - keep new flags OFF so existing sites are unaffected
--
-- NOTE: config values are cached in memory at application startup. Running this script while
-- the client or service is up will NOT enable the feature until it restarts.
USE [medstreaming]
GO

DECLARE @configTypeId INT
SET @configTypeId = (SELECT ID FROM ConfigType WHERE TargetComponent = 'HL7Messaging')

IF NOT EXISTS (SELECT * FROM ConfigProperty WHERE ShortString = 'EnableYourFeature')
BEGIN
	INSERT INTO ConfigProperty (ShortString, TypeString, Description, ConfigTypeId)
	VALUES ('EnableYourFeature', 'bool',
	        'Enable/disable <what it does>', @configTypeId)
END
GO

DECLARE @configPropId INT
SET @configPropId = (SELECT Id FROM ConfigProperty WHERE ShortString = 'EnableYourFeature')

IF NOT EXISTS (SELECT * FROM ConfigCombination WHERE ConfigPropertyId = @configPropId)
BEGIN
	INSERT INTO ConfigCombination (ConfigId, ConfigPropertyId, ConfigPropertyValue)
	VALUES (1, @configPropId, 'False')
END
GO
