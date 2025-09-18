package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "go/ast"
    "go/parser"
    "go/token"
    "go/printer"
    "bytes"
    packages "golang.org/x/tools/go/packages"
    "io/ioutil"
    "os"
    "path/filepath"
    "reflect"
    "runtime"
    "sort"
    "strings"
    "sync"
    "strconv"
)

// Debug logging (enabled when PARSE_DEBUG=1)
var debug = os.Getenv("PARSE_DEBUG") == "1"

func dbgf(format string, args ...interface{}) {
    if debug {
        fmt.Fprintf(os.Stderr, format, args...)
    }
}

// Output structures
type ExtractedData struct {
    Version    string      `json:"version"`
    Components []Component `json:"components"`
    Document   DocumentSchema `json:"document"`
    // Optional: shared type definitions (reserved for future reuse)
    Definitions map[string]any `json:"definitions,omitempty"`
}

type Component struct {
    Name        string       `json:"name"`
    Type        string       `json:"type"` // receiver, processor, exporter
    Module      string       `json:"-"`
    Description string       `json:"description"`
    Config      ConfigSchema `json:"config"`
    Constraints []Constraint `json:"constraints"`
}

type ConfigSchema struct {
    StructName string        `json:"-"`
    Fields     []ConfigField `json:"fields"`
    Examples   []string      `json:"examples"`
}

type ConfigField struct {
    Name         string            `json:"name"`
    Type         string            `json:"type"`
    GoType       string            `json:"-"`
    MapStructure string            `json:"-"`
    Description  string            `json:"description"`
    Required     bool              `json:"required"`
    Default      interface{}       `json:"default,omitempty"`
    Validation   map[string]string `json:"validation,omitempty"`
    // Hierarchical path tokens for clean DTOs (e.g., ["protocols","http","cors","allowed_origins"]).
    PathTokens   []string          `json:"path_tokens,omitempty"`
    // Enum values for fields that accept a closed set of strings.
    EnumValues   []string          `json:"enum_values,omitempty"`
    // Display/validation hints
    Format       string            `json:"format,omitempty"`   // e.g., "duration", "hostport", "url", "pem", "bytes"
    Unit         string            `json:"unit,omitempty"`     // e.g., "MiB", "bytes"
    Sensitive    bool              `json:"sensitive,omitempty"`
    // Arrays: item type and optional component reference info
    ItemType     string            `json:"item_type,omitempty"` // e.g., "string", "object", "componentRef"
    RefKind      string            `json:"ref_kind,omitempty"`  // e.g., "extension", "receiver", ...
    RefScope     string            `json:"ref_scope,omitempty"` // e.g., "authenticator", "middleware"
}

type DefaultValue struct {
    FieldName string      `json:"field_name"`
    YamlKey   string      `json:"yaml_key"`
    Value     interface{} `json:"value"`
}

type Constraint struct {
    Kind       string     `json:"kind"`   // anyOf, oneOf, allOf, atMostOne
    KeyTokens  [][]string `json:"keys"`   // YAML keys as path tokens
    Message    string     `json:"message,omitempty"`
}

// DocumentSchema describes the top-level YAML document shape (service, pipelines, etc.)
type DocumentSchema struct {
    Sections               []string `json:"sections"`                      // receivers, processors, exporters, connectors, extensions, service
    Signals                []string `json:"signals"`                       // traces, metrics, logs, profiles
    ComponentIDPattern     string   `json:"component_id_pattern"`          // e.g., "<type>[/<instance>]"
    SupportsInstanceSuffix bool     `json:"supports_instance_suffix"`
    // Pipelines are arrays of component IDs by kind; shape is standard and enforced by the collector.
    PipelineShape struct {
        Receivers  bool `json:"receivers"`
        Processors bool `json:"processors"`
        Exporters  bool `json:"exporters"`
        Connectors bool `json:"connectors"`
    } `json:"pipeline_shape"`
    // Telemetry levels (service.telemetry)
    Telemetry struct {
        MetricsLevels []string `json:"metrics_levels"` // none, basic, normal, detailed
        DefaultLevel  string   `json:"default_level"`
    } `json:"telemetry"`
}

// Package parsing helpers for recursive extraction
type packageContext struct {
    dir         string
    files       []*ast.File
    fset        *token.FileSet
    imports     map[string]string // alias -> import path
    types       map[string]*ast.StructType
    aliases     map[string]ast.Expr // named type -> underlying expr
    importCache map[string]*packageContext // resolved external packages
}

// Global package cache to avoid re-loading packages repeatedly across components
var globalPkgCache = struct {
    mu       sync.RWMutex
    byImport map[string]*packageContext
    byDir    map[string]*packageContext
}{
    byImport: map[string]*packageContext{},
    byDir:    map[string]*packageContext{},
}

// Command line flags
var (
    version      = flag.String("version", "", "Collector version being extracted")
    collectorPath = flag.String("collector-path", "", "Path to opentelemetry-collector repo")
    contribPath  = flag.String("contrib-path", "", "Path to opentelemetry-collector-contrib repo")
    output       = flag.String("output", "configs.json", "Output JSON file")
    singleName   = flag.String("single-name", "", "Extract only component with this canonical name (e.g., otlp)")
    singleType   = flag.String("single-type", "", "Component type when using --single-name (receiver|processor|exporter|extension|connector)")
    printSchema  = flag.Bool("print", false, "Print extracted YAML keys for --single-name instead of writing JSON")
)

func main() {
    flag.Parse()

    if *version == "" || *collectorPath == "" || *contribPath == "" {
        fmt.Println("Usage: go run extract_configs.go --version=v0.91.0 --collector-path=../opentelemetry-collector --contrib-path=../opentelemetry-collector-contrib --output=configs.json")
        os.Exit(1)
    }

    fmt.Printf("Extracting configs for version %s\n", *version)

    // Pre-warm global package cache for both repos to speed up lookups
    prewarmPackageCache(*collectorPath)
    prewarmPackageCache(*contribPath)

    // Single-component mode for debugging/iteration
    if *singleName != "" && *singleType != "" {
        dir := findComponentDirByID(*collectorPath, *singleType, *singleName)
        isContrib := false
        if dir == "" {
            dir = findComponentDirByID(*contribPath, *singleType, *singleName)
            isContrib = dir != ""
        }
        if dir == "" {
            fmt.Printf("Component %s/%s not found in provided repos\n", *singleType, *singleName)
            os.Exit(1)
        }
        dbgf("[extractor] single component: dir=%s type=%s id=%s\n", dir, *singleType, *singleName)
        comp := extractComponent(dir, filepath.Base(dir), *singleType, isContrib)
        if comp == nil {
            fmt.Println("Extraction failed")
            os.Exit(2)
        }
        if *printSchema {
            fmt.Printf("%s/%s [%s] root=%s\n", *singleType, *singleName, comp.Module, comp.Config.StructName)
            keys := make([]string, 0, len(comp.Config.Fields))
            for _, f := range comp.Config.Fields { keys = append(keys, f.MapStructure) }
            sort.Strings(keys)
            for _, k := range keys { fmt.Println(k) }
            return
        }
        // Otherwise, write a tiny JSON with just this component
        data, _ := json.MarshalIndent(ExtractedData{Version: *version, Components: []Component{*comp}}, "", "  ")
        if err := os.WriteFile(*output, data, 0644); err != nil { panic(err) }
        fmt.Printf("Extracted 1 component to %s\n", *output)
        return
    }

    var components []Component

    // Extract from core collector
    coreComponents := extractFromPath(*collectorPath, false)
    components = append(components, coreComponents...)

    // Extract from contrib
    contribComponents := extractFromPath(*contribPath, true)
    components = append(components, contribComponents...)

    result := ExtractedData{
        Version:    *version,
        Components: components,
        Document:   buildDocumentSchema(),
        Definitions: nil,
    }

    // Save to JSON
    data, err := json.MarshalIndent(result, "", "  ")
    if err != nil {
        panic(err)
    }

    err = ioutil.WriteFile(*output, data, 0644)
    if err != nil {
        panic(err)
    }

    fmt.Printf("Extracted %d components to %s\n", len(components), *output)
}

func extractFromPath(basePath string, isContrib bool) []Component {
    var components []Component

    type task struct {
        componentPath string
        name          string
        typ           string
        isContrib     bool
    }

    var tasks []task
    componentTypes := []string{"receiver", "processor", "exporter", "extension", "connector"}
    for _, componentType := range componentTypes {
        typePath := filepath.Join(basePath, componentType)
        if st, err := os.Stat(typePath); err != nil || !st.IsDir() {
            continue
        }
        entries, err := os.ReadDir(typePath)
        if err != nil { continue }
        for _, e := range entries {
            if !e.IsDir() { continue }
            componentPath := filepath.Join(typePath, e.Name())
            if _, err := os.Stat(filepath.Join(componentPath, "config.go")); err != nil {
                continue
            }
            tasks = append(tasks, task{componentPath: componentPath, name: e.Name(), typ: componentType, isContrib: isContrib})
        }
    }

    // Worker pool
    workers := runtime.NumCPU()
    if workers < 2 { workers = 2 }
    in := make(chan task)
    out := make(chan *Component)

    var wg sync.WaitGroup
    worker := func() {
        defer wg.Done()
        for t := range in {
            dbgf("[extractor] scanning %s/%s\n", t.typ, t.name)
            c := extractComponent(t.componentPath, t.name, t.typ, t.isContrib)
            out <- c
        }
    }
    wg.Add(workers)
    for i := 0; i < workers; i++ { go worker() }

    go func() {
        for _, t := range tasks { in <- t }
        close(in)
        wg.Wait()
        close(out)
    }()

    for c := range out {
        if c != nil {
            components = append(components, *c)
            dbgf("[extractor] ✓ extracted %s/%s fields=%d constraints=%d\n",
                c.Type, c.Name, len(c.Config.Fields), len(c.Constraints))
        }
    }

    return components
}

// findComponentDirByID scans a type directory to locate a component whose
// factory reports the given canonical ID (e.g., otlp). Returns empty string if not found.
func findComponentDirByID(basePath, componentType, id string) string {
    typeDir := filepath.Join(basePath, componentType)
    entries, err := os.ReadDir(typeDir)
    if err != nil { return "" }
    for _, e := range entries {
        if !e.IsDir() { continue }
        compDir := filepath.Join(typeDir, e.Name())
        factory := filepath.Join(compDir, "factory.go")
        if !fileExists(factory) { continue }
        if componentIDFromFactory(factory) == id {
            return compDir
        }
        // Fallback: derive ID from directory name by stripping common suffix
        name := e.Name()
        for _, suf := range []string{"receiver", "exporter", "processor", "extension", "connector"} {
            if strings.HasSuffix(name, suf) { name = strings.TrimSuffix(name, suf); break }
        }
        if name == id { return compDir }
    }
    return ""
}

func fileExists(p string) bool {
    st, err := os.Stat(p)
    return err == nil && !st.IsDir()
}

