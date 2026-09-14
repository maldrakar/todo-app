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
}
