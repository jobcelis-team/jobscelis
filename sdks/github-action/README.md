# Jobcelis Send Event Action

Send events to the [Jobcelis Event Infrastructure Platform](https://jobcelis.com) from your GitHub Actions workflows.

## Usage

### Basic usage

```yaml
- uses: vladimirCeli/jobscelis/sdks/github-action@main
  with:
    api-key: ${{ secrets.JOBCELIS_API_KEY }}
    topic: deploy.completed
```

### With payload

```yaml
- uses: vladimirCeli/jobscelis/sdks/github-action@main
  with:
    api-key: ${{ secrets.JOBCELIS_API_KEY }}
    topic: deploy.completed
    payload: '{"environment": "production", "version": "${{ github.sha }}", "repo": "${{ github.repository }}"}'
```

### Full workflow example — notify on deploy

```yaml
name: Deploy & Notify
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy application
        run: echo "Deploying..."

      - name: Notify Jobcelis
        uses: vladimirCeli/jobscelis/sdks/github-action@main
        with:
          api-key: ${{ secrets.JOBCELIS_API_KEY }}
          topic: deploy.completed
          payload: |
            {
              "environment": "production",
              "version": "${{ github.sha }}",
              "repo": "${{ github.repository }}",
              "actor": "${{ github.actor }}",
              "run_id": "${{ github.run_id }}"
            }
```

### Notify on test results

```yaml
- name: Run tests
  run: npm test

- name: Notify test results
  if: always()
  uses: vladimirCeli/jobscelis/sdks/github-action@main
  with:
    api-key: ${{ secrets.JOBCELIS_API_KEY }}
    topic: test.${{ job.status }}
    payload: '{"repo": "${{ github.repository }}", "branch": "${{ github.ref_name }}", "status": "${{ job.status }}"}'
```

## Inputs

| Input      | Description                                        | Required | Default                |
|------------|----------------------------------------------------|----------|------------------------|
| `api-key`  | Jobcelis API key                                   | Yes      |                        |
| `topic`    | Event topic (e.g., `deploy.completed`, `test.passed`) | Yes      |                        |
| `payload`  | JSON payload for the event                         | No       | `{}`                   |
| `base-url` | Jobcelis API base URL                              | No       | `https://jobcelis.com` |

## Outputs

| Output     | Description               |
|------------|---------------------------|
| `event-id` | ID of the created event   |
| `status`   | HTTP status code          |

## Setup

1. Go to your Jobcelis dashboard at [jobcelis.com](https://jobcelis.com) and create an API key.
2. In your GitHub repository, go to **Settings > Secrets and variables > Actions**.
3. Click **New repository secret** and add `JOBCELIS_API_KEY` with your API key as the value.
4. Reference it in your workflow as `${{ secrets.JOBCELIS_API_KEY }}`.
