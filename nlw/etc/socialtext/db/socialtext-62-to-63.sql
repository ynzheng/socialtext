BEGIN;

ALTER TABLE gallery_gadget
    ADD COLUMN socialtext BOOLEAN DEFAULT FALSE;

UPDATE gallery_gadget
    SET socialtext = TRUE WHERE section = 'socialtext';

ALTER TABLE gallery_gadget
    DROP COLUMN section;

UPDATE "System"
    SET value = '63'
  WHERE field = 'socialtext-schema-version';

COMMIT;
