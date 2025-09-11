//go:build integration

package main

import (
    "errors"
    "io/fs"
    "os"
    "path/filepath"
    "strings"
    "testing"

    yaml "gopkg.in/yaml.v3"
)

// Integration test: verifies that for a selection of components, the keys used in
// their testdata YAML files are covered by the extracted schema (either as exact
// leaves or via a map-type parent path).
//
// Requirements:
// - Local checkouts of the collector repositories.
// - Set env vars:
//     LOCOL_COLLECTOR_PATH=<path/to/opentelemetry-collector>
//     LOCOL_CONTRIB_PATH=<path/to/opentelemetry-collector-contrib>
// - Run with tags: `go test -tags integration ./scripts -run TestExtractorAgainstTestdata`
//
func TestExtractorAgainstTestdata(t *testing.T) {
    roots := []struct{
        base string
        isContrib bool
    }{
        {os.Getenv("LOCOL_COLLECTOR_PATH"), false},
        {os.Getenv("LOCOL_CONTRIB_PATH"), true},
    }

    var anyFound bool
    for _, r := range roots {
        if r.base == "" { continue }
        if st, err := os.Stat(r.base); err != nil || !st.IsDir() { continue }
        anyFound = true
        // Sample a few common types to keep test time reasonable
        for _, typ := range []string{"receiver", "processor", "exporter", "extension", "connector"} {
            typeDir := filepath.Join(r.base, typ)
            _ = filepath.WalkDir(typeDir, func(path string, d fs.DirEntry, err error) error {
                if err != nil { return nil }
                if !d.IsDir() { return nil }
                if d.Name() == "testdata" {
                    compDir := filepath.Dir(path)
                    runComponentCheck(t, compDir, typ, r.isContrib)
                    return fs.SkipDir
                }
                return nil
            })
        }
    }
    if !anyFound {
        t.Skip("Set LOCOL_COLLECTOR_PATH and/or LOCOL_CONTRIB_PATH to run integration checks")
    }
}

func runComponentCheck(t *testing.T, compDir, typ string, isContrib bool) {
    t.Helper()
    factoryPath := filepath.Join(compDir, "factory.go")
    configPath := filepath.Join(compDir, "config.go")
    if !exists(factoryPath) || !exists(configPath) { return }

    // Derive component ID from factory
    id := componentIDFromFactory(factoryPath)
    if id == "" {
        // Fallback: dir name without common suffix
        base := filepath.Base(compDir)
        for _, suf := range []string{"receiver", "exporter", "processor", "extension", "connector"} {
            if strings.HasSuffix(base, suf) { base = strings.TrimSuffix(base, suf) }
        }
        id = base
    }

    // Extract schema using preferred root from factory
    preferredRoot := findRootConfigTypeFromFactory(factoryPath)
    schema, err := extractConfigSchemaRecursive(compDir, configPath, preferredRoot)
    if err != nil { t.Fatalf("extract schema: %v", err) }
    keys := map[string]struct{}{}
    for _, f := range schema.Fields { keys[f.MapStructure] = struct{}{} }

    // Collect YAML files in testdata
    td := filepath.Join(compDir, "testdata")
    var yamls []string
    _ = filepath.WalkDir(td, func(path string, d fs.DirEntry, err error) error {
        if err != nil { return nil }
        if d.IsDir() { return nil }
        if strings.HasSuffix(path, ".yaml") || strings.HasSuffix(path, ".yml") {
            yamls = append(yamls, path)
        }
        return nil
    })
    if len(yamls) == 0 { return }

    // Validate each YAML file
    plural := typ + "s"
    for _, y := range yamls {
        data, err := os.ReadFile(y)
        if err != nil { t.Fatalf("read %s: %v", y, err) }
        dec := yaml.NewDecoder(strings.NewReader(string(data)))
        for {
            var doc map[string]any
            if err := dec.Decode(&doc); err != nil {
                if errors.Is(err, yaml.ErrDecoderClosed) || errors.Is(err, os.ErrClosed) { break }
                if err.Error() == "EOF" { break }
                break
            }
            sect, _ := doc[plural].(map[string]any)
            if len(sect) == 0 { continue }
            // Choose entries starting with id or id/...
            for k, v := range sect {
                if k == id || strings.HasPrefix(k, id+"/") {
                    if cfg, ok := v.(map[string]any); ok {
                        flat := flattenYAML(cfg, "")
                        for fk := range flat {
                            if !coveredBySchema(fk, keys) {
                                t.Errorf("%s: %s missing key %q for component %s", filepath.Base(compDir), filepath.Base(y), fk, id)
                            }
                        }
                    }
                }
            }
        }
    }
}

func exists(p string) bool { st, err := os.Stat(p); return err == nil && !st.IsDir() }

func flattenYAML(m map[string]any, prefix string) map[string]struct{} {
    out := map[string]struct{}{}
    for k, v := range m {
        key := k
        if prefix != "" { key = prefix + "." + k }
        switch x := v.(type) {
        case map[string]any:
            for fk := range flattenYAML(x, key) { out[fk] = struct{}{} }
        default:
            out[key] = struct{}{}
        }
    }
    return out
}

func coveredBySchema(key string, schema map[string]struct{}) bool {
    if _, ok := schema[key]; ok { return true }
    // Allow coverage via map-typed parent (we don’t have types here; be permissive)
    for i := len(key)-1; i >= 0; i-- {
        if key[i] == '.' {
            if _, ok := schema[key[:i]]; ok { return true }
        }
    }
    return false
}

