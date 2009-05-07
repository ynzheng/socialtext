BEGIN;

CREATE INDEX ix_job_piro_non_null ON job (COALESCE(priority,0));

ALTER TABLE "Workspace"
    ADD COLUMN allows_page_locking BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE "System"
   SET value = '57'
 WHERE field = 'socialtext-schema-version';

COMMIT;
