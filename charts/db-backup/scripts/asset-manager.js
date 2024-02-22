disableTelemetry();
db.assets.updateMany(
  {
    access_limited: { $exists: true, $nin: [[], false] },
    legacy_url_path: { $exists: true }
  },
  {
    $set: { legacy_url_path: "/redacted.pdf" }
  }
);
