package main

import (
    "database/sql"
    "encoding/json"
    "flag"
    "fmt"
    "os"
    "path/filepath"
    "sort"
    "strings"
    _ "modernc.org/sqlite"
)

type DocumentSchema struct {
    Sections               []string `json:"sections"`
    Signals                []string `json:"signals"`
    ComponentIDPattern     string   `json:"component_id_pattern"`
    SupportsInstanceSuffix bool     `json:"supports_instance_suffix"`
    PipelineShape          struct {
        Receivers  bool `json:"receivers"`
        Processors bool `json:"processors"`
        Exporters  bool `json:"exporters"`
        Connectors bool `json:"connectors"`
    } `json:"pipeline_shape"`
    Telemetry struct {
        MetricsLevels []string `json:"metrics_levels"`
        DefaultLevel  string   `json:"default_level"`
    } `json:"telemetry"`
}

type Extracted struct {
    Version    string         `json:"version"`
    Components []Component    `json:"components"`
    Document   DocumentSchema `json:"document"`
}

type Component struct {
    Name        string       `json:"name"`
    Type        string       `json:"type"`
    Description string       `json:"description"`
    Config      ConfigSchema `json:"config"`
    Constraints []Constraint `json:"constraints"`
}

type ConfigSchema struct {
    Fields   []Field  `json:"fields"`
    Examples []string `json:"examples"`
}

type Field struct {
    Name        string            `json:"name"`
    Type        string            `json:"type"`
    Required    bool              `json:"required"`
    Default     any               `json:"default"`
    Description string            `json:"description"`
    PathTokens  []string          `json:"path_tokens"`
    EnumValues  []string          `json:"enum_values"`
    Format      string            `json:"format"`
    Unit        string            `json:"unit"`
    Sensitive   bool              `json:"sensitive"`
    ItemType    string            `json:"item_type"`
    RefKind     string            `json:"ref_kind"`
    RefScope    string            `json:"ref_scope"`
    Validation  map[string]string `json:"validation"`
}

type Constraint struct {
    Kind      string     `json:"kind"`
    KeyTokens [][]string `json:"keys"`
    Message   string     `json:"message"`
}

var (
    flagInput  = flag.String("input", "", "Input JSON file glob (e.g., satellite/Resources/configs_*.json)")
    flagOutput = flag.String("output", "satellite/Resources/config.sqlite", "Output SQLite file path")
)

