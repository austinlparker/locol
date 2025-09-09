package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"
)

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
	Value     interface{} `json:"value"`
}

// Command line flags
var (
	version      = flag.String("version", "", "Collector version being extracted")
	collectorPath = flag.String("collector-path", "", "Path to opentelemetry-collector repo")
	contribPath  = flag.String("contrib-path", "", "Path to opentelemetry-collector-contrib repo")
	output       = flag.String("output", "configs.json", "Output JSON file")
)

func main() {
	flag.Parse()

	if *version == "" || *collectorPath == "" || *contribPath == "" {
		fmt.Println("Usage: go run extract_configs.go --version=v0.91.0 --collector-path=../opentelemetry-collector --contrib-path=../opentelemetry-collector-contrib --output=configs.json")
		os.Exit(1)
	}

	fmt.Printf("Extracting configs for version %s\n", *version)

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

	componentTypes := []string{"receiver", "processor", "exporter", "extension", "connector"}

	for _, componentType := range componentTypes {
		typePath := filepath.Join(basePath, componentType)
		if _, err := os.Stat(typePath); os.IsNotExist(err) {
			continue
		}

		// Find all component directories
		dirs, err := ioutil.ReadDir(typePath)
		if err != nil {
			continue
		}

		for _, dir := range dirs {
			if !dir.IsDir() {
				continue
			}

			componentPath := filepath.Join(typePath, dir.Name())
			configPath := filepath.Join(componentPath, "config.go")

			// Skip if no config.go
			if _, err := os.Stat(configPath); os.IsNotExist(err) {
				continue
			}

			component := extractComponent(componentPath, dir.Name(), componentType, isContrib)
			if component != nil {
				components = append(components, *component)
			}
		}
	}

	return components
}

func extractComponent(componentPath, name, componentType string, isContrib bool) *Component {
	configPath := filepath.Join(componentPath, "config.go")
	factoryPath := filepath.Join(componentPath, "factory.go")

	// Extract config structure
	configSchema, err := extractConfigSchema(configPath)
	if err != nil {
		fmt.Printf("Warning: failed to extract config for %s: %v\n", name, err)
		return nil
	}

	// Extract defaults from factory
	defaults := extractDefaults(factoryPath)
	configSchema.Defaults = defaults

	// Build module path
	modulePath := fmt.Sprintf("go.opentelemetry.io/collector/%s/%s", componentType, name)
	if isContrib {
		modulePath = fmt.Sprintf("github.com/open-telemetry/opentelemetry-collector-contrib/%s/%s", componentType, name)
	}

	component := &Component{
		Name:   name,
		Type:   componentType,
		Module: modulePath,
		Config: *configSchema,
	}

	return component
}

func extractConfigSchema(configPath string) (*ConfigSchema, error) {
	content, err := ioutil.ReadFile(configPath)
	if err != nil {
		return nil, err
	}

	fset := token.NewFileSet()
	node, err := parser.ParseFile(fset, configPath, string(content), parser.ParseComments)
	if err != nil {
		return nil, err
	}

	schema := &ConfigSchema{
		Fields: []ConfigField{},
	}

	// Find Config structs
	ast.Inspect(node, func(n ast.Node) bool {
		ts, ok := n.(*ast.TypeSpec)
		if !ok {
			return true
		}

		st, ok := ts.Type.(*ast.StructType)
		if !ok || !strings.Contains(ts.Name.Name, "Config") {
			return true
		}

		schema.StructName = ts.Name.Name

		// Extract fields
		for _, field := range st.Fields.List {
			configField := extractField(field)
			if configField != nil {
				schema.Fields = append(schema.Fields, *configField)
			}
		}

		return true
	})

	return schema, nil
}

func extractField(field *ast.Field) *ConfigField {
	if field.Tag == nil {
		return nil
	}

	tag := reflect.StructTag(strings.Trim(field.Tag.Value, "`"))
	mapstructure := tag.Get("mapstructure")

	// Skip fields without mapstructure or with squash
	if mapstructure == "" || strings.Contains(mapstructure, "squash") {
		return nil
	}

	// Extract field name
	fieldName := ""
	if len(field.Names) > 0 {
		fieldName = field.Names[0].Name
	}

	// Extract type information
	goType := extractType(field.Type)
	swiftType := mapGoTypeToSwift(goType)

	// Extract comments
	comment := extractComment(field)

	// Determine if required (basic heuristic)
	required := !strings.Contains(mapstructure, "omitempty")

	configField := &ConfigField{
		Name:         fieldName,
		Type:         swiftType,
		GoType:       goType,
		MapStructure: strings.Split(mapstructure, ",")[0], // Remove omitempty etc
		Description:  comment,
		Required:     required,
	}

	return configField
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

func extractDefaults(factoryPath string) []DefaultValue {
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

	// Find createDefaultConfig function
	ast.Inspect(node, func(n ast.Node) bool {
		fn, ok := n.(*ast.FuncDecl)
		if !ok || fn.Name.Name != "createDefaultConfig" {
			return true
		}

		// Look for return statement with struct literal
		ast.Inspect(fn.Body, func(n ast.Node) bool {
			ret, ok := n.(*ast.ReturnStmt)
			if !ok || len(ret.Results) == 0 {
				return true
			}

			// Look for &Config{...} pattern
			unary, ok := ret.Results[0].(*ast.UnaryExpr)
			if !ok || unary.Op != token.AND {
				return true
			}

			comp, ok := unary.X.(*ast.CompositeLit)
			if !ok {
				return true
			}

			// Extract field assignments
			for _, elt := range comp.Elts {
				kv, ok := elt.(*ast.KeyValueExpr)
				if !ok {
					continue
				}

				fieldName := extractIdentifier(kv.Key)
				value := extractLiteralValue(kv.Value)

				if fieldName != "" && value != nil {
					defaults = append(defaults, DefaultValue{
						FieldName: fieldName,
						Value:     value,
					})
				}
			}

			return false
		})

		return false
	})

	return defaults
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