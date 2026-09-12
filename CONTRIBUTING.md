# Contributing to Vania

## Creating a Pull Request

Before creating a pull request, please follow these steps:

1. Fork the repository and create your branch from `dev`.
2. Install all dependencies (`dart pub get`).
3. Squash your commits and ensure you have a meaningful, [semantic](https://www.conventionalcommits.org/en/v1.0.0/) commit message.
4. Add tests! Pull Requests without 100% test coverage will not be approved.
5. Ensure the existing test suite passes locally.
6. Format your code (`dart format .`).
7. Analyze your code (`dart analyze --fatal-infos --fatal-warnings .`).
8. Create the Pull Request targeting the `dev` branch.
9. Verify that all status checks are passing.
