// Sources/TodoCore/Storage/Schema.swift

enum Schema {
    static let version1 = """
    CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value
    ) WITHOUT ROWID;

    CREATE TABLE tasks (
        rid INTEGER PRIMARY KEY,
        id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL DEFAULT '',
        status INTEGER NOT NULL DEFAULT 0,
        when_day INTEGER,
        deadline_day INTEGER,
        parent TEXT,
        rank TEXT NOT NULL DEFAULT 'i',
        trashed INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        notes TEXT NOT NULL DEFAULT ''
    );
    CREATE INDEX tasks_status ON tasks(status);
    CREATE INDEX tasks_when ON tasks(when_day);
    CREATE INDEX tasks_deadline ON tasks(deadline_day);
    CREATE INDEX tasks_parent ON tasks(parent, rank);

    CREATE TABLE tags (
        rid INTEGER PRIMARY KEY,
        id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL DEFAULT '',
        parent TEXT,
        rank TEXT NOT NULL DEFAULT 'i',
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE task_tags (
        task_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        present INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (task_id, tag_id)
    ) WITHOUT ROWID;
    CREATE INDEX task_tags_tag ON task_tags(tag_id, task_id) WHERE present = 1;

    CREATE TABLE views (
        rid INTEGER PRIMARY KEY,
        id TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL DEFAULT '',
        parent TEXT,
        rank TEXT NOT NULL DEFAULT 'i',
        filter TEXT,
        sort TEXT NOT NULL DEFAULT '[]',
        group_by TEXT,
        deleted INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE view_items (
        view_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        present INTEGER NOT NULL DEFAULT 1,
        rank TEXT NOT NULL DEFAULT 'i',
        PRIMARY KEY (view_id, task_id)
    ) WITHOUT ROWID;

    CREATE TABLE ops (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        field TEXT NOT NULL,
        value,
        clock INTEGER NOT NULL,
        device TEXT NOT NULL,
        applied INTEGER NOT NULL DEFAULT 1
    );
    CREATE INDEX ops_clock ON ops(clock, device);
    CREATE UNIQUE INDEX ops_identity ON ops(device, clock, entity, entity_id, field);
    CREATE INDEX ops_unapplied ON ops(applied) WHERE applied = 0;

    CREATE TABLE field_clocks (
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        field TEXT NOT NULL,
        clock INTEGER NOT NULL,
        device TEXT NOT NULL,
        PRIMARY KEY (entity, entity_id, field)
    ) WITHOUT ROWID;

    CREATE TABLE task_tree (
        id TEXT PRIMARY KEY,
        parent TEXT,
        trashed INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID;
    CREATE INDEX task_tree_parent ON task_tree(parent);

    CREATE VIRTUAL TABLE tasks_title_fts USING fts5(title, content='tasks', content_rowid='rid', tokenize='trigram remove_diacritics 1');
    CREATE VIRTUAL TABLE tasks_notes_fts USING fts5(notes, content='tasks', content_rowid='rid', tokenize='unicode61 remove_diacritics 2', prefix='2 3');
    CREATE VIRTUAL TABLE tags_title_fts USING fts5(title, content='tags', content_rowid='rid', tokenize='trigram remove_diacritics 1');
    CREATE VIRTUAL TABLE views_title_fts USING fts5(title, content='views', content_rowid='rid', tokenize='trigram remove_diacritics 1');

    CREATE TRIGGER tasks_ai AFTER INSERT ON tasks BEGIN
        INSERT INTO tasks_title_fts(rowid, title) VALUES (new.rid, new.title);
        INSERT INTO tasks_notes_fts(rowid, notes) VALUES (new.rid, new.notes);
    END;
    CREATE TRIGGER tasks_ad AFTER DELETE ON tasks BEGIN
        INSERT INTO tasks_title_fts(tasks_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO tasks_notes_fts(tasks_notes_fts, rowid, notes) VALUES ('delete', old.rid, old.notes);
    END;
    CREATE TRIGGER tasks_au AFTER UPDATE OF title, notes ON tasks BEGIN
        INSERT INTO tasks_title_fts(tasks_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO tasks_title_fts(rowid, title) VALUES (new.rid, new.title);
        INSERT INTO tasks_notes_fts(tasks_notes_fts, rowid, notes) VALUES ('delete', old.rid, old.notes);
        INSERT INTO tasks_notes_fts(rowid, notes) VALUES (new.rid, new.notes);
    END;

    CREATE TRIGGER tags_ai AFTER INSERT ON tags BEGIN
        INSERT INTO tags_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;
    CREATE TRIGGER tags_ad AFTER DELETE ON tags BEGIN
        INSERT INTO tags_title_fts(tags_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
    END;
    CREATE TRIGGER tags_au AFTER UPDATE OF title ON tags BEGIN
        INSERT INTO tags_title_fts(tags_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO tags_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;

    CREATE TRIGGER views_ai AFTER INSERT ON views BEGIN
        INSERT INTO views_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;
    CREATE TRIGGER views_ad AFTER DELETE ON views BEGIN
        INSERT INTO views_title_fts(views_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
    END;
    CREATE TRIGGER views_au AFTER UPDATE OF title ON views BEGIN
        INSERT INTO views_title_fts(views_title_fts, rowid, title) VALUES ('delete', old.rid, old.title);
        INSERT INTO views_title_fts(rowid, title) VALUES (new.rid, new.title);
    END;
    """

