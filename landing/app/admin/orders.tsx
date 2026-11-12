"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  DEFAULT_SELLER,
  type Order,
  type Seller,
  downloadCsv,
  downloadInvoicePdf,
  invoiceDate,
  money,
} from "./invoice";
import { APPS, type AppKey, appInfo, errorText, rpc } from "./lib";

const SELLER_KEY = "oi_invoice_seller";
const PRICES_KEY = "oi_invoice_prices";

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw ? { ...fallback, ...JSON.parse(raw) } : fallback;
  } catch {
    return fallback;
  }
}

function writeJson(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage blocked: keep it for this visit only */
  }
}

type Draft = Record<AppKey, { qty: string; price: string }>;

const emptyDraft = (prices: Record<string, string>): Draft =>
  Object.fromEntries(APPS.map((a) => [a.key, { qty: "", price: prices[a.key] ?? "" }])) as Draft;

const toNum = (s: string) => (s.trim() === "" ? 0 : Number(s));

const inputCls =
  "mt-1 block w-full rounded-lg border border-line bg-ink px-3 py-2.5 text-base text-white outline-none focus:border-cyan";
const labelCls = "block text-xs font-bold tracking-wider text-silver";

/** ORDERS & INVOICES: make codes for a client in one go, then download the
 * invoice (PDF, with the codes) and the codes (CSV). Every order is kept. */
