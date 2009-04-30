BEGIN;

ALTER TABLE container_type
    ADD COLUMN global BOOLEAN DEFAULT FALSE,
    DROP COLUMN layout_template,
    ADD COLUMN columns INTEGER DEFAULT 3;

UPDATE "System"
   SET value = '56'
 WHERE field = 'socialtext-schema-version';

COMMIT;
