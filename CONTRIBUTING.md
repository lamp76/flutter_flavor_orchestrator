# Contributing to Flutter Flavor Orchestrator

First off, thank you for considering contributing to Flutter Flavor Orchestrator! It's people like you that make this tool better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to fostering an open and welcoming environment. Please be respectful and constructive in your interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (code snippets, configuration files)
- **Describe the behavior you observed** and what you expected
- **Include screenshots** if applicable
- **Mention your environment** (OS, Dart/Flutter version, package version)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List any alternatives** you've considered

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Ensure your code follows the style guidelines
5. Write or update tests as needed
6. Update documentation if needed
7. Run `dart analyze` and ensure there are no errors
8. Run `dart test` and ensure all tests pass
9. Commit your changes (`git commit -m 'Add amazing feature'`)
10. Push to the branch (`git push origin feature/amazing-feature`)
11. Open a Pull Request

## Development Setup

### Prerequisites

- Dart SDK ^3.0.0
- Git

### Getting Started

```bash
# Clone the repository
git clone https://github.com/lamp76/flutter_flavor_orchestrator.git
cd flutter_flavor_orchestrator

# Install dependencies
dart pub get

# Run tests
dart test

# Run analyzer
dart analyze
```

## Style Guidelines

### Dart Code Style

This project follows the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style) with some additional rules defined in `analysis_options.yaml`:

- Use `final` for variables that won't be reassigned
- Prefer `const` constructors when possible
- Use trailing commas for better formatting
- Write doc comments (`///`) for all public APIs
- Keep lines under 80 characters when practical
- Use meaningful variable and function names

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

Example:
```
Add support for macOS platform configuration

- Implement MacOSProcessor class
- Add macOS-specific file manipulation
- Update documentation with macOS examples

Closes #123
```

### Documentation

- All public APIs must have doc comments
- Update README.md if you add new features
- Update CHANGELOG.md following the [Keep a Changelog](https://keepachangelog.com/) format
- Add examples for new features

### Testing

- Write tests for all new functionality
- Maintain or improve code coverage
- Use descriptive test names
- Group related tests using `group()`
- Mock file system operations in tests

Example test structure:
```dart
group('FeatureName', () {
  test('does something specific', () {
    // Arrange
    final input = ...;
    
    // Act
    final result = doSomething(input);
    
    // Assert
    expect(result, equals(expected));
  });
});
```

## Project Structure

```
flutter_flavor_orchestrator/
├── lib/
│   ├── src/              # Internal implementation
│   │   ├── models/       # Data models
│   │   ├── processors/   # Platform processors
│   │   └── utils/        # Utility classes
│   └── flutter_flavor_orchestrator.dart  # Public API
├── bin/                  # CLI executable
├── test/                 # Test files (mirror lib/ structure)
├── example/              # Example project
└── docs/                 # Additional documentation
```

## Architecture Principles

This project follows Clean Architecture principles:

1. **Separation of Concerns**: Each class has a single, well-defined responsibility
2. **Dependency Inversion**: Depend on abstractions, not concrete implementations
3. **Testability**: All components should be easily testable
4. **Immutability**: Prefer immutable data structures where possible

## Release Process

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md` with changes
3. Run all tests and ensure they pass
4. Run `dart analyze` and fix any issues
5. Create a git tag: `git tag -a v0.x.0 -m "Version 0.x.0"`
6. Push the tag: `git push origin v0.x.0`
7. Publish to pub.dev: `dart pub publish`

## Questions?

Feel free to open an issue with the `question` label if you have any questions about contributing.

## Recognition

Contributors will be recognized in the project's README.md and release notes.

Thank you for contributing! 🎉