func extractComponent(componentPath, name, componentType string, isContrib bool) *Component {
    configPath := filepath.Join(componentPath, "config.go")
    factoryPath := filepath.Join(componentPath, "factory.go")

    // Parse factory once and reuse for ID/root/defaults
    fset, factoryAST := parseFactoryFile(factoryPath)
    // Prefer the root config type declared in factory.go's createDefaultConfig
    preferredRoot := findRootConfigTypeFromFactoryAST(factoryAST)

    // Extract config structure (recursive)
    configSchema, err := extractConfigSchemaRecursive(componentPath, configPath, preferredRoot)
    if err != nil {
        dbgf("[extractor] warn: failed to extract config for %s: %v\n", name, err)
        return nil
    }
    dbgf("[extractor] root=%s fields=%d\n", configSchema.StructName, len(configSchema.Fields))

    // Extract defaults from factory (deep) using parsed AST
    defaults := extractDefaultsDeepWithAST(componentPath, configPath, fset, factoryAST)
    // Apply defaults onto matching fields and clear required for those fields
    if len(defaults) > 0 {
        defByKey := map[string]interface{}{}
        for _, d := range defaults {
            defByKey[d.YamlKey] = d.Value
        }
        for i := range configSchema.Fields {
            if v, ok := defByKey[configSchema.Fields[i].MapStructure]; ok {
                configSchema.Fields[i].Default = v
                configSchema.Fields[i].Required = false
            }
        }
        // Normalize enum defaults to YAML tokens now that defaults are applied
        configSchema.Fields = normalizeEnumDefaults(configSchema.Fields)
    }

    // Build module path
    modulePath := fmt.Sprintf("go.opentelemetry.io/collector/%s/%s", componentType, name)
    if isContrib {
        modulePath = fmt.Sprintf("github.com/open-telemetry/opentelemetry-collector-contrib/%s/%s", componentType, name)
    }

    // Determine canonical component ID (e.g., "otlp", "debug") from factory metadata
    id := componentIDFromFactoryAST(factoryAST)
    if id == "" {
        // Fallback: strip common suffixes (e.g., otlpreceiver -> otlp)
        for _, suf := range []string{"receiver", "exporter", "processor", "extension", "connector"} {
            if strings.HasSuffix(name, suf) {
                name = strings.TrimSuffix(name, suf)
                break
            }
        }
        id = name
    }

    component := &Component{
        Name:   id,
        Type:   componentType,
        Module: modulePath,
        Config: *configSchema,
    }
    // Attach constraints derived from validation
    constraints := analyzeConstraints(componentPath, configPath)
    component.Constraints = constraints
    // Collect examples from example/examples/testdata folders
    component.Config.Examples = gatherExamples(componentPath)
    return component
}

// componentIDFromFactory attempts to extract the component's canonical type ID from factory.go
func componentIDFromFactory(factoryPath string) string {
    _, node := parseFactoryFile(factoryPath)
    if node == nil { return "" }
    return componentIDFromFactoryAST(node)
}

// componentIDFromFactoryAST extracts the canonical type ID from a parsed factory file
func componentIDFromFactoryAST(node *ast.File) string {
    // 1) Look for: func Type() component.Type { return component.MustNewType("otlp") }
    var result string
    ast.Inspect(node, func(n ast.Node) bool {
        fd, ok := n.(*ast.FuncDecl)
        if !ok || fd.Name.Name != "Type" || fd.Body == nil {
            return true
        }
        ast.Inspect(fd.Body, func(m ast.Node) bool {
            ret, ok := m.(*ast.ReturnStmt)
            if !ok || len(ret.Results) == 0 {
                return true
            }
            call, ok := ret.Results[0].(*ast.CallExpr)
            if !ok {
                return true
            }
            // Selector like component.MustNewType or component.NewType
            if sel, ok := call.Fun.(*ast.SelectorExpr); ok {
                if id, ok := callArgString(call); ok && (sel.Sel.Name == "MustNewType" || sel.Sel.Name == "NewType") {
                    result = id
                    return false
                }
            }
            return true
        })
        return result == ""
    })
    if result != "" {
        return result
    }
    // 2) Look for: const typeStr = "otlp" or var typeStr = "otlp"
    ast.Inspect(node, func(n ast.Node) bool {
        gd, ok := n.(*ast.GenDecl)
        if !ok || (gd.Tok != token.CONST && gd.Tok != token.VAR) {
            return true
        }
        for _, spec := range gd.Specs {
            vs, ok := spec.(*ast.ValueSpec)
            if !ok || len(vs.Names) == 0 || len(vs.Values) == 0 {
                continue
            }
            name := vs.Names[0].Name
            if name == "typeStr" || strings.Contains(strings.ToLower(name), "type") {
                if bl, ok := vs.Values[0].(*ast.BasicLit); ok && bl.Kind == token.STRING {
                    str := bl.Value
                    if len(str) >= 2 {
                        str = str[1 : len(str)-1]
                    }
                    result = str
                    return false
                }
            }
        }
        return true
    })
    return result
}

// findRootConfigTypeFromFactory returns the struct type used in
// createDefaultConfig (e.g., "Config"). This is our best signal for the
// actual root config type when multiple *Config types exist.
func findRootConfigTypeFromFactory(factoryPath string) string {
    _, node := parseFactoryFile(factoryPath)
    if node == nil { return "" }
    return findRootConfigTypeFromFactoryAST(node)
}

// findRootConfigTypeFromFactoryAST returns the struct type used in createDefaultConfig from parsed AST
func findRootConfigTypeFromFactoryAST(node *ast.File) string {
    var typeName string
    ast.Inspect(node, func(n ast.Node) bool {
        fn, ok := n.(*ast.FuncDecl)
        if !ok || fn.Name.Name != "createDefaultConfig" || fn.Body == nil {
            return true
        }
        ast.Inspect(fn.Body, func(n ast.Node) bool {
            ret, ok := n.(*ast.ReturnStmt)
            if !ok || len(ret.Results) == 0 {
                return true
            }
            if u, ok := ret.Results[0].(*ast.UnaryExpr); ok && u.Op == token.AND {
                if comp, ok := u.X.(*ast.CompositeLit); ok {
                    typeName = typeNameFromExpr(comp.Type)
                    return false
                }
            }
            return true
        })
        return false
    })
    return typeName
}

// parseFactoryFile reads and parses factory.go once
func parseFactoryFile(factoryPath string) (*token.FileSet, *ast.File) {
    content, err := ioutil.ReadFile(factoryPath)
    if err != nil { return nil, nil }
    fset := token.NewFileSet()
    node, err := parser.ParseFile(fset, factoryPath, string(content), parser.ParseComments)
    if err != nil { return nil, nil }
    return fset, node
}

// structTypeName attempts to find the declared name for the struct within the package context
func structTypeName(ctx *packageContext, st *ast.StructType) string {
    for name, cand := range ctx.types {
        if cand == st { return name }
    }
    return ""
}

func structTypeKey(ctx *packageContext, st *ast.StructType) string {
    if name := structTypeName(ctx, st); name != "" {
        return ctx.dir + ":" + name
    }
    return fmt.Sprintf("%s:@%p", ctx.dir, st)
}

func callArgString(call *ast.CallExpr) (string, bool) {
    if len(call.Args) == 0 {
        return "", false
    }
    if bl, ok := call.Args[0].(*ast.BasicLit); ok && bl.Kind == token.STRING {
        s := bl.Value
        if len(s) >= 2 {
            s = s[1 : len(s)-1]
        }
        return s, true
    }
    return "", false
}

// --- Recursive schema extraction ---

func extractConfigSchemaRecursive(componentDir string, configPath string, preferredRoot string) (*ConfigSchema, error) {
    pkgCtx, err := loadPackage(componentDir, ".")
    if err != nil {
        return nil, err
    }

    schema := &ConfigSchema{Fields: []ConfigField{}}

    // Locate the canonical root config struct. Track the owning package context for the struct
    // so nested resolution and Validate scanning use the correct files.
    var rootStruct *ast.StructType
    var rootName string
    rootCtx := pkgCtx

    // Helper: resolve alias to external struct
    resolveAlias := func(name string) bool {
        if expr, ok := pkgCtx.aliases[name]; ok {
            if extCtx, st := resolveStructFromExprWithCtx(pkgCtx, expr); st != nil {
                rootStruct = st
                rootCtx = extCtx
                rootName = name
                return true
            }
        }
        return false
    }

    // 1) Prefer the factory-declared root type when present.
    if preferredRoot != "" {
        if st, ok := pkgCtx.types[preferredRoot]; ok {
            rootStruct = st
            rootName = preferredRoot
        } else {
            // Try alias to external package
            _ = resolveAlias(preferredRoot)
        }
    }
    // 2) Fallback to exact "Config"
    if rootStruct == nil {
        if st, ok := pkgCtx.types["Config"]; ok {
            rootStruct = st
            rootName = "Config"
        } else {
            _ = resolveAlias("Config")
        }
    }
    // 3) As a last resort, pick the *Config with most mapstructure-tagged fields (local only)
    if rootStruct == nil {
        bestCount := -1
        for name, st := range pkgCtx.types {
            if !strings.HasSuffix(name, "Config") { continue }
            cnt := countMapstructureFields(st)
            if cnt > bestCount { bestCount = cnt; rootStruct = st; rootName = name; rootCtx = pkgCtx }
        }
    }
    if rootStruct == nil {
        return schema, nil
    }
    schema.StructName = rootName
    dbgf("[extractor] using root struct: %s (pkg=%s)\n", rootName, rootCtx.dir)

    visited := map[string]int{}
    fields := []ConfigField{}
    extractStructFields(rootCtx, rootStruct, "", &fields, visited)
    // Augment with Validate() insights (field-level) from the owning package
    applyValidationHeuristics(componentDir, rootCtx, rootName, &fields)
    // Post-process fields: collapse arrays-of-components and add hints/tokens
    schema.Fields = postProcessFields(fields)
    return schema, nil
}

// countMapstructureFields returns how many direct fields on st carry a
// mapstructure tag (used to pick the most likely root Config when multiple
// *Config types exist in a package, e.g., HTTPConfig, GRPCConfig, etc.).
func countMapstructureFields(st *ast.StructType) int {
    if st == nil || st.Fields == nil { return 0 }
    c := 0
    for _, f := range st.Fields.List {
        if f.Tag == nil { continue }
        tag := strings.Trim(f.Tag.Value, "`")
        if strings.Contains(tag, "mapstructure:") { c++ }
    }
    return c
}

