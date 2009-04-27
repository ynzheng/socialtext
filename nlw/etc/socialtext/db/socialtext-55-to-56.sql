BEGIN;

ALTER TABLE container_type
    ADD COLUMN global BOOLEAN DEFAULT FALSE;

UPDATE "System"
   SET value = '56'
 WHERE field = 'socialtext-schema-version';

COMMIT;
