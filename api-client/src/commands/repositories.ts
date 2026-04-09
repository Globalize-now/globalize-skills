import { Command, Option } from "commander";
import type { ApiClient } from "../client.js";
import { extractError } from "../client.js";
import { output, outputError, type OutputOptions } from "../format.js";

type ClientFactory = () => Promise<ApiClient>;

export async function listRepositories(client: ApiClient, projectId: string) {
  const { data, error, response } = await client.GET("/api/repositories", {
    params: { query: { projectId } },
  });
  if (error) throw new Error(extractError(response, error));
  return data!;
}

export async function createRepository(
  client: ApiClient,
  projectId: string,
  gitUrl: string,
  provider: "github" | "gitlab",
  branches?: string[],
  localePathPattern?: string,
  githubInstallationId?: string,
  prTranslations?: boolean,
  skipDraftPrs?: boolean,
) {
  const { data, error, response } = await client.POST("/api/repositories", {
    body: {
      projectId,
      gitUrl,
      provider,
      branches,
      localePathPattern,
      githubInstallationId,
      prTranslations,
      skipDraftPrs,
    },
  });
  if (error) throw new Error(extractError(response, error));
  return data!;
}

export async function updateRepository(
  client: ApiClient,
  id: string,
  updates: {
    gitUrl?: string;
    branches?: string[];
    localePathPattern?: string | null;
    githubInstallationId?: string;
    provider?: "github" | "gitlab";
    fileFormat?: string;
    detectedFramework?: string | null;
    prTranslations?: boolean;
    skipDraftPrs?: boolean;
  },
) {
  const { data, error, response } = await client.PATCH("/api/repositories/{id}", {
    params: { path: { id } },
    body: updates,
  });
  if (error) throw new Error(extractError(response, error));
  return data!;
}

export async function deleteRepository(client: ApiClient, id: string) {
  const { data, error, response } = await client.DELETE("/api/repositories/{id}", {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data ?? { deleted: true };
}

export async function detectRepository(client: ApiClient, id: string) {
  const { data, error, response } = await client.POST("/api/repositories/{id}/detect", {
    params: { path: { id } },
  });
  if (error) throw new Error(extractError(response, error));
  return data!;
}

export function register(group: Command, getClient: ClientFactory): void {
  group
    .command("list")
    .description("List repositories")
    .requiredOption("--project-id <id>", "Project UUID")
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await listRepositories(client, cmdOpts.projectId), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command("create")
    .description("Create a repository")
    .requiredOption("--project-id <id>", "Project UUID")
    .requiredOption("--git-url <url>", "Git repository URL")
    .addOption(new Option("--provider <provider>", "Git provider").choices(["github", "gitlab"]).makeOptionMandatory())
    .option("--branches <branches...>", "Branches to track")
    .option("--locale-path-pattern <pattern>", "Locale path pattern")
    .option("--github-installation-id <id>", "GitHub App installation ID")
    .option("--pr-translations", "Enable PR translations")
    .option("--skip-draft-prs", "Skip draft pull requests")
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(
          await createRepository(
            client,
            cmdOpts.projectId,
            cmdOpts.gitUrl,
            cmdOpts.provider,
            cmdOpts.branches,
            cmdOpts.localePathPattern,
            cmdOpts.githubInstallationId,
            cmdOpts.prTranslations,
            cmdOpts.skipDraftPrs,
          ),
          opts,
        );
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command("update")
    .description("Update a repository")
    .requiredOption("--id <id>", "Repository UUID")
    .option("--git-url <url>", "Git repository URL")
    .option("--branches <branches...>", "Branches to track")
    .option("--locale-path-pattern <pattern>", "Locale path pattern")
    .option("--github-installation-id <id>", "GitHub App installation ID")
    .addOption(new Option("--provider <provider>", "Git provider").choices(["github", "gitlab"]))
    .option("--file-format <format>", "File format")
    .option("--detected-framework <framework>", "Detected framework")
    .option("--pr-translations", "Enable PR translations")
    .option("--no-pr-translations", "Disable PR translations")
    .option("--skip-draft-prs", "Skip draft pull requests")
    .option("--no-skip-draft-prs", "Do not skip draft pull requests")
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        const updates: Record<string, unknown> = {};
        if (cmdOpts.gitUrl !== undefined) updates.gitUrl = cmdOpts.gitUrl;
        if (cmdOpts.branches !== undefined) updates.branches = cmdOpts.branches;
        if (cmdOpts.localePathPattern !== undefined) updates.localePathPattern = cmdOpts.localePathPattern;
        if (cmdOpts.githubInstallationId !== undefined) updates.githubInstallationId = cmdOpts.githubInstallationId;
        if (cmdOpts.provider !== undefined) updates.provider = cmdOpts.provider;
        if (cmdOpts.fileFormat !== undefined) updates.fileFormat = cmdOpts.fileFormat;
        if (cmdOpts.detectedFramework !== undefined) updates.detectedFramework = cmdOpts.detectedFramework;
        if (cmdOpts.prTranslations !== undefined) updates.prTranslations = cmdOpts.prTranslations;
        if (cmdOpts.skipDraftPrs !== undefined) updates.skipDraftPrs = cmdOpts.skipDraftPrs;
        output(await updateRepository(client, cmdOpts.id, updates), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command("delete")
    .description("Delete a repository")
    .requiredOption("--id <id>", "Repository UUID")
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await deleteRepository(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });

  group
    .command("detect")
    .description("Detect repository configuration")
    .requiredOption("--id <id>", "Repository UUID")
    .action(async (cmdOpts, cmd) => {
      const opts: OutputOptions = cmd.optsWithGlobals();
      try {
        const client = await getClient();
        output(await detectRepository(client, cmdOpts.id), opts);
      } catch (e) {
        outputError((e as Error).message, opts);
      }
    });
}
