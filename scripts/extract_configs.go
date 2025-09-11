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
)

// Debug logging (enabled when LOCOL_DEBUG=1)
var debug = os.Getenv("LOCOL_DEBUG") == "1"

func dbgf(format string, args ...interface{}) {
    if debug {
        fmt.Fprintf(os.Stderr, format, args...)
    }
}

// Output structures
type ExtractedData struct {
	Version    string      `json:"version"`
	Components []Component `json:"components"`
}

type Component struct {
    Name        string       `json:"name"`
    Type        string       `json:"type"` // receiver, processor, exporter
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
            dbgf("[extractor] ✓ extracted %s/%s fields=%d defaults=%d constraints=%d\n",
                c.Type, c.Name, len(c.Config.Fields), len(c.Config.Defaults), len(c.Constraints))
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
    configSchema.Defaults = defaults

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
    ctx, err := loadPackage(componentDir, ".")
    if err != nil {
        return nil, err
    }

    schema := &ConfigSchema{Fields: []ConfigField{}}

    // Locate the canonical root config struct.
    // 1) Prefer the factory-declared root type when present.
    var rootStruct *ast.StructType
    var rootName string
    if preferredRoot != "" {
        if st, ok := ctx.types[preferredRoot]; ok {
            rootStruct = st
            rootName = preferredRoot
        }
    }
    // 2) Fallback to exact "Config"
    if rootStruct == nil {
        if st, ok := ctx.types["Config"]; ok {
            rootStruct = st
            rootName = "Config"
        }
    }
    // 3) As a last resort, pick the *Config with most mapstructure-tagged fields
    if rootStruct == nil {
        bestCount := -1
        for name, st := range ctx.types {
            if !strings.HasSuffix(name, "Config") { continue }
            cnt := countMapstructureFields(st)
            if cnt > bestCount { bestCount = cnt; rootStruct = st; rootName = name }
        }
    }
    if rootStruct == nil {
        return schema, nil
    }
    schema.StructName = rootName
    dbgf("[extractor] using root struct: %s\n", rootName)

    visited := map[string]int{}
    fields := []ConfigField{}
    extractStructFields(ctx, rootStruct, "", &fields, visited)
    // Augment with Validate() insights (field-level)
    applyValidationHeuristics(componentDir, ctx, rootName, &fields)
    schema.Fields = fields
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
        required := mapstruct != "" && !strings.Contains(mapstruct, "omitempty")
        *out = append(*out, ConfigField{
            Name:         fieldName,
            Type:         swiftType,
            GoType:       goType,
            MapStructure: fullKey,
            Description:  comment,
            Required:     required,
        })
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
                yamlToken = strings.Split(ms, ",")[0]
            }
        }
        if yamlToken == "" {
            yamlToken = strings.ToLower(fieldName)
        }
        yamlParts = append(yamlParts, yamlToken)
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
    for _, g := range anyOfGroups {
        kind := "anyOf"
        // If an atMostOne group exists with the same keys (order-insensitive), upgrade to oneOf
        for _, h := range atMostOneGroups {
            if sameSet(g, h) {
                kind = "oneOf"
                break
            }
        }
        constraints = append(constraints, Constraint{Kind: kind, Keys: uniqueSorted(g)})
    }
    // Add remaining atMostOne groups that weren't upgraded
    for _, g := range atMostOneGroups {
        upgraded := false
        for _, c := range constraints {
            if (c.Kind == "oneOf" || c.Kind == "anyOf") && sameSet(c.Keys, g) {
                upgraded = true
                break
            }
        }
        if !upgraded {
            constraints = append(constraints, Constraint{Kind: "atMostOne", Keys: uniqueSorted(g)})
        }
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
        ast.Inspect(fn.Body, func(n ast.Node) bool {
            ret, ok := n.(*ast.ReturnStmt)
            if !ok || len(ret.Results) == 0 { return true }
            unary, ok := ret.Results[0].(*ast.UnaryExpr)
            if !ok || unary.Op != token.AND { return true }
            comp, ok := unary.X.(*ast.CompositeLit)
            if !ok { return true }
            // Determine root struct type name
            typeName := typeNameFromExpr(comp.Type)
            walkCompositeDefaults(ctx, ctx, typeName, comp, nil, nil, &defaults)
            return false
        })
        return false
    })
    _ = fset // reserved for potential future use
    return defaults
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
        }
        yamlToken := fieldName
        if fieldDecl != nil && fieldDecl.Tag != nil {
            tag := reflect.StructTag(strings.Trim(fieldDecl.Tag.Value, "`"))
            ms := tag.Get("mapstructure")
            if ms != "" {
                yamlToken = strings.Split(ms, ",")[0]
            }
        }
        newGoPath := append(append([]string{}, goPath...), fieldName)
        newYamlPath := append(append([]string{}, yamlPath...), yamlToken)

        // Nested struct literal
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
        // Leaf value
        if val := extractLiteralValue(kv.Value); val != nil {
            *out = append(*out, DefaultValue{
                FieldName: strings.Join(newGoPath, "."),
                YamlKey:   strings.Join(newYamlPath, "."),
                Value:     val,
            })
        }
    }
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
			return v.Value
		case token.FLOAT:
			return v.Value
		}
	case *ast.Ident:
		switch v.Name {
		case "true":
			return true
		case "false":
			return false
		}
		return v.Name // For constants
	case *ast.SelectorExpr:
		// Handle things like configtelemetry.LevelBasic
		return fmt.Sprintf("%s.%s", extractIdentifier(v.X), v.Sel.Name)
	}
	return nil
}
