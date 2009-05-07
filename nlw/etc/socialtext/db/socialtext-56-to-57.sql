BEGIN;

-- Stub -- To be filled in later for the Page locking feature

ALTER TABLE "Workspace"
    ADD COLUMN allows_page_locking BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE "System"
   SET value = '57'
 WHERE field = 'socialtext-schema-version';

COMMIT;
