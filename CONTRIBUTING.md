# Contributing to Jobcelis

Thank you for your interest in contributing to Jobcelis! This guide will help you get started.

## How to Contribute

### Reporting Bugs

- Open an issue on GitHub with the `bug` label
- Include steps to reproduce, expected vs actual behavior
- Include your environment details (OS, Elixir/OTP version)

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the use case and why it would be valuable
- Check existing issues first to avoid duplicates

### Pull Requests

1. **Fork** the repository
2. **Create a branch** from `develop` (not `main`)
3. **Make your changes** following the code conventions below
4. **Run the checks** before submitting:
   ```bash
   mix compile --warnings-as-errors
   mix format --check-formatted
   mix credo --min-priority=high
   mix test
   ```
5. **Open a PR** against the `develop` branch

### Code Conventions

- All modules must have `@moduledoc`
- Use `timestamps(type: :utc_datetime_usec)` for all schemas
- All primary/foreign keys are binary UUIDs (`:binary_id`)
- Follow the umbrella dependency flow: `streamflix_web -> streamflix_accounts -> streamflix_core`
- User-facing strings must use `gettext()` and be translated to both English and Spanish

### Internationalization (i18n)

Jobcelis supports English and Spanish. When adding user-facing strings:

1. Wrap strings with `gettext("your string")`
2. Run `mix gettext.extract --merge`
3. Update both `en/LC_MESSAGES/default.po` and `es/LC_MESSAGES/default.po`

### Commit Messages

- Use conventional commit format: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- Keep the first line under 72 characters
- Focus on the "why", not the "what"

### Branch Workflow

- **Application changes** (Elixir/Phoenix): always target `develop`
- **Documentation changes** (README, docs): can target `main` directly
- **SDK changes** (`sdks/` folder): can target `main` directly

## Development Setup

### Prerequisites

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+
- Node.js 20+ (for assets)

### Getting Started

```bash
# Clone the repo
git clone https://github.com/vladimirCeli/jobscelis.git
cd jobscelis

# Install dependencies
mix deps.get
npm install --prefix apps/streamflix_web/assets

# Setup database
mix ecto.setup

# Start the server
mix phx.server
```

## License

By contributing, you agree that your contributions will be licensed under the project's Business Source License 1.1, which converts to Apache 2.0 on the Change Date.

## Questions?

- Open a GitHub Discussion
- Email: support@jobcelis.com
