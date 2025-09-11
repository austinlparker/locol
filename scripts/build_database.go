package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

// Structures matching extract_configs.go
type ExtractedData struct {
	Version    string      `json:"version"`
	Components []Component `json:"components"`
}

type Component struct {
    Name        string       `json:"name"`
    Type        string       `json:"type"`
    Module      string       `json:"module"`
    Description string       `json:"description"`
    Config      ConfigSchema `json:"config"`
    Constraints []Constraint `json:"constraints"`
}

type ConfigSchema struct {
    StructName string        `json:"struct_name"`
    Fields     []ConfigField `json:"fields"`
    Defaults   []DefaultValue `json:"defaults"`
    Examples   []string      `json:"examples"`
}

type ConfigField struct {
	Name         string            `json:"name"`
	Type         string            `json:"type"`
	GoType       string            `json:"go_type"`
	MapStructure string            `json:"mapstructure"`
	Description  string            `json:"description"`
	Required     bool              `json:"required"`
	Validation   map[string]string `json:"validation,omitempty"`
}

type DefaultValue struct {
    FieldName string      `json:"field_name"`
    YamlKey   string      `json:"yaml_key"`
    Value     interface{} `json:"value"`
}

type Constraint struct {
    Kind    string   `json:"kind"`   // anyOf, oneOf, allOf, atMostOne
    Keys    []string `json:"keys"`   // YAML keys
    Message string   `json:"message,omitempty"`
}

// Debug logging (enabled when LOCOL_DEBUG=1)
var debug = os.Getenv("LOCOL_DEBUG") == "1"

func dbgf(format string, args ...interface{}) {
    if debug {
        fmt.Fprintf(os.Stderr, format, args...)
    }
}

var (
	input  = flag.String("input", "configs_*.json", "Input JSON file pattern")
	output = flag.String("output", "components.db", "Output SQLite database file")
)

func main() {
	flag.Parse()

	fmt.Println("Building component database...")

	// Find input files
	files, err := filepath.Glob(*input)
	if err != nil {
		panic(err)
	}

	if len(files) == 0 {
		fmt.Printf("No files found matching pattern: %s\n", *input)
		os.Exit(1)
	}

	// Remove existing database
	if _, err := os.Stat(*output); err == nil {
		os.Remove(*output)
	}

	// Create database
	db, err := sql.Open("sqlite3", *output)
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// Create schema
	if err := createSchema(db); err != nil {
		panic(err)
	}

	// Process each input file
	for _, file := range files {
		dbgf("Processing %s...\n", file)
		if err := processFile(db, file); err != nil {
			dbgf("Error processing %s: %v\n", file, err)
			continue
		}
	}

	// Create indexes
	if err := createIndexes(db); err != nil {
		panic(err)
	}

	fmt.Printf("Database created successfully: %s\n", *output)
	
	// Print summary
	printSummary(db)
}

func createSchema(db *sql.DB) error {
    schema := `
	-- Collector versions
	CREATE TABLE collector_versions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		version TEXT UNIQUE NOT NULL,
		is_contrib BOOLEAN DEFAULT FALSE,
		extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	-- Components
	CREATE TABLE components (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		type TEXT NOT NULL, -- receiver, processor, exporter, extension, connector
		module TEXT NOT NULL,
		description TEXT,
		struct_name TEXT,
		version_id INTEGER NOT NULL,
		FOREIGN KEY (version_id) REFERENCES collector_versions(id),
		UNIQUE(name, type, version_id)
	);

	-- Config fields
	CREATE TABLE config_fields (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		component_id INTEGER NOT NULL,
		field_name TEXT NOT NULL,
		yaml_key TEXT NOT NULL,
		field_type TEXT NOT NULL, -- Swift type
		go_type TEXT NOT NULL,    -- Original Go type
		description TEXT,
		required BOOLEAN DEFAULT FALSE,
		validation_json TEXT, -- JSON string of validation rules
		FOREIGN KEY (component_id) REFERENCES components(id)
	);

    -- Default values
    CREATE TABLE default_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        component_id INTEGER NOT NULL,
        field_name TEXT NOT NULL,
        yaml_key TEXT NOT NULL,
        default_value TEXT, -- JSON-encoded value
        FOREIGN KEY (component_id) REFERENCES components(id)
    );

    -- Config examples (for future use)
    CREATE TABLE config_examples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        component_id INTEGER NOT NULL,
        example_yaml TEXT NOT NULL,
        description TEXT,
        FOREIGN KEY (component_id) REFERENCES components(id)
    );

    -- Component-level validation constraints
    CREATE TABLE component_constraints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        component_id INTEGER NOT NULL,
        kind TEXT NOT NULL, -- anyOf, oneOf, allOf, atMostOne
        keys_json TEXT NOT NULL, -- JSON array of YAML keys
        message TEXT,
        FOREIGN KEY (component_id) REFERENCES components(id)
    );
    `

	_, err := db.Exec(schema)
	return err
}

