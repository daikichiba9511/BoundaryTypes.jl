# API Reference

## Macros

```@docs
@model
@rules
@validated_model
```

## Validation Functions

```@docs
model_validate
try_model_validate
model_validate_json
try_model_validate_json
```

## Update Functions

```@docs
model_copy
model_copy!
```

## Introspection

```@docs
show_rules
schema
available_rules
string_rules
numeric_rules
collection_rules
show_rule_examples
```

## Error Types

```@docs
BoundaryTypes.ValidationError
BoundaryTypes.FieldError
```

## Validation Rules

### String Rules

```@docs
minlen
maxlen
regex
email
url
uuid
choices
```

### Numeric Rules

```@docs
ge
le
gt
lt
between
multiple_of
```

### Collection Rules

```@docs
each
```

### Other Rules

```@docs
present
notnothing
secret
custom
```

## Internal Types

```@docs
BoundaryTypes.ModelSpec
BoundaryTypes.FieldSpec
BoundaryTypes.Rule
BoundaryTypes.RuleCtx
```
