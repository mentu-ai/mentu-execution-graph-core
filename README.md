# Mentu Execution Graph Core

`MentuExecutionGraphCore` is the deterministic constitution for contract-bearing
execution graphs: how a candidate graph becomes a canonical executable artifact,
how trusted qualification becomes admission, how a DAG becomes ordered
activations, and how every activation receives an append-only outcome.

It is a pure Swift library. It performs no I/O, spawns no process, calls no
model, and holds no credential. A host (the Mentu engine is one) supplies the
effects; this package supplies the meaning, so two hosts cannot disagree about
what a graph is.

This is the reference implementation behind the *Agent Graph Runtime*
preprint published at [mentu-ai/agent-graph-runtime](https://github.com/mentu-ai/agent-graph-runtime).

## What is in the package

| Area | Types | What it fixes |
| --- | --- | --- |
| Canonical form | `ExecutionGraphCanonicalizer`, `CanonicalJSONValue` | RFC 8785 canonical JSON with duplicate-key rejection, so every hash is reproducible byte for byte. |
| Contracts | `CandidateGraphNode`, `CandidateStepContract`, `ExecutionAuthorityEnvelope`, `PlanningPermit`, `EffectiveExecutionPolicy` | Strict, unknown-key-rejecting schemas for what a planner may propose and what an operator authorized. |
| Lowering | `ExecutionGraphLowerer`, `ExecutionArtifactBundle` | One candidate graph becomes one executable definition plus sealed prompts, hashed as a unit. |
| Qualification and admission | `ExecutionGraphQualification`, `ExecutionGraphAdmission`, `AdmissionReceipt` | Authority-subset checks, drift detection between qualification and run time, and a receipt bound to the exact runtime context. |
| Scheduling | `ExecutionDAG`, `ExecutionGraphScheduler` | Cycle-free frontier scheduling with unique activation sequence numbers and hash-linked outcomes. |
| Lifecycle | `ExecutionGraphLifecycle` | Typed phase events with stable reason identifiers. |

The frozen baseline fixtures under `Tests/MentuExecutionGraphCoreTests/Fixtures`
pin the byte-exact shape of every artifact above. A change that alters any hash
fails those tests on purpose.

## Use it

```swift
// Package.swift
.package(url: "https://github.com/mentu-ai/mentu-execution-graph-core.git", from: "1.0.0")
```

```swift
import MentuExecutionGraphCore
```

`Tests/ConsumerFixture` is a complete standalone consumer: it lowers a
three-node candidate, qualifies it, admits it, and schedules it, printing the
receipt hash. Run it with:

```sh
swift run --package-path Tests/ConsumerFixture
```

## Verify

```sh
swift test
swift build -c release
```

CI runs the tests, a release build, the consumer fixture, a check that the
consumer cannot compile without the package, and a source-hygiene scan.

## Relationship to Mentu

The Mentu engine embeds this package unchanged and adds the host side:
repository discovery, planner dispatch, prompt materialization, worktrees,
locks, evidence bundles. Nothing here depends on that host. The public runner
[mentu-ai/mentu-recipes](https://github.com/mentu-ai/mentu-recipes) does not
use this package; it is the file-based on-ramp, and this is the graph layer
above it.

## License

MIT. See [LICENSE](LICENSE).
