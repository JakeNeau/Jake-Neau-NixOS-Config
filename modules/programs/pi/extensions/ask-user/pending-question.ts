import type { AskUserDetails, AskUserParams } from "./core.ts";

type AskUserStatus = AskUserDetails["status"];

export class PendingQuestion {
  private question: AskUserParams | undefined;
  private reopening = false;

  beginToolCall(): void {
    this.question = undefined;
  }

  finishToolCall(question: AskUserParams, status: AskUserStatus): void {
    this.question = status === "clarification" ? question : undefined;
  }

  beginReopen(): AskUserParams | undefined {
    if (!this.question || this.reopening) return undefined;
    this.reopening = true;
    return this.question;
  }

  finishReopen(status: AskUserStatus): void {
    if (status !== "clarification") this.question = undefined;
    this.reopening = false;
  }

  releaseReopen(): void {
    this.reopening = false;
  }

  reset(): void {
    this.question = undefined;
    this.reopening = false;
  }
}