func createIndexes(db *sql.DB) error {
    indexes := []string{
		"CREATE INDEX idx_version ON collector_versions(version);",
		"CREATE INDEX idx_component_version ON components(name, type, version_id);",
		"CREATE INDEX idx_component_type ON components(type);",
		"CREATE INDEX idx_field_component ON config_fields(component_id);",
		"CREATE INDEX idx_field_yaml_key ON config_fields(yaml_key);",
        "CREATE INDEX idx_default_component ON default_values(component_id);",
        "CREATE INDEX idx_constraint_component ON component_constraints(component_id);",
    }

	for _, idx := range indexes {
		if _, err := db.Exec(idx); err != nil {
			return err
		}
	}

	return nil
}

func processFile(db *sql.DB, filename string) error {
	// Read and parse JSON
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return err
	}

	var extracted ExtractedData
	if err := json.Unmarshal(data, &extracted); err != nil {
		return err
	}

	// Insert version
	versionID, err := insertVersion(db, extracted.Version)
	if err != nil {
		return err
	}

	// Insert components
	for _, component := range extracted.Components {
		if err := insertComponent(db, component, versionID); err != nil {
			fmt.Printf("Warning: failed to insert component %s: %v\n", component.Name, err)
			continue
		}
	}

	return nil
}

func insertVersion(db *sql.DB, version string) (int64, error) {
	// Check if version already exists
	var id int64
	err := db.QueryRow("SELECT id FROM collector_versions WHERE version = ?", version).Scan(&id)
	if err == nil {
		return id, nil // Version already exists
	}

	// Insert new version
	result, err := db.Exec("INSERT INTO collector_versions (version) VALUES (?)", version)
	if err != nil {
		return 0, err
	}

	return result.LastInsertId()
}

func insertComponent(db *sql.DB, component Component, versionID int64) error {
	// Insert component
	result, err := db.Exec(`
		INSERT OR REPLACE INTO components 
		(name, type, module, description, struct_name, version_id) 
		VALUES (?, ?, ?, ?, ?, ?)`,
		component.Name, component.Type, component.Module, 
		component.Description, component.Config.StructName, versionID)
	if err != nil {
		return err
	}

	componentID, err := result.LastInsertId()
	if err != nil {
		return err
	}

    // Insert config fields
    for _, field := range component.Config.Fields {
        if err := insertConfigField(db, field, componentID); err != nil {
            return err
        }
    }

    // Insert default values
    for _, def := range component.Config.Defaults {
        if err := insertDefaultValue(db, def, componentID); err != nil {
            return err
        }
    }

    // Insert component constraints
    for _, c := range component.Constraints {
        if err := insertConstraint(db, c, componentID); err != nil {
            return err
        }
    }

    return nil
}

func insertConfigField(db *sql.DB, field ConfigField, componentID int64) error {
	// Convert validation map to JSON
	validationJSON := ""
	if len(field.Validation) > 0 {
		data, err := json.Marshal(field.Validation)
		if err == nil {
			validationJSON = string(data)
		}
	}

	_, err := db.Exec(`
		INSERT INTO config_fields 
		(component_id, field_name, yaml_key, field_type, go_type, description, required, validation_json)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		componentID, field.Name, field.MapStructure, field.Type, field.GoType,
		field.Description, field.Required, validationJSON)

	return err
}

func insertDefaultValue(db *sql.DB, def DefaultValue, componentID int64) error {
    // Convert value to JSON string
    valueJSON, err := json.Marshal(def.Value)
    if err != nil {
        return err
    }

    // Prefer YAML key if present; fall back to field name
    yamlKey := def.YamlKey
    if yamlKey == "" {
        yamlKey = def.FieldName
    }

    _, err = db.Exec(`
        INSERT INTO default_values (component_id, field_name, yaml_key, default_value)
        VALUES (?, ?, ?, ?)`,
        componentID, def.FieldName, yamlKey, string(valueJSON))

    return err
}

func insertConstraint(db *sql.DB, c Constraint, componentID int64) error {
    keysJSONBytes, err := json.Marshal(c.Keys)
    if err != nil {
        return err
    }
    _, err = db.Exec(`
        INSERT INTO component_constraints (component_id, kind, keys_json, message)
        VALUES (?, ?, ?, ?)`,
        componentID, c.Kind, string(keysJSONBytes), c.Message)
    return err
}

func printSummary(db *sql.DB) error {
	fmt.Println("\n=== Database Summary ===")

	// Count versions
	var versionCount int
	db.QueryRow("SELECT COUNT(*) FROM collector_versions").Scan(&versionCount)
	fmt.Printf("Versions: %d\n", versionCount)

	// Count components by type
	rows, err := db.Query(`
		SELECT type, COUNT(*) as count
		FROM components 
		GROUP BY type 
		ORDER BY count DESC`)
	if err != nil {
		return err
	}
	defer rows.Close()

	fmt.Println("Components by type:")
	for rows.Next() {
		var componentType string
		var count int
		if err := rows.Scan(&componentType, &count); err != nil {
			continue
		}
		fmt.Printf("  %s: %d\n", componentType, count)
	}

	// Total fields
	var fieldCount int
	db.QueryRow("SELECT COUNT(*) FROM config_fields").Scan(&fieldCount)
	fmt.Printf("Total config fields: %d\n", fieldCount)

	// Total defaults
	var defaultCount int
	db.QueryRow("SELECT COUNT(*) FROM default_values").Scan(&defaultCount)
	fmt.Printf("Default values: %d\n", defaultCount)

	return nil
}
