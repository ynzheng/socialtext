BEGIN;

ALTER TABLE page
    ADD COLUMN locked BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE "System"
   SET value = '57'
 WHERE field = 'socialtext-schema-version';

COMMIT;