func extractStructFields(ctx *packageContext, st *ast.StructType, prefix string, out *[]ConfigField, visited map[string]int) {
    if st == nil || st.Fields == nil {
        return
    }
    // Recursion guard to prevent cycles through embedded fields/types
    key := structTypeKey(ctx, st)
    if visited[key] > 0 { return }
    visited[key]++
    defer func() { visited[key]--; if visited[key] <= 0 { delete(visited, key) } }()
    for _, f := range st.Fields.List {
        // Determine tags and mapstructure
        tagValue := ""
        if f.Tag != nil {
            tagValue = strings.Trim(f.Tag.Value, "`")
        }
        tag := reflect.StructTag(tagValue)
        mapstruct := tag.Get("mapstructure")
        validateTag := tag.Get("validate")
        hasSquash := strings.Contains(mapstruct, "squash")

        // Embedded (anonymous) field handling
        if len(f.Names) == 0 {
            nextCtx, target := resolveStructFromExprWithCtx(ctx, f.Type)
            if target != nil {
                // If anonymous has a mapstructure name (and not squash), treat it as a nested namespace
                var nextPrefix = prefix
                if mapstruct != "" && !hasSquash {
                    token := strings.Split(mapstruct, ",")[0]
                    if nextPrefix != "" { nextPrefix = nextPrefix + "." + token } else { nextPrefix = token }
                }
                extractStructFields(nextCtx, target, nextPrefix, out, visited)
            }
            continue
        }
        // Named field with squash: inline
        if hasSquash {
            nextCtx, target := resolveStructFromExprWithCtx(ctx, f.Type)
            if target != nil {
                extractStructFields(nextCtx, target, prefix, out, visited)
            }
            continue
        }

        // Prefer explicit mapstructure; otherwise derive a token from the Go name
        yamlKey := ""
        if mapstruct != "" {
            yamlKey = strings.Split(mapstruct, ",")[0]
        } else if len(f.Names) > 0 {
            yamlKey = guessYAMLTokenFromGoName(f.Names[0].Name)
        } else {
            continue
        }
        fullKey := yamlKey
        if prefix != "" {
            fullKey = prefix + "." + yamlKey
        }
        fullKey = normalizeArrayToken(fullKey)

        // If struct-like, recurse; otherwise add as leaf
        if isStructLike(f.Type) {
            nextCtx, target := resolveStructFromExprWithCtx(ctx, f.Type)
            // Optional debug for single-component runs
            dbgf("DBG %s field type=%T\n", fullKey, f.Type)
            if target != nil {
                extractStructFields(nextCtx, target, fullKey, out, visited)
                continue
            }
        }

        // Leaf field
        fieldName := ""
        if len(f.Names) > 0 {
            fieldName = f.Names[0].Name
        }
        goType := extractType(f.Type)
        swiftType := mapGoTypeToSwift(goType)
        comment := extractComment(f)
        // Do NOT infer required from absence of "omitempty" — that's a serializer hint.
        // Default to optional unless we have strong signals (validate tag or Validate() method).
        required := false
        if validateTag != "" && strings.Contains(validateTag, "required") {
            required = true
        }
        cf := ConfigField{
            Name:         fieldName,
            Type:         swiftType,
            GoType:       goType,
            MapStructure: fullKey,
            Description:  comment,
            Required:     required,
            PathTokens:   makePathTokens(fullKey),
        }
        // Enum extraction
        if swiftType == "enum" {
            cf.EnumValues = inferEnumValues(ctx, f.Type, comment, goType)
        } else if swiftType == "custom" {
            // Only consider named custom types with declared constants as enums (e.g., string-typed aliases)
            if vals := extractEnumValuesFromType(ctx, f.Type, goType); len(vals) > 0 {
                cf.Type = "enum"
                cf.EnumValues = vals
            }
        }
        // Hints: format/unit/sensitive
        annotateFieldHints(&cf)
        *out = append(*out, cf)
    }
}

// Replace generic array element placeholders in paths with a readable token.
// E.g., "auth.authenticator.-.name" -> "auth.authenticator[].name"
func normalizeArrayToken(path string) string {
    // Middle occurrence: .-. -> .[].
    path = strings.ReplaceAll(path, ".-.", ".[].")
    // Trailing occurrence: .- -> .[]
    if strings.HasSuffix(path, ".-") {
        path = strings.TrimSuffix(path, ".-") + ".[]"
    }
    // Leading occurrence: -.
    if strings.HasPrefix(path, "-.") {
        path = "[]" + strings.TrimPrefix(path, "-.")
    }
    if path == "-" { return "[]" }
    return path
}

// Convert Go field name to a conservative snake_case YAML token
func guessYAMLTokenFromGoName(name string) string {
    if name == "" { return "" }
    var b []rune
    for i, r := range name {
        if i > 0 && r >= 'A' && r <= 'Z' {
            b = append(b, '_', r+('a'-'A'))
        } else {
            if r >= 'A' && r <= 'Z' { r = r + ('a' - 'A') }
            b = append(b, r)
        }
    }
    return string(b)
}

// --- Path tokens & field hints ---
func makePathTokens(fullKey string) []string {
    if fullKey == "" { return nil }
    parts := strings.Split(fullKey, ".")
    tokens := make([]string, 0, len(parts))
    for _, p := range parts {
        switch {
        case p == "[]":
            tokens = append(tokens, "[]")
        case strings.HasSuffix(p, "[]"):
            base := strings.TrimSuffix(p, "[]")
            if base != "" { tokens = append(tokens, base) }
            tokens = append(tokens, "[]")
        default:
            tokens = append(tokens, p)
        }
    }
    return tokens
}

func annotateFieldHints(cf *ConfigField) {
    key := strings.ToLower(cf.MapStructure)
    name := strings.ToLower(cf.Name)
    desc := strings.ToLower(cf.Description)
    // Sensitive
    if strings.Contains(cf.GoType, "configopaque.String") {
        cf.Sensitive = true
    }
    // Common secret keywords
    if strings.Contains(key, "token") || strings.Contains(key, "password") || strings.Contains(key, "secret") {
        cf.Sensitive = true
    }
    if strings.Contains(name, "token") || strings.Contains(name, "password") || strings.Contains(name, "secret") {
        cf.Sensitive = true
    }
    // Format hints
    if strings.HasSuffix(key, ".timeout") || strings.HasSuffix(name, "timeout") || cf.Type == "duration" {
        cf.Format = "duration"
    }
    if strings.HasSuffix(key, ".endpoint") || name == "endpoint" {
        if strings.Contains(desc, "http") || strings.Contains(desc, "https") || strings.Contains(desc, "url") {
            cf.Format = "url"
        } else if strings.Contains(desc, "host:port") || strings.Contains(desc, "listening address") {
            cf.Format = "hostport"
        }
    }
    if strings.Contains(key, "certificate") || strings.Contains(name, "certificate") || strings.Contains(name, "client_key") || strings.Contains(key, "client_key") {
        // PEM/key-like
        cf.Format = "pem"
        cf.Sensitive = true
    }
    // Units
    if strings.HasSuffix(key, "_mib") {
        cf.Unit = "MiB"
    } else if strings.Contains(key, "_bytes") || strings.HasSuffix(key, "body_size") {
        cf.Unit = "bytes"
    }
}

// Infer enum values: from known Go types or by parsing description
func inferEnumValues(ctx *packageContext, t ast.Expr, description string, goType string) []string {
    // Try generic extraction from the named type definition (constants in the type's package).
    if vals := extractEnumValuesFromType(ctx, t, goType); len(vals) > 0 {
        return vals
    }
    // Fallback: Parse description for Allowed/Valid values like `ignore` and `propagate` or "tcp" etc.
    vals := parseEnumValuesFromDescription(description)
    return vals
}

func parseEnumValuesFromDescription(desc string) []string {
    if desc == "" { return nil }
    vals := []string{}
    // Backtick-quoted tokens
    tmp := desc
    for {
        i := strings.Index(tmp, "`")
        if i < 0 { break }
        tmp = tmp[i+1:]
        j := strings.Index(tmp, "`")
        if j < 0 { break }
        tok := strings.TrimSpace(tmp[:j])
        tmp = tmp[j+1:]
        if tok != "" {
            vals = append(vals, strings.ToLower(tok))
        }
    }
    // Double-quote tokens
    tmp = desc
    for {
        i := strings.Index(tmp, "\"")
        if i < 0 { break }
        tmp = tmp[i+1:]
        j := strings.Index(tmp, "\"")
        if j < 0 { break }
        tok := strings.TrimSpace(tmp[:j])
        tmp = tmp[j+1:]
        if tok != "" && len(tok) <= 20 { // crude guard
            // ignore phrases with spaces (likely not enum tokens)
            if !strings.Contains(tok, " ") {
                vals = append(vals, strings.ToLower(tok))
            }
        }
    }
    // Dedupe and stable order
    if len(vals) == 0 { return nil }
    m := map[string]struct{}{}
    out := []string{}
    for _, v := range vals {
        if _, ok := m[v]; !ok {
            m[v] = struct{}{}
            out = append(out, v)
        }
    }
    // simple insertion sort
    for i := 1; i < len(out); i++ {
        j := i
        for j > 0 && out[j] < out[j-1] {
            out[j], out[j-1] = out[j-1], out[j]
            j--
        }
    }
    return out
}

// Resolve a named type to its defining package and the underlying type expr.
// Returns (pkgCtx, typeName, underlyingExpr). If resolution fails, returns nils/empty.
func resolveNamedType(ctx *packageContext, expr ast.Expr) (*packageContext, string, ast.Expr) {
    switch t := expr.(type) {
    case *ast.Ident:
        // Local type alias or definition
        if underlying, ok := ctx.aliases[t.Name]; ok {
            return ctx, t.Name, underlying
        }
        return ctx, t.Name, nil
    case *ast.SelectorExpr:
        if pkgIdent, ok := t.X.(*ast.Ident); ok {
            importPath := ctx.imports[pkgIdent.Name]
            if importPath != "" {
                ext := resolveExternalPackage(ctx, importPath)
                if ext != nil {
                    if underlying, ok := ext.aliases[t.Sel.Name]; ok {
                        return ext, t.Sel.Name, underlying
                    }
                    return ext, t.Sel.Name, nil
                }
            }
        }
    }
    return nil, "", nil
}

