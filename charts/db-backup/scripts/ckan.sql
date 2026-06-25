-- ckan.sql
-- Anonymises PII in the CKAN integration database.
-- Masks rather than deletes rows so relational structure is preserved.
-- Runs as part of the db-backup transform step after restore from staging.
--
-- Tables covered:
--   user          (name, fullname, email, apikey)
--   package       (author, author_email, maintainer, maintainer_email)
--   package_extra (value for PII-bearing keys)

-- ---------------------------------------------------------------------------
-- user
-- ---------------------------------------------------------------------------
-- email:    user_{id}@example.com  — unique per user, traceable via UUID
-- name:     user_{id}              — replaces username slug (often email-derived)
-- fullname: repeat '*' to match original length
-- apikey:   repeat '*' to match original length
--
-- Excludes active sysadmin accounts with a @dsit.gov.uk email — these are
-- real admin accounts that must remain functional after restore.

UPDATE public.user
SET
  name = 'user_' || id,
  fullname = CASE
    WHEN fullname IS NOT NULL THEN repeat('*', length(fullname))
  END,
  email = 'user_' || id || '@example.com',
  apikey = CASE
    WHEN apikey IS NOT NULL THEN repeat('*', length(apikey))
  END
WHERE NOT (sysadmin = TRUE AND state = 'active' AND email ILIKE '%@dsit.gov.uk');

-- ---------------------------------------------------------------------------
-- package
-- ---------------------------------------------------------------------------
-- author/maintainer names:  repeat '*' to match original length
-- author/maintainer emails: fixed masked value (not user-account emails,
--                           so UUID tracing is not needed)

UPDATE public.package
SET
  author = CASE
    WHEN author IS NOT NULL THEN repeat('*', greatest(length(author), 1))
  END,
  author_email = CASE
    WHEN author_email IS NOT NULL THEN 'masked@example.com'
  END,
  maintainer = CASE
    WHEN maintainer IS NOT NULL THEN repeat('*', greatest(length(maintainer), 1))
  END,
  maintainer_email = CASE
    WHEN maintainer_email IS NOT NULL THEN 'masked@example.com'
  END;

-- ---------------------------------------------------------------------------
-- package_extra
-- ---------------------------------------------------------------------------
-- Mask values for all keys that may contain contact or personal data.
-- Email keys  → fixed masked email address
-- Name keys   → repeat '*' to match original length
-- Phone keys  → '***'

UPDATE public.package_extra
SET value = 'masked@example.com'
WHERE key IN (
  'dcat_publisher_email',
  'contact-email',
  'email_notify_maintainer',
  'email_notify_author',
  'contact_email',
  'publisher_email',
  'foi-email'
);

UPDATE public.package_extra
SET
  value = CASE
    WHEN value IS NOT NULL THEN repeat('*', greatest(length(value), 1))
  END
WHERE key IN (
  'publisher_name',
  'license_name',
  'dcat_publisher_name',
  'contact-name',
  'foi-name'
);

UPDATE public.package_extra
SET value = '***'
WHERE key IN (
  'contact-phone',
  'foi-phone'
);
