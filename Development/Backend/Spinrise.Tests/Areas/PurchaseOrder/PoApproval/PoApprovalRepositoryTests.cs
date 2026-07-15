using System.Data;
using Dapper;
using FluentAssertions;
using Spinrise.Application.Areas.PurchaseOrder.PoApproval.DTOs;
using Spinrise.Infrastructure.Areas.PurchaseOrder.PoApproval;

namespace Spinrise.Tests.Areas.PurchaseOrder.PoApproval;

// 10-Jul-2026 /verify follow-up: the @Disposition/@PostponeDate parameter-wiring gap
// (PoApprovalRepository.SetApprovalAsync silently omitting them, then a later fix
// wiring them for all 3 levels without checking Second/Final's live SP signature)
// shipped with zero test coverage — Dapper's ExecuteAsync is an extension method on
// IDbConnection and can't be intercepted via Moq, so the repository's SQL-facing
// behavior was previously untestable. BuildSetApprovalParameters was extracted as a
// pure function specifically so this class of regression is caught here instead of
// live, against a real SP, against real data.
public class PoApprovalRepositoryTests
{
    private static PoApprovalSaveItemRequest MakeItem(
        int disposition = 2, string? remarks = "remarks", string? postponeDate = null) =>
        new("01", 1234m, "2026-07-10", disposition, remarks, postponeDate);

    private static object? GetValue(DynamicParameters p, string name)
    {
        var lookup = (SqlMapper.IParameterLookup)p;
        return lookup[name];
    }

    [Fact]
    public void BuildSetApprovalParameters_IncludesDisposition()
    {
        var p = PoApprovalRepository.BuildSetApprovalParameters(
            MakeItem(disposition: 4), "KSL", "KALSOFTE", "127.0.0.1", "host");

        p.ParameterNames.Should().Contain("Disposition");
        GetValue(p, "Disposition").Should().Be(4);
    }

    [Fact]
    public void BuildSetApprovalParameters_PostponeNull_SendsDbNull()
    {
        var p = PoApprovalRepository.BuildSetApprovalParameters(
            MakeItem(disposition: 2, postponeDate: null), "KSL", "KALSOFTE", null, null);

        p.ParameterNames.Should().Contain("PostponeDate");
        var value = GetValue(p, "PostponeDate");
        (value is null or DBNull).Should().BeTrue();
    }

    [Fact]
    public void BuildSetApprovalParameters_PostponeDisposition_ParsesDate()
    {
        var p = PoApprovalRepository.BuildSetApprovalParameters(
            MakeItem(disposition: 5, postponeDate: "2026-08-01"), "KSL", "KALSOFTE", null, null);

        GetValue(p, "PostponeDate").Should().Be(new DateTime(2026, 8, 1));
    }

    [Fact]
    public void BuildSetApprovalParameters_DivCode_ComesFromItemNotCaller()
    {
        var item = new PoApprovalSaveItemRequest("07", 1234m, "2026-07-10", 2, "r", null);
        var p = PoApprovalRepository.BuildSetApprovalParameters(item, "KSL", "KALSOFTE", null, null);

        GetValue(p, "DivCode").Should().Be("07");
    }

    [Fact]
    public void BuildSetApprovalParameters_RowVersion_IsAlwaysNull()
    {
        // CD-08 gap (CR-PO-APPROVAL-01 Open Question 2) — frontend never supplies a
        // row_version token; must stay NULL so the SP's own bypass branch runs.
        var p = PoApprovalRepository.BuildSetApprovalParameters(
            MakeItem(), "KSL", "KALSOFTE", null, null);

        var value = GetValue(p, "RowVersion");
        (value is null or DBNull).Should().BeTrue();
    }

    [Fact]
    public void BuildSetApprovalParameters_HasResultOutputParameter()
    {
        var p = PoApprovalRepository.BuildSetApprovalParameters(
            MakeItem(), "KSL", "KALSOFTE", null, null);

        p.ParameterNames.Should().Contain("Result");
    }
}
