-- Sync durumu: JSON durum dosyasının yerini alır. Yayın verisi dosyalarda kalır.
CREATE TABLE sync_city_year (
    city_id         INTEGER NOT NULL,
    year            INTEGER NOT NULL,
    last_fetched_at TEXT    NOT NULL DEFAULT '',
    horizon         TEXT    NOT NULL DEFAULT '',
    complete        INTEGER NOT NULL DEFAULT 0,
    days            INTEGER NOT NULL DEFAULT 0,
    note            TEXT    NOT NULL DEFAULT '',
    PRIMARY KEY (city_id, year)
);

CREATE TABLE sync_places (
    id                INTEGER PRIMARY KEY CHECK (id = 1),
    updated_at        TEXT    NOT NULL DEFAULT '',
    countries         INTEGER NOT NULL DEFAULT 0,
    cities            INTEGER NOT NULL DEFAULT 0,
    enabled_countries TEXT    NOT NULL DEFAULT ''
);

CREATE TABLE sync_religious_days (
    year       INTEGER PRIMARY KEY,
    updated_at TEXT NOT NULL
);

CREATE TABLE sync_daily_content (
    id         INTEGER PRIMARY KEY CHECK (id = 1),
    updated_at TEXT    NOT NULL DEFAULT '',
    days       INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE sync_counters (
    name  TEXT PRIMARY KEY,
    value INTEGER NOT NULL DEFAULT 0
);
