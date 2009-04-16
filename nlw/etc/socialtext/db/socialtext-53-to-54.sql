BEGIN;

-- Create tables for per-workspace plugin prefs

ALTER TABLE ONLY "UserMetadata"
    ADD COLUMN dm_sends_email BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE "System"
   SET value = '54'
 WHERE field = 'socialtext-schema-version';

COMMIT;
