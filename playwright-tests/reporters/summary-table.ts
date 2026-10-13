// End-of-run summary: one row per spec file with a ✔ / ✖, per project, plus a
// totals row and the list of failed tests. Printed to stdout after the other
// reporters, and written as a Markdown table to the GitHub job summary when
// GITHUB_STEP_SUMMARY is set.
//
// A spec is ✖ when any of its tests failed (outcome "unexpected"). Flaky tests
// (failed, then passed on retry) count as passed and are shown in their own
// column. Time is the sum of every attempt's duration, so for specs whose tests
// run in parallel it is test time, not wall-clock time.
import fs from "node:fs";
import path from "node:path";
import type {
  FullConfig,
  FullResult,
  Reporter,
  Suite,
  TestCase,
} from "@playwright/test/reporter";

interface SpecRow {
  spec: string;
  tests: number;
  passed: number;
  failed: number;
  flaky: number;
  skipped: number;
  durationMs: number;
  failures: string[];
}

const useColor =
  !process.env.NO_COLOR &&
  (Boolean(process.stdout.isTTY) ||
    Boolean(process.env.CI) ||
    Boolean(process.env.FORCE_COLOR));
const paint = (code: number) => (s: string) =>
  useColor ? `\u001b[${code}m${s}\u001b[0m` : s;
const green = paint(32);
const red = paint(31);
const yellow = paint(33);
const gray = paint(90);

const TICK = "✔";
const CROSS = "✖";

