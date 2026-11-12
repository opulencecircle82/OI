import { supabase } from "../site";

/** Apps sharing the license table (column `app`). */
export const APPS = [
  { key: "fap", label: "A320 FAP", prefix: "A320-", product: "A320 FAP Simulator" },
  { key: "mcdu", label: "A320 MCDU Trainer", prefix: "MCDU-", product: "A320 MCDU Trainer" },
  // Needs PRIVATE_supabase_cabin.sql on the database first (else the
  // server treats "cabin" as "fap").
  { key: "cabin", label: "Cabin Entertainment", prefix: "CABIN-", product: "Cabin Entertainment" },
  // Needs PRIVATE_supabase_safety.sql (run 2026-11-12).
  { key: "safety", label: "A320 Cabin Safety", prefix: "SAFETY-", product: "A320 Cabin Safety" },
] as const;
export type AppKey = (typeof APPS)[number]["key"];

export const appInfo = (key: string) => APPS.find((a) => a.key === key) ?? APPS[0];

export class RpcError extends Error {}

/** Calls a Supabase RPC function with the publishable key. Database errors
 * raised with a known code (NOT_AUTHORIZED, BAD_LINE...) come back as that
 * code; anything else is SERVER. */
export async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${supabase.url}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: { apikey: supabase.key, "Content-Type": "application/json" },
      body: JSON.stringify(args),
    });
  } catch {
    throw new RpcError("NETWORK");
  }
  const text = await res.text();
  if (!res.ok) {
    if (res.status === 404) throw new RpcError("NOT_SET_UP");
    const known = KNOWN_ERRORS.find((k) => text.includes(`"${k}"`));
    throw new RpcError(known ?? "SERVER");
  }
  return (text ? JSON.parse(text) : null) as T;
}

const KNOWN_ERRORS = [
  "NOT_AUTHORIZED",
  "NO_CLIENT",
  "NO_LINES",
  "BAD_APP",
  "BAD_LINE",
  "BAD_DISCOUNT",
];

export const errorText: Record<string, string> = {
  INVALID: "Wrong username or password.",
  TOO_MANY_ATTEMPTS: "Too many attempts. Please wait 15 minutes.",
  NETWORK: "No connection to the server.",
  NOT_SET_UP: "The database is not set up yet. Run the setup SQL in Supabase.",
  SERVER: "Server error. Please try again.",
  WRONG_PASSWORD: "Current password is wrong.",
  TOO_SHORT: "Username needs 3+ characters and password 8+ characters.",
  NOT_USED: "That code is no longer active on a device (already released). Reload the page.",
  NO_CLIENT: "Enter the client's name.",
  NO_LINES: "Enter how many codes to make for at least one app.",
  BAD_APP: "Unknown app in the order.",
  BAD_LINE: "Each quantity must be 0 to 500 and each price 0 to 1,000,000.",
  BAD_DISCOUNT: "The discount cannot be more than the subtotal.",
};

export function fmt(d: string | null) {
  return d ? new Date(d).toLocaleString() : "—";
}
