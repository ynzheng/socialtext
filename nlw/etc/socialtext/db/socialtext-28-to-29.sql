BEGIN;

-- Create a WebHooks table
CREATE TABLE webhook (
    id bigint NOT NULL,
    workspace_id bigint,
    action text,
    page_id text,
    url text
);

CREATE SEQUENCE "webhook___webhook_id"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE INDEX webhook__workspace_ix
        ON webhook (workspace_id);

CREATE INDEX webhook__workspace_action_ix
        ON webhook (workspace_id, action);

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_workspace_id_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_ukey
        UNIQUE (workspace_id, action, page_id, url);

-- No FK contstraint on page_id - it's not necessary that the page exists

--
-- Begin Schwartz schema
--
-- Created by: Michael Zedeler <michael@zedeler.dk>

CREATE TABLE funcmap (
        funcid SERIAL,
        funcname       VARCHAR(255) NOT NULL,
        UNIQUE(funcname)
);

CREATE TABLE job (
        jobid           SERIAL,
        funcid          INT NOT NULL,
        arg             BYTEA,
        uniqkey         VARCHAR(255) NULL,
        insert_time     INTEGER,
        run_after       INTEGER NOT NULL,
        grabbed_until   INTEGER NOT NULL,
        priority        SMALLINT,
        coalesce        VARCHAR(255),
        UNIQUE(funcid, uniqkey)
);

CREATE INDEX job_funcid_runafter ON job (funcid, run_after);

CREATE INDEX job_funcid_coalesce ON job (funcid, coalesce);

CREATE TABLE note (
        jobid           BIGINT NOT NULL,
        notekey         VARCHAR(255),
        PRIMARY KEY (jobid, notekey),
        value           BYTEA
);

CREATE TABLE error (
        error_time      INTEGER NOT NULL,
        jobid           BIGINT NOT NULL,
        message         VARCHAR(255) NOT NULL,
        funcid          INT NOT NULL DEFAULT 0
);

CREATE INDEX error_funcid_errortime ON error (funcid, error_time);
CREATE INDEX error_time ON error (error_time);
CREATE INDEX error_jobid ON error (jobid);

CREATE TABLE exitstatus (
        jobid           BIGINT PRIMARY KEY NOT NULL,
        funcid          INT NOT NULL DEFAULT 0,
        status          SMALLINT,
        completion_time INTEGER,
        delete_after    INTEGER
);

CREATE INDEX exitstatus_funcid ON exitstatus (funcid);
CREATE INDEX exitstatus_deleteafter ON exitstatus (delete_after);

-- Update schema version
UPDATE "System"
   SET value = '29'
 WHERE field = 'socialtext-schema-version';

COMMIT;
