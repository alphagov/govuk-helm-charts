DELETE FROM events WHERE created_at < NOW() - INTERVAL '1 month';

UPDATE events SET payload = NULL
WHERE
  action = 'PutContent'
  AND content_id IN (
    SELECT documents.content_id
    FROM documents
    INNER JOIN editions ON (documents.id = editions.document_id)
    INNER JOIN access_limits ON (editions.id = access_limits.edition_id)
  );

DELETE FROM change_notes WHERE edition_id IN (
  SELECT edition_id
  FROM access_limits
);

DELETE FROM editions WHERE id IN (
  SELECT edition_id
  FROM access_limits
);

DELETE FROM access_limits;
