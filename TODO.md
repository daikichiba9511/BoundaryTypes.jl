# TODO

This document tracks planned features and improvements for BoundaryTypes.jl.

## High Priority

### Collection Validation
- [x] Implement `each(rule)` for validating array elements
- [x] Support `Vector{T}`, `Set{T}` validation
- [x] Add collection-specific rules (`minlen`, `maxlen` for collections)
- [x] Example: `field(:tags, each(minlen(3)))`

### Type Coercion
- [ ] String to numeric conversion (`"123"` → `123`)
- [ ] Opt-in design (default: strict type checking)
- [ ] Add `coerce=true` option to `@model` or `@rules`
- [ ] Support common conversions: String → Int, Float, Bool

### Error Message Customization
- [ ] Custom error messages per rule
  - Example: `field(:age, ge(0), msg="年齢は0以上である必要があります")`
- [ ] i18n support (Japanese, English)
- [ ] Locale-aware error formatting

## Medium Priority

### Nested Collections
- [ ] Support `Vector{ModelType}` (array of nested models)
- [ ] Support `Dict{String, ModelType}`
- [ ] Proper error path reporting for nested collections
  - Example: `users[0].email`, `addresses[2].zipcode`

### Advanced String Rules
- [x] `email()` - dedicated email validation
- [x] `url()` - URL validation
- [x] `uuid()` - UUID validation
- [x] `maxlen(n)` - maximum string/collection length
- [x] `choices(values)` - enum-like validation
  - Example: `field(:status, choices(["active", "inactive", "pending"]))`

### Advanced Numeric Rules
- [x] `gt(n)` - strictly greater than
- [x] `lt(n)` - strictly less than
- [x] `between(min, max)` - range validation
- [x] `multiple_of(n)` - divisibility check

## Lower Priority

### Cross-Field Validation
- [ ] `@validator` macro for multi-field validation
- [ ] Built-in cross-field validators
  - Example: `field(:password_confirm, matches(:password))`
- [ ] Conditional validation based on other fields

### Field Aliases / Mapping
- [ ] Separate JSON keys from Julia field names
- [ ] `alias` option in field rules
  - Example: `field(:user_name, alias="userName")`
- [ ] Support for multiple aliases per field

### Partial Validation
- [ ] Validate specific fields only
- [ ] Useful for PATCH operations in APIs
- [ ] `model_validate(User, data, fields=[:email, :age])`

### Performance Optimization
- [ ] Compile-time rule optimization
- [ ] Validation result caching
- [ ] Benchmark suite
- [ ] Performance profiling and optimization

## Research / Future Ideas

### Advanced Features
- [ ] Recursive/self-referential models
- [ ] Polymorphic validation (union types)
- [ ] Async validation (for DB checks, external APIs)
- [ ] Custom serialization hooks
- [ ] Integration with common web frameworks

### Documentation
- [x] Helper functions for rule discovery (`available_rules`, `string_rules`, `numeric_rules`, `collection_rules`, `show_rule_examples`)
- [ ] More examples in documentation
- [ ] Tutorial for common use cases
- [ ] Performance guide
- [ ] Migration guide from other validation libraries

### Tooling
- [ ] VS Code snippets for common patterns
- [ ] Automatic rule generation from existing structs
- [ ] Integration with OpenAPI/Swagger generators

---

## Completed Features

- ✅ `@model` and `@rules` macros for declarative validation
- ✅ `@validated_model` for automatic constructor validation
- ✅ `model_validate` / `try_model_validate` for Dict/NamedTuple input
- ✅ `model_validate_json` / `try_model_validate_json` for JSON strings
- ✅ `model_copy` / `model_copy!` for updating instances
- ✅ `show_rules` for introspection
- ✅ `schema` for JSON Schema generation
- ✅ Validation rules: `minlen`, `maxlen`, `regex`, `ge`, `le`, `gt`, `lt`, `between`, `multiple_of`, `email`, `url`, `uuid`, `choices`, `present`, `notnothing`, `secret`, `custom`, `each`
- ✅ Helper functions for rule discovery: `available_rules`, `string_rules`, `numeric_rules`, `collection_rules`, `show_rule_examples`
- ✅ Type mismatch detection
- ✅ Extra field detection
- ✅ Default value validation
- ✅ Optional field handling (`Union{Nothing,T}`)
- ✅ Secret field masking in error messages
- ✅ Nested struct validation with automatic recursion
- ✅ Extra field handling configuration
  - ✅ `@model extra=:forbid` (reject extra fields, default)
  - ✅ `@model extra=:ignore` (silently ignore extra fields)
  - ✅ `@model extra=:allow` (store extra fields in `_extra::Dict{Symbol,Any}`)
  - ✅ Works with `@validated_model` as well
  - ✅ `model_dump` automatically merges `_extra` fields back into output
  - ✅ Nested models support with proper propagation of extra modes

---

## Notes

- This is a toy/experimental project - prioritize learning and exploration over production readiness
- Breaking API changes are acceptable before v1.0
- Focus on Julia-idiomatic design patterns
- Keep the core philosophy: validation at boundaries, clean domain types
