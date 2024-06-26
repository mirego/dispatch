<div align="center">
  <img src="https://user-images.githubusercontent.com/11348/52736094-07446200-2f97-11e9-8c43-80b0a0cf2e1e.png" width="400" />
  <p><br />Dispatch makes sure pull requests within a GitHub<br /> organization get reviewed by the right people.</p>

  <a href="https://travis-ci.com/mirego/dispatch"><img src="https://travis-ci.com/mirego/dispatch.svg?branch=master" /></a>
  <a href="https://coveralls.io/github/mirego/dispatch"><img src="https://coveralls.io/repos/github/mirego/dispatch/badge.svg?branch=master" /></a>
</div>
<br />

| Section                                                  | Description                                                     |
|----------------------------------------------------------|-----------------------------------------------------------------|
| [👋 Introduction](#-introduction)                        | What is this project?                                           |
| [🚧 Dependencies](#-dependencies)                        | The technical dependencies for the project                      |
| [🏎 Setup](#-setup)                                      | Setup instructions to quickly kickstart the project development |
| [🏗 Code & architecture](#-code--architecture)            | Details on the project modules and components                   |
| [🔭 Possible improvements](#-possible-improvements)      | Possible refactors and ideas                                    |
| [🚑 Troubleshooting](#-troubleshooting)                  | Troubleshooting information for potential problems              |
| [🚀 Deploy](#-deploy)                                    | Instructions on how to deploy the application                   |

## 👋 Introduction

### What is Dispatch?

Dispatch gets notified about pull requests opened in GitHub projects. It then selects random users (based on existing contributors and stack-skilled developers) and requests their review.

<img src="https://user-images.githubusercontent.com/11348/54038916-b12a9f00-418f-11e9-84d9-035c9b4c3da8.png" width="771">

### How to use it?

Everything is done via a simple GitHub webhook:

| Field        | Value                                  |
|--------------|----------------------------------------|
| Payload URL  | `https://my-dispatch-app.com/webhooks` |
| Content type | `application/json`                     |
| Events       | Send me **everything**.                |

#### Webhook query string parameters

| Parameter                   | Default value     | Description                                                        |
|-----------------------------|-------------------|--------------------------------------------------------------------|
| `stacks`                    | `""`              | Comma-separated values of project’s stacks (e.g. `elixir,graphql`) |
| `disable_learners`          | `false`           | Disable _learners_ for this repository                             |
| `minimum_contributor_count` | 1                 | Number of contributors to select                                   |

### Features

### Smart reviewer selection

When a pull request is opened, Dispatch selects a list of users that will be requested for a review:

* One or many recent repository contributor
* One reviewer _per stack_
* One or many learners _per stack_ (who will only be mentionned in the request comment)

### Ignoring pull requests

Draft pull requests or pull requests with a title that begins with `WIP `, `WIP:` or `[WIP] ` will be ignored. Pull requests that do not belong to repositories inside the configured organization (`GITHUB_ORGANIZATION_LOGIN` environment variable) will also be ignored.

### Pull request-specific stacks

From time to time, it can be useful to pass some specific stacks for a single pull request that differ from the ones used in the Webhook URL. `#dispatch/<stack>` tags can be added to the pull request body and Dispatch will use them as stacks instead of the default ones (configured in the webhook URL).

### Contributors blocklist

GitHub users listed in `blocklist` will never be requested for a review nor mentionned.

### Learners

GitHub users listed in `learners` will not be requested for a review. Instead, they will only be mentionned in the request comment. The `exposure` variable is used to mention the corresponding user to a percentage of the pull requests of that stack. For example, a user with an `exposure` factor of `0.75` would have a `75%` chance of getting a mention for each pull request of that stack.

### Absence.io

If an Absence.io iCal URL is provided, users that are out-of-office when a pull request is opened will never be requested for a review.

## 🚧 Dependencies

- Elixir (`1.8.1`)
- Erlang (`21.2.5`)

## 🏎 Setup

### Environment variables

All required environment variables are documented in the [`.env.dev`](./.env.dev) file.

When running `mix` or `make` commands, all of these variables must be present in the environement. To achieve this, we can use `source`, [`nv`](https://github.com/jcouture/nv) or another custom tool.

### Initial setup

1. Create an `.env.dev.local` file from [`.env.dev`](./.env.dev)
2. Install Mix dependencies with `make dependencies`
3. Compile the application `mix compile`
4. Start a Phoenix development server with `iex -S mix phx.server` after loading `.env.dev` and `.env.dev.local` files into the environment

### `make` commands

A `Makefile` file is present and expose several common tasks. The list of available tasks can be viewed with `make help`.

### Tests

Tests can be ran with `make test` and test coverage can be calculated with `make test-coverage`.

### Lint

Several linting and formatting tools can also be ran to ensure coding style consistency:

* `make lint-format` makes sure all Elixir code is properly formatted
* `make lint-credo` makes sure all Elixir code conforms to our best practices and guidelines
* `make lint-compile` makes sure all Elixir compiles without warnings

All these commands can be executed at once with the handy `make lint` command.

### Continuous integration

The `priv/scripts/ci-check.sh` script runs a few commands (tests, lint, etc.) to make sure the project and its code are in a good state.

## 🏗 Code & architecture

### Experts, learners and blocklisted users

The configuration file stored at `CONFIGURATION_FILE_URL` should contain a JSON object with three keys:

* `blocklist`
* `reviewers`
* `learners`

```json
{
  "blocklist": [
    {
      "username": "github_username"
    }
  ],
  "reviewers": {
    "stack_name": [
      {
        "username": "github_username"
      }
    ]
  },
  "learners": {
    "stack_name": [
      {
        "username": "github_username",
        "exposure": 0.25
      }
    ]
  }
}
```

## 🔭 Possible improvements

| Description                                                | Priority | Complexity | Ideas                                                                                             |
|------------------------------------------------------------|----------|------------|---------------------------------------------------------------------------------------------------|
| Improve the link between Absence.io users and GitHub users | Moderate | Moderate   | For now, we simply match both full names — this is error-prone                                    |

## 🚑 Troubleshooting

### Why no reviews or fewer reviews were requested?

The most common reasons as to why reviews were not requested after a pull request was opened:

* The user associated with the GitHub access token does not have “write” access to the repository
* The pull request title started with `WIP `, `WIP:` or `[WIP]` when it was first opened

The most common reasons as to why there was fewer requested reviews that usual (for the same repository) on a pull request:

* There are no other active contributors to the repository other than the pull request creator
* There are no other reviewers for the repository stacks other than the pull request creator

## 🚀 Deploy

The application can be deployed to Heroku following the [Container Registry & Runtime](https://devcenter.heroku.com/articles/container-registry-and-runtime) guide.

### tl;dr

1. Create a docker image for the _OTP release_ (`DOCKER_IMAGE_TAG=latest` is the default value).
    ```shell
    > make build DOCKER_IMAGE_TAG=latest
    ```

1. Tag the image for Heroky’s registry
    ```shell
    > docker tag dispatch:latest registry.heroku.com/dispatch/web
    ```

1. Login to the Heroku registry
    ```shell
    > heroku container:login
    ```

1. Push the image to the registry
    ```shell
    > docker push registry.heroku.com/dispatch/web
    ```

1. Release the image
    ```shell
    > heroku container:release web
    ```

## License

Dispatch is © 2018-2019 [Mirego](https://www.mirego.com) and may be freely distributed under the [New BSD license](http://opensource.org/licenses/BSD-3-Clause). See the [`LICENSE.md`](https://github.com/mirego/dispatch/blob/master/LICENSE.md) file.

## About Mirego

[Mirego](https://www.mirego.com) is a team of passionate people who believe that work is a place where you can innovate and have fun. We’re a team of [talented people](https://life.mirego.com) who imagine and build beautiful Web and mobile applications. We come together to share ideas and [change the world](http://www.mirego.org).

We also [love open-source software](https://open.mirego.com) and we try to give back to the community as much as we can.
