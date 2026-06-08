# gft_reviewer

Built with [Frai](https://github.com/aasmolsky/frai) — Ruby LLM framework.

Ruby is an expressive language built for developer happiness — but it rarely appears in AI tooling, where Python dominates. Frai brings Rails-style conventions to LLM workflows: clear structure, sensible defaults, and a simple contract that scales from a single prompt to a multi-agent system.

Requires Ruby >= 3.3.0.

---

## Installation

Install Frai in the Ruby project that will run these files, or install it globally:

```bash
gem install frai
```

If your host application uses Bundler, add Frai there:

```ruby
gem "frai"
```

In that mode, run Frai commands through Bundler, for example:

```bash
bundle exec frai c
bundle exec frai e AnalyzeReviewsTask "input"
```

`frai console` / `frai c` loads the current Frai project, so it only works from a directory that contains `config/frai.rb` and the Frai project structure.

You may also need a provider gem in that host application, depending on the model you use:

```ruby
gem "anthropic"    # for Claude
gem "ruby-openai"  # for OpenAI
gem "ollama-ai"    # for Ollama (local models)
```

---

## Getting started

```bash
cp .env.example .env    # fill in your secrets
frai setup              # register MCP servers with Claude CLI
frai gt analyze_item    # generate your first task
```

---

## Structure

```
gft_reviewer/
  tasks/               # single LLM calls — the main building block
    base_task.rb
  pipelines/           # sequential chains of tasks
    base_pipeline.rb
  agents/              # orchestrators that decide what to call and when
    base_agent.rb
  applications/        # public entrypoints for external callers
  scripts/             # shared scripts in any language (Python, JS, bash...)
  directives/          # shared prompt templates (reused across tasks)
    base.md.erb
  mcp/                 # external MCP server definitions
  config/
    frai.rb            # model, API key, autoload
  .env                 # local secrets — git-ignored
  .env.example         # template to commit
  .gitignore
  spec/
    conventions_spec.rb
```

---

## Environments

Frai supports three environments controlled by `FRAI_ENV` in `.env`:

| `FRAI_ENV` | MCPs | LLM | Returns |
|------------|------|-----|---------|
| `development` | skipped | skipped | rendered prompt |
| `test` | skipped | skipped | rendered prompt |
| `production` | connected | called | LLM response |

Default is `production`. In `development` and `test`, all MCP servers are skipped and the null adapter is used regardless of `LLM_MODEL` — you see the rendered prompt without any API calls.

Override inline for a single run:
```bash
FRAI_ENV=production frai exec AnalyzeReviewsTask "place_id(ChIJ...)"
FRAI_ENV=development frai exec AnalyzeReviewsTask "place_id(ChIJ...)"
```

---

## Two modes of operation

**CLI mode** (`LLM_MODEL` not set in `.env`):
- `frai exec` renders the prompt and returns it as text
- Claude CLI reads it and acts as the LLM
- No API key required

**API mode** (`LLM_MODEL` is set):
- `frai exec` renders the prompt, sends it to the LLM via RubyLLM, returns the response
- Works for cron jobs, pipelines, automation — no Claude CLI needed

Switch by setting `LLM_MODEL` in `.env`:

```bash
# API mode
LLM_MODEL=claude-sonnet-4-20250514
LLM_API_KEY=your_api_key
```

---

## Tasks

A task is the core unit — **one LLM call**. It validates input, runs scripts, renders a prompt, and optionally calls an LLM.

Generate a task:

```bash
frai gt analyze_item        # short for: frai generate task
```

This creates:

```
tasks/
  analyze_item/
    task.rb
    directives/
      main.md.erb
    scripts/
```

### Minimal

```ruby
class AnalyzeItemTask < BaseTask
end

AnalyzeItemTask.call("some input")
```

### Schema DSL

All task declarations live inside `schema do ... end`:

| Command | Description |
|---------|-------------|
| `llm false` | Skip the LLM call — return the rendered prompt as a string. Default: `true` |
| `mcp :name` | Declare an MCP server dependency. Server must exist in `mcp/name.rb` |
| `const :name, value` | Define a constant available in directives as `<%= name %>` |
| `param :name, type: T, required: true` | Declare a required input parameter |
| `param :name, type: T, default: val` | Declare an optional input parameter with default |
| `use :name` | Include a sub-directive (`directives/name.md.erb`) |
| `run :name do ... end` | Declare a script (`scripts/name.rb`) with input/returns |

### Full example

`task.rb` is the **contract** — params, constants, MCPs, sub-directives, and scripts are all declared in `schema do ... end`.

```ruby
class AnalyzeReviewsTask < BaseTask
  schema do
    param :place_id,   type: String, required: true
    param :language,   type: String, required: true
    param :place_data, type: Hash,   required: true
    param :reviews,    type: Array,  required: true

    use :review_scores
    use :review_patterns
  end
end
```

For a single return field, shorthand is also supported:

```ruby
returns diff: String
```

### Skipping the LLM call

By default every task sends the rendered prompt to the LLM. Set `llm false` to return the rendered prompt as a string without calling the LLM — useful for template-only tasks, intermediate pipeline steps, or debugging:

```ruby
class BuildReportTask < BaseTask
  schema do
    llm false

    param :analysis_result, type: Hash,   required: true
    param :language,        type: String, required: true

    run :process_reviews do
      input Hash
      returns do
        review_report Hash
      end
    end
  end
end
```

| `llm` | Behaviour |
|-------|-----------|
| `true` (default) | render prompt → call LLM → return response |
| `false` | render prompt → return prompt string |

The Ruby class stays minimal — all structure comes from `schema do ... end` in `task.rb`.

**MCP validation rules:**
- Task declares `mcp :name` but `mcp/name.rb` is missing → error at startup
- `mcp/name.rb` exists but no task declares it → error at startup
- MCP not registered with Claude CLI (CLI mode) → error before LLM call
- MCP not accessible (API mode) → error before LLM call

---

## Directives

Directives are Markdown + ERB prompt templates. `main.md.erb` is always the entry point.

### Variables

Params, constants, and script results are available as plain methods:

```erb
You are an expert analyst.
Analyze task <%= place_id %> in <%= language %>.
```

### Scripts

```erb
% run("process_reviews", params: :analysis_result, return: :review_report)

<%= review_report %>
```

### Sub-directives

```erb
<%= use("review_scores") %>
<%= use("review_patterns") %>
```

### Multiple inputs

```erb
% run("analyze", params: [:diff, :language], return: :result)

<%= result %>
```

### Conditional logic

Full Ruby is available in templates:

```erb
% if reviews.size > 50
  <%= use("large_batch") %>
% else
  <%= use("small_batch") %>
% end
```

### Mode-aware directives

Use `Frai.configuration.model` to adapt content to CLI vs API mode:

```erb
<% if Frai.configuration.model %>
<%# API mode: MCP tools already verified — proceed directly %>
<% else %>
<%# CLI mode: ask Claude to verify MCP access %>
Before starting, verify that required MCP tools are accessible.
<% end %>
```

---

## Scripts

Scripts receive `{ input: value }` as JSON on stdin and write a JSON hash to stdout:

```ruby
# tasks/build_report/scripts/process_reviews.rb
require 'json'
input = JSON.parse($stdin.read, symbolize_names: true)[:input]
puts JSON.generate({ review_report: transform(input) })
```

```python
# tasks/analyze_item/scripts/fetch.py
import sys, json
data = json.load(sys.stdin)
print(json.dumps({ "result": f"fetched: {data['input']}" }))
```

Scripts in `scripts/` are never autoloaded — they run as subprocesses. Results are memoized per task execution.

---

## Configuration

```ruby
# config/frai.rb
Frai.configure do |config|
  config.model   = ENV["LLM_MODEL"]     # nil = CLI mode, set = API mode
  config.api_key = ENV["LLM_API_KEY"]   # for the configured LLM provider
end
```

`config/frai.rb` automatically loads `.env` on startup.

---

## Environment variables

```bash
# .env — git-ignored
LLM_MODEL=claude-sonnet-4-20250514   # comment out for CLI mode
LLM_API_KEY=your_api_key
```

Commit `.env.example` with empty values as a template for teammates.

---

## Claude CLI integration

Each task gets its own slash command — created automatically by `frai gt`:

```bash
frai gt analyze_reviews
# → creates task files
# → creates .claude/commands/analyze_reviews.md
```

Invoke from Claude CLI **inside the project directory**:

```
/analyze_reviews place_id(ChIJ...) language(ru) place_data({...}) reviews([...])
```

Arguments use `name(value)` format — names match params declared in `schema do`.
Also supports `key:value` format.

If the command fails, Claude reports the error and stops — it does not retry or guess parameters.

---

## Pipelines

```ruby
module GftReviewer
  class ReviewAnalysisPipeline < BasePipeline
    def call(input)
      scored = AnalyzeReviewsTask.call(
        place_id:   input[:place_id],
        language:   input[:language],
        place_data: input[:place_data],
        reviews:    input[:reviews]
      )

      BuildReportTask.call(
        analysis_result: scored,
        language:        input[:language]
      )
    end
  end
end
```

---

## Applications

An application is the **stable public entrypoint** for a Frai project. External callers — Rails, other services, scripts — always call `Application.call(...)`. The internal implementation can change freely without affecting the caller.

```ruby
module GftReviewer
  class Application < Frai::Application
    def call(place_id:, language:, place_data:, reviews:)
      ReviewAnalysisPipeline.call(
        place_id: place_id, language: language,
        place_data: place_data, reviews: reviews
      )
    end
  end
end

GftReviewer::Application.call(
  place_id:   "ChIJEZGkUgDpD0cRug0NW_Qcu08",
  language:   "ru",
  place_data: { title: "Old School Garage", rating: 4.7 },
  reviews:    [{ review_id: "r1", rating: 5, snippet: "Great!" }]
)
```

### Calling from Rails

```ruby
# config/initializers/frai.rb
require Rails.root.join("lib/gft_reviewer/config/frai")

# app/services/frai_reviews_analysis_service.rb
result = GftReviewer::Application.call(
  place_id: place_id, language: language,
  place_data: place_data, reviews: reviews
)
```

The frai project lives in `lib/` and is loaded via the initializer.

---

## Application vs Agent

| | Application | Agent |
|---|---|---|
| **Who decides what to call** | Developer (Ruby) | LLM at runtime |
| **Flow** | Fixed: step 1 → step 2 → output | Dynamic: branches, loops, retries |
| **LLM in control loop** | No | Yes |
| **Steps defined upfront** | Yes | No |
| **Use when** | Predictable, repeatable workflows | Open-ended tasks requiring reasoning |

---

## Agents

An agent is an **LLM-driven orchestrator** — it decides which tasks and tools to call based on intermediate results.

```ruby
class ResearchAgent < BaseAgent
  def call(input)
    data    = FetchDataTask.call(input)
    summary = SummarizeTask.call(data)
    summary
  end
end
```

---

## Removing a task

```bash
frai rt analyze_reviews   # short for: frai remove task
```

Removes the task directory and `.claude/commands/analyze_reviews.md`.

---

## Project discovery

`frai list` (alias: `frai l`) shows everything in the project at a glance:

```
Tasks:

  # Scores reviews for fraud signals using LLM
  analyze_reviews
    params:
      - place_id(required, String)
      - language(required, String)
      - place_data(required, Hash)
      - reviews(required, Array)
    directives:
      - review_scores
      - review_patterns

  # Processes scored reviews into a final report
  build_report
    params:
      - analysis_result(required, Hash)
      - language(required, String)
    scripts:
      - process_reviews
```

### Adding descriptions

**Task** — add `<desc>` tag at the top of `main.md.erb`:
```erb
<desc>Scores reviews for fraud signals using LLM</desc>

You are a review fraud scorer...
```

**Script** — `# desc:` comment at the top:
```ruby
# desc: Processes scored reviews into a final report
require 'json'
...
```

---

## Logging

Write task output and errors to a log file:

```bash
frai exec AnalyzeReviewsTask "place_id(ChIJ...)" --log logs/analyze.log
```

---

## CLI reference

| Command | Description |
|---|---|
| `frai new PROJECT_NAME` | Create a new project (`frai n`) |
| `frai generate task NAME` | Generate a task + Claude CLI command (`frai gt`) |
| `frai generate pipeline NAME` | Generate a pipeline (`frai gp`) |
| `frai generate agent NAME` | Generate an agent (`frai ga`) |
| `frai remove task NAME` | Remove a task and its Claude CLI command (`frai rt`) |
| `frai setup` | Register `mcp/*.rb` servers with Claude CLI (`frai s`) |
| `frai destroy` | Clean up MCP servers and commands before deleting the project |
| `frai list` | List all tasks, MCPs, pipelines, agents and shared directives (`frai l`) |
| `frai exec CLASS_NAME [INPUT]` | Execute a task, pipeline, or agent (`frai e`) |
| `frai exec ... --log PATH` | Execute and write output/errors to log file |
| `frai console` | Interactive Ruby console with project loaded (`frai c`) |

---

## License

MIT
