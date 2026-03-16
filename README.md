# ClusterGoodies
Collection of scripts and automations that make working and living with Kubernetes cluster (especially AWS EKS) easier

---

## What is here

| Tool | Purpose |
|:-----|:-------:|
| **kcc** | Kubernetes Current Context - script to automate switching between multiple AWS EKS accounts and clusters. Just store it somewhere in the $PATH, use AWS credentials as environmental variables, and run `kcc` |

## Testing

The project includes a comprehensive test suite for the `kcc` script.

### Running Tests

1. Install dependencies:
   ```bash
   cpanm --installdeps .
   ```

2. Run the test suite:
   ```bash
   prove t/
   ```

The tests cover:
- Pure function testing (normalization, alias building, cluster selection)
- AWS detection mocking (region, account, clusters)
- Kubeconfig parsing and context finding
- Integration scenarios with mocked external commands

### Test Structure

- `t/01-functions.t`: Tests for pure functions that don't require external calls
- `t/02-detection.t`: Tests for AWS detection functions with mocked `run_cmd_capture`
- `t/03-kubeconfig.t`: Tests for kubectl config parsing with mocked commands
- `t/04-integration.t`: Integration tests (placeholder for now)
- `t/05-help.t`: Tests for help output
