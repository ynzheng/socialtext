BEGIN;

-- Story: Custom skin is applied to Socialtext Desktop

ALTER TABLE "Account"
    ADD COLUMN allow_invitation boolean DEFAULT true NOT NULL;

UPDATE "System"
   SET value = '58'
 WHERE field = 'socialtext-schema-version';

COMMIT;
