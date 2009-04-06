BEGIN;

ALTER TABLE ONLY signal
    ADD COLUMN recipient_id bigint,
    ADD CONSTRAINT signal_recipient_fk
        FOREIGN KEY (recipient_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE;
CREATE INDEX ix_signal__recipient_id
    ON signal (recipient_id);

UPDATE "System"
   SET value = '49'
 WHERE field = 'socialtext-schema-version';

COMMIT;
