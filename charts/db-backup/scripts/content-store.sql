-- sqlfluff:dialect:mysql

-- Occasionally, Content Store and Publishing API can fall out of
-- sync in non-production environments after the environment sync
-- process has completed. Content Store can be a day 'ahead' of
-- Publishing API.
--
-- Consequently, any publish events from Publishing API in the
-- affected environment will be rejected by Content Store, if the
-- `Event.maximum_id` in Publishing API is behind the
-- `payload_version` of the `ContentItem` being updated in Content
-- Store.
--
-- The pragmatic fix is to reset the `payload_version` in Content
-- Store so that it can never be ahead of Publishing API.
UPDATE content_items
SET payload_version = 0;
