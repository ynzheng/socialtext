BEGIN;

ALTER TABLE gadget
  ADD COLUMN name TEXT;

UPDATE gadget
  SET name = regexp_replace(src, '^.*?([^/]*).xml$', '\\1')
WHERE plugin IS NOT NULL;

UPDATE "System"
   SET value = '49'
 WHERE field = 'socialtext-schema-version';

COMMIT;