export function Orders({ token, onExpired }: { token: string; onExpired: () => void }) {
  const [orders, setOrders] = useState<Order[] | null>(null);
  const [version, setVersion] = useState(0);
  const [message, setMessage] = useState<{ text: string; ok: boolean } | null>(null);
  const [busy, setBusy] = useState(false);
  const [created, setCreated] = useState<Order | null>(null);
  const [open, setOpen] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  const [seller, setSeller] = useState<Seller>(DEFAULT_SELLER);
  const [showSeller, setShowSeller] = useState(false);
  const [client, setClient] = useState({ name: "", contact: "", address: "", notes: "", discount: "" });
  const [draft, setDraft] = useState<Draft>(() => emptyDraft({}));

  // Saved seller details and last prices live in this browser only.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- read browser storage after mount
    setSeller(readJson(SELLER_KEY, DEFAULT_SELLER));
    setDraft(emptyDraft(readJson<Record<string, string>>(PRICES_KEY, {})));
  }, []);

  const fail = useCallback(
    (err: unknown) => {
      const code = (err as Error).message;
      if (code === "NOT_AUTHORIZED") {
        onExpired();
        return;
      }
      setMessage({ text: errorText[code] ?? errorText.SERVER, ok: false });
    },
    [onExpired],
  );

  useEffect(() => {
    let alive = true;
    rpc<Order[]>("a320_admin_list_orders", { p_token: token })
      .then((rows) => {
        if (alive) setOrders(rows ?? []);
      })
      .catch((err) => {
        if (alive) {
          setOrders([]);
          fail(err);
        }
      });
    return () => {
      alive = false;
    };
  }, [token, fail, version]);

  // ------------------------------------------------------------- the order form
  const lines = APPS.map((a) => {
    const qty = toNum(draft[a.key].qty);
    const price = toNum(draft[a.key].price);
    return { app: a.key, qty, price, amount: qty * price };
  });
  const totalQty = lines.reduce((s, l) => s + (Number.isFinite(l.qty) ? l.qty : 0), 0);
  const subtotal = lines.reduce((s, l) => s + (Number.isFinite(l.amount) ? l.amount : 0), 0);
  const discount = toNum(client.discount);
  const total = subtotal - (Number.isFinite(discount) ? discount : 0);

  const problem = (() => {
    if (!client.name.trim()) return "Enter the client's name.";
    for (const l of lines) {
      if (!Number.isInteger(l.qty) || l.qty < 0 || l.qty > 500)
        return `${appInfo(l.app).label}: quantity must be a whole number from 0 to 500.`;
      if (!Number.isFinite(l.price) || l.price < 0 || l.price > 1_000_000)
        return `${appInfo(l.app).label}: price must be from 0 to 1,000,000.`;
    }
    if (totalQty === 0) return "Enter how many codes to make for at least one app.";
    if (!Number.isFinite(discount) || discount < 0 || discount > subtotal)
      return "The discount must be from 0 up to the subtotal.";
    return null;
  })();

  const generate = async () => {
    if (problem) {
      setMessage({ text: problem, ok: false });
      return;
    }
    const summary = lines
      .filter((l) => l.qty > 0)
      .map((l) => `${l.qty} × ${appInfo(l.app).label}`)
      .join(", ");
    if (
      !confirm(
        `Create an invoice for ${client.name.trim()}?\n\n${summary}\nTotal: ₱${money(total)}\n\n` +
          `${totalQty} new license codes will be made. This cannot be undone.`,
      )
    )
      return;
    setBusy(true);
    setMessage(null);
    try {
      const order = await rpc<Order>("a320_admin_create_order", {
        p_token: token,
        p_client: client.name.trim(),
        p_contact: client.contact.trim(),
        p_address: client.address.trim(),
        p_notes: client.notes.trim(),
        p_discount: Number.isFinite(discount) ? discount : 0,
        p_lines: lines.map((l) => ({ app: l.app, qty: l.qty, unit_price: l.price })),
      });
      // Remember this browser's prices for the next order.
      writeJson(PRICES_KEY, Object.fromEntries(APPS.map((a) => [a.key, draft[a.key].price])));
      setCreated(order);
      setClient({ name: "", contact: "", address: "", notes: "", discount: "" });
      setDraft(emptyDraft(Object.fromEntries(APPS.map((a) => [a.key, draft[a.key].price]))));
      setMessage({ text: `${order.invoice_no} created: ${order.codes.length} codes.`, ok: true });
      setVersion((v) => v + 1);
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  };

  const pdf = async (o: Order) => {
    try {
      await downloadInvoicePdf(o, seller);
    } catch {
      setMessage({ text: "Could not make the PDF. Please try again.", ok: false });
    }
  };
  const copyAll = (o: Order) =>
    navigator.clipboard
      ?.writeText(
        APPS.filter((a) => o.codes.some((c) => c.app === a.key))
          .map(
            (a) =>
              `${a.product}\n` +
              o.codes
                .filter((c) => c.app === a.key)
                .map((c) => c.code)
                .join("\n"),
          )
          .join("\n\n"),
      )
      .then(() => setMessage({ text: `${o.codes.length} codes of ${o.invoice_no} copied.`, ok: true }));

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return orders ?? [];
    return (orders ?? []).filter(
      (o) =>
        o.invoice_no.toLowerCase().includes(q) ||
        o.client_name.toLowerCase().includes(q) ||
        o.codes.some((c) => c.code.toLowerCase().includes(q)),
    );
  }, [orders, query]);

  const actionBtn = "rounded-md border border-line px-2.5 py-1 text-xs font-bold text-silver hover:text-white";

  return (
    <div className="mt-6 space-y-6">
      {message && (
        <p
          className={`rounded-lg border px-4 py-3 text-sm font-bold ${
            message.ok ? "border-fap-green/50 text-fap-green" : "border-fap-red/50 text-fap-red"
          }`}
        >
          {message.text}
        </p>
      )}

      {created && (
        <section className="rounded-2xl border border-fap-green/50 bg-fap-green/5 p-5">
          <div className="flex flex-wrap items-center gap-3">
            <div>
              <div className="font-mono text-xs font-bold tracking-widest text-fap-green">INVOICE READY</div>
              <div className="mt-1 text-xl font-extrabold">
                {created.invoice_no} · {created.client_name}
              </div>
              <div className="text-sm text-silver">
                {created.codes.length} codes · ₱{money(created.total)}
              </div>
            </div>
            <div className="ml-auto flex flex-wrap gap-2">
              <button
                onClick={() => pdf(created)}
                className="rounded-xl bg-cyan px-4 py-2.5 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
              >
                DOWNLOAD INVOICE (PDF)
              </button>
              <button onClick={() => downloadCsv(created)} className="rounded-xl border border-line px-4 py-2.5 text-sm font-bold text-silver hover:text-white">
                Codes (CSV)
              </button>
              <button onClick={() => copyAll(created)} className="rounded-xl border border-line px-4 py-2.5 text-sm font-bold text-silver hover:text-white">
                Copy codes
              </button>
              <button onClick={() => setCreated(null)} className="rounded-xl px-3 py-2.5 text-sm font-bold text-silver hover:text-white">
                ✕
              </button>
            </div>
          </div>
        </section>
      )}

      {/* ------------------------------------------------------------- new order */}
      <section className="rounded-2xl border border-cyan/40 bg-panel/80 p-5 sm:p-6">
        <h2 className="text-lg font-extrabold">New order</h2>
        <p className="mt-1 text-sm text-silver">
          Make license codes for a client in one go. Codes made here are the client&apos;s: they are
          not part of the 10 unused codes of each app.
        </p>

        <div className="mt-5 grid gap-4 sm:grid-cols-2">
          <label className={labelCls}>
            CLIENT NAME *
            <input value={client.name} onChange={(e) => setClient({ ...client, name: e.target.value })} maxLength={120} className={inputCls} />
          </label>
          <label className={labelCls}>
            CONTACT (EMAIL / PHONE)
            <input value={client.contact} onChange={(e) => setClient({ ...client, contact: e.target.value })} maxLength={160} className={inputCls} />
          </label>
          <label className={`${labelCls} sm:col-span-2`}>
            ADDRESS
            <input value={client.address} onChange={(e) => setClient({ ...client, address: e.target.value })} maxLength={300} className={inputCls} />
          </label>
        </div>

        <div className="mt-5 overflow-x-auto">
          <table className="w-full min-w-[560px] text-left text-sm">
            <thead>
              <tr className="text-xs tracking-wider text-silver">
                <th className="py-2">APP</th>
                <th className="py-2">QUANTITY</th>
                <th className="py-2">PRICE PER CODE (₱)</th>
                <th className="py-2 text-right">AMOUNT (₱)</th>
              </tr>
            </thead>
            <tbody>
              {APPS.map((a) => {
                const l = lines.find((x) => x.app === a.key)!;
                return (
                  <tr key={a.key} className="border-t border-line/60">
                    <td className="py-2 pr-3 font-bold">
                      {a.label}
                      <span className="ml-2 font-mono text-xs text-silver">{a.prefix}</span>
                    </td>
                    <td className="py-2 pr-3">
                      <input
                        inputMode="numeric"
                        value={draft[a.key].qty}
                        placeholder="0"
                        onChange={(e) =>
                          setDraft({ ...draft, [a.key]: { ...draft[a.key], qty: e.target.value.replace(/[^0-9]/g, "") } })
                        }
                        className="w-24 rounded-lg border border-line bg-ink px-3 py-2 text-white outline-none focus:border-cyan"
                      />
                    </td>
                    <td className="py-2 pr-3">
                      <input
                        inputMode="decimal"
                        value={draft[a.key].price}
                        placeholder="0.00"
                        onChange={(e) =>
                          setDraft({ ...draft, [a.key]: { ...draft[a.key], price: e.target.value.replace(/[^0-9.]/g, "") } })
                        }
                        className="w-36 rounded-lg border border-line bg-ink px-3 py-2 text-white outline-none focus:border-cyan"
                      />
                    </td>
                    <td className="py-2 text-right font-mono">{Number.isFinite(l.amount) ? money(l.amount) : "—"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        <div className="mt-4 grid gap-4 sm:grid-cols-[1fr_auto]">
          <label className={labelCls}>
            NOTES ON THE INVOICE
            <input value={client.notes} onChange={(e) => setClient({ ...client, notes: e.target.value })} maxLength={500} className={inputCls} />
          </label>
          <label className={labelCls}>
            DISCOUNT (₱)
            <input
              inputMode="decimal"
              value={client.discount}
              placeholder="0.00"
              onChange={(e) => setClient({ ...client, discount: e.target.value.replace(/[^0-9.]/g, "") })}
              className={`${inputCls} sm:w-40`}
            />
          </label>
        </div>

        <div className="mt-5 flex flex-wrap items-end gap-4 border-t border-line pt-4">
          <div className="text-sm text-silver">
            {totalQty} codes · Subtotal ₱{money(subtotal)}
            {discount > 0 && <> · Discount ₱{money(discount)}</>}
            <div className="mt-1 text-2xl font-extrabold text-white">TOTAL ₱{Number.isFinite(total) ? money(total) : "—"}</div>
            <div className="text-xs">No VAT.</div>
          </div>
          <button
            disabled={busy}
            onClick={generate}
            className="ml-auto rounded-xl bg-cyan px-6 py-3 font-extrabold tracking-wider text-black hover:brightness-110 disabled:opacity-50"
          >
            {busy ? "Generating…" : "GENERATE CODES & INVOICE"}
          </button>
        </div>
      </section>

      {/* ------------------------------------------------------------- seller */}
      <section className="rounded-2xl border border-line bg-panel/60 p-5">
        <button onClick={() => setShowSeller(!showSeller)} className="flex w-full items-center text-left">
          <span className="font-extrabold">Your details on the invoice</span>
          <span className="ml-3 text-sm text-silver">{seller.name}</span>
          <span className="ml-auto text-silver">{showSeller ? "▲" : "▼"}</span>
        </button>
        {showSeller && (
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            {(
              [
                ["name", "BUSINESS NAME", false],
                ["contact", "CONTACT (EMAIL / PHONE)", false],
                ["address", "ADDRESS", true],
                ["payment", "PAYMENT INSTRUCTIONS (e.g. GCash / bank account)", true],
                ["footer", "CLOSING LINE", true],
              ] as const
            ).map(([key, label, wide]) => (
              <label key={key} className={`${labelCls} ${wide ? "sm:col-span-2" : ""}`}>
                {label}
                <input
                  value={seller[key]}
                  onChange={(e) => {
                    const next = { ...seller, [key]: e.target.value };
                    setSeller(next);
                    writeJson(SELLER_KEY, next);
                  }}
                  className={inputCls}
                />
              </label>
            ))}
            <p className="text-xs text-silver sm:col-span-2">
              Saved in this browser only. They are printed on every invoice you download here, including old ones.
            </p>
          </div>
        )}
      </section>

      {/* ------------------------------------------------------------- order list */}
      <section className="rounded-2xl border border-line bg-panel/80 p-5">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-lg font-extrabold">
            Orders <span className="text-cyan">({orders ? orders.length : "…"})</span>
          </h2>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search invoice, client or code"
            className="ml-auto w-full rounded-lg border border-line bg-ink px-3 py-2 text-sm text-white outline-none focus:border-cyan sm:w-72"
          />
        </div>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[760px] text-left text-sm">
            <thead>
              <tr className="text-xs tracking-wider text-silver">
                <th className="py-2">INVOICE</th>
                <th className="py-2">DATE</th>
                <th className="py-2">CLIENT</th>
                <th className="py-2">CODES ACTIVATED</th>
                <th className="py-2 text-right">TOTAL</th>
                <th className="py-2 text-right">ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {orders && shown.length === 0 && (
                <tr>
                  <td colSpan={6} className="py-6 text-center text-silver">
                    {orders.length === 0 ? "No orders yet." : "No order matches the search."}
                  </td>
                </tr>
              )}
              {shown.map((o) => {
                const active = o.codes.filter((c) => c.is_used).length;
                return [
                  <tr key={o.id} className="border-t border-line/60 align-top">
                    <td className="py-2.5 font-mono font-bold">{o.invoice_no}</td>
                    <td className="py-2.5 text-silver">{invoiceDate(o.created_at)}</td>
                    <td className="py-2.5 font-bold">{o.client_name}</td>
                    <td className="py-2.5">
                      <span className={active === o.codes.length ? "text-fap-green" : "text-silver"}>
                        {active} / {o.codes.length}
                      </span>
                    </td>
                    <td className="py-2.5 text-right font-mono">₱{money(o.total)}</td>
                    <td className="py-2.5 text-right">
                      <div className="flex justify-end gap-1.5">
                        <button onClick={() => pdf(o)} className={actionBtn}>PDF</button>
                        <button onClick={() => downloadCsv(o)} className={actionBtn}>CSV</button>
                        <button onClick={() => copyAll(o)} className={actionBtn}>Copy</button>
                        <button onClick={() => setOpen(open === o.id ? null : o.id)} className={actionBtn}>
                          {open === o.id ? "Hide" : "Codes"}
                        </button>
                      </div>
                    </td>
                  </tr>,
                  open === o.id && (
                    <tr key={`${o.id}-codes`}>
                      <td colSpan={6} className="pb-4">
                        <div className="grid gap-x-6 gap-y-1 rounded-xl border border-line bg-ink/60 p-4 sm:grid-cols-2 lg:grid-cols-3">
                          {o.codes.map((c) => (
                            <div key={c.code} className="flex items-center gap-2 font-mono text-sm">
                              <span className="font-bold">{c.code}</span>
                              <span className="text-xs text-silver">
                                {c.is_used
                                  ? c.platform === "windows"
                                    ? "💻 active"
                                    : "📱 active"
                                  : c.released_at
                                    ? "released"
                                    : "not used"}
                              </span>
                            </div>
                          ))}
                        </div>
                        <p className="mt-2 text-xs text-silver">
                          {o.lines.map((l) => `${l.qty} × ${appInfo(l.app).label} at ₱${money(l.unit_price)}`).join(" · ")}
                          {o.discount > 0 && ` · discount ₱${money(o.discount)}`}
                          {o.client_contact && ` · ${o.client_contact}`}
                        </p>
                      </td>
                    </tr>
                  ),
                ];
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-3 text-xs text-silver">
          An order code that a client activates also shows in LICENSE CODES under its app, where it can be
          released for a new device like any other code.
        </p>
      </section>
    </div>
  );
}
