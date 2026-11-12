"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  DEFAULT_SELLER,
  type Order,
  type Seller,
  downloadCsv,
  downloadInvoicePdf,
  downloadRecordCodesPdf,
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

const inputCls =
  "mt-1 block w-full rounded-lg border border-line bg-ink px-3 py-2.5 text-base text-white outline-none focus:border-cyan";
const labelCls = "block text-xs font-bold tracking-wider text-silver";
const smallBtn = "rounded-md border border-line px-2.5 py-1 text-xs font-bold text-silver hover:text-white";
const bigBtn = "rounded-xl border border-line px-4 py-2.5 text-sm font-bold text-silver hover:text-white";

// ------------------------------------------------------------------ line items

type Draft = Record<AppKey, { qty: string; price: string }>;
type Lines = { app: AppKey; qty: number; price: number; amount: number }[];

const emptyDraft = (prices: Record<string, string>): Draft =>
  Object.fromEntries(APPS.map((a) => [a.key, { qty: "", price: prices[a.key] ?? "" }])) as Draft;

const toNum = (s: string) => (s.trim() === "" ? 0 : Number(s));

function linesOf(draft: Draft): Lines {
  return APPS.map((a) => {
    const qty = toNum(draft[a.key].qty);
    const price = toNum(draft[a.key].price);
    return { app: a.key, qty, price, amount: qty * price };
  });
}

/** Totals and the first problem (or null) of a draft order. */
function check(lines: Lines, discountText: string) {
  const totalQty = lines.reduce((s, l) => s + (Number.isFinite(l.qty) ? l.qty : 0), 0);
  const subtotal = lines.reduce((s, l) => s + (Number.isFinite(l.amount) ? l.amount : 0), 0);
  const discount = toNum(discountText);
  const total = subtotal - (Number.isFinite(discount) ? discount : 0);
  let problem: string | null = null;
  for (const l of lines) {
    if (!Number.isInteger(l.qty) || l.qty < 0 || l.qty > 500) {
      problem = `${appInfo(l.app).label}: quantity must be a whole number from 0 to 500.`;
      break;
    }
    if (!Number.isFinite(l.price) || l.price < 0 || l.price > 1_000_000) {
      problem = `${appInfo(l.app).label}: price must be from 0 to 1,000,000.`;
      break;
    }
  }
  if (!problem && totalQty === 0) problem = "Enter how many codes to make for at least one app.";
  if (!problem && (!Number.isFinite(discount) || discount < 0 || discount > subtotal))
    problem = "The discount must be from 0 up to the subtotal.";
  return { totalQty, subtotal, discount, total, problem };
}

/** Quantity and price per app, used by "New order" and "Add codes". */
function LinesEditor({ draft, setDraft }: { draft: Draft; setDraft: (d: Draft) => void }) {
  const lines = linesOf(draft);
  return (
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
                    aria-label={`${a.label} quantity`}
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
                    aria-label={`${a.label} price`}
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
  );
}

function TotalsBar({
  totals,
  busy,
  label,
  onGo,
}: {
  totals: ReturnType<typeof check>;
  busy: boolean;
  label: string;
  onGo: () => void;
}) {
  return (
    <div className="mt-5 flex flex-wrap items-end gap-4 border-t border-line pt-4">
      <div className="text-sm text-silver">
        {totals.totalQty} codes · Subtotal ₱{money(totals.subtotal)}
        {totals.discount > 0 && <> · Discount ₱{money(totals.discount)}</>}
        <div className="mt-1 text-2xl font-extrabold text-white">
          TOTAL ₱{Number.isFinite(totals.total) ? money(totals.total) : "—"}
        </div>
        <div className="text-xs">No VAT.</div>
      </div>
      <button
        disabled={busy}
        onClick={onGo}
        className="ml-auto rounded-xl bg-cyan px-6 py-3 font-extrabold tracking-wider text-black hover:brightness-110 disabled:opacity-50"
      >
        {busy ? "Generating…" : label}
      </button>
    </div>
  );
}

// ------------------------------------------------------------------ records

/** A client record: its first invoice and every addition, oldest first. */
type ClientRecord = { root: Order; invoices: Order[] };

function groupRecords(orders: Order[]): ClientRecord[] {
  const roots = orders.filter((o) => !o.parent_id);
  const byRecord = new Map<string, Order[]>(roots.map((r) => [r.id, [r]]));
  for (const o of orders) if (o.parent_id) byRecord.get(o.parent_id)?.push(o);
  const records = roots.map((root) => ({
    root,
    invoices: (byRecord.get(root.id) ?? [root]).sort((a, b) => a.created_at.localeCompare(b.created_at)),
  }));
  // Most recent activity first.
  const last = (r: ClientRecord) => r.invoices[r.invoices.length - 1].created_at;
  return records.sort((a, b) => last(b).localeCompare(last(a)));
}

