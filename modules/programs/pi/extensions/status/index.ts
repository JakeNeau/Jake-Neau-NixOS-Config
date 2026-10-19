import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const STATUS_QUESTION = [
  "Status check. Answer fast: reply only from this conversation, use no tools, and keep reasoning brief.",
  "Take the latest of my last message to you and my last answer to an ask_user question as the reference point.",
  "In at most five short bullets, summarize the run since then: what I asked for, what you have done, what you are doing now, and what remains.",
].join(" ");

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("status", {
    description: "Ask a BTW side thread how the current run is going",
    handler: async () => {
      // A new thread reseeds from the live session; reusing one would report a stale snapshot.
      pi.sendUserMessage(`/btw:new ${STATUS_QUESTION}`, { expandPromptTemplates: true });
    },
  });
}
