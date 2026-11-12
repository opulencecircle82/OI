import type { jsPDF as JsPdf } from "jspdf";
import { appInfo } from "./lib";

export type OrderCode = {
  app: string;
  code: string;
  is_used: boolean;
  platform: string | null;
  used_at: string | null;
  released_at: string | null;
};

export type OrderLine = { app: string; qty: number; unit_price: number; amount: number };

/** One invoice. The first invoice of a client is the record (parent_id null);
 * later additions point to it with parent_id. */
export type Order = {
  id: string;
  parent_id: string | null;
  /** Invoice number of the record this invoice belongs to (its own if first). */
  record_invoice_no: string;
  invoice_no: string;
  created_at: string;
  client_name: string;
  client_contact: string | null;
  client_address: string | null;
  notes: string | null;
  lines: OrderLine[];
  subtotal: number;
  discount: number;
  total: number;
  codes: OrderCode[];
};

/** The seller's own details printed on every invoice (kept in this browser). */
export type Seller = {
  name: string;
  address: string;
  contact: string;
  payment: string;
  footer: string;
};

export const DEFAULT_SELLER: Seller = {
  name: "Overdrive Interactive",
  address: "",
  contact: "",
  payment: "",
  footer: "Thank you for your order.",
};

/** "1,500.00" */
export const money = (n: number) =>
  Number(n).toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** The invoice date in Philippine time, e.g. "12 November 2026". */
export const invoiceDate = (iso: string) =>
  new Date(iso).toLocaleDateString("en-GB", {
    timeZone: "Asia/Manila",
    day: "numeric",
    month: "long",
    year: "numeric",
  });

const fileSafe = (s: string) => s.replace(/[^A-Za-z0-9-]+/g, "_").replace(/^_+|_+$/g, "");

/** Codes as CSV (opens in Excel / Google Sheets). One invoice, or every
 * invoice of a client record. */
export function downloadCsv(orders: Order[], name: string) {
  const esc = (v: string) => `"${v.replace(/"/g, '""')}"`;
  const rows = [
    ["Invoice", "Client", "App", "Code"],
    ...orders.flatMap((o) => o.codes.map((c) => [o.invoice_no, o.client_name, appInfo(c.app).product, c.code])),
  ];
  const csv = "﻿" + rows.map((r) => r.map(esc).join(",")).join("\r\n") + "\r\n";
  save(new Blob([csv], { type: "text/csv;charset=utf-8" }), `${fileSafe(name)}_codes.csv`);
}