const allCodes = (r: ClientRecord) => r.invoices.flatMap((o) => o.codes);
const billed = (r: ClientRecord) => r.invoices.reduce((s, o) => s + Number(o.total), 0);

/** ORDERS & INVOICES: client records with their invoices and codes. A new
 * order makes a record; "Add codes" puts a new invoice in an existing one. */
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
  const [prices, setPrices] = useState<Record<string, string>>({});
  const [client, setClient] = useState({ name: "", contact: "", address: "", notes: "", discount: "" });
  const [draft, setDraft] = useState<Draft>(() => emptyDraft({}));

  // Saved seller details and last prices live in this browser only.
  useEffect(() => {
    const saved = readJson<Record<string, string>>(PRICES_KEY, {});
    // eslint-disable-next-line react-hooks/set-state-in-effect -- read browser storage after mount
    setSeller(readJson(SELLER_KEY, DEFAULT_SELLER));
    setPrices(saved);
    setDraft(emptyDraft(saved));
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

  const records = useMemo(() => groupRecords(orders ?? []), [orders]);

  const rememberPrices = (d: Draft) => {
    const next = Object.fromEntries(APPS.map((a) => [a.key, d[a.key].price]));
    writeJson(PRICES_KEY, next);
    setPrices(next);
  };

  /** Shared by "New order" and "Add codes": confirm, call, show the result. */
  const submit = async (
    who: string,
    lines: Lines,
    totals: ReturnType<typeof check>,
    call: () => Promise<Order>,
    after: () => void,
  ) => {
    if (totals.problem) {
      setMessage({ text: totals.problem, ok: false });
      return;
    }
    const summary = lines
      .filter((l) => l.qty > 0)
      .map((l) => `${l.qty} × ${appInfo(l.app).label}`)
      .join(", ");
    if (
      !confirm(
        `Create an invoice for ${who}?\n\n${summary}\nTotal: ₱${money(totals.total)}\n\n` +
          `${totals.totalQty} new license codes will be made. This cannot be undone.`,
      )
    )
      return;
    setBusy(true);
    setMessage(null);
    try {
      const order = await call();
      setCreated(order);
      after();
      setMessage({ text: `${order.invoice_no} created: ${order.codes.length} codes.`, ok: true });
      setVersion((v) => v + 1);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  };

  const newLines = linesOf(draft);
  const newTotals = check(newLines, client.discount);
  const createOrder = () => {
    if (!client.name.trim()) {
      setMessage({ text: "Enter the client's name.", ok: false });
      return;
    }
    submit(
      client.name.trim(),
      newLines,
      newTotals,
      () =>
        rpc<Order>("a320_admin_create_order", {
          p_token: token,
          p_client: client.name.trim(),
          p_contact: client.contact.trim(),
          p_address: client.address.trim(),
          p_notes: client.notes.trim(),
          p_discount: Number.isFinite(newTotals.discount) ? newTotals.discount : 0,
          p_lines: newLines.map((l) => ({ app: l.app, qty: l.qty, unit_price: l.price })),
        }),
      () => {
        rememberPrices(draft);
        setClient({ name: "", contact: "", address: "", notes: "", discount: "" });
        setDraft(emptyDraft(Object.fromEntries(APPS.map((a) => [a.key, draft[a.key].price]))));
      },
    );
  };

  const pdf = async (o: Order) => {
    try {
      await downloadInvoicePdf(o, seller);
    } catch {
      setMessage({ text: "Could not make the PDF. Please try again.", ok: false });
    }
  };
  const recordPdf = async (r: ClientRecord) => {
    try {
      await downloadRecordCodesPdf(r.invoices, seller);
    } catch {
      setMessage({ text: "Could not make the PDF. Please try again.", ok: false });
    }
  };
  const copyCodes = (orders: Order[], label: string) => {
    const codes = orders.flatMap((o) => o.codes);
    const text = APPS.filter((a) => codes.some((c) => c.app === a.key))
      .map((a) => `${a.product}\n${codes.filter((c) => c.app === a.key).map((c) => c.code).join("\n")}`)
      .join("\n\n");
    navigator.clipboard
      ?.writeText(text)
      .then(() => setMessage({ text: `${codes.length} codes of ${label} copied.`, ok: true }));
  };

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return records;
    return records.filter(
      (r) =>
        r.root.client_name.toLowerCase().includes(q) ||
        r.invoices.some((o) => o.invoice_no.toLowerCase().includes(q)) ||
        allCodes(r).some((c) => c.code.toLowerCase().includes(q)),
    );
  }, [records, query]);

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
                {created.parent_id && <> · added to record {created.record_invoice_no}</>}
              </div>
            </div>
            <div className="ml-auto flex flex-wrap gap-2">
              <button
                onClick={() => pdf(created)}
                className="rounded-xl bg-cyan px-4 py-2.5 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
              >
                DOWNLOAD INVOICE (PDF)
              </button>
              <button onClick={() => downloadCsv([created], created.invoice_no)} className={bigBtn}>
                Codes (CSV)
              </button>
              <button onClick={() => copyCodes([created], created.invoice_no)} className={bigBtn}>
                Copy codes
              </button>
              <button onClick={() => setCreated(null)} aria-label="Close" className="rounded-xl px-3 py-2.5 text-sm font-bold text-silver hover:text-white">
                ✕
              </button>
            </div>
          </div>
        </section>
      )}

      {/* ------------------------------------------------------------- new order */}
      <section className="rounded-2xl border border-cyan/40 bg-panel/80 p-5 sm:p-6">
        <h2 className="text-lg font-extrabold">New client order</h2>
        <p className="mt-1 text-sm text-silver">
          Makes a new client record with its first invoice. For a client who already has a record, open it
          below and use <b>Add codes</b> instead. Codes made here are the client&apos;s: they are not part of the
          10 unused codes of each app.
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
        <LinesEditor draft={draft} setDraft={setDraft} />
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
        <TotalsBar totals={newTotals} busy={busy} label="GENERATE CODES & INVOICE" onGo={createOrder} />
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

      {/* ------------------------------------------------------------- records */}
      <section className="rounded-2xl border border-line bg-panel/80 p-5">
        <div className="flex flex-wrap items-center gap-3">
          <h2 className="text-lg font-extrabold">
            Client records <span className="text-cyan">({orders ? records.length : "…"})</span>
          </h2>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search client, invoice or code"
            className="ml-auto w-full rounded-lg border border-line bg-ink px-3 py-2 text-sm text-white outline-none focus:border-cyan sm:w-72"
          />
        </div>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[780px] text-left text-sm">
            <thead>
              <tr className="text-xs tracking-wider text-silver">
                <th className="py-2">CLIENT</th>
                <th className="py-2">RECORD</th>
                <th className="py-2">INVOICES</th>
                <th className="py-2">CODES ACTIVATED</th>
                <th className="py-2">LAST INVOICE</th>
                <th className="py-2 text-right">TOTAL BILLED</th>
                <th className="py-2 text-right"></th>
              </tr>
            </thead>
            <tbody>
              {orders && shown.length === 0 && (
                <tr>
                  <td colSpan={7} className="py-6 text-center text-silver">
                    {records.length === 0 ? "No client records yet." : "No record matches the search."}
                  </td>
                </tr>
              )}
              {shown.map((r) => {
                const codes = allCodes(r);
                const active = codes.filter((c) => c.is_used).length;
                const isOpen = open === r.root.id;
                return [
                  <tr key={r.root.id} className={`border-t border-line/60 ${isOpen ? "bg-cyan/5" : ""}`}>
                    <td className="py-2.5 font-bold">{r.root.client_name}</td>
                    <td className="py-2.5 font-mono">{r.root.invoice_no}</td>
                    <td className="py-2.5">{r.invoices.length}</td>
                    <td className="py-2.5">
                      <span className={active === codes.length ? "text-fap-green" : "text-silver"}>
                        {active} / {codes.length}
                      </span>
                    </td>
                    <td className="py-2.5 text-silver">{invoiceDate(r.invoices[r.invoices.length - 1].created_at)}</td>
                    <td className="py-2.5 text-right font-mono">₱{money(billed(r))}</td>
                    <td className="py-2.5 text-right">
                      <button onClick={() => setOpen(isOpen ? null : r.root.id)} className={smallBtn}>
                        {isOpen ? "Close" : "Open"}
                      </button>
                    </td>
                  </tr>,
                  isOpen && (
                    <tr key={`${r.root.id}-detail`}>
                      <td colSpan={7} className="pb-5">
                        <RecordDetail
                          record={r}
                          token={token}
                          busy={busy}
                          setBusy={setBusy}
                          prices={prices}
                          fail={fail}
                          setMessage={setMessage}
                          onChanged={() => setVersion((v) => v + 1)}
                          submit={submit}
                          rememberPrices={rememberPrices}
                          pdf={pdf}
                          recordPdf={recordPdf}
                          copyCodes={copyCodes}
                        />
                      </td>
                    </tr>
                  ),
                ];
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-3 text-xs text-silver">
          An order code that a client activates also shows in LICENSE CODES under its app, where it can be released
          for a new device like any other code.
        </p>
      </section>
    </div>
  );
}

/** One open client record: details (editable), invoices, add codes, all codes. */
function RecordDetail({
  record,
  token,
  busy,
  setBusy,
  prices,
  fail,
  setMessage,
  onChanged,
  submit,
  rememberPrices,
  pdf,
  recordPdf,
  copyCodes,
}: {
  record: ClientRecord;
  token: string;
  busy: boolean;
  setBusy: (b: boolean) => void;
  prices: Record<string, string>;
  fail: (err: unknown) => void;
  setMessage: (m: { text: string; ok: boolean } | null) => void;
  onChanged: () => void;
  submit: (
    who: string,
    lines: Lines,
    totals: ReturnType<typeof check>,
    call: () => Promise<Order>,
    after: () => void,
  ) => Promise<void>;
  rememberPrices: (d: Draft) => void;
  pdf: (o: Order) => void;
  recordPdf: (r: ClientRecord) => void;
  copyCodes: (orders: Order[], label: string) => void;
}) {
  const { root, invoices } = record;
  const [editing, setEditing] = useState(false);
  const [edit, setEdit] = useState({ name: root.client_name, contact: root.client_contact ?? "", address: root.client_address ?? "" });
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState<Draft>(() => emptyDraft(prices));
  const [extra, setExtra] = useState({ notes: "", discount: "" });

  const saveEdit = async () => {
    if (!edit.name.trim()) {
      setMessage({ text: "Enter the client's name.", ok: false });
      return;
    }
    setBusy(true);
    setMessage(null);
    try {
      await rpc("a320_admin_update_record", {
        p_token: token,
        p_record: root.id,
        p_client: edit.name.trim(),
        p_contact: edit.contact.trim(),
        p_address: edit.address.trim(),
      });
      setEditing(false);
      setMessage({ text: `${edit.name.trim()}: client details saved on all ${invoices.length} invoice(s).`, ok: true });
      onChanged();
    } catch (err) {
      fail(err);
    } finally {
      setBusy(false);
    }
  };

  const lines = linesOf(draft);
  const totals = check(lines, extra.discount);
  const addCodes = () =>
    submit(
      `${root.client_name} (record ${root.invoice_no})`,
      lines,
      totals,
      () =>
        rpc<Order>("a320_admin_add_to_order", {
          p_token: token,
          p_record: root.id,
          p_notes: extra.notes.trim(),
          p_discount: Number.isFinite(totals.discount) ? totals.discount : 0,
          p_lines: lines.map((l) => ({ app: l.app, qty: l.qty, unit_price: l.price })),
        }),
      () => {
        rememberPrices(draft);
        setAdding(false);
        setDraft(emptyDraft(Object.fromEntries(APPS.map((a) => [a.key, draft[a.key].price]))));
        setExtra({ notes: "", discount: "" });
      },
    );

  const codes = allCodes(record);
  const perApp = APPS.map((a) => [a, codes.filter((c) => c.app === a.key)] as const).filter(([, l]) => l.length > 0);

  return (
    <div className="space-y-4 rounded-2xl border border-cyan/30 bg-ink/60 p-4 sm:p-5">
      {/* Client details */}
      <div className="flex flex-wrap items-start gap-3">
        {editing ? (
          <div className="grid flex-1 gap-3 sm:grid-cols-3">
            <label className={labelCls}>
              CLIENT NAME *
              <input value={edit.name} onChange={(e) => setEdit({ ...edit, name: e.target.value })} maxLength={120} className={inputCls} />
            </label>
            <label className={labelCls}>
              CONTACT
              <input value={edit.contact} onChange={(e) => setEdit({ ...edit, contact: e.target.value })} maxLength={160} className={inputCls} />
            </label>
            <label className={labelCls}>
              ADDRESS
              <input value={edit.address} onChange={(e) => setEdit({ ...edit, address: e.target.value })} maxLength={300} className={inputCls} />
            </label>
          </div>
        ) : (
          <div className="flex-1">
            <div className="text-xl font-extrabold">{root.client_name}</div>
            <div className="text-sm text-silver">
              {[root.client_contact, root.client_address].filter(Boolean).join(" · ") || "No contact details"}
            </div>
          </div>
        )}
        <div className="flex gap-2">
          {editing ? (
            <>
              <button disabled={busy} onClick={saveEdit} className="rounded-lg bg-cyan px-4 py-2 text-sm font-extrabold text-black disabled:opacity-50">
                Save
              </button>
              <button
                onClick={() => {
                  setEditing(false);
                  setEdit({ name: root.client_name, contact: root.client_contact ?? "", address: root.client_address ?? "" });
                }}
                className="rounded-lg border border-line px-4 py-2 text-sm font-bold text-silver hover:text-white"
              >
                Cancel
              </button>
            </>
          ) : (
            <button onClick={() => setEditing(true)} className="rounded-lg border border-line px-4 py-2 text-sm font-bold text-silver hover:text-white">
              Edit details
            </button>
          )}
        </div>
      </div>

      {/* Invoices */}
      <div>
        <div className="text-xs font-bold tracking-widest text-silver">INVOICES</div>
        <table className="mt-2 w-full text-left text-sm">
          <tbody>
            {invoices.map((o) => (
              <tr key={o.id} className="border-t border-line/60">
                <td className="py-2 pr-3 font-mono font-bold">{o.invoice_no}</td>
                <td className="py-2 pr-3 text-silver">{invoiceDate(o.created_at)}</td>
                <td className="py-2 pr-3 text-silver">
                  {o.lines.map((l) => `${l.qty} ${appInfo(l.app).label}`).join(" · ")}
                  {o.parent_id ? "" : " (first order)"}
                </td>
                <td className="py-2 pr-3 text-right font-mono">₱{money(o.total)}</td>
                <td className="py-2 text-right">
                  <div className="flex justify-end gap-1.5">
                    <button onClick={() => pdf(o)} className={smallBtn}>PDF</button>
                    <button onClick={() => downloadCsv([o], o.invoice_no)} className={smallBtn}>CSV</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add codes */}
      {adding ? (
        <div className="rounded-xl border border-cyan/40 p-4">
          <div className="font-extrabold">Add codes to {root.client_name}</div>
          <p className="text-sm text-silver">
            Makes a new invoice in this record. The client keeps all their old codes.
          </p>
          <LinesEditor draft={draft} setDraft={setDraft} />
          <div className="mt-4 grid gap-4 sm:grid-cols-[1fr_auto]">
            <label className={labelCls}>
              NOTES ON THE INVOICE
              <input value={extra.notes} onChange={(e) => setExtra({ ...extra, notes: e.target.value })} maxLength={500} className={inputCls} />
            </label>
            <label className={labelCls}>
              DISCOUNT (₱)
              <input
                inputMode="decimal"
                value={extra.discount}
                placeholder="0.00"
                onChange={(e) => setExtra({ ...extra, discount: e.target.value.replace(/[^0-9.]/g, "") })}
                className={`${inputCls} sm:w-40`}
              />
            </label>
          </div>
          <TotalsBar totals={totals} busy={busy} label="ADD CODES & MAKE INVOICE" onGo={addCodes} />
          <button onClick={() => setAdding(false)} className="mt-2 text-sm font-bold text-silver hover:text-white">
            Cancel
          </button>
        </div>
      ) : (
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => {
              setDraft(emptyDraft(prices));
              setAdding(true);
            }}
            className="rounded-xl bg-cyan px-5 py-2.5 text-sm font-extrabold tracking-wider text-black hover:brightness-110"
          >
            + ADD CODES
          </button>
          <button onClick={() => recordPdf(record)} className={bigBtn}>
            All codes (PDF)
          </button>
          <button onClick={() => downloadCsv(invoices, `${root.invoice_no}_${root.client_name}_all`)} className={bigBtn}>
            All codes (CSV)
          </button>
          <button onClick={() => copyCodes(invoices, root.client_name)} className={bigBtn}>
            Copy all codes
          </button>
        </div>
      )}

      {/* All codes */}
      <div>
        <div className="text-xs font-bold tracking-widest text-silver">
          ALL CODES ({codes.filter((c) => c.is_used).length} of {codes.length} activated)
        </div>
        {perApp.map(([a, list]) => (
          <div key={a.key} className="mt-3">
            <div className="text-sm font-bold">
              {a.label} <span className="font-normal text-silver">· {list.length}</span>
            </div>
            <div className="mt-1 grid gap-x-6 gap-y-1 sm:grid-cols-2 lg:grid-cols-3">
              {list.map((c) => (
                <div key={c.code} className="flex items-center gap-2 font-mono text-sm">
                  <span className="font-bold">{c.code}</span>
                  <span className={`text-xs ${c.is_used ? "text-fap-green" : "text-silver"}`}>
                    {c.is_used ? (c.platform === "windows" ? "💻 active" : "📱 active") : c.released_at ? "released" : "not used"}
                  </span>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
