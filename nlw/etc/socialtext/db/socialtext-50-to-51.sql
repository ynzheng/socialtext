BEGIN;

ALTER TABLE gadget
    DROP COLUMN plugin,
    ALTER COLUMN href DROP NOT NULL,
    ALTER COLUMN content_type DROP NOT NULL;

UPDATE gadget
  SET src = regexp_replace(src, '^file:([^/]*).*?([^/]*).xml$', 'local:\\1:\\2')
WHERE src LIKE 'file:%';

UPDATE "System"
   SET value = '51'
 WHERE field = 'socialtext-schema-version';

COMMIT;
