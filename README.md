# Gremlin Helm Charts

This repository hosts the official **Gremlin Helm Charts** to deploy **Gremlin** products
to [Kubernetes](https://kubernetes.io/)

## Install Helm

Get the latest [Helm release](https://github.com/kubernetes/helm#install).

## Install Charts

Add this Chart repo to Helm, and install:

```shell
helm repo add gremlin https://helm.gremlin.com/
````

### Gremlin

```shell
helm install gremlin gremlin/gremlin \
    --namespace gremlin --create-namespace \
    --set gremlin.secret.managed=true \
    --set gremlin.secret.type=secret \
    --set gremlin.secret.teamID=YOUR-TEAM-ID \
    --set gremlin.secret.clusterID=YOUR-CLUSTER-ID \
    --set gremlin.secret.teamSecret=YOUR-TEAM-SECRET
```

For more detailed instructions, see the chart's
documentation [here](https://github.com/gremlin/helm/blob/master/gremlin/README.md).

### Gremlin Integration

#### Secret Auth

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
    --namespace gremlin --create-namespace \
    --set gremlin.secret.managed=true \
    --set gremlin.secret.type=secret \
    --set gremlin.secret.teamID=YOUR-TEAM-ID \
    --set gremlin.secret.teamSecret=YOUR-TEAM-SECRET
```

#### Certificate Auth

```shell
helm install gremlin-integrations gremlin/gremlin-integrations \
    --namespace gremlin --create-namespace \
    --set gremlin.secret.teamID=YOUR-TEAM-ID \
    --set-file gremlin.secret.certificate=PATH_TO_CERTIFICATE \
    --set-file gremlin.secret.key=PATH_TO_PRIVATE_KEY
```

For more detailed instructions, see the chart's
documentation [here](https://github.com/gremlin/helm/blob/master/gremlin-integrations/README.md).

## Contributing

This repo lints, schema-validates, and generates docs for its charts via a `Makefile`. To get set
up:

```shell
make setup
```

This installs the pinned toolchain (`helm-docs`, the `helm schema` plugin, `pre-commit`) and
registers the pre-commit hooks - each idempotently, and it never replaces or upgrades a tool
you've already installed at a different version (you'll get a warning instead, naming the
version found and the version this repo pins).

The `helm schema` plugin install disables Helm 4's plugin signature verification
(`--verify=false`): its upstream, [losisin/helm-values-schema-json](https://github.com/losisin/helm-values-schema-json),
publishes no signed release for Helm to verify against, so this is the only way to install it at
all, not a shortcut taken instead of a safer option. `make setup` prints this at install time too.
The `helm-docs` download is checksummed against a pinned SHA-256 before it's extracted, so that
one isn't in the same position.

Before committing, or at any time:

```shell
make check
```

runs the same schema, docs and lint checks the `chart-tooling` workflow runs, in that order:
regenerating each chart's `values.schema.json` and `README.md`, then linting. It does not run the
unit test suites - CI checks those separately (`.github/workflows/unittest.yml`), so run
`make test` too before pushing. The pre-commit hooks run `check`'s steps automatically on
`git commit`.

Individual targets:

| Target | What it does |
|---|---|
| `make lint` | `helm lint --strict` on every chart, with defaults and with its `ci/linting` override |
| `make schema` | Regenerates every chart's `values.schema.json` from its `.schema.yaml` |
| `make docs` | Regenerates every chart's `README.md` from its `README.md.gotmpl` |
| `make test` | Runs the `helm unittest` suites |
| `make check` | `schema`, `docs`, `lint`, then fails if regeneration produced an uncommitted diff |

## Reporting Issues

Please report all issues [here](https://support-site.gremlin.com/).