    /// The Trash view selects on inherited trash, which lives only in `task_tree`, and version 1 indexed
    /// that table by parent alone: the query walked every task in the database to find the few in the trash.
    ///
    /// Partial, and that is the whole point. Every other view carries the implicit `tt.trashed = 0` that
    /// `FilterCompiler.whereClause` appends, and an index over the whole column is usable by it — so the
    /// planner drives their join from the rows that are *not* trashed, which is nearly all of them, instead
    /// of from the condition the view is about. Measured in a release build at 50,000 tasks, 2,000 of them
    /// done: a plain index cost the Logbook 1.8 ms against 15.8 ms, an 8.9x loss, to buy Trash 0.6 ms. An
    /// index restricted to the trashed rows cannot be used by `= 0` at all, so it buys Trash without
    /// touching anyone else: Trash 0.64 ms to 0.066 ms, Logbook unchanged at 1.81 ms.
    ///
    /// It only works because `FilterCompiler` writes the flag as a literal: SQLite can see that `= 1`
    /// implies this index's `WHERE trashed = 1`, and cannot prove it of a bound parameter. The two belong
    /// together — the literal without this index makes Trash scan `tasks` instead, at 7.2 ms.
    ///
    /// What reaches it is a plain positive `tt.trashed = 1`, which is the Trash view and an `and` built on
    /// it. The proof SQLite does is syntactic, so it does not see through `NOT COALESCE((tt.trashed = 0), 0)`
    /// or through an `or`: a view a person edits into "cancelled or thrown away" scans instead, as it did
    /// before this index existed. If that shape turns out to matter, the remedy is the spec's, a composite
    /// index for it, and not widening this one.
    static let version2 = """
    CREATE INDEX task_tree_trashed ON task_tree(trashed) WHERE trashed = 1;
    """