// Extract enum tokens by scanning const declarations for the given named type.
// - For string-typed enums, use the literal values.
// - For numeric enums, derive tokens from constant identifiers by stripping the type name prefix and lowercasing.
func extractEnumValuesFromType(ctx *packageContext, typeExpr ast.Expr, goType string) []string {
    pkg, typeName, underlying := resolveNamedType(ctx, typeExpr)
    if pkg == nil || typeName == "" {
        return nil
    }
    // Determine if underlying is string-like
    isString := false
    switch u := underlying.(type) {
    case *ast.Ident:
        isString = (u.Name == "string")
    case *ast.SelectorExpr:
        // Rare: alias to something string-like in another pkg — ignore for now.
        isString = false
    }

    // Scan constants in the defining package
    tokens := []string{}
    seen := map[string]struct{}{}
    for _, f := range pkg.files {
        for _, d := range f.Decls {
            gd, ok := d.(*ast.GenDecl)
            if !ok || gd.Tok != token.CONST { continue }
            var currentType string
            for _, s := range gd.Specs {
                vs, ok := s.(*ast.ValueSpec)
                if !ok { continue }
                // Track explicit type for subsequent untyped entries in the same const block
                if vs.Type != nil {
                    if id, ok := vs.Type.(*ast.Ident); ok {
                        currentType = id.Name
                    } else {
                        // SelectorExpr in same package scope shouldn't happen for local type names
                        currentType = ""
                    }
                }
                // Determine if this spec belongs to our type
                typeMatch := (currentType == typeName)
                // Some files explicitly annotate every spec; when annotated, require exact match
                if vs.Type != nil {
                    typeMatch = false
                    if id, ok := vs.Type.(*ast.Ident); ok && id.Name == typeName { typeMatch = true }
                }
                if !typeMatch { continue }

                for i, name := range vs.Names {
                    // Skip blank or private names just in case
                    if name == nil || name.Name == "_" { continue }
                    var tok string
                    if isString {
                        if i < len(vs.Values) {
                            if bl, ok := vs.Values[i].(*ast.BasicLit); ok && bl.Kind == token.STRING {
                                s := bl.Value
                                if len(s) >= 2 { s = s[1:len(s)-1] }
                                // Skip empty string enum value
                                if s == "" {
                                    continue
                                }
                                tok = s
                            }
                        }
                        // If string-typed constant has no literal, skip; do not fallback to identifier.
                    } else {
                        if tok == "" {
                            // Fallback: derive from constant identifier (e.g., LevelBasic -> basic)
                            tok = strings.ToLower(strings.TrimPrefix(name.Name, typeName))
                            tok = strings.TrimPrefix(tok, "_")
                        }
                    }
                    // Filter empty tokens
                    if tok == "" { continue }
                    if _, ok := seen[tok]; !ok {
                        seen[tok] = struct{}{}
                        tokens = append(tokens, tok)
                    }
                }
            }
        }
    }
    // Keep stable order
    for i := 1; i < len(tokens); i++ {
        j := i
        for j > 0 && tokens[j] < tokens[j-1] {
            tokens[j], tokens[j-1] = tokens[j-1], tokens[j]
            j--
        }
    }
    return tokens
}

// Collapse noisy array tokenizations like "auth.authenticator.[]" and
// "auth.authenticator.[].name" into a single array field with itemType hints.
func postProcessFields(fields []ConfigField) []ConfigField {
    if len(fields) == 0 { return fields }
    // Index by normalized prefix before []
    type agg struct { idxs []int }
    buckets := map[string]*agg{}
    for i := range fields {
        ft := fields[i].PathTokens
        for j := range ft {
            if ft[j] == "[]" {
                prefix := strings.Join(ft[:j], ".")
                if prefix == "" { prefix = fields[i].MapStructure }
                if buckets[prefix] == nil { buckets[prefix] = &agg{} }
                buckets[prefix].idxs = append(buckets[prefix].idxs, i)
                break
            }
        }
    }
    removed := map[int]struct{}{}
    out := make([]ConfigField, 0, len(fields))
    for prefix, b := range buckets {
        if len(b.idxs) == 0 { continue }
        // Create a single representative field
        rep := fields[b.idxs[0]]
        rep.MapStructure = prefix + ".[]"
        rep.PathTokens = makePathTokens(rep.MapStructure)
        rep.Type = "array"
        rep.ItemType = "object"
        // Infer componentRef for common cases
        low := strings.ToLower(prefix)
        if strings.HasSuffix(low, ".authenticator") || strings.HasSuffix(low, "auth.authenticator") {
            rep.ItemType = "componentRef"
            rep.RefKind = "extension"
            rep.RefScope = "authenticator"
        }
        if strings.HasSuffix(low, ".middlewares") || strings.HasSuffix(low, "grpc.middlewares") {
            rep.ItemType = "componentRef"
            rep.RefKind = "extension"
            rep.RefScope = "middleware"
        }
        // Keep first, mark all involved fields for removal
        // (we'll keep rep only once later)
        for _, idx := range b.idxs { removed[idx] = struct{}{} }
        // Stash rep in a special slot by overwriting the first index
        fields[b.idxs[0]] = rep
    }
    for i := range fields {
        if _, ok := removed[i]; ok {
            // Keep only the representative at the first index of its bucket
            // by re-adding it; others are dropped
            // Identify if this index is a representative
            ft := fields[i].PathTokens
            isRep := len(ft) > 0 && ft[len(ft)-1] == "[]"
            if isRep {
                out = append(out, fields[i])
            }
            continue
        }
        out = append(out, fields[i])
    }
    // Normalize enum defaults to YAML if possible
    out = normalizeEnumDefaults(out)
    return out
}

// normalizeEnumDefaults converts Go-typed enum defaults (e.g., configtelemetry.LevelBasic)
// to their YAML string tokens when enum_values are present.
func normalizeEnumDefaults(fields []ConfigField) []ConfigField {
    for i := range fields {
        if len(fields[i].EnumValues) == 0 { continue }
        if s, ok := fields[i].Default.(string); ok {
            parts := strings.Split(s, ".")
            last := parts[len(parts)-1]
            last = strings.TrimPrefix(strings.ToLower(last), "level")
            if last == "" { last = strings.ToLower(s) }
            for _, ev := range fields[i].EnumValues {
                if ev == last {
                    fields[i].Default = ev
                    break
                }
            }
        }
    }
    return fields
}

// Build a static document schema for the top-level collector config.
func buildDocumentSchema() DocumentSchema {
    var d DocumentSchema
    d.Sections = []string{"receivers", "processors", "exporters", "connectors", "extensions", "service"}
    d.Signals = []string{"traces", "metrics", "logs", "profiles"}
    d.ComponentIDPattern = "<type>[/<instance>]"
    d.SupportsInstanceSuffix = true
    d.PipelineShape.Receivers = true
    d.PipelineShape.Processors = true
    d.PipelineShape.Exporters = true
    d.PipelineShape.Connectors = true
    d.Telemetry.MetricsLevels = []string{"none", "basic", "normal", "detailed"}
    d.Telemetry.DefaultLevel = "basic"
    return d
}

// --- Examples collection ---
func gatherExamples(componentDir string) []string {
    // Find YAML examples in common locations under the component directory.
    var out []string
    maxFiles := 3
    maxBytes := 100 * 1024 // 100KB per file cap
    _ = filepath.WalkDir(componentDir, func(path string, d os.DirEntry, err error) error {
        if err != nil || d.IsDir() { return nil }
        if len(out) >= maxFiles { return nil }
        rel, _ := filepath.Rel(componentDir, path)
        // Filter YAML files only
        if !(strings.HasSuffix(rel, ".yaml") || strings.HasSuffix(rel, ".yml")) {
            return nil
        }
        // Detect interesting locations: example/, examples/, */testdata/*config*.yaml
        relSl := filepath.ToSlash(rel)
        base := filepath.Base(relSl)
        if strings.Contains(relSl, "/example/") || strings.Contains(relSl, "/examples/") || (strings.Contains(relSl, "/testdata/") && strings.Contains(strings.ToLower(base), "config")) {
            if data, err := os.ReadFile(path); err == nil {
                if len(data) > maxBytes { data = data[:maxBytes] }
                out = append(out, string(data))
            }
        }
        return nil
    })
    return out
}

func isStructLike(expr ast.Expr) bool {
    switch t := expr.(type) {
    case *ast.IndexExpr:
        return isStructLike(t.Index)
    case *ast.IndexListExpr:
        if n := len(t.Indices); n > 0 { return isStructLike(t.Indices[n-1]) }
        return false
    case *ast.StructType:
        return true
    case *ast.StarExpr:
        return isStructLike(t.X)
    case *ast.Ident:
        return true // may resolve to struct in local package
    case *ast.SelectorExpr:
        return true // may resolve to struct in external package
    default:
        return false
    }
}

func loadPackage(dir string, pattern string) (*packageContext, error) {
    if pattern == "" { pattern = "." }
    // Fast path: resolve from global cache by dir (for ".") or by import path
    if pattern == "." || pattern == "./" {
        globalPkgCache.mu.RLock()
        if pc := globalPkgCache.byDir[dir]; pc != nil { globalPkgCache.mu.RUnlock(); return pc, nil }
        globalPkgCache.mu.RUnlock()
    } else if !strings.HasPrefix(pattern, ".") {
        globalPkgCache.mu.RLock()
        if pc := globalPkgCache.byImport[pattern]; pc != nil { globalPkgCache.mu.RUnlock(); return pc, nil }
        globalPkgCache.mu.RUnlock()
    }

    cfg := &packages.Config{Mode: packages.NeedName | packages.NeedFiles | packages.NeedSyntax, Dir: dir}
    pkgs, err := packages.Load(cfg, pattern)
    if err != nil { return nil, err }
    if len(pkgs) == 0 { return nil, fmt.Errorf("no packages for %s in %s", pattern, dir) }
    p := pkgs[0]
    files := p.Syntax
    fset := p.Fset
    imports := map[string]string{}
    types := map[string]*ast.StructType{}
    aliases := map[string]ast.Expr{}
    for _, file := range files {
        for _, is := range file.Imports {
            path := strings.Trim(is.Path.Value, "\"")
            alias := ""
            if is.Name != nil { alias = is.Name.Name } else {
                parts := strings.Split(path, "/")
                alias = parts[len(parts)-1]
            }
            imports[alias] = path
        }
        for _, decl := range file.Decls {
            gd, ok := decl.(*ast.GenDecl)
            if !ok || gd.Tok != token.TYPE { continue }
            for _, spec := range gd.Specs {
                ts, ok := spec.(*ast.TypeSpec)
                if !ok { continue }
                switch tt := ts.Type.(type) {
                case *ast.StructType:
                    types[ts.Name.Name] = tt
                default:
                    aliases[ts.Name.Name] = tt
                }
            }
        }
    }
    pc := &packageContext{dir: dir, files: files, fset: fset, imports: imports, types: types, aliases: aliases, importCache: map[string]*packageContext{}}
    // Update global cache
    globalPkgCache.mu.Lock()
    // best-effort mapping by dir
    if _, ok := globalPkgCache.byDir[dir]; !ok {
        globalPkgCache.byDir[dir] = pc
    }
    // p.PkgPath may be empty for local pattern; try to read from go list; but skip if not available
    if p.PkgPath != "" {
        if _, ok := globalPkgCache.byImport[p.PkgPath]; !ok { globalPkgCache.byImport[p.PkgPath] = pc }
    }
    globalPkgCache.mu.Unlock()
    return pc, nil
}

