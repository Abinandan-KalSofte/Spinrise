using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using QuestPDF.Fluent;
using QuestPDF.Infrastructure;
using Spinrise.Application.Areas.PurchaseOrder.PoReport.DTOs;
using Spinrise.Reports.Areas.PurchaseOrder.Documents;

QuestPDF.Settings.License = LicenseType.Community;

// Live-data render harness for the PO List reports (Date-wise + Item-wise).
// Connects to the internal JAT DB, runs the report SPs, renders each QuestPDF
// document against real data. Read-only.
const string ConnStr = @"Server=172.16.16.52\sql2016;Database=JAT;User ID=sa;Password=;TrustServerCertificate=True;";
const string DivCode = "01";
var fromDate = new DateTime(2026, 7, 1);
var toDate   = new DateTime(2026, 7, 6);
var outDir   = @"D:\SpinriseV2\Docs\Deployments\20260706\pdf_pulls";
Directory.CreateDirectory(outDir);

var request = new PoReportRequest { DivCode = DivCode, FromDate = fromDate, ToDate = toDate };

using IDbConnection db = new SqlConnection(ConnStr);
db.Open();

// ── Date-wise ──
var dateRows = (await db.QueryAsync<PoDateWiseRowDto>(
    "ksp_PO_DateWise_Report",
    new { Divcode = DivCode, FromDate = fromDate, ToDate = toDate },
    commandType: CommandType.StoredProcedure)).ToList();
var datePath = Path.Combine(outDir, "PO_DateWise_live.pdf");
new PoDateWiseDocument(dateRows, request).GeneratePdf(datePath);
Console.WriteLine($"Date-wise : {dateRows.Count,4} rows -> {datePath}");

// ── Item-wise ──
var itemRows = (await db.QueryAsync<PoItemWiseRowDto>(
    "ksp_PO_ItemWise_Report",
    new { Divcode = DivCode, FromDate = fromDate.ToString("yyyy-MM-dd"), ToDate = toDate.ToString("yyyy-MM-dd"), FItem = "A", TItem = "A", Opt = "A" },
    commandType: CommandType.StoredProcedure)).ToList();
var itemPath = Path.Combine(outDir, "PO_ItemWise_live.pdf");
new PoItemWiseDocument(itemRows, request).GeneratePdf(itemPath);
Console.WriteLine($"Item-wise : {itemRows.Count,4} rows -> {itemPath}");

// ── Supplier-wise (the reconciled gold standard — render for side-by-side) ──
var supRows = (await db.QueryAsync<PoSupplierWiseRowDto>(
    "ksp_PO_SupplierWise_Report",
    new { Divcode = DivCode, FromDate = fromDate, ToDate = toDate, SupplierCode = (string?)null },
    commandType: CommandType.StoredProcedure)).ToList();
var supPath = Path.Combine(outDir, "PO_SupplierWise_live.pdf");
new PoSupplierWiseDocument(supRows, request).GeneratePdf(supPath);
Console.WriteLine($"Supplier  : {supRows.Count,4} rows -> {supPath}");

Console.WriteLine("Done.");
