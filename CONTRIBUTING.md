# Contributing to Vania

Thank you for your interest in contributing to Vania! Your contributions are vital for making Vania better. Below are the guidelines for contributing to the project.

## Table of Contents
1. [Code of Conduct](#code-of-conduct)
2. [How to Contribute](#how-to-contribute)
    - [Reporting Bugs](#reporting-bugs)
    - [Proposing Features](#proposing-features)
    - [Submitting Pull Requests](#submitting-pull-requests)
3. [Setting Up Your Development Environment](#setting-up-your-development-environment)
4. [Understanding the Repository Structure](#understanding-the-repository-structure)
5. [Releasing New Versions](#releasing-new-versions)
6. [Community and Support](#community-and-support)

## Code of Conduct

Please adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

## How to Contribute

### Reporting Bugs

- **Search for existing issues** to avoid duplicates.
- **Provide a clear and detailed description** of the bug.
- **Include steps to reproduce the bug** and any relevant code snippets.
- **Add screenshots or logs** if applicable.

### Proposing Features

- **Search for existing feature requests** before submitting.
- **Describe the feature in detail** and include use cases.
- **Explain why this feature would be useful** to the community.

### Submitting Pull Requests

Before submitting a pull request (PR), please:

1. **Fork the repository** and create your branch from the `dev` branch.
2. **Install all dependencies**: `dart pub get`.
3. **Ensure your commits are meaningful and semantic**.
4. **Add tests** to cover your changes. Pull requests without 100% test coverage will not be approved.
5. **Verify that the existing test suite passes** locally.
6. **Format your code**: `dart format .`.
7. **Analyze your code**: `dart analyze --fatal-infos --fatal-warnings .`.
8. **Create the Pull Request targeting the `dev` branch**.
9. **Verify that all status checks are passing**.

## Setting Up Your Development Environment

### Prerequisites

- **Dart SDK**: Ensure you have a valid Dart SDK installed.
- **Mason CLI**: For running and testing bricks.
- **Node.js**: Required for working with the VS Code extension or documentation website.
- **Shell scripting capability**: For running internal scripts.

### Installation

1. **Clone the repository**: `git clone https://github.com/your_username/vania.git`.
2. **Navigate to the project directory**: `cd vania`.
3. **Install dependencies**: `dart pub get`.

## Understanding the Repository Structure

- **`tool/`**: Internal operation scripts.
- **`assets/`**: Images for READMEs.
- **`docs/`**: Source code for documentation.
- **`examples/`**: Example projects demonstrating various usages.
- **`extensions/`**: IDE integrations like VS Code.
- **`bricks/`**: Internal Mason bricks used by the CLI for tasks like project creation, development server, and production server setup.
- **`packages/`**: Source code for the main and companion packages.

## Releasing New Versions

Before starting the release process:

1. **Ensure your local `dev` branch is up to date**:
    ```sh
    git checkout dev
    git fetch
    git status
    ```
2. **Ensure the CI pipeline is green** for the package.
3. **Run the release script** within the package root:
    ```sh
    ../../tool/release_ready.sh <version>
    ```
4. **Review and update the CHANGELOG**.
5. **Commit, push, and open a pull request** from the new release branch.
6. **Create a release on GitHub**. The publish workflow will handle the publication.

## Community and Support

Join our community for discussions and support:

- **Slack**: [Join our Slack community](#)
- **Discord**: [Join our Discord server](#)
- **GitHub Discussions**: [Participate in discussions](#)
- **Mailing List**: [Subscribe to our mailing list](#)

---

## Enforcement Responsibilities

Community leaders are responsible for clarifying and enforcing our standards of acceptable behavior and will take appropriate and fair corrective action in response to any behavior that they deem inappropriate, threatening, offensive, or harmful.

The community leaders for this project are:

- **Lead Maintainer**: Javad, [javad@example.com]
- **Co-Maintainer and Mobile Compatibility Manager**: Ali, [ali@example.com]
- **Community and Project Manager**: Hossein, [hossein@example.com]

These individuals are responsible for handling reports of Code of Conduct violations and ensuring that the community remains welcoming and inclusive.

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported to the community leaders responsible for enforcement at coc@vdart.dev or via the contact form on our website at [vdart.dev/contact](https://vdart.dev/contact). All complaints will be reviewed and investigated promptly and fairly.

All community leaders are obligated to respect the privacy and security of the reporter of any incident.

---

By following these guidelines, you help us maintain a safe and effective environment for collaboration and contribution. Thank you for being part of Vania!