    /// SQLite folds what its own table covers, which is the Latin ranges, and `ё` (U+0451) is not in it:
    /// neither `trigram` nor `unicode61` maps it to `е`, so a person who typed `отчет` did not find
    /// `Квартальный отчёт` (#47). To a reader of Russian the two are not a letter and an accented one, they
    /// are one letter written two ways, and the way a person types is rarely the way the title was saved.
    ///
    /// So the fold is ours and it happens on the way into the index. Every indexed column gains a generated
    /// copy with the pair collapsed, and the four indexes are built over the copies. The rule is written once,
    /// in the column definitions below, and `Store.folded` repeats it for the query text; the test
    /// `theFoldOfTheQueryIsTheFoldOfTheSchema` holds the two to each other, including the one case where a
    /// fold in Swift would go further than `replace` does — an `е` that carries a combining diaeresis is a
    /// different string to SQLite and the same string to Swift, and it stays as it is.
    ///
    /// The copies are `VIRTUAL`: they cost nothing on disk, they are computed when the index reads them, and
    /// `PRAGMA table_info` does not list them, so the journal's field map, which is built by walking it,
    /// neither writes them nor has to learn about them. They are not hidden, though — `PRAGMA table_xinfo`
    /// names them and `SELECT *` returns them — so a read that wants the columns a person wrote names those
    /// columns instead of taking what a star hands it. What is stored is the index, which was stored before.
    ///
    /// Two other ways were measured against this one and rejected. A tokenizer of our own, registered through
    /// the fts5 API, would fold inside the index and leave the columns alone — but it is C in a core that is
    /// Swift (ADR-0001), and it makes the file unusable without it: these triggers run on every write, so a
    /// database whose tokenizer is not registered refuses an ordinary `INSERT INTO tasks`. Indexing folded
    /// text while telling fts5 that the content is the original needs no new column at all, and it is a trap
    /// for whoever comes next: `'rebuild'` silently replaces the folded index with an unfolded one, and
    /// `'integrity-check'` answers `fts5: checksum mismatch`.
    ///
    /// The index reads the copy, so `snippet()` answers in folded text as well. `searchNotes` does not show
    /// that answer: it cuts the same window out of the original notes, which is what the person wrote.
    ///
    /// Upgrading an existing file is a reindex and not only an added column, so it is paid once and in full:
    /// measured against the vendored SQLite with the flags `Package.swift` builds it with, 50,000 tasks whose
    /// titles and notes are Russian text of about 150 characters take 0.368 s here, against 1.704 s to insert
    /// them in the first place. It runs inside the single transaction `Migrations.run` gives a step, so a
    /// device that opens an old database waits that once and every open after it costs nothing.
    static let version3 = """
    ALTER TABLE tasks ADD COLUMN title_fold TEXT GENERATED ALWAYS AS (replace(replace(title, 'ё', 'е'), 'Ё', 'Е')) VIRTUAL;
    ALTER TABLE tasks ADD COLUMN notes_fold TEXT GENERATED ALWAYS AS (replace(replace(notes, 'ё', 'е'), 'Ё', 'Е')) VIRTUAL;
    ALTER TABLE tags ADD COLUMN title_fold TEXT GENERATED ALWAYS AS (replace(replace(title, 'ё', 'е'), 'Ё', 'Е')) VIRTUAL;
    ALTER TABLE views ADD COLUMN title_fold TEXT GENERATED ALWAYS AS (replace(replace(title, 'ё', 'е'), 'Ё', 'Е')) VIRTUAL;

    DROP TRIGGER tasks_ai;
    DROP TRIGGER tasks_ad;
    DROP TRIGGER tasks_au;
    DROP TRIGGER tags_ai;
    DROP TRIGGER tags_ad;
    DROP TRIGGER tags_au;
    DROP TRIGGER views_ai;
    DROP TRIGGER views_ad;
    DROP TRIGGER views_au;

    DROP TABLE tasks_title_fts;
    DROP TABLE tasks_notes_fts;
    DROP TABLE tags_title_fts;
    DROP TABLE views_title_fts;

    CREATE VIRTUAL TABLE tasks_title_fts USING fts5(title_fold, content='tasks', content_rowid='rid', tokenize='trigram remove_diacritics 1');
    CREATE VIRTUAL TABLE tasks_notes_fts USING fts5(notes_fold, content='tasks', content_rowid='rid', tokenize='unicode61 remove_diacritics 2', prefix='2 3');
    CREATE VIRTUAL TABLE tags_title_fts USING fts5(title_fold, content='tags', content_rowid='rid', tokenize='trigram remove_diacritics 1');
    CREATE VIRTUAL TABLE views_title_fts USING fts5(title_fold, content='views', content_rowid='rid', tokenize='trigram remove_diacritics 1');

    INSERT INTO tasks_title_fts(tasks_title_fts) VALUES('rebuild');
    INSERT INTO tasks_notes_fts(tasks_notes_fts) VALUES('rebuild');
    INSERT INTO tags_title_fts(tags_title_fts) VALUES('rebuild');
    INSERT INTO views_title_fts(views_title_fts) VALUES('rebuild');

    CREATE TRIGGER tasks_ai AFTER INSERT ON tasks BEGIN
        INSERT INTO tasks_title_fts(rowid, title_fold) VALUES (new.rid, new.title_fold);
        INSERT INTO tasks_notes_fts(rowid, notes_fold) VALUES (new.rid, new.notes_fold);
    END;
    CREATE TRIGGER tasks_ad AFTER DELETE ON tasks BEGIN
        INSERT INTO tasks_title_fts(tasks_title_fts, rowid, title_fold) VALUES ('delete', old.rid, old.title_fold);
        INSERT INTO tasks_notes_fts(tasks_notes_fts, rowid, notes_fold) VALUES ('delete', old.rid, old.notes_fold);
    END;
    CREATE TRIGGER tasks_au AFTER UPDATE OF title, notes ON tasks BEGIN
        INSERT INTO tasks_title_fts(tasks_title_fts, rowid, title_fold) VALUES ('delete', old.rid, old.title_fold);
        INSERT INTO tasks_title_fts(rowid, title_fold) VALUES (new.rid, new.title_fold);
        INSERT INTO tasks_notes_fts(tasks_notes_fts, rowid, notes_fold) VALUES ('delete', old.rid, old.notes_fold);
        INSERT INTO tasks_notes_fts(rowid, notes_fold) VALUES (new.rid, new.notes_fold);
    END;

    CREATE TRIGGER tags_ai AFTER INSERT ON tags BEGIN
        INSERT INTO tags_title_fts(rowid, title_fold) VALUES (new.rid, new.title_fold);
    END;
    CREATE TRIGGER tags_ad AFTER DELETE ON tags BEGIN
        INSERT INTO tags_title_fts(tags_title_fts, rowid, title_fold) VALUES ('delete', old.rid, old.title_fold);
    END;
    CREATE TRIGGER tags_au AFTER UPDATE OF title ON tags BEGIN
        INSERT INTO tags_title_fts(tags_title_fts, rowid, title_fold) VALUES ('delete', old.rid, old.title_fold);
        INSERT INTO tags_title_fts(rowid, title_fold) VALUES (new.rid, new.title_fold);
    END;

    CREATE TRIGGER views_ai AFTER INSERT ON views BEGIN
        INSERT INTO views_title_fts(rowid, title_fold) VALUES (new.rid, new.title_fold);
    END;
    CREATE TRIGGER views_ad AFTER DELETE ON views BEGIN
        INSERT INTO views_title_fts(views_title_fts, rowid, title_fold) VALUES ('delete', old.rid, old.title_fold);
    END;
    CREATE TRIGGER views_au AFTER UPDATE OF title ON views BEGIN
        INSERT INTO views_title_fts(views_title_fts, rowid, title_fold) VALUES ('delete', old.rid, old.title_fold);
        INSERT INTO views_title_fts(rowid, title_fold) VALUES (new.rid, new.title_fold);
    END;
    """

