# Custom Gradle Configuration

When using `custom_gradle_config` in your flavor configuration, be aware of the syntax differences between Groovy and Kotlin DSL.

## Groovy (build.gradle)

Use this syntax for `build.gradle` files:

```yaml
custom_gradle_config:
  defaultConfig: |
    buildConfigField "String", "API_URL", "\"https://api.example.com\""
    buildConfigField "boolean", "ENABLE_LOGGING", "true"
```

## Kotlin DSL (build.gradle.kts)

Use this syntax for `build.gradle.kts` files:

```yaml
custom_gradle_config:
  defaultConfig: |
    buildConfigField("String", "API_URL", "\"https://api.example.com\"")
    buildConfigField("Boolean", "ENABLE_LOGGING", "true")
```

## Important Notes

1. **Kotlin DSL uses parentheses** for function calls, not just spaces
2. **Kotlin DSL uses assignment operator `=`** for properties
3. **Type names may differ**: `boolean` → `Boolean`, `string` → `String`
4. The tool adds the configuration as raw code, so ensure correct syntax for your build file type

## Recommendation

For maximum compatibility, consider using Gradle properties or other configuration methods instead of `buildConfigField` in the custom config section, as they work the same in both Groovy and Kotlin DSL.

Alternatively, add buildConfigField declarations directly in your build.gradle(.kts) file and use flavor-specific values through other means (environment variables, flavor dimensions, etc.).
