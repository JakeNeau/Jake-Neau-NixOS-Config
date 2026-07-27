import type { Readable, Writable } from "node:stream";

interface PendingRequest {
  resolve(value: unknown): void;
  reject(error: Error): void;
  timer: NodeJS.Timeout;
}

export interface ConnectionOptions {
  timeoutMs?: number;
  mode?: "jsonrpc" | "dap";
}

export interface RequestOptions {
  timeoutMs?: number;
}

type NotificationHandler = (params: unknown) => void;

export function encodeFrame(message: unknown): Buffer {
  const body = Buffer.from(JSON.stringify(message), "utf8");
  return Buffer.concat([
    Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "ascii"),
    body,
  ]);
}

export class ContentLengthConnection {
  private buffer = Buffer.alloc(0);
  private nextId = 1;
  private readonly pending = new Map<number, PendingRequest>();
  private readonly handlers = new Map<string, Set<NotificationHandler>>();
  private closed = false;
  private readonly timeoutMs: number;
  private readonly mode: "jsonrpc" | "dap";
  private readonly readable: Readable;
  private readonly writable: Writable;

  constructor(
    readable: Readable,
    writable: Writable,
    options: ConnectionOptions = {},
  ) {
    this.readable = readable;
    this.writable = writable;
    this.timeoutMs = options.timeoutMs ?? 10_000;
    this.mode = options.mode ?? "jsonrpc";
    readable.on("data", this.onData);
    readable.on("error", this.onFailure);
    readable.on("end", this.onEnd);
    writable.on("error", this.onFailure);
  }

  async request(method: string, params: unknown, options: RequestOptions = {}): Promise<unknown> {
    if (this.closed) throw new Error("protocol connection is closed");
    const id = this.nextId++;
    const timeoutMs = options.timeoutMs ?? this.timeoutMs;
    const result = new Promise<unknown>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${method} request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
    });
    try {
      await this.write(this.mode === "dap"
        ? { seq: id, type: "request", command: method, arguments: params }
        : { jsonrpc: "2.0", id, method, params });
    } catch (error) {
      const pending = this.pending.get(id);
      if (pending) {
        clearTimeout(pending.timer);
        this.pending.delete(id);
        pending.reject(error instanceof Error ? error : new Error(String(error)));
      }
    }
    return result;
  }

  async notify(method: string, params: unknown): Promise<void> {
    if (this.closed) throw new Error("protocol connection is closed");
    await this.write(this.mode === "dap"
      ? { seq: this.nextId++, type: "event", event: method, body: params }
      : { jsonrpc: "2.0", method, params });
  }

  onNotification(method: string, handler: NotificationHandler): () => void {
    const handlers = this.handlers.get(method) ?? new Set<NotificationHandler>();
    handlers.add(handler);
    this.handlers.set(method, handlers);
    return () => {
      handlers.delete(handler);
      if (handlers.size === 0) this.handlers.delete(method);
    };
  }

  close(): Promise<void> {
    if (this.closed) return Promise.resolve();
    this.closed = true;
    this.detach();
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error("protocol connection closed"));
    }
    this.pending.clear();
    if (!this.writable.destroyed) this.writable.end();
    return Promise.resolve();
  }

  private readonly write = async (message: unknown): Promise<void> => {
    const frame = encodeFrame(message);
    await new Promise<void>((resolve, reject) => {
      this.writable.write(frame, (error) => error ? reject(error) : resolve());
    });
  };

  private readonly onData = (chunk: Buffer | string) => {
    this.buffer = Buffer.concat([this.buffer, Buffer.from(chunk)]);
    while (true) {
      const boundary = this.buffer.indexOf("\r\n\r\n");
      if (boundary === -1) return;
      const header = this.buffer.subarray(0, boundary).toString("ascii");
      const match = header.match(/(?:^|\r\n)Content-Length:\s*(\d+)/i);
      if (!match) {
        this.fail(new Error("protocol frame has no Content-Length header"));
        return;
      }
      const length = Number(match[1]);
      const end = boundary + 4 + length;
      if (this.buffer.length < end) return;
      const body = this.buffer.subarray(boundary + 4, end);
      this.buffer = this.buffer.subarray(end);
      try {
        this.dispatch(JSON.parse(body.toString("utf8")) as Record<string, unknown>);
      } catch (error) {
        this.fail(error instanceof Error ? error : new Error(String(error)));
        return;
      }
    }
  };

  private dispatch(message: Record<string, unknown>): void {
    if (this.mode === "dap") {
      if (message.type === "response" && typeof message.request_seq === "number") {
        const pending = this.pending.get(message.request_seq);
        if (!pending) return;
        clearTimeout(pending.timer);
        this.pending.delete(message.request_seq);
        if (message.success === false) {
          pending.reject(new Error(typeof message.message === "string" ? message.message : "DAP request failed"));
        } else {
          pending.resolve(message.body);
        }
        return;
      }
      if (message.type !== "event" || typeof message.event !== "string") return;
      for (const handler of this.handlers.get(message.event) ?? []) handler(message.body);
      return;
    }
    if (typeof message.id === "number" && ("result" in message || "error" in message)) {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      clearTimeout(pending.timer);
      this.pending.delete(message.id);
      if (message.error && typeof message.error === "object") {
        const value = message.error as { message?: unknown };
        pending.reject(new Error(typeof value.message === "string" ? value.message : "protocol request failed"));
      } else {
        pending.resolve(message.result);
      }
      return;
    }
    if (typeof message.method !== "string") return;
    for (const handler of this.handlers.get(message.method) ?? []) handler(message.params);
  }

  private readonly onFailure = (error: Error) => this.fail(error);
  private readonly onEnd = () => this.fail(new Error("protocol stream ended"));

  private fail(error: Error): void {
    if (this.closed) return;
    this.closed = true;
    this.detach();
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
    if (!this.writable.destroyed) this.writable.destroy();
  }

  private detach(): void {
    this.readable.off("data", this.onData);
    this.readable.off("error", this.onFailure);
    this.readable.off("end", this.onEnd);
    this.writable.off("error", this.onFailure);
  }
}