func main() {
    flag.Parse()
    if *flagInput == "" {
        fatalf("--input is required")
    }
    files, err := expandGlob(*flagInput)
    if err != nil || len(files) == 0 {
        fatalf("no input JSON files match %q", *flagInput)
    }
    // Pick the latest file by modification time
    latest := pickLatest(files)
    data, err := os.ReadFile(latest)
    if err != nil { fatalf("read %s: %v", latest, err) }
    var doc Extracted
    if err := json.Unmarshal(data, &doc); err != nil {
        fatalf("parse %s: %v", latest, err)
    }

    // (Re)create DB
    if err := os.RemoveAll(*flagOutput); err != nil {
        fatalf("remove existing db: %v", err)
    }
    db, err := sql.Open("sqlite", *flagOutput)
    if err != nil { fatalf("open sqlite: %v", err) }
    defer db.Close()
    if _, err := db.Exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;`); err != nil {
        fatalf("pragma: %v", err)
    }
    if err := createSchema(db); err != nil { fatalf("schema: %v", err) }
    if err := loadDocument(db, &doc); err != nil { fatalf("load: %v", err) }
    fmt.Printf("Built %s from %s (%d components)\n", *flagOutput, filepath.Base(latest), len(doc.Components))
}

func expandGlob(pattern string) ([]string, error) {
    // Support simple globbing and literal files
    if strings.ContainsAny(pattern, "*?[]") {
        return filepath.Glob(pattern)
    }
    // Non-glob; check existence
    if _, err := os.Stat(pattern); err != nil { return nil, err }
    return []string{pattern}, nil
}

func pickLatest(files []string) string {
    type fi struct{ path string; mod int64 }
    list := make([]fi, 0, len(files))
    for _, p := range files {
        st, err := os.Stat(p)
        if err != nil { continue }
        list = append(list, fi{p, st.ModTime().UnixNano()})
    }
    if len(list) == 0 { return files[0] }
    sort.Slice(list, func(i, j int) bool { return list[i].mod > list[j].mod })
    return list[0].path
}

func createSchema(db *sql.DB) error {
    stmts := []string{
        `CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);`,
        `CREATE TABLE document (
            id INTEGER PRIMARY KEY CHECK (id=1),
            sections_json TEXT NOT NULL,
            signals_json TEXT NOT NULL,
            pipeline_shape_json TEXT NOT NULL,
            telemetry_levels_json TEXT NOT NULL,
            default_level TEXT NOT NULL
        );`,
        `CREATE TABLE components (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            description TEXT,
            version TEXT NOT NULL
        );`,
        `CREATE INDEX idx_components_type_name ON components(type,name);`,
        `CREATE TABLE fields (
            id INTEGER PRIMARY KEY,
            component_id INTEGER NOT NULL REFERENCES components(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            required INTEGER NOT NULL,
            default_json TEXT,
            description TEXT,
            format TEXT,
            unit TEXT,
            sensitive INTEGER NOT NULL,
            item_type TEXT,
            ref_kind TEXT,
            ref_scope TEXT,
            validation_json TEXT
        );`,
        `CREATE INDEX idx_fields_component ON fields(component_id);`,
        `CREATE TABLE field_paths (
            field_id INTEGER NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
            idx INTEGER NOT NULL,
            token TEXT NOT NULL
        );`,
        `CREATE INDEX idx_field_paths_field ON field_paths(field_id, idx);`,
        `CREATE TABLE field_enums (
            field_id INTEGER NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
            value TEXT NOT NULL
        );`,
        `CREATE INDEX idx_field_enums_field ON field_enums(field_id, value);`,
        `CREATE TABLE constraints (
            id INTEGER PRIMARY KEY,
            component_id INTEGER NOT NULL REFERENCES components(id) ON DELETE CASCADE,
            kind TEXT NOT NULL,
            keys_json TEXT NOT NULL,
            message TEXT
        );`,
        `CREATE INDEX idx_constraints_component ON constraints(component_id);`,
        `CREATE TABLE examples (
            id INTEGER PRIMARY KEY,
            component_id INTEGER NOT NULL REFERENCES components(id) ON DELETE CASCADE,
            yaml TEXT NOT NULL
        );`,
    }
    for _, s := range stmts {
        if _, err := db.Exec(s); err != nil { return err }
    }
    return nil
}

func loadDocument(db *sql.DB, d *Extracted) error {
    // meta
    if _, err := db.Exec(`INSERT INTO meta(key,value) VALUES
        ('collector_version', ?),
        ('schema_version', ?)
    ;`, d.Version, "1"); err != nil { return err }

    // document
    sec, _ := json.Marshal(d.Document.Sections)
    sig, _ := json.Marshal(d.Document.Signals)
    pipe := map[string]bool{
        "receivers": d.Document.PipelineShape.Receivers,
        "processors": d.Document.PipelineShape.Processors,
        "exporters": d.Document.PipelineShape.Exporters,
        "connectors": d.Document.PipelineShape.Connectors,
    }
    pipeJSON, _ := json.Marshal(pipe)
    levelsJSON, _ := json.Marshal(d.Document.Telemetry.MetricsLevels)
    if _, err := db.Exec(`INSERT INTO document(id,sections_json,signals_json,pipeline_shape_json,telemetry_levels_json,default_level)
        VALUES(1,?,?,?,?,?)`, string(sec), string(sig), string(pipeJSON), string(levelsJSON), d.Document.Telemetry.DefaultLevel); err != nil {
        return err
    }

    // components and related
    // Use simple integer counters for ids
    nextComponentID := 1
    nextFieldID := 1
    nextConstraintID := 1

    compStmt, err := db.Prepare(`INSERT INTO components(id,name,type,description,version) VALUES(?,?,?,?,?)`)
    if err != nil { return err }
    defer compStmt.Close()

    fieldStmt, err := db.Prepare(`INSERT INTO fields(id,component_id,name,kind,required,default_json,description,format,unit,sensitive,item_type,ref_kind,ref_scope,validation_json)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)`)
    if err != nil { return err }
    defer fieldStmt.Close()

    pathStmt, err := db.Prepare(`INSERT INTO field_paths(field_id,idx,token) VALUES(?,?,?)`)
    if err != nil { return err }
    defer pathStmt.Close()

    enumStmt, err := db.Prepare(`INSERT INTO field_enums(field_id,value) VALUES(?,?)`)
    if err != nil { return err }
    defer enumStmt.Close()

    consStmt, err := db.Prepare(`INSERT INTO constraints(id,component_id,kind,keys_json,message) VALUES(?,?,?,?,?)`)
    if err != nil { return err }
    defer consStmt.Close()

    exStmt, err := db.Prepare(`INSERT INTO examples(id,component_id,yaml) VALUES(?,?,?)`)
    if err != nil { return err }
    defer exStmt.Close()

    tx, err := db.Begin()
    if err != nil { return err }
    defer func() { _ = tx.Rollback() }()

    for _, c := range d.Components {
        if _, err := tx.Stmt(compStmt).Exec(nextComponentID, c.Name, c.Type, nullIfEmpty(c.Description), d.Version); err != nil {
            return err
        }
        // Fields
        for _, f := range c.Config.Fields {
            defJSON := mustJSON(f.Default)
            valJSON := mustJSON(f.Validation)
            sens := 0
            if f.Sensitive { sens = 1 }
            if _, err := tx.Stmt(fieldStmt).Exec(nextFieldID, nextComponentID, f.Name, f.Type, btoi(f.Required), defJSON, nullIfEmpty(f.Description), nullIfEmpty(f.Format), nullIfEmpty(f.Unit), sens, nullIfEmpty(f.ItemType), nullIfEmpty(f.RefKind), nullIfEmpty(f.RefScope), valJSON); err != nil {
                return err
            }
            for i, t := range f.PathTokens {
                if _, err := tx.Stmt(pathStmt).Exec(nextFieldID, i, t); err != nil { return err }
            }
            for _, ev := range f.EnumValues {
                if _, err := tx.Stmt(enumStmt).Exec(nextFieldID, ev); err != nil { return err }
            }
            nextFieldID++
        }
        // Constraints
        for _, cs := range c.Constraints {
            keysJSON := mustJSON(cs.KeyTokens)
            if _, err := tx.Stmt(consStmt).Exec(nextConstraintID, nextComponentID, cs.Kind, keysJSON, nullIfEmpty(cs.Message)); err != nil { return err }
            nextConstraintID++
        }
        // Examples
        for _, ex := range c.Config.Examples {
            if strings.TrimSpace(ex) == "" { continue }
            if _, err := tx.Stmt(exStmt).Exec(nil, nextComponentID, ex); err != nil { return err }
        }
        nextComponentID++
    }

    if err := tx.Commit(); err != nil { return err }
    return nil
}

func mustJSON(v any) string {
    if v == nil { return "" }
    // Avoid encoding empty maps/slices as "null"; prefer empty literal
    switch t := v.(type) {
    case map[string]string:
        if len(t) == 0 { return "{}" }
    }
    b, err := json.Marshal(v)
    if err != nil { return "" }
    return string(b)
}

func btoi(b bool) int { if b { return 1 }; return 0 }

func nullIfEmpty(s string) any { if strings.TrimSpace(s) == "" { return nil }; return s }

func fatalf(format string, args ...any) {
    _, _ = fmt.Fprintf(os.Stderr, format+"\n", args...)
    os.Exit(1)
}