// resolveStructFromExprWithCtx resolves an expression to a struct type and returns the
// package context owning that struct. This lets downstream resolution use the correct
// import alias table for further nested types.
func resolveStructFromExprWithCtx(ctx *packageContext, expr ast.Expr) (*packageContext, *ast.StructType) {
    switch t := expr.(type) {
    case *ast.IndexExpr:
        // Option[T] or similar — dive into type parameter
        var b bytes.Buffer
        _ = printer.Fprint(&b, ctx.fset, t.Index)
        // Debug print of inner expression form
        if s := b.String(); strings.Contains(s, "configgrpc") || strings.Contains(s, "confighttp") {
            dbgf("DBG IndexExpr inner code=%s type=%T\n", s, t.Index)
        }
        return resolveStructFromExprWithCtx(ctx, t.Index)
    case *ast.IndexListExpr:
        // Generic[A,B] — prefer value type (last index)
        if n := len(t.Indices); n > 0 { return resolveStructFromExprWithCtx(ctx, t.Indices[n-1]) }
        return nil, nil
    case *ast.StarExpr:
        return resolveStructFromExprWithCtx(ctx, t.X)
    case *ast.Ident:
        if st, ok := ctx.types[t.Name]; ok {
            return ctx, st
        }
        if underlying, ok := ctx.aliases[t.Name]; ok {
            return resolveStructFromExprWithCtx(ctx, underlying)
        }
        return nil, nil
    case *ast.SelectorExpr:
        // X is package alias, Sel is type name
        if pkgIdent, ok := t.X.(*ast.Ident); ok {
            importPath := ctx.imports[pkgIdent.Name]
            if importPath == "" {
                dbgf("DBG selector missing import for alias=%s in %s\n", pkgIdent.Name, ctx.dir)
                return nil, nil
            }
            ext := resolveExternalPackage(ctx, importPath)
            if ext == nil {
                dbgf("DBG resolveExternalPackage nil for %s\n", importPath)
                return nil, nil
            }
            // Debug: show selector resolution path for tricky cases
            if t.Sel != nil && (t.Sel.Name == "ServerConfig" || t.Sel.Name == "ClientConfig") {
                dbgf("DBG resolving selector %s.%s in %s\n", pkgIdent.Name, t.Sel.Name, importPath)
            }
            if st, ok := ext.types[t.Sel.Name]; ok {
                return ext, st
            }
            if underlying, ok := ext.aliases[t.Sel.Name]; ok {
                return resolveStructFromExprWithCtx(ext, underlying)
            }
        }
        return nil, nil
    case *ast.StructType:
        return ctx, t
    default:
        return nil, nil
    }
}

// Backward-compatible thin wrapper for callers that only need the struct.
func resolveStructFromExpr(ctx *packageContext, expr ast.Expr) *ast.StructType {
    _, st := resolveStructFromExprWithCtx(ctx, expr)
    return st
}

func resolveExternalPackage(ctx *packageContext, importPath string) *packageContext {
    if pc, ok := ctx.importCache[importPath]; ok { return pc }
    // Check global cache first
    globalPkgCache.mu.RLock()
    if pc := globalPkgCache.byImport[importPath]; pc != nil { globalPkgCache.mu.RUnlock(); ctx.importCache[importPath] = pc; return pc }
    globalPkgCache.mu.RUnlock()
    // Fallback to loading relative to current module root
    pc, err := loadPackage(ctx.dir, importPath)
    if err == nil {
        ctx.importCache[importPath] = pc
        return pc
    }
    ctx.importCache[importPath] = nil
    return nil
}

func findGoModRoot(start string) (string, string) {
    dir := start
    for i := 0; i < 12; i++ {
        gomod := filepath.Join(dir, "go.mod")
        if data, err := ioutil.ReadFile(gomod); err == nil {
            lines := strings.Split(string(data), "\n")
            for _, ln := range lines {
                ln = strings.TrimSpace(ln)
                if strings.HasPrefix(ln, "module ") {
                    mod := strings.TrimSpace(strings.TrimPrefix(ln, "module "))
                    return dir, mod
                }
            }
            return dir, ""
        }
        parent := filepath.Dir(dir)
        if parent == dir { break }
        dir = parent
    }
    return start, ""
}

// Preload all packages under a repo root (best-effort). Greatly reduces repeated loads.
func prewarmPackageCache(root string) {
    if root == "" { return }
    st, err := os.Stat(root)
    if err != nil || !st.IsDir() { return }
    cfg := &packages.Config{Mode: packages.NeedName | packages.NeedFiles | packages.NeedSyntax, Dir: root}
    // Load all subpackages
    pkgs, err := packages.Load(cfg, "./...")
    if err != nil || len(pkgs) == 0 { return }
    for _, p := range pkgs {
        files := p.Syntax
        fset := p.Fset
        imports := map[string]string{}
        types := map[string]*ast.StructType{}
        aliases := map[string]ast.Expr{}
        for _, file := range files {
            for _, is := range file.Imports {
                path := strings.Trim(is.Path.Value, "\"")
                alias := ""
                if is.Name != nil { alias = is.Name.Name } else {
                    parts := strings.Split(path, "/")
                    alias = parts[len(parts)-1]
                }
                imports[alias] = path
            }
            for _, decl := range file.Decls {
                if gd, ok := decl.(*ast.GenDecl); ok && gd.Tok == token.TYPE {
                    for _, spec := range gd.Specs {
                        if ts, ok := spec.(*ast.TypeSpec); ok {
                            switch tt := ts.Type.(type) {
                            case *ast.StructType:
                                types[ts.Name.Name] = tt
                            default:
                                aliases[ts.Name.Name] = tt
                            }
                        }
                    }
                }
            }
        }
        // Determine dir for this package
        dir := root
        if len(p.GoFiles) > 0 {
            dir = filepath.Dir(p.GoFiles[0])
        }
        pc := &packageContext{dir: dir, files: files, fset: fset, imports: imports, types: types, aliases: aliases, importCache: map[string]*packageContext{}}
        globalPkgCache.mu.Lock()
        if p.PkgPath != "" { globalPkgCache.byImport[p.PkgPath] = pc }
        globalPkgCache.byDir[dir] = pc
        globalPkgCache.mu.Unlock()
    }
}

// --- Validation analysis (best-effort) ---
func applyValidationHeuristics(componentDir string, ctx *packageContext, rootName string, fields *[]ConfigField) {
    // Build a map from yaml key -> index
    index := map[string]int{}
    for i, f := range *fields {
        index[f.MapStructure] = i
    }
    // Parse package files to find Validate method on Config
    for _, file := range ctx.files {
        ast.Inspect(file, func(n ast.Node) bool {
            fd, ok := n.(*ast.FuncDecl)
            if !ok || fd.Recv == nil || fd.Name.Name != "Validate" || fd.Body == nil {
                return true
            }
            // Ensure receiver is *Config or Config
            if len(fd.Recv.List) == 0 {
                return true
            }
            // Only approximate: proceed
            // Look for if statements that return on error
            ast.Inspect(fd.Body, func(n ast.Node) bool {
                ifs, ok := n.(*ast.IfStmt)
                if !ok {
                    return true
                }
                // Check if body contains a return
                hasReturn := false
                ast.Inspect(ifs.Body, func(x ast.Node) bool {
                    if _, ok := x.(*ast.ReturnStmt); ok {
                        hasReturn = true
                        return false
                    }
                    return true
                })
                if !hasReturn {
                    return true
                }
                // Gather checks of nil/empty using && combinations
                keys, combined := gatherZeroChecks(ctx, rootName, ifs.Cond)
                if len(keys) == 0 {
                    return true
                }
                if combined && len(keys) >= 2 {
                    // mark involved keys as part of a group; component-level constraint assembled later
                    // annotate locally so UI can hint too
                    any := strings.Join(keys, ",")
                    for _, k := range keys {
                        if idx, ok := index[k]; ok {
                            if (*fields)[idx].Validation == nil {
                                (*fields)[idx].Validation = map[string]string{}
                            }
                            (*fields)[idx].Validation["anyOf"] = any
                        }
                    }
                } else {
                    // Mark individual required fields
                    for _, k := range keys {
                        if idx, ok := index[k]; ok {
                            (*fields)[idx].Required = true
                        }
                    }
                }
                return true
            })
            // Also scan for simple numeric bounds in conditions
            scanNumericBounds(ctx, rootName, fd.Body, fields)
            return false
        })
    }
}

func scanNumericBounds(ctx *packageContext, rootName string, body *ast.BlockStmt, fields *[]ConfigField) {
    // Build index for quick lookup
    index := map[string]int{}
    for i, f := range *fields {
        index[f.MapStructure] = i
    }
    ast.Inspect(body, func(n ast.Node) bool {
        be, ok := n.(*ast.BinaryExpr)
        if !ok {
            return true
        }
        // Pattern: selector op literal
        var selector ast.Expr
        var lit *ast.BasicLit
        var op token.Token = be.Op
        if s, ok := be.X.(*ast.SelectorExpr); ok {
            selector = s
        }
        if b, ok := be.Y.(*ast.BasicLit); ok {
            lit = b
        }
        // Also support reversed operand order
        if selector == nil || lit == nil {
            if s, ok := be.Y.(*ast.SelectorExpr); ok {
                selector = s
            }
            if b, ok := be.X.(*ast.BasicLit); ok {
                lit = b
            }
            // Reverse operator if swapped
            switch op {
            case token.LSS:
                op = token.GTR
            case token.GTR:
                op = token.LSS
            case token.LEQ:
                op = token.GEQ
            case token.GEQ:
                op = token.LEQ
            }
        }
        if selector == nil || lit == nil {
            return true
        }
        // Map selector to YAML key
        key := yamlKeyFromSelector(ctx, rootName, selector)
        if key == "" {
            return true
        }
        // Only handle numeric literals
        if lit.Kind != token.INT && lit.Kind != token.FLOAT {
            return true
        }
        if idx, ok := index[key]; ok {
            if (*fields)[idx].Validation == nil {
                (*fields)[idx].Validation = map[string]string{}
            }
            switch op {
            case token.LEQ:
                (*fields)[idx].Validation["minExclusive"] = lit.Value
            case token.LSS:
                (*fields)[idx].Validation["min"] = lit.Value
            case token.GEQ:
                (*fields)[idx].Validation["maxExclusive"] = lit.Value
            case token.GTR:
                (*fields)[idx].Validation["max"] = lit.Value
            }
        }
        return true
    })
}

func yamlKeyFromSelector(ctx *packageContext, rootName string, sel ast.Expr) string {
    path := selectorPath(sel)
    if len(path) == 0 { return "" }
    // drop receiver
    if len(path) > 0 { path = path[1:] }
    return mapGoPathToYAML(ctx, rootName, path)
}

func gatherZeroChecks(ctx *packageContext, rootName string, expr ast.Expr) ([]string, bool) {
    switch e := expr.(type) {
    case *ast.BinaryExpr:
        if e.Op == token.LAND {
            a, _ := gatherZeroChecks(ctx, rootName, e.X)
            b, _ := gatherZeroChecks(ctx, rootName, e.Y)
            return append(a, b...), true
        }
        if e.Op == token.EQL {
            if key := yamlKeyFromEquality(ctx, rootName, e.X, e.Y); key != "" {
                return []string{key}, false
            }
            if key := yamlKeyFromEquality(ctx, rootName, e.Y, e.X); key != "" {
                return []string{key}, false
            }
        }
    }
    return nil, false
}

func yamlKeyFromEquality(ctx *packageContext, rootName string, left ast.Expr, right ast.Expr) string {
    // left should be a selector path on receiver; right should be zero (nil or "")
    if !isZeroLiteral(right) {
        return ""
    }
    path := selectorPath(left)
    if len(path) == 0 {
        return ""
    }
    // Drop receiver identifier (first element)
    if len(path) > 0 {
        path = path[1:]
    }
    return mapGoPathToYAML(ctx, rootName, path)
}

