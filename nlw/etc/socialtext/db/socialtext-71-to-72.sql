BEGIN;

-- Create a table to store data in the caching json proxy
CREATE TABLE json_proxy_cache (
    expires timestamptz NOT NULL,
    url TEXT NOT NULL,
    headers TEXT NOT NULL DEFAULT '',
    authz TEXT, -- not implemented
    content TEXT
);

CREATE INDEX json_proxy_cache_idx 
        ON json_proxy_cache (url, headers);

UPDATE "System"
   SET value = '72'
 WHERE field = 'socialtext-schema-version';

COMMIT;
