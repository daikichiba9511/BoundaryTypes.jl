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
```

## Error Types

```@docs
BoundaryTypes.ValidationError
BoundaryTypes.FieldError
```

## Validation Rules

```@docs
minlen
regex
ge
le
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