func isZeroLiteral(e ast.Expr) bool {
    switch v := e.(type) {
    case *ast.Ident:
        return v.Name == "nil"
    case *ast.BasicLit:
        if v.Kind == token.STRING && v.Value == "\"\"" {
            return true
        }
        if v.Kind == token.INT && v.Value == "0" {
            return true
        }
    }
    return false
}

func selectorPath(e ast.Expr) []string {
    var parts []string
    for {
        switch s := e.(type) {
        case *ast.SelectorExpr:
            parts = append([]string{s.Sel.Name}, parts...)
            e = s.X
        case *ast.Ident:
            parts = append([]string{s.Name}, parts...)
            return parts
        default:
            return nil
        }
    }
}

func mapGoPathToYAML(ctx *packageContext, rootName string, goPath []string) string {
    st := ctx.types[rootName]
    if st == nil {
        return ""
    }
    var yamlParts []string
    cur := st
    for _, fieldName := range goPath {
        var decl *ast.Field
        var yamlToken string
        var hasSquash bool
        for _, f := range cur.Fields.List {
            if len(f.Names) > 0 && f.Names[0].Name == fieldName {
                decl = f
                break
            }
        }
        if decl == nil {
            return strings.Join(yamlParts, ".")
        }
        if decl.Tag != nil {
            tag := reflect.StructTag(strings.Trim(decl.Tag.Value, "`"))
            ms := tag.Get("mapstructure")
            if ms != "" {
                parts := strings.Split(ms, ",")
                if len(parts) > 0 {
                    yamlToken = parts[0]
                }
                if strings.Contains(ms, "squash") {
                    hasSquash = true
                }
            }
        }
        if yamlToken == "" && !hasSquash {
            yamlToken = strings.ToLower(fieldName)
        }
        if !hasSquash && yamlToken != "" {
            yamlParts = append(yamlParts, yamlToken)
        }
        // descend
        _, next := resolveStructFromExprWithCtx(ctx, decl.Type)
        if next == nil {
            // stop descent
            break
        }
        cur = next
    }
    return strings.Join(yamlParts, ".")
}

// --- Component-level constraints analysis ---
func analyzeConstraints(componentDir, configPath string) []Constraint {
    constraints := []Constraint{}
    ctx, err := loadPackage(componentDir, ".")
    if err != nil {
        return constraints
    }
    anyOfGroups := [][]string{}
    atMostOneGroups := [][]string{}

    for _, file := range ctx.files {
        ast.Inspect(file, func(n ast.Node) bool {
            fd, ok := n.(*ast.FuncDecl)
            if !ok || fd.Recv == nil || fd.Name.Name != "Validate" || fd.Body == nil {
                return true
            }
            ast.Inspect(fd.Body, func(n ast.Node) bool {
                ifs, ok := n.(*ast.IfStmt)
                if !ok {
                    return true
                }
                // anyOf: all zero => error
                keysZero, combinedZero := gatherZeroChecks(ctx, "Config", ifs.Cond)
                if combinedZero && len(keysZero) >= 2 {
                    anyOfGroups = append(anyOfGroups, dedupe(keysZero))
                }
                // atMostOne: all non-zero => error
                keysNonZero, combinedNonZero := gatherNonZeroChecks(ctx, "Config", ifs.Cond)
                if combinedNonZero && len(keysNonZero) >= 2 {
                    atMostOneGroups = append(atMostOneGroups, dedupe(keysNonZero))
                }
                return true
            })
            return false
        })
    }

    // Merge groups and upgrade to oneOf when both constraints exist for same key set
    // Track added groups using a signature of sorted keys
    added := map[string]struct{}{}
    for _, g := range anyOfGroups {
        kind := "anyOf"
        for _, h := range atMostOneGroups {
            if sameSet(g, h) { kind = "oneOf"; break }
        }
        sorted := uniqueSorted(g)
        sig := strings.Join(sorted, "|")
        tokens := make([][]string, 0, len(sorted))
        for _, k := range sorted { tokens = append(tokens, makePathTokens(k)) }
        constraints = append(constraints, Constraint{Kind: kind, KeyTokens: tokens})
        added[sig] = struct{}{}
    }
    // Add remaining atMostOne groups that weren't upgraded
    for _, g := range atMostOneGroups {
        sorted := uniqueSorted(g)
        sig := strings.Join(sorted, "|")
        if _, ok := added[sig]; ok { continue }
        tokens := make([][]string, 0, len(sorted))
        for _, k := range sorted { tokens = append(tokens, makePathTokens(k)) }
        constraints = append(constraints, Constraint{Kind: "atMostOne", KeyTokens: tokens})
    }
    return constraints
}

func gatherNonZeroChecks(ctx *packageContext, rootName string, expr ast.Expr) ([]string, bool) {
    switch e := expr.(type) {
    case *ast.BinaryExpr:
        if e.Op == token.LAND {
            a, _ := gatherNonZeroChecks(ctx, rootName, e.X)
            b, _ := gatherNonZeroChecks(ctx, rootName, e.Y)
            return append(a, b...), true
        }
        if e.Op == token.NEQ {
            if key := yamlKeyFromNonEquality(ctx, rootName, e.X, e.Y); key != "" {
                return []string{key}, false
            }
            if key := yamlKeyFromNonEquality(ctx, rootName, e.Y, e.X); key != "" {
                return []string{key}, false
            }
        }
    }
    return nil, false
}

func yamlKeyFromNonEquality(ctx *packageContext, rootName string, left ast.Expr, right ast.Expr) string {
    if !isZeroLiteral(right) {
        return ""
    }
    path := selectorPath(left)
    if len(path) == 0 {
        return ""
    }
    if len(path) > 0 {
        path = path[1:]
    }
    return mapGoPathToYAML(ctx, rootName, path)
}

func sameSet(a, b []string) bool {
    if len(a) != len(b) { return false }
    ma := map[string]int{}
    for _, x := range a { ma[x]++ }
    for _, y := range b { if ma[y] == 0 { return false } else { ma[y]-- } }
    for _, v := range ma { if v != 0 { return false } }
    return true
}

func dedupe(s []string) []string {
    m := map[string]struct{}{}
    out := []string{}
    for _, x := range s {
        if _, ok := m[x]; !ok {
            m[x] = struct{}{}
            out = append(out, x)
        }
    }
    return out
}

func uniqueSorted(s []string) []string {
    out := dedupe(s)
    // Not importing sort; simple insertion sort for small slices
    for i := 1; i < len(out); i++ {
        j := i
        for j > 0 && out[j] < out[j-1] {
            out[j], out[j-1] = out[j-1], out[j]
            j--
        }
    }
    return out
}

func extractType(expr ast.Expr) string {
    switch t := expr.(type) {
    case *ast.Ident:
        return t.Name
    case *ast.SelectorExpr:
        return fmt.Sprintf("%s.%s", extractType(t.X), t.Sel.Name)
    case *ast.ArrayType:
        return "[]" + extractType(t.Elt)
    case *ast.MapType:
        return fmt.Sprintf("map[%s]%s", extractType(t.Key), extractType(t.Value))
    case *ast.StarExpr:
        return "*" + extractType(t.X)
    case *ast.StructType:
        return "struct{}"
    case *ast.InterfaceType:
        return "interface{}"
    default:
        return fmt.Sprintf("%T", expr)
    }
}

func mapGoTypeToSwift(goType string) string {
    // Basic type mappings
    switch {
    case goType == "string":
        return "string"
    case goType == "bool":
        return "bool"
    case goType == "int" || goType == "int32" || goType == "int64":
        return "int"
    case goType == "uint" || goType == "uint32" || goType == "uint64":
        return "int"
    case goType == "float32" || goType == "float64":
        return "double"
    case goType == "time.Duration":
        return "duration"
    case strings.HasPrefix(goType, "[]string"):
        return "stringArray"
    case strings.HasPrefix(goType, "[]"):
        return "array"
    case strings.HasPrefix(goType, "map[string]"):
        return "stringMap"
    case strings.HasPrefix(goType, "map["):
        return "map"
    case strings.Contains(goType, "Level") || strings.Contains(goType, "Mode"):
        return "enum"
    default:
        return "custom"
    }
}

func extractComment(field *ast.Field) string {
    var comments []string

    // Check field comments
    if field.Comment != nil {
        for _, c := range field.Comment.List {
            text := strings.TrimPrefix(c.Text, "//")
            text = strings.TrimPrefix(text, " ")
            if text != "" {
                comments = append(comments, text)
            }
        }
    }

    // Check doc comments
    if field.Doc != nil {
        for _, c := range field.Doc.List {
            text := strings.TrimPrefix(c.Text, "//")
            text = strings.TrimPrefix(text, " ")
            if text != "" {
                comments = append(comments, text)
            }
        }
    }

    return strings.Join(comments, " ")
}

// --- Deep defaults extraction ---
func extractDefaultsDeep(componentDir, configPath, factoryPath string) []DefaultValue {
    var defaults []DefaultValue
    content, err := ioutil.ReadFile(factoryPath)
    if err != nil {
        return defaults
    }
    fset := token.NewFileSet()
    node, err := parser.ParseFile(fset, factoryPath, string(content), parser.ParseComments)
    if err != nil {
        return defaults
    }
    // Load package context for mapping Go field names to YAML keys
    ctx, err := loadPackage(componentDir, ".")
    if err != nil {
        return defaults
    }
    // Find createDefaultConfig function
    ast.Inspect(node, func(n ast.Node) bool {
        fn, ok := n.(*ast.FuncDecl)
        if !ok || fn.Name.Name != "createDefaultConfig" {
            return true
        }
        ast.Inspect(fn.Body, func(n ast.Node) bool {
            ret, ok := n.(*ast.ReturnStmt)
            if !ok || len(ret.Results) == 0 {
                return true
            }
            unary, ok := ret.Results[0].(*ast.UnaryExpr)
            if !ok || unary.Op != token.AND {
                return true
            }
            comp, ok := unary.X.(*ast.CompositeLit)
            if !ok {
                return true
            }
            // Determine root struct type name
            typeName := typeNameFromExpr(comp.Type)
            walkCompositeDefaults(ctx, ctx, typeName, comp, nil, nil, &defaults)
            return false
        })
        return false
    })
    return defaults
}