function save(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

// Colours (RGB).
type Rgb = [number, number, number];
const NAVY: Rgb = [10, 21, 32];
const CYAN: Rgb = [0, 137, 196];
const BLUE: Rgb = [0, 162, 232];
const INK: Rgb = [19, 32, 44];
const MUTE: Rgb = [91, 107, 122];
const LINE: Rgb = [213, 221, 229];
const PALE: Rgb = [168, 184, 200];
const WHITE: Rgb = [255, 255, 255];

const W = 210;
const M = 18;
const R = W - M;

type TextOpts = { size?: number; bold?: boolean; color?: Rgb; align?: "left" | "right" | "center"; font?: string };

/** Small drawing kit around one jsPDF document. */
function kit(doc: JsPdf) {
  const text = (s: string, x: number, y: number, o: TextOpts = {}) => {
    doc.setFont(o.font ?? "helvetica", o.bold ? "bold" : "normal");
    doc.setFontSize(o.size ?? 10);
    doc.setTextColor(...(o.color ?? INK));
    doc.text(s, x, y, { align: o.align ?? "left" });
  };
  const wrap = (s: string, width: number, size: number) => {
    doc.setFontSize(size);
    return doc.splitTextToSize(s, width) as string[];
  };
  return { text, wrap };
}

async function newDoc() {
  const { jsPDF } = await import("jspdf");
  return new jsPDF({ unit: "mm", format: "a4" });
}

/** "LICENSE CODES" pages: the activation note, then the codes by app in
 * three columns. Starts on a new page when [newPage] is true. */
function drawCodePages(doc: JsPdf, codes: OrderCode[], headerRight: string, newPage: boolean) {
  const { text, wrap } = kit(doc);
  const top = (first: boolean) => {
    if (!first || newPage) doc.addPage();
    doc.setFillColor(...NAVY);
    doc.rect(0, 0, W, 22, "F");
    text("LICENSE CODES", M, 14, { size: 14, bold: true, color: WHITE });
    text(headerRight, R, 14, { size: 9.5, color: PALE, align: "right" });
    return 32;
  };
  let y = top(true);
  const how = wrap(
    "How to activate: install the app, open it, and type the code exactly as shown (capital and small letters " +
      "are different). The internet is needed once for activation; after that the app works offline. Each code " +
      "works on one device at a time. To move a code to a new device, contact your provider.",
    R - M - 8,
    8.5,
  );
  doc.setFillColor(238, 247, 252);
  doc.rect(M, y - 4, R - M, how.length * 4.2 + 5, "F");
  how.forEach((l, i) => text(l, M + 4, y + 1 + i * 4.2, { size: 8.5 }));
  y += how.length * 4.2 + 9;

  const byApp = new Map<string, OrderCode[]>();
  for (const c of codes) byApp.set(c.app, [...(byApp.get(c.app) ?? []), c]);
  const order = ["fap", "mcdu", "cabin", "safety"];
  const apps = [...byApp.keys()].sort((a, b) => order.indexOf(a) - order.indexOf(b));
  const colX = [M, M + 58, M + 116];
  for (const app of apps) {
    const list = byApp.get(app)!;
    const info = appInfo(app);
    if (y > 262) y = top(false);
    text(info.product, M, y, { size: 11.5, bold: true });
    text(`${list.length} code${list.length === 1 ? "" : "s"} · ${info.prefix}`, R, y, { size: 8.5, color: MUTE, align: "right" });
    doc.setDrawColor(...BLUE);
    doc.setLineWidth(0.5);
    doc.line(M, y + 2, R, y + 2);
    y += 9;
    for (let i = 0; i < list.length; i += 3) {
      if (y > 280) {
        y = top(false);
        text(`${info.product} (continued)`, M, y, { size: 10, bold: true, color: MUTE });
        y += 8;
      }
      for (let k = 0; k < 3 && i + k < list.length; k++) {
        text(`${i + k + 1}.`, colX[k] + 7, y, { size: 8.5, color: MUTE, align: "right" });
        text(list[i + k].code, colX[k] + 9, y, { size: 11, bold: true, font: "courier" });
      }
      y += 7;
    }
    y += 5;
  }
}

function drawFooters(doc: JsPdf, label: string) {
  const { text } = kit(doc);
  const pages = doc.getNumberOfPages();
  for (let p = 1; p <= pages; p++) {
    doc.setPage(p);
    doc.setDrawColor(...LINE);
    doc.setLineWidth(0.25);
    doc.line(M, 287, R, 287);
    text(label, M, 291.5, { size: 7.5, color: MUTE });
    text(`Page ${p} / ${pages}`, R, 291.5, { size: 7.5, color: MUTE, align: "right" });
  }
}

/** Builds one invoice PDF (invoice page, then its license codes) and downloads it. */
export async function downloadInvoicePdf(order: Order, seller: Seller) {
  const doc = await newDoc();
  const { text, wrap } = kit(doc);
  const sellerName = seller.name || DEFAULT_SELLER.name;

  // ---------------------------------------------------------------- header band
  doc.setFillColor(...NAVY);
  doc.rect(0, 0, W, 40, "F");
  doc.setDrawColor(...BLUE);
  doc.setLineWidth(0.8);
  doc.roundedRect(M, 10, 18, 18, 3, 3, "S");
  text("OI", M + 9, 22, { size: 13, bold: true, color: BLUE, align: "center", font: "courier" });
  text(sellerName, M + 24, 17, { size: 14, bold: true, color: WHITE });
  let hy = 22.5;
  for (const line of [seller.address, seller.contact].filter(Boolean)) {
    for (const l of wrap(line, 95, 8.5)) {
      text(l, M + 24, hy, { size: 8.5, color: PALE });
      hy += 4;
    }
  }
  text("INVOICE", R, 20, { size: 24, bold: true, color: WHITE, align: "right" });
  text(order.invoice_no, R, 28, { size: 11, bold: true, color: BLUE, align: "right", font: "courier" });
  if (order.parent_id) {
    text(`Additional codes · record ${order.record_invoice_no}`, R, 34, { size: 8, color: PALE, align: "right" });
  }

  // ---------------------------------------------------------------- bill to / meta
  let y = 54;
  text("BILL TO", M, y, { size: 8, bold: true, color: MUTE });
  text(order.client_name, M, y + 6.5, { size: 13, bold: true });
  let by = y + 12;
  for (const line of [order.client_contact, order.client_address].filter(Boolean) as string[]) {
    for (const l of wrap(line, 95, 9)) {
      text(l, M, by, { size: 9, color: MUTE });
      by += 4.6;
    }
  }
  const meta: [string, string][] = [
    ["INVOICE NO.", order.invoice_no],
    ["DATE", invoiceDate(order.created_at)],
    ["CURRENCY", "Philippine peso (PHP)"],
  ];
  meta.forEach(([k, v], i) => {
    text(k, 128, y + i * 7, { size: 8, bold: true, color: MUTE });
    text(v, R, y + i * 7, { size: 9.5, bold: true, align: "right" });
  });
  doc.setFillColor(238, 247, 252);
  doc.roundedRect(124, y + 18, R - 124, 14, 2, 2, "F");
  text("AMOUNT DUE", 128, y + 26.5, { size: 8, bold: true, color: CYAN });
  text(`PHP ${money(order.total)}`, R - 3, y + 27, { size: 13, bold: true, align: "right" });

  // ---------------------------------------------------------------- lines table
  y = Math.max(by, y + 34) + 8;
  const cols = { item: M + 2, qty: 124, unit: 158, amount: R - 2 };
  doc.setFillColor(...NAVY);
  doc.rect(M, y, R - M, 9, "F");
  text("ITEM", cols.item, y + 6, { size: 8.5, bold: true, color: WHITE });
  text("QTY", cols.qty, y + 6, { size: 8.5, bold: true, color: WHITE, align: "right" });
  text("UNIT PRICE", cols.unit, y + 6, { size: 8.5, bold: true, color: WHITE, align: "right" });
  text("AMOUNT", cols.amount, y + 6, { size: 8.5, bold: true, color: WHITE, align: "right" });
  y += 9;
  for (const line of order.lines) {
    const info = appInfo(line.app);
    y += 7;
    text(`${info.product} - license code`, cols.item, y, { size: 10, bold: true });
    text(`Codes start with ${info.prefix} · each activates one device`, cols.item, y + 4.6, { size: 8, color: MUTE });
    text(String(line.qty), cols.qty, y, { size: 10, align: "right" });
    text(money(line.unit_price), cols.unit, y, { size: 10, align: "right" });
    text(money(line.amount), cols.amount, y, { size: 10, bold: true, align: "right" });
    y += 8;
    doc.setDrawColor(...LINE);
    doc.setLineWidth(0.25);
    doc.line(M, y, R, y);
  }

  // ---------------------------------------------------------------- totals
  y += 8;
  const totalRow = (label: string, value: string, bold = false) => {
    text(label, 150, y, { size: bold ? 11 : 9.5, bold, color: bold ? INK : MUTE, align: "right" });
    text(value, R - 2, y, { size: bold ? 11 : 9.5, bold, align: "right" });
    y += bold ? 8 : 6;
  };
  totalRow("Subtotal", `PHP ${money(order.subtotal)}`);
  if (Number(order.discount) > 0) totalRow("Discount", `- PHP ${money(order.discount)}`);
  doc.setDrawColor(...BLUE);
  doc.setLineWidth(0.6);
  doc.line(112, y - 3, R, y - 3);
  y += 2;
  totalRow("TOTAL", `PHP ${money(order.total)}`, true);
  text("No VAT.", R - 2, y - 2, { size: 7.5, color: MUTE, align: "right" });

  // ---------------------------------------------------------------- notes, payment
  y += 6;
  const block = (title: string, body: string) => {
    if (!body.trim()) return;
    const lines = wrap(body, R - M, 9);
    text(title, M, y, { size: 8, bold: true, color: MUTE });
    y += 5;
    for (const l of lines) {
      text(l, M, y, { size: 9 });
      y += 4.6;
    }
    y += 4;
  };
  block("NOTES", order.notes ?? "");
  block("PAYMENT", seller.payment);
  const n = order.codes.length;
  block(
    "LICENSE CODES",
    `${n} license code${n === 1 ? " is" : "s are"} listed on the next page${n > 60 ? "s" : ""}. ` +
      "Each code activates the app on one device (Android or Windows) and is case-sensitive. Keep the codes private.",
  );
  if (seller.footer.trim()) text(seller.footer.trim(), M, Math.max(y + 2, 262), { size: 10, bold: true, color: CYAN });

  drawCodePages(doc, order.codes, `${order.invoice_no} · ${order.client_name}`, true);
  drawFooters(doc, `${sellerName} · Invoice ${order.invoice_no}`);
  doc.setProperties({ title: `Invoice ${order.invoice_no} - ${order.client_name}`, author: sellerName });
  save(doc.output("blob"), `${order.invoice_no}_${fileSafe(order.client_name)}.pdf`);
}

/** Every code of a client record (all its invoices) in one PDF, with a
 * summary of the invoices on the first page. */
export async function downloadRecordCodesPdf(invoices: Order[], seller: Seller) {
  const doc = await newDoc();
  const { text } = kit(doc);
  const sellerName = seller.name || DEFAULT_SELLER.name;
  const sorted = [...invoices].sort((a, b) => a.created_at.localeCompare(b.created_at));
  const record = sorted[0];
  const codes = sorted.flatMap((o) => o.codes);

  doc.setFillColor(...NAVY);
  doc.rect(0, 0, W, 40, "F");
  text(sellerName, M, 17, { size: 14, bold: true, color: WHITE });
  text("ALL LICENSE CODES", M, 27, { size: 10, bold: true, color: BLUE });
  text(record.client_name, R, 20, { size: 15, bold: true, color: WHITE, align: "right" });
  text(`Record ${record.record_invoice_no}`, R, 28, { size: 10, bold: true, color: BLUE, align: "right", font: "courier" });

  let y = 54;
  text("INVOICES IN THIS RECORD", M, y, { size: 8, bold: true, color: MUTE });
  y += 4;
  doc.setFillColor(...NAVY);
  doc.rect(M, y, R - M, 9, "F");
  text("INVOICE", M + 2, y + 6, { size: 8.5, bold: true, color: WHITE });
  text("DATE", 70, y + 6, { size: 8.5, bold: true, color: WHITE });
  text("CODES", 150, y + 6, { size: 8.5, bold: true, color: WHITE, align: "right" });
  text("TOTAL", R - 2, y + 6, { size: 8.5, bold: true, color: WHITE, align: "right" });
  y += 9;
  for (const o of sorted) {
    y += 7;
    text(o.invoice_no, M + 2, y, { size: 10, bold: true, font: "courier" });
    text(invoiceDate(o.created_at), 70, y, { size: 9.5 });
    text(String(o.codes.length), 150, y, { size: 9.5, align: "right" });
    text(`PHP ${money(o.total)}`, R - 2, y, { size: 9.5, align: "right" });
    y += 4;
    doc.setDrawColor(...LINE);
    doc.setLineWidth(0.25);
    doc.line(M, y, R, y);
  }
  y += 9;
  const counts = ["fap", "mcdu", "cabin", "safety"]
    .map((a) => [a, codes.filter((c) => c.app === a).length] as const)
    .filter(([, k]) => k > 0)
    .map(([a, k]) => `${k} ${appInfo(a).product}`)
    .join(" · ");
  text(`${codes.length} codes in total: ${counts}`, M, y, { size: 10, bold: true });

  drawCodePages(doc, codes, `Record ${record.record_invoice_no} · ${record.client_name}`, true);
  drawFooters(doc, `${sellerName} · ${record.client_name} · record ${record.record_invoice_no}`);
  doc.setProperties({ title: `License codes - ${record.client_name}`, author: sellerName });
  save(doc.output("blob"), `${record.record_invoice_no}_${fileSafe(record.client_name)}_all_codes.pdf`);
}
