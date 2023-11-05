-- This is supposed to be identical to
-- https://github.com/alphagov/email-alert-api/blob/main/lib/data_hygiene/anonymise_email_addresses.sql
-- TODO: Fix the CI in alphagov/email-alert-api to pull in this script
-- (perhaps via git submodule) instead of running tests against its own copy.
-- TODO: Simplify this script.

-- This SQL file anonymises email addresses in the email-alert-api database.
--
-- It tries to preserve structure so that multiple occurences of the same address
-- are mapped to the same anonymous address.

-- Delete all emails that are older than 1 day old.
DELETE FROM emails
WHERE created_at < current_timestamp - interval '1 day';

-- Create a table to store all email addresses.
CREATE TABLE addresses (id serial, address varchar NOT NULL);

-- Copy all email addresses into the table.
-- Ignore nulled out subscriber addresses.
INSERT INTO addresses (address)
SELECT address FROM subscribers WHERE address IS NOT NULL
UNION DISTINCT
SELECT address FROM emails;

-- Index the table so we can efficiently lookup addresses.
CREATE UNIQUE INDEX addresses_index ON addresses (address);

-- Set subscribers.address from the auto-incremented id in addresses table.
UPDATE subscribers s
SET address = concat('anonymous-', a.id, '@example.com')
FROM addresses AS a
WHERE a.address = s.address;

-- Set emails.address from the auto-incremented id in addresses table.
UPDATE emails e
SET
  address = concat('anonymous-', a.id, '@example.com'),
  subject = replace(e.subject, e.address, concat('anonymous-', a.id, '@example.com')),
  body = replace(e.body, e.address, concat('anonymous-', a.id, '@example.com'))
FROM addresses AS a
WHERE a.address = e.address;

-- Clean up by deleting the addresses table and its index.
DROP INDEX addresses_index;
DROP TABLE addresses;
