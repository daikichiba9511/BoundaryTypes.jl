# BoundaryTypes.jl Examples

This directory contains practical examples demonstrating how to use BoundaryTypes.jl in various scenarios.

## Running the Examples

All examples are standalone Julia scripts that can be executed directly:

```bash
cd examples
julia --project=.. 01_basic_usage.jl
```

Or from the project root:

```bash
julia --project=. examples/01_basic_usage.jl
```

## Examples Overview

### 01_basic_usage.jl
**Fundamentals of BoundaryTypes.jl**

Learn the core concepts:
- Defining models with `@model`
- Creating validation rules with `@rules`
- Validating input with `model_validate`
- Safe validation with `try_model_validate`
- Working with optional fields
- Handling multiple validation errors

Perfect for getting started!

### 02_advanced_rules.jl
**Advanced Validation Rules**

Explore advanced rule types:
- String validation: `email()`, `url()`, `uuid()`, `choices()`
- Numeric constraints: `gt()`, `lt()`, `between()`, `multiple_of()`
- Custom validation rules with `custom()`
- Secret field masking with `secret()`
- Combining multiple rules

Great for understanding the full power of validation rules.

### 03_nested_models.jl
**Nested Struct Validation**

Work with hierarchical data:
- Simple nested models
- Multi-level nesting (nested within nested)
- Optional nested models
- Automatic recursive validation
- Error paths in nested structures

Essential for complex domain models.

### 04_collections.jl
**Collection Validation**

Validate arrays, vectors, and sets:
- Basic collection validation with `each()`
- Numeric collection constraints
- Multiple collection rules
- Set validation
- Optional collections
- Complex collection scenarios (e.g., email lists)

Learn how to validate collections of data.

### 05_error_handling.jl
**Error Handling Patterns**

Master error handling:
- Throwing vs non-throwing validation
- Comprehensive error collection
- Working with `ValidationError` and `FieldError`
- Filtering and categorizing errors
- Custom error handling logic
- JSON error responses for APIs
- Graceful degradation patterns

Critical for production applications.

### 06_real_world.jl
**Real-World Use Cases**

See practical applications:
- Web API request validation
- Configuration file validation
- E-commerce order processing
- Data import/ETL pipelines

Shows how to integrate BoundaryTypes.jl into real applications.

## Using Examples with VSCode

These examples are designed to work well with the Julia VSCode extension:

1. **Open in VSCode**: Open the project in VSCode with the Julia extension installed
2. **Hover for docs**: Hover over functions like `email()`, `minlen()`, etc. to see documentation
3. **Go to definition**: Cmd/Ctrl+Click on functions to jump to their definitions
4. **Autocomplete**: Type `field(:name, ` and get autocomplete suggestions for rules
5. **Type hints**: See inferred types by hovering over variables

## Example Workflow

Here's a recommended learning path:

1. **Start with basics** (`01_basic_usage.jl`)
   - Understand `@model` and `@rules`
   - Learn validation basics

2. **Explore rules** (`02_advanced_rules.jl`)
   - Discover available validation rules
   - Try `string_rules()`, `numeric_rules()` for reference

3. **Work with structure** (`03_nested_models.jl`, `04_collections.jl`)
   - Learn nested validation
   - Master collection validation

4. **Handle errors** (`05_error_handling.jl`)
   - Understand error handling patterns
   - Prepare for production use

5. **Build real apps** (`06_real_world.jl`)
   - See complete use cases
   - Apply patterns to your own code

## Quick Reference

While working with examples, keep these helper functions handy:

```julia
using BoundaryTypes

# Show all available rules
available_rules()

# Show rules by category
string_rules()
numeric_rules()
collection_rules()

# Show comprehensive examples
show_rule_examples()

# Show rules for a specific model
@model struct MyModel
    name::String
end

@rules MyModel begin
    field(:name, minlen(1))
end

show_rules(MyModel)
```

## Tips for Learning

1. **Run the examples**: Don't just read—run each example and observe the output
2. **Modify and experiment**: Change validation rules and see what happens
3. **Use VSCode features**: Hover, autocomplete, and go-to-definition are your friends
4. **Read the comments**: Each example includes detailed comments explaining concepts
5. **Check error messages**: Invalid examples show you what errors look like

## Common Patterns

### Pattern 1: API Request Validation
```julia
function handle_request(json_string::String)
    raw_data = JSON3.read(json_string, Dict{Symbol,Any})
    ok, result = try_model_validate(MyRequest, raw_data)

    if ok
        # Process valid request
        return process(result)
    else
        # Return validation errors
        return format_errors(result)
    end
end
```

### Pattern 2: Configuration Loading
```julia
function load_config(path::String)
    json = read(path, String)
    raw = JSON3.read(json, Dict{Symbol,Any})
    config = model_validate(AppConfig, raw)  # Throws on error
    return config
end
```

### Pattern 3: Data Validation Pipeline
```julia
function validate_batch(records::Vector)
    valid = []
    invalid = []

    for record in records
        ok, result = try_model_validate(MyModel, record)
        if ok
            push!(valid, result)
        else
            push!(invalid, (record, result.errors))
        end
    end

    return (valid=valid, invalid=invalid)
end
```

## Getting Help

- **Rule discovery**: Use `available_rules()` to see all validation rules
- **Documentation**: Use `?minlen` in Julia REPL for detailed docs
- **Main README**: See project README.md for comprehensive documentation
- **API Reference**: Check docs/src/api.md for API documentation

## Contributing Examples

Have a useful example? Consider contributing:
1. Follow the existing example format
2. Include clear comments and explanations
3. Show both valid and invalid cases
4. Test the example before submitting

## Next Steps

After working through these examples:
1. Try building your own models
2. Integrate BoundaryTypes.jl into your projects
3. Explore the test suite for more advanced usage
4. Read the main documentation for complete API reference

Happy validating! 🚀