// New variant that reuses a parsed factory AST
func extractDefaultsDeepWithAST(componentDir, configPath string, fset *token.FileSet, factoryNode *ast.File) []DefaultValue {
    var defaults []DefaultValue
    if factoryNode == nil { return defaults }
    // Load package context for mapping Go field names to YAML keys
    ctx, err := loadPackage(componentDir, ".")
    if err != nil { return defaults }

    ast.Inspect(factoryNode, func(n ast.Node) bool {
        fn, ok := n.(*ast.FuncDecl)
        if !ok || fn.Name.Name != "createDefaultConfig" || fn.Body == nil {
            return true
        }

        // First: collect variable initializations and field updates within createDefaultConfig
        varStates := collectVarDefaults(ctx, fn)

        // Then: locate the returned &Config{...} and walk it; when encountering identifiers bound to collected vars,
        // merge their composite defaults and assignment updates under the appropriate YAML path.
        ast.Inspect(fn.Body, func(n ast.Node) bool {
            ret, ok := n.(*ast.ReturnStmt)
            if !ok || len(ret.Results) == 0 { return true }
            expr := ret.Results[0]
            if unary, ok := expr.(*ast.UnaryExpr); ok && unary.Op == token.AND {
                if comp, ok := unary.X.(*ast.CompositeLit); ok {
                    typeName := typeNameFromExpr(comp.Type)
                    walkCompositeWithVars(ctx, typeName, comp, nil, nil, varStates, &defaults)
                    return false
                }
            }
            if ident, ok := expr.(*ast.Ident); ok {
                if vd := varStates[ident.Name]; vd != nil && vd.comp != nil && vd.typeName != "" {
                    walkCompositeWithVars(ctx, vd.typeName, vd.comp, nil, nil, varStates, &defaults)
                    return false
                }
            }
            return true
        })
        return false
    })
    _ = fset // reserved
    return defaults
}

type fieldUpdate struct {
    path []string
    expr ast.Expr
}

type varDefaults struct {
    typeName string
    pkg      *packageContext
    comp     *ast.CompositeLit
    updates  []fieldUpdate
}

func collectVarDefaults(ctx *packageContext, fn *ast.FuncDecl) map[string]*varDefaults {
    vars := map[string]*varDefaults{}
    ast.Inspect(fn.Body, func(n ast.Node) bool {
        as, ok := n.(*ast.AssignStmt)
        if !ok { return true }
        if len(as.Lhs) != 1 || len(as.Rhs) != 1 { return true }
        // Variable declaration or update
        switch lhs := as.Lhs[0].(type) {
        case *ast.Ident:
            // Declaration or reassignment
            switch rhs := as.Rhs[0].(type) {
            case *ast.CompositeLit:
                tname := typeNameFromExpr(rhs.Type)
                vars[lhs.Name] = &varDefaults{typeName: tname, pkg: ctx, comp: rhs}
            case *ast.UnaryExpr:
                if rhs.Op == token.AND {
                    if c, ok := rhs.X.(*ast.CompositeLit); ok {
                        tname := typeNameFromExpr(c.Type)
                        vars[lhs.Name] = &varDefaults{typeName: tname, pkg: ctx, comp: c}
                    }
                }
            case *ast.CallExpr:
                if nctx, ntype, ncomp := resolveConstructorToComposite(ctx, ctx, rhs); ncomp != nil {
                    vars[lhs.Name] = &varDefaults{typeName: ntype, pkg: nctx, comp: ncomp}
                }
            }
        case *ast.SelectorExpr:
            // Field update on a tracked variable
            // Build selector path and see if it starts with an ident var
            path := selectorPath(lhs)
            if len(path) < 2 { return true }
            base := path[0]
            if st := vars[base]; st != nil {
                // Drop base ident; store path relative to struct
                rel := path[1:]
                st.updates = append(st.updates, fieldUpdate{path: rel, expr: as.Rhs[0]})
            }
        }
        return true
    })
    return vars
}

func walkCompositeWithVars(rootCtx *packageContext, structTypeName string, comp *ast.CompositeLit, goPath []string, yamlPath []string, vars map[string]*varDefaults, out *[]DefaultValue) {
    ctx := rootCtx
    st := ctx.types[structTypeName]
    if st == nil { return }
    for _, elt := range comp.Elts {
        kv, ok := elt.(*ast.KeyValueExpr)
        if !ok { continue }
        fieldName := extractIdentifier(kv.Key)
        if fieldName == "" { continue }
        // Find field decl and mapstructure
        var fieldDecl *ast.Field
        for _, f := range st.Fields.List {
            if len(f.Names) > 0 && f.Names[0].Name == fieldName { fieldDecl = f; break }
        }
        yamlToken := ""
        hasSquash := false
        if fieldDecl != nil && fieldDecl.Tag != nil {
            tag := reflect.StructTag(strings.Trim(fieldDecl.Tag.Value, "`"))
            ms := tag.Get("mapstructure")
            if ms != "" {
                parts := strings.Split(ms, ",")
                if len(parts) > 0 && parts[0] != "" { yamlToken = parts[0] }
                if strings.Contains(ms, "squash") { hasSquash = true }
            }
        }
        if yamlToken == "" && !hasSquash {
            yamlToken = guessYAMLTokenFromGoName(fieldName)
        }
        newGoPath := append(append([]string{}, goPath...), fieldName)
        newYamlPath := append([]string{}, yamlPath...)
        if !hasSquash && yamlToken != "" { newYamlPath = append(newYamlPath, yamlToken) }

        // Cases: nested composite, call, identifier var, or leaf value
        if nested, ok := kv.Value.(*ast.CompositeLit); ok {
            // Determine nested struct type from field type or explicit literal type
            var nestedTypeName string
            var nestedStruct *ast.StructType
            if fieldDecl != nil {
                nestedStruct = resolveStructFromExpr(ctx, fieldDecl.Type)
                nestedTypeName = typeNameFromExpr(fieldDecl.Type)
            }
            if nestedStruct == nil && nested.Type != nil {
                nestedStruct = resolveStructFromExpr(ctx, nested.Type)
                nestedTypeName = typeNameFromExpr(nested.Type)
            }
            if nestedStruct != nil && nestedTypeName != "" {
                walkCompositeWithVars(rootCtx, nestedTypeName, nested, newGoPath, newYamlPath, vars, out)
            }
            continue
        }
        if u, ok := kv.Value.(*ast.UnaryExpr); ok && u.Op == token.AND {
            if nested, ok := u.X.(*ast.CompositeLit); ok {
                var nestedTypeName string
                var nestedStruct *ast.StructType
                if fieldDecl != nil {
                    nestedStruct = resolveStructFromExpr(ctx, fieldDecl.Type)
                    nestedTypeName = typeNameFromExpr(fieldDecl.Type)
                }
                if nestedStruct == nil && nested.Type != nil {
                    nestedStruct = resolveStructFromExpr(ctx, nested.Type)
                    nestedTypeName = typeNameFromExpr(nested.Type)
                }
                if nestedStruct != nil && nestedTypeName != "" {
                    walkCompositeWithVars(rootCtx, nestedTypeName, nested, newGoPath, newYamlPath, vars, out)
                    continue
                }
            }
        }
        if call, ok := kv.Value.(*ast.CallExpr); ok {
            if nctx, ntype, ncomp := resolveConstructorToComposite(rootCtx, ctx, call); ncomp != nil {
                walkCompositeWithVars(nctx, ntype, ncomp, newGoPath, newYamlPath, vars, out)
                continue
            }
        }
        if ident, ok := kv.Value.(*ast.Ident); ok {
            // Merge defaults for referenced variable if tracked
            if vd := vars[ident.Name]; vd != nil {
                if vd.comp != nil && vd.typeName != "" {
                    walkCompositeWithVars(vd.pkg, vd.typeName, vd.comp, nil, newYamlPath, vars, out)
                }
                // Apply assignment updates captured for this var
                for _, upd := range vd.updates {
                    relYaml := mapGoPathToYAML(vd.pkg, vd.typeName, upd.path)
                    parts := append([]string{}, newYamlPath...)
                    if relYaml != "" { parts = append(parts, relYaml) }
                    full := strings.Join(parts, ".")
                    val := extractLiteralValue(upd.expr)
                    if val == nil {
                        if id, ok := upd.expr.(*ast.Ident); ok {
                            if rv, ok := resolveTopLevelIdent(vd.pkg, id.Name); ok { val = rv }
                        }
                    }
                    if val != nil {
                        *out = append(*out, DefaultValue{FieldName: strings.Join(append([]string{}, upd.path...), "."), YamlKey: full, Value: val})
                    }
                }
                continue
            }
        }
        // Leaf value
        val := extractLiteralValue(kv.Value)
        if val == nil {
            if id, ok := kv.Value.(*ast.Ident); ok {
                if rv, ok := resolveTopLevelIdent(ctx, id.Name); ok { val = rv }
            }
        }
        if val != nil {
            *out = append(*out, DefaultValue{FieldName: strings.Join(newGoPath, "."), YamlKey: strings.Join(newYamlPath, "."), Value: val})
        }
    }
}

func typeNameFromExpr(expr ast.Expr) string {
    switch t := expr.(type) {
    case *ast.Ident:
        return t.Name
    case *ast.SelectorExpr:
        return t.Sel.Name
    case *ast.StarExpr:
        return typeNameFromExpr(t.X)
    default:
        return ""
    }
}

func walkCompositeDefaults(rootCtx *packageContext, ctx *packageContext, structTypeName string, comp *ast.CompositeLit, goPath []string, yamlPath []string, out *[]DefaultValue) {
    st := ctx.types[structTypeName]
    if st == nil {
        return
    }
    for _, elt := range comp.Elts {
        kv, ok := elt.(*ast.KeyValueExpr)
        if !ok {
            continue
        }
        fieldName := extractIdentifier(kv.Key)
        if fieldName == "" {
            continue
        }
        // Map Go field name to YAML token via mapstructure on this struct
        var fieldDecl *ast.Field
        for _, f := range st.Fields.List {
            if len(f.Names) > 0 && f.Names[0].Name == fieldName {
                fieldDecl = f
                break
            }
            // Match anonymous embedded field by type name (for keyed composites on embedded fields)
            if len(f.Names) == 0 {
                if typeNameFromExpr(f.Type) == fieldName {
                    fieldDecl = f
                    break
                }
            }
        }
        // Derive YAML token respecting mapstructure and squash
        yamlToken := ""
        hasSquash := false
        if fieldDecl != nil && fieldDecl.Tag != nil {
            tag := reflect.StructTag(strings.Trim(fieldDecl.Tag.Value, "`"))
            ms := tag.Get("mapstructure")
            if ms != "" {
                parts := strings.Split(ms, ",")
                if len(parts) > 0 && parts[0] != "" {
                    yamlToken = parts[0]
                }
                if strings.Contains(ms, "squash") {
                    hasSquash = true
                }
            }
        }
        if yamlToken == "" && !hasSquash {
            // Fallback to snake_case of Go field name
            yamlToken = guessYAMLTokenFromGoName(fieldName)
        }
        newGoPath := append(append([]string{}, goPath...), fieldName)
        newYamlPath := append([]string{}, yamlPath...)
        if !hasSquash && yamlToken != "" {
            newYamlPath = append(newYamlPath, yamlToken)
        }

        // Nested struct literal or constructor returning a struct literal
        if nested, ok := kv.Value.(*ast.CompositeLit); ok {
            // Determine nested struct type from field type or explicit literal type
            var nestedTypeName string
            var nestedStruct *ast.StructType
            if fieldDecl != nil {
                nestedStruct = resolveStructFromExpr(ctx, fieldDecl.Type)
                nestedTypeName = typeNameFromExpr(fieldDecl.Type)
            }
            if nestedStruct == nil && nested.Type != nil {
                nestedStruct = resolveStructFromExpr(ctx, nested.Type)
                nestedTypeName = typeNameFromExpr(nested.Type)
            }
            if nestedStruct != nil && nestedTypeName != "" {
                walkCompositeDefaults(rootCtx, ctx, nestedTypeName, nested, newGoPath, newYamlPath, out)
            }
            continue
        }
        if u, ok := kv.Value.(*ast.UnaryExpr); ok && u.Op == token.AND {
            if nested, ok := u.X.(*ast.CompositeLit); ok {
                var nestedTypeName string
                var nestedStruct *ast.StructType
                if fieldDecl != nil {
                    nestedStruct = resolveStructFromExpr(ctx, fieldDecl.Type)
                    nestedTypeName = typeNameFromExpr(fieldDecl.Type)
                }
                if nestedStruct == nil && nested.Type != nil {
                    nestedStruct = resolveStructFromExpr(ctx, nested.Type)
                    nestedTypeName = typeNameFromExpr(nested.Type)
                }
                if nestedStruct != nil && nestedTypeName != "" {
                    walkCompositeDefaults(rootCtx, ctx, nestedTypeName, nested, newGoPath, newYamlPath, out)
                }
                continue
            }
        }
        if call, ok := kv.Value.(*ast.CallExpr); ok {
            if nctx, ntype, ncomp := resolveConstructorToComposite(rootCtx, ctx, call); nctx != nil && ntype != "" && ncomp != nil {
                walkCompositeDefaults(rootCtx, nctx, ntype, ncomp, newGoPath, newYamlPath, out)
                continue
            }
        }
        // Leaf value
        val := extractLiteralValue(kv.Value)
        if val == nil {
            if id, ok := kv.Value.(*ast.Ident); ok {
                if rv, ok := resolveTopLevelIdent(ctx, id.Name); ok {
                    val = rv
                }
            }
        }
        if val != nil {
            *out = append(*out, DefaultValue{
                FieldName: strings.Join(newGoPath, "."),
                YamlKey:   strings.Join(newYamlPath, "."),
                Value:     val,
            })
        }
    }
}

