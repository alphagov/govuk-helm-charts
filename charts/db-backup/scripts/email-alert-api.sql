-- email-alert-api.sql pseudonymises email addresses in the email-alert-api
-- database. The intent is to take the production dataset and automatically to
-- produce a dataset somewhat more suitable for loading into the integration
-- test environment.
--
-- It tries to preserve structure so that multiple occurences of the same
-- address are mapped to the same "anonymous" address.

-- TODO: generate sufficiently realistic synthetic test data and stop copying
-- production data outside of production altogether.

-- Drop all emails more than a day old.
ALTER TABLE emails RENAME TO old_emails;

CREATE TABLE emails (
  LIKE old_emails INCLUDING CONSTRAINTS INCLUDING DEFAULTS INCLUDING INDEXES
);

ALTER TABLE emails OWNER TO "email-alert-api";

INSERT INTO emails
SELECT * FROM old_emails  -- noqa: AM04
WHERE created_at < current_timestamp - interval '1 day';

DROP TABLE old_emails CASCADE;

-- Create a table to store all email addresses.
CREATE TEMP TABLE addresses (id serial, address varchar NOT NULL);

-- Copy all email addresses into the table.
INSERT INTO addresses (address)
SELECT address FROM subscribers WHERE address IS NOT NULL;

CREATE UNIQUE INDEX addresses_index ON addresses (address);

INSERT INTO addresses (address)
SELECT address FROM emails
ON CONFLICT DO NOTHING;

-- Redact address-containing fields in the subscribers and emails tables.
UPDATE subscribers s
SET address = concat('anon-', a.id, '@example.com')
FROM addresses AS a
WHERE a.address = s.address;

UPDATE emails e
SET
  address = concat('anon-', a.id, '@example.com'),
  subject = replace(e.subject, e.address, concat('anon-', a.id, '@example.com')),
  body = replace(e.body, e.address, concat('anon-', a.id, '@example.com'))
FROM addresses AS a
WHERE a.address = e.address;