    /// The device ids this database has written under, which is not the set of devices it has heard from: it
    /// is what a push answers "is this row mine to send" with. One row for a database that never left its
    /// machine, and one more after every restore, because the copy opens under an identity of its own (#51)
    /// while the operations its predecessor never managed to push are still in the journal under the old id.
    /// A push filtered by the current id alone would strand those edits on the copy forever and in silence.
    ///
    /// The `device_id` row that held the one identity moves in here and is then gone: the id comes from the
    /// platform at every open (ADR-0005), so a row in the database that still looks like the answer is a
    /// trap for whoever reads it next. It moves only if it is text, the rule the clock's seed scan follows
    /// for the same reason: `meta` declares no type for its value, and a null there would fail the NOT NULL
    /// of a primary key and take this step with it — on this open and, since a step that failed is a step
    /// still to run, on every open after it.
    static let version4 = """
    CREATE TABLE own_devices (
        id TEXT PRIMARY KEY
    ) WITHOUT ROWID;

    INSERT INTO own_devices (id) SELECT value FROM meta WHERE key = 'device_id' AND typeof(value) = 'text';
    DELETE FROM meta WHERE key = 'device_id';
    """

    /// A view's kind, colour and icon, and the device's own state (spec sections 2 and 5; ADR-0004, amendment
    /// of 2026-10-25; ADR-0010).
    ///
    /// The three columns are nullable text with no default, because every row already in the table was
    /// written before them and has to read as a plain list with no tile, which is what an empty column says;
    /// a default would put a value on those rows that no operation in the journal carries. They are known
    /// journal fields from this version on, so an operation a newer device sent for one of them, journaled
    /// and left unapplied by the version before, reaches the state at this open through the replay.
    ///
    /// `device_state` is outside the journal: no operation names it and nothing in it leaves the device. A
    /// value is NOT NULL because a key with no value is a row deleted, which is what writing none does.
    static let version5 = """
    ALTER TABLE views ADD COLUMN kind TEXT;
    ALTER TABLE views ADD COLUMN color TEXT;
    ALTER TABLE views ADD COLUMN icon TEXT;

    CREATE TABLE device_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    ) WITHOUT ROWID;
    """
}