const formatDuration = (ms: number): string => {
  const totalSeconds = Math.round(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
};

// A count, or "-" for zero, as Cypress prints it.
const count = (n: number): string => (n === 0 ? "-" : String(n));

export default class SummaryTableReporter implements Reporter {
  private config!: FullConfig;
  private root!: Suite;

  onBegin(config: FullConfig, suite: Suite): void {
    this.config = config;
    this.root = suite;
  }

  printsToStdio(): boolean {
    return true;
  }

  onEnd(result: FullResult): void {
    // Nothing ran (e.g. `--list`): there is no run to summarise.
    if (!this.root.allTests().some((test) => test.results.length > 0)) return;
    const byProject = this.collect();
    if (byProject.size === 0) return;

    const lines: string[] = ["", "  (Run Finished)", ""];
    for (const [project, rows] of byProject) {
      lines.push(...this.renderTable(project, rows), "");
    }

    const failures = [...byProject].flatMap(([project, rows]) =>
      rows.flatMap((row) =>
        row.failures.map((title) => `[${project}] › ${row.spec} › ${title}`),
      ),
    );
    if (failures.length > 0) {
      lines.push(`  ${red(`Failed tests (${failures.length}):`)}`);
      for (const failure of failures)
        lines.push(`    ${red(CROSS)}  ${failure}`);
      lines.push("");
    }
    if (result.status === "interrupted" || result.status === "timedout") {
      lines.push(
        `  ${yellow(`Run ${result.status}: tests that never started are counted as skipped.`)}`,
        "",
      );
    }
    process.stdout.write(`${lines.join("\n")}\n`);

    this.writeGitHubSummary(byProject, failures);
  }

  /** project name → one row per spec file, in file order. */
  private collect(): Map<string, SpecRow[]> {
    const byProject = new Map<string, SpecRow[]>();
    for (const projectSuite of this.root.suites) {
      const project = projectSuite.project();
      const projectName = project?.name || "default";
      const testDir = project?.testDir ?? this.config.rootDir;
      const rows: SpecRow[] = [];

      for (const fileSuite of projectSuite.suites) {
        const tests = fileSuite.allTests();
        if (tests.length === 0) continue;
        const row: SpecRow = {
          spec: path
            .relative(testDir, fileSuite.location?.file ?? fileSuite.title)
            .split(path.sep)
            .join("/"),
          tests: tests.length,
          passed: 0,
          failed: 0,
          flaky: 0,
          skipped: 0,
          durationMs: 0,
          failures: [],
        };
        for (const test of tests) {
          row.durationMs += test.results.reduce((ms, r) => ms + r.duration, 0);
          switch (test.outcome()) {
            case "expected":
              row.passed++;
              break;
            case "flaky":
              row.flaky++;
              break;
            case "unexpected":
              row.failed++;
              row.failures.push(titleOf(test));
              break;
            case "skipped":
              row.skipped++;
              break;
          }
        }
        rows.push(row);
      }
      if (rows.length > 0) byProject.set(projectName, rows);
    }
    return byProject;
  }

  private renderTable(project: string, rows: SpecRow[]): string[] {
    const specWidth = Math.max(4, ...rows.map((r) => r.spec.length));
    const numbers = (r: {
      durationMs: number;
      tests: number;
      passed: number;
      failed: number;
      flaky: number;
      skipped: number;
    }) =>
      [
        formatDuration(r.durationMs).padStart(7),
        String(r.tests).padStart(7),
        count(r.passed).padStart(8),
        count(r.failed).padStart(8),
        count(r.flaky).padStart(7),
        count(r.skipped).padStart(8),
      ].join("");
    const header =
      `       ${"Spec".padEnd(specWidth)}` +
      [
        "Time".padStart(7),
        "Tests".padStart(7),
        "Passing".padStart(8),
        "Failing".padStart(8),
        "Flaky".padStart(7),
        "Skipped".padStart(8),
      ].join("");
    const innerWidth = header.length - 2;

    const out: string[] = [`  ${gray(`Project: ${project}`)}`, "", header];
    out.push(`  ┌${"─".repeat(innerWidth)}┐`);
    for (const row of rows) {
      const ok = row.failed === 0;
      const mark = ok ? green(TICK) : red(CROSS);
      const spec = row.spec.padEnd(specWidth);
      let body = `${mark}  ${ok ? spec : red(spec)}${numbers(row)}`;
      // Pad by visible length (colour codes take no space).
      const visible = `${TICK}  ${spec}${numbers(row)}`;
      body += " ".repeat(Math.max(0, innerWidth - 2 - visible.length));
      out.push(`  │ ${body} │`);
    }
    out.push(`  └${"─".repeat(innerWidth)}┘`);

    const total = rows.reduce(
      (t, r) => ({
        durationMs: t.durationMs + r.durationMs,
        tests: t.tests + r.tests,
        passed: t.passed + r.passed,
        failed: t.failed + r.failed,
        flaky: t.flaky + r.flaky,
        skipped: t.skipped + r.skipped,
      }),
      { durationMs: 0, tests: 0, passed: 0, failed: 0, flaky: 0, skipped: 0 },
    );
    const failedSpecs = rows.filter((r) => r.failed > 0).length;
    const verdict =
      failedSpecs === 0
        ? green(`${TICK}  All specs passed!`.padEnd(specWidth + 3))
        : red(
            `${CROSS}  ${failedSpecs} of ${rows.length} failed (${Math.round((failedSpecs / rows.length) * 100)}%)`.padEnd(
              specWidth + 3,
            ),
          );
    out.push(`    ${verdict}${numbers(total)}`);
    return out;
  }

  private writeGitHubSummary(
    byProject: Map<string, SpecRow[]>,
    failures: string[],
  ): void {
    const file = process.env.GITHUB_STEP_SUMMARY;
    if (!file) return;
    const md: string[] = [];
    for (const [project, rows] of byProject) {
      md.push(
        `### Playwright — ${project}`,
        "",
        "| | Spec | Time | Tests | Passing | Failing | Flaky | Skipped |",
        "|---|---|---:|---:|---:|---:|---:|---:|",
      );
      for (const r of rows) {
        md.push(
          `| ${r.failed === 0 ? "✅" : "❌"} | \`${r.spec}\` | ${formatDuration(r.durationMs)} | ${r.tests} | ${count(r.passed)} | ${count(r.failed)} | ${count(r.flaky)} | ${count(r.skipped)} |`,
        );
      }
      const failedSpecs = rows.filter((r) => r.failed > 0).length;
      const sum = (k: keyof SpecRow) =>
        rows.reduce((n, r) => n + (r[k] as number), 0);
      md.push(
        `| ${failedSpecs === 0 ? "✅" : "❌"} | **${failedSpecs === 0 ? "All specs passed" : `${failedSpecs} of ${rows.length} failed`}** | ${formatDuration(sum("durationMs"))} | ${sum("tests")} | ${count(sum("passed"))} | ${count(sum("failed"))} | ${count(sum("flaky"))} | ${count(sum("skipped"))} |`,
        "",
      );
    }
    if (failures.length > 0) {
      md.push(
        `<details><summary>Failed tests (${failures.length})</summary>`,
        "",
        ...failures.map((f) => `- ❌ ${f.replace(/\|/g, "\\|")}`),
        "",
        "</details>",
        "",
      );
    }
    try {
      fs.appendFileSync(file, `${md.join("\n")}\n`);
    } catch {
      // The job summary is a convenience; never fail the run over it.
    }
  }
}

/** "describe › nested describe › test" without the project and file levels. */
function titleOf(test: TestCase): string {
  return test.titlePath().slice(3).join(" › ");
}
