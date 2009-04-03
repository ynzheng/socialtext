BEGIN;

-- Story: user can send signal direct messages and view dms
-- XXX Stub XXX

UPDATE "System"
   SET value = '49'
 WHERE field = 'socialtext-schema-version';

COMMIT;
