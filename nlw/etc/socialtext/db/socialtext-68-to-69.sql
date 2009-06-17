BEGIN;

CREATE INDEX user_group_role_group_id
    ON user_group_role (group_id);

CREATE INDEX watchlist_workspace_page
    ON "Watchlist" (workspace_id, page_text_id);

UPDATE "System"
   SET value = '69'
 WHERE field = 'socialtext-schema-version';

COMMIT;