// resolveConstructorToComposite attempts to resolve a function call (possibly from an imported package)
// to a returned struct composite literal like: return &Type{ ... } or return Type{ ... }.
func resolveConstructorToComposite(rootCtx, ctx *packageContext, call *ast.CallExpr) (*packageContext, string, *ast.CompositeLit) {
    switch fun := call.Fun.(type) {
    case *ast.Ident:
        // Local function in the same package
        if fd := findFuncDecl(ctx, fun.Name); fd != nil {
            if tname, comp := findReturnedComposite(fd); comp != nil {
                return ctx, tname, comp
            }
        }
    case *ast.SelectorExpr:
        // Package-qualified: alias.Func
        if alias, ok := fun.X.(*ast.Ident); ok {
            importPath := ctx.imports[alias.Name]
            if importPath != "" {
                if pc, err := loadPackage(ctx.dir, importPath); err == nil && pc != nil {
                    if fd := findFuncDecl(pc, fun.Sel.Name); fd != nil {
                        if tname, comp := findReturnedComposite(fd); comp != nil {
                            return pc, tname, comp
                        }
                    }
                }
            }
        }
    }
    return nil, "", nil
}

func findFuncDecl(ctx *packageContext, name string) *ast.FuncDecl {
    for _, f := range ctx.files {
        for _, d := range f.Decls {
            if fd, ok := d.(*ast.FuncDecl); ok {
                if fd.Name.Name == name && fd.Body != nil {
                    return fd
                }
            }
        }
    }
    return nil
}

func findReturnedComposite(fd *ast.FuncDecl) (string, *ast.CompositeLit) {
    var comp *ast.CompositeLit
    var typeName string
    ast.Inspect(fd.Body, func(n ast.Node) bool {
        ret, ok := n.(*ast.ReturnStmt)
        if !ok || len(ret.Results) == 0 { return true }
        expr := ret.Results[0]
        // handle &Type{...}
        if u, ok := expr.(*ast.UnaryExpr); ok && u.Op == token.AND {
            if c, ok := u.X.(*ast.CompositeLit); ok {
                comp = c
                typeName = typeNameFromExpr(c.Type)
                return false
            }
        }
        if c, ok := expr.(*ast.CompositeLit); ok {
            comp = c
            typeName = typeNameFromExpr(c.Type)
            return false
        }
        return true
    })
    return typeName, comp
}

func extractIdentifier(expr ast.Expr) string {
    if ident, ok := expr.(*ast.Ident); ok {
        return ident.Name
    }
    return ""
}

func extractLiteralValue(expr ast.Expr) interface{} {
    switch v := expr.(type) {
    case *ast.BasicLit:
        switch v.Kind {
        case token.STRING:
            // Remove quotes
            str := v.Value
            if len(str) >= 2 {
                str = str[1 : len(str)-1]
            }
            return str
        case token.INT:
            if i, err := strconv.ParseInt(v.Value, 10, 64); err == nil { return i }
            return v.Value
        case token.FLOAT:
            if f, err := strconv.ParseFloat(v.Value, 64); err == nil { return f }
            return v.Value
        }
    case *ast.Ident:
        switch v.Name {
        case "true":
            return true
        case "false":
            return false
        default:
            // Defer to resolveTopLevelIdent to get the actual value; returning nil here lets callers attempt resolution.
            return nil
        }
    case *ast.SelectorExpr:
        // Handle things like configtelemetry.LevelBasic
        return fmt.Sprintf("%s.%s", extractIdentifier(v.X), v.Sel.Name)
    case *ast.CompositeLit:
        // Arrays/slices: attempt to extract simple literal arrays
        switch v.Type.(type) {
        case *ast.ArrayType:
            var arr []interface{}
            for _, e := range v.Elts {
                // Array elements are expressions, not key-value
                if val := extractLiteralValue(e); val != nil {
                    arr = append(arr, val)
                } else {
                    // If any element is non-literal, bail out
                    return nil
                }
            }
            return arr
        case *ast.MapType:
            // Maps: expect KeyValueExpr entries; keys should stringify
            m := map[string]interface{}{}
            for _, e := range v.Elts {
                kv, ok := e.(*ast.KeyValueExpr)
                if !ok { return nil }
                k := extractLiteralValue(kv.Key)
                val := extractLiteralValue(kv.Value)
                ks, ok := k.(string)
                if !ok { return nil }
                if val == nil { return nil }
                m[ks] = val
            }
            return m
        default:
            // Unknown composite (likely struct). Let caller recurse if needed.
            return nil
        }
    case *ast.BinaryExpr:
        if s := tryDurationString(v); s != "" {
            return s
        }
        if n, ok := evalNumericBinary(v); ok { return n }
        return nil
    case *ast.CallExpr:
        // Handle simple type conversions like uint32(8192) or time.Duration(0)
        if len(v.Args) == 1 {
            if _, ok := v.Fun.(*ast.Ident); ok {
                if val := extractLiteralValue(v.Args[0]); val != nil { return val }
            }
        }
        return nil
    }
    return nil
}

// Evaluate numeric binary expressions with literal operands.
func evalNumericBinary(be *ast.BinaryExpr) (interface{}, bool) {
    lx, lok := evalNumeric(be.X)
    ly, rok := evalNumeric(be.Y)
    if !lok || !rok { return nil, false }
    switch be.Op {
    case token.ADD:
        return lx + ly, true
    case token.SUB:
        return lx - ly, true
    case token.MUL:
        return lx * ly, true
    case token.QUO:
        if ly == 0 { return nil, false }
        return lx / ly, true
    default:
        return nil, false
    }
}

func evalNumeric(expr ast.Expr) (float64, bool) {
    switch v := expr.(type) {
    case *ast.BasicLit:
        switch v.Kind {
        case token.INT:
            if i, err := strconv.ParseInt(v.Value, 10, 64); err == nil { return float64(i), true }
        case token.FLOAT:
            if f, err := strconv.ParseFloat(v.Value, 64); err == nil { return f, true }
        }
        return 0, false
    case *ast.UnaryExpr:
        f, ok := evalNumeric(v.X)
        if !ok { return 0, false }
        switch v.Op {
        case token.ADD:
            return +f, true
        case token.SUB:
            return -f, true
        default:
            return 0, false
        }
    case *ast.BinaryExpr:
        if s := tryDurationString(v); s != "" { return 0, false }
        if n, ok := evalNumericBinary(v); ok {
            switch t := n.(type) {
            case float64:
                return t, true
            case int64:
                return float64(t), true
            case int:
                return float64(t), true
            }
        }
        return 0, false
    default:
        return 0, false
    }
}

// tryDurationString attempts to convert expressions like 15 * time.Second or time.Millisecond * 500 into "15s" / "500ms".
func tryDurationString(be *ast.BinaryExpr) string {
    if be.Op != token.MUL && be.Op != token.QUO { return "" }
    // Normalize order: int * SelectorExpr or SelectorExpr * int
    var factor string
    var unit string
    if lit, ok := be.X.(*ast.BasicLit); ok && lit.Kind == token.INT {
        factor = lit.Value
        if sel, ok := be.Y.(*ast.SelectorExpr); ok {
            unit = sel.Sel.Name
        }
    } else if lit, ok := be.Y.(*ast.BasicLit); ok && lit.Kind == token.INT {
        factor = lit.Value
        if sel, ok := be.X.(*ast.SelectorExpr); ok {
            unit = sel.Sel.Name
        }
    }
    if factor == "" || unit == "" { return "" }
    switch unit {
    case "Second", "Seconds":
        return factor + "s"
    case "Millisecond", "Milliseconds":
        return factor + "ms"
    case "Microsecond", "Microseconds":
        return factor + "us"
    case "Nanosecond", "Nanoseconds":
        return factor + "ns"
    case "Minute", "Minutes":
        return factor + "m"
    case "Hour", "Hours":
        return factor + "h"
    default:
        return ""
    }
}

// resolveTopLevelIdent tries to resolve a package-level constant or var to a literal value.
func resolveTopLevelIdent(ctx *packageContext, name string) (interface{}, bool) {
    for _, f := range ctx.files {
        for _, d := range f.Decls {
            gd, ok := d.(*ast.GenDecl)
            if !ok { continue }
            if gd.Tok != token.CONST && gd.Tok != token.VAR { continue }
            for _, s := range gd.Specs {
                vs, ok := s.(*ast.ValueSpec)
                if !ok { continue }
                for i, n := range vs.Names {
                    if n.Name != name { continue }
                    if i < len(vs.Values) {
                        if v := extractLiteralValue(vs.Values[i]); v != nil { return v, true }
                        // Try numeric/evaluable expressions (e.g., 512*1024)
                        if be, ok := vs.Values[i].(*ast.BinaryExpr); ok {
                            if n, ok := evalNumericBinary(be); ok { return n, true }
                        }
                    }
                }
            }
        }
    }
    return nil, false
}
